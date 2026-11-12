pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.kicker as Kicker
import Panel
import Rekta
import RektaShell.DBus

// "zuletzt" in the Start: the files used last, newest first, at most ten, each a row as "heute" has them, on hairlines:
// the file type's icon, the name, the folder under it, cut, and how long ago at the end. It is a view: nothing is
// removed here. A press opens the file. KDE's activity manager keeps what was used; Kickoff's model reads it. A file
// used anew enters at the top and the eleventh leaves (motion.md, "Arriving, leaving"); held under the pointer or the
// focus it stands still and counts the waiting updates (live.md, "Holding still"). Without the activity manager it
// says so with a retry (states.md, "Data states"), and asks again each time the Start opens.
Column {
    id: recent

    // Off, there is no model: nothing reads what was used.
    property bool active: true
    // The Start shows: the activity manager is asked again whenever this turns true.
    property bool inSight: false
    // Opens an address in the program the user has for it.
    property var openUrl: null
    property var locale: Qt.locale()
    // The wall clock, replaceable for tests.
    property var clock: () => new Date()
    property var now: clock()
    readonly property int most: 10
    // PlasmaActivitiesStats' ResultModel::LastUpdateRole, the last use in seconds, which Kickoff's model has no role for.
    readonly property int lastUpdateRole: Qt.UserRole + 4
    // Whether the activity manager answers on the bus: "" until asked, "up" or "down".
    property string service: ""
    readonly property var source: models.object
    // The files the model lists, newest first: {url, name, folder, icon, stamp}.
    property var listed: []
    readonly property bool holdsFocus: {
        let item = Window.window?.activeFocusItem;
        while (item && item !== recent)
            item = item.parent;
        return item === recent;
    }
    readonly property bool held: hover.hovered || holdsFocus
    readonly property int waiting: held ? waitingCount() : 0

    // A file was opened: its program has the screen now.
    signal chosen

    // What a key or a press reaches, from the top.
    function entries(): var {
        return Array.from({ length: rowItems.count }, (_, k) => rowItems.itemAt(k)).filter(row => row?.visible && !row.going);
    }

    function check() {
        if (!active)
            return;
        bus.call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "NameHasOwner", ["org.kde.ActivityManager"], "s", (error, values) => {
            recent.service = !error && values[0] === true ? "up" : "down";
        });
    }

    function relist() {
        const stamps = source?.sourceModel;
        const files = [];
        for (let k = 0; k < rows.count; k++) {
            const row = rows.objectAt(k) as FileRecord;
            if (!row)
                continue;
            files.push({
                url: String(row.url),
                name: row.display,
                folder: row.description,
                icon: typeof row.decoration === "string" && row.decoration !== "" ? `image://icon/${row.decoration}` : "",
                stamp: 1000 * Number(stamps?.data(stamps.index(k, 0), lastUpdateRole) ?? 0)
            });
        }
        listed = files;
        follow();
    }

    function follow() {
        if (!held)
            showNewest();
    }

    // The rows follow the newest files: those no longer among them leave, new ones come in where their last use puts
    // them, and one used anew moves up, keeping its item and its focus.
    function showNewest() {
        const wanted = listed.slice(0, most);
        const urls = wanted.map(file => file.url);
        for (let k = 0; k < shown.count; k++) {
            if (!urls.includes(shown.get(k).url))
                (rowItems.itemAt(k) as MessageRow)?.leave();
        }
        for (const file of wanted) {
            const at = indexOf(file.url);
            if (at < 0) {
                shown.insert(rank(file, -1), fields(file));
                continue;
            }
            shown.set(at, fields(file));
            const to = rank(file, at);
            if (to !== at)
                shown.move(at, to, 1);
        }
    }

    // Where a file stands among the rows but the one at `except`: after every newer one.
    function rank(file: var, except: int): int {
        const order = url => {
            const at = listed.findIndex(other => other.url === url);
            return at < 0 ? Infinity : at;
        };
        let count = 0;
        for (let k = 0; k < shown.count; k++) {
            const row = shown.get(k);
            if (k !== except && (row.stamp > file.stamp || (row.stamp === file.stamp && order(row.url) < order(file.url))))
                count++;
        }
        return count;
    }

    function indexOf(url: string): int {
        for (let k = 0; k < shown.count; k++) {
            if (shown.get(k).url === url)
                return k;
        }
        return -1;
    }

    function waitingCount(): int {
        const newest = shown.count > 0 ? shown.get(0).stamp : -Infinity;
        const came = listed.slice(0, most).filter(file => {
            const at = indexOf(file.url);
            // An older one that moves up as a newer goes is no news of its own.
            return at < 0 ? file.stamp > newest : shown.get(at).stamp !== file.stamp || shown.get(at).summary !== file.name;
        });
        const gone = Array.from({ length: shown.count }, (_, k) => k).filter(k => {
            const staying = !(rowItems.itemAt(k) as MessageRow)?.going;
            return staying && !listed.some(file => file.url === shown.get(k).url);
        });
        return came.length + gone.length;
    }

    // The roles a MessageRow takes: the name as its summary, the folder as its line.
    function fields(file: var): var {
        return {
            order: 0,
            url: file.url,
            app: "",
            summary: file.name,
            body: file.folder,
            icon: file.icon,
            stamp: file.stamp,
            actions: "[]"
        };
    }

    function open(url: string) {
        recent.openUrl?.(url);
        recent.chosen();
    }

    component FileRecord: QtObject {
        required property var display
        required property var decoration
        required property var description
        required property var url
    }

    objectName: "zuletzt"
    width: parent ? parent.width : 0
    Component.onCompleted: check()
    onInSightChanged: {
        if (inSight)
            check();
    }
    onActiveChanged: check()
    onHeldChanged: follow()

    DBusConnection {
        id: bus
    }

    Instantiator {
        id: models

        active: recent.active && recent.service === "up"

        Kicker.RecentUsageModel {
            shownItems: Kicker.RecentUsageModel.OnlyDocs
            ordering: Kicker.RecentUsageModel.Recent
        }
    }

    // A record for each file the model lists, to read its roles by name.
    Instantiator {
        id: rows

        model: recent.source
        onObjectAdded: Qt.callLater(recent.relist)
        onObjectRemoved: Qt.callLater(recent.relist)

        delegate: FileRecord {}
    }

    Connections {
        target: recent.source
        ignoreUnknownSignals: true

        function onDataChanged() {
            Qt.callLater(recent.relist);
        }

        function onRowsMoved() {
            Qt.callLater(recent.relist);
        }

        function onModelReset() {
            Qt.callLater(recent.relist);
        }

        function onLayoutChanged() {
            Qt.callLater(recent.relist);
        }
    }

    HoverHandler {
        id: hover
    }

    // Once a minute while in sight; coming into sight it catches up at once.
    Timer {
        objectName: "tick"
        interval: Calendar.untilNextMinute(recent.now)
        running: recent.visible
        repeat: true
        onTriggered: recent.now = recent.clock()
        onRunningChanged: {
            if (running)
                recent.now = recent.clock();
        }
    }

    Column {
        objectName: "recentRows"
        width: recent.width
        visible: recent.service === "up"
        add: RowArrival {}
        move: RowsMakeRoom {}

        Repeater {
            id: rowItems

            model: ListModel {
                id: shown
            }

            delegate: MessageRow {
                id: row

                required property string url
                readonly property bool opens: true

                now: recent.now
                locale: recent.locale
                removable: false
                // On the Start's glass a ring in `bg` would show: the icon keeps Rekta's square crop.
                ground: "transparent"
                onPressed: recent.open(row.url)
                // A row that left and is wanted again comes back in.
                onGone: {
                    shown.remove(recent.indexOf(row.url));
                    recent.follow();
                }
            }
        }
    }

    Hairline {
        width: recent.width
        visible: recent.service === "up" && shown.count > 0
    }

    Empty {
        objectName: "recentEmpty"
        width: recent.width
        visible: recent.service === "up" && shown.count === 0
        text: "noch keine datei geöffnet."
    }

    Empty {
        objectName: "recentFailed"
        width: recent.width
        visible: recent.service === "down"
        failed: true
        text: "zuletzt geöffnete dateien lassen sich nicht laden: der dienst von kde, der sie sich merkt, läuft nicht. eine neue anmeldung startet ihn."

        Button {
            objectName: "retry"
            text: "neu laden"
            onClicked: recent.check()
        }
    }

    LiveMore {
        objectName: "waiting"
        count: recent.waiting
        onClicked: {
            const hadFocus = activeFocus;
            recent.showNewest();
            // The button goes once nothing waits; the focus stays in the region.
            if (hadFocus)
                recent.entries()[0]?.forceActiveFocus();
        }
    }
}
