pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.qmlmodels
import Rekta
import "TrayRules.js" as TrayRules

// The menu of the background apps, in one floating surface (ADR: in place). It lists the apps, one row each: their icon,
// word and state. A row's menu replaces the list, headed by a back row; an entry with children opens the next level the
// same way. Escape and ← go back one level, Tab closes everything, choosing a leaf triggers it and closes.
//
// `apps` are objects with word, icon, state, hasMenu, menu and activate(). `opener` makes an object with a
// `menu` property and `children.values`, the entries of that menu (Quickshell's QsMenuOpener), one per level.
Menu {
    id: tray

    property var apps: []
    property Component opener
    // Whether the icon theme has an icon of this name, as the host learns from its theme; until it says, none.
    property var iconKnown: name => false
    // One frame per level in view: the app, its opener, the index of the row that opened the level, and that row's words.
    property var levels: []
    readonly property var current: levels.length > 0 ? levels[levels.length - 1].opener.children.values : apps
    // What the rows show: `current` once it has entries, so a level whose entries are still loading changes nothing.
    property var shown: []
    // Where the focus goes once a level's rows are there: DBusMenu hands them over a moment after the level opens.
    property var focusOnFill: null

    // Keeps the level in view in sync with what its owner reports.
    function refill() {
        // ponytail: a submenu that never has entries keeps the previous rows in view; back still leaves it.
        if (levels.length > 0 && current.length === 0)
            return;
        const was = focusedIndex();
        shown = current;
        rowKinds.clear();
        for (let at = 0; at < shown.length; at++)
            rowKinds.append({ kind: levels.length === 0 ? "app" : shown[at].isSeparator ? "separator" : "entry", at });
        if (focusOnFill !== null) {
            // Later: the back row's visibility follows `levels` only once its binding has run.
            Qt.callLater(focusOnFill);
            focusOnFill = null;
        } else if (was >= 0) {
            focusAt(was);
        }
    }

    function enter(app: var, handle: var, row: Item) {
        const byKeys = focusedIndex() >= 0;
        const opener = tray.opener.createObject(tray, { menu: handle });
        focusOnFill = byKeys ? focusLevelStart : null;
        levels = [...levels, { app, opener, from: items().indexOf(row), name: levels.length === 0 ? app.word : handle.text }];
        if (!byKeys)
            forceActiveFocus();
    }

    function leave() {
        const byKeys = focusedIndex() >= 0;
        const frame = levels[levels.length - 1];
        focusOnFill = byKeys ? () => focusAt(frame.from) : null;
        levels = levels.slice(0, -1);
        frame.opener.destroy();
        if (!byKeys)
            forceActiveFocus();
    }

    function reset() {
        focusOnFill = null;
        levels.forEach(frame => frame.opener.destroy());
        levels = [];
    }

    function openMenuOf(row: Item) {
        const app = (row as AppRow)?.app;
        if (app?.hasMenu)
            enter(app, app.menu, row);
        const entry = (row as EntryRow)?.entry;
        if (entry?.hasChildren)
            enter(levels[0].app, entry, row);
    }

    function press(app: var, row: Item) {
        if (app.hasMenu)
            enter(app, app.menu, row);
        else
            app.activate();
    }

    function pressEntry(entry: var, row: Item) {
        if (entry.hasChildren)
            enter(levels[0].app, entry, row);
        else
            entry.triggered();
    }

    back: levels.length > 0 ? leave : null
    backName: levels.length > 0 ? levels[levels.length - 1].name : ""
    backWord: "zurück"
    onCurrentChanged: refill()
    // On opening rather than closing: a choice is told after the menu has closed, and its row must still be its own.
    onOpenChanged: {
        if (open)
            reset();
    }
    // → opens the menu of the focused row.
    Keys.onRightPressed: event => {
        const row = items()[focusedIndex()];
        event.accepted = row !== undefined;
        if (row)
            openMenuOf(row);
    }
    onChosen: item => {
        const app = (item as AppRow)?.app;
        if (app)
            press(app, item);
        const entry = (item as EntryRow)?.entry;
        if (entry)
            pressEntry(entry, item);
        items().forEach(row => (row as EntryRow)?.follow());
    }

    // The secondary button opens the menu of the row under the pointer, whether or not its app has a window.
    TapHandler {
        acceptedButtons: Qt.RightButton
        longPressThreshold: 0

        onTapped: eventPoint => {
            const row = parent.childAt(eventPoint.position.x, eventPoint.position.y);
            if (row)
                tray.openMenuOf(row);
        }
    }

    ListModel {
        id: rowKinds
    }

    Repeater {
        model: rowKinds

        delegate: DelegateChooser {
            role: "kind"

            DelegateChoice {
                roleValue: "app"

                AppRow {}
            }

            DelegateChoice {
                roleValue: "entry"

                EntryRow {}
            }

            DelegateChoice {
                roleValue: "separator"

                MenuSeparator {}
            }
        }
    }

    // Loads an app's picture unseen and hands it on only once it is no checkerboard of Quickshell's for a picture it
    // could not get, so a row never shows that, not even for a frame. Quickshell hands that over as a ready picture of
    // the size asked for, like a real one, so only its pixels tell. Until a new picture is judged, the last one stays.
    component PictureCheck: Item {
        id: check

        property string source
        // The last source known to be a real picture, else empty.
        property string real: ""

        function verdict(): string {
            // The canvas announces itself only later (a queued availableChanged), maybe while a new picture loads.
            if (loaded.status === Image.Loading)
                return check.real;
            // A row that has left its window has no context.
            const context = reader.available ? reader.getContext("2d") : null;
            if (context === null || loaded.status !== Image.Ready)
                return "";
            // The image `loaded` has just put into Qt's cache, so the canvas takes it from there at once and never
            // asks the provider itself: on a reader thread Quickshell's providers are unsafe (QQuickPixmap::load).
            const url = loaded.source.toString();
            reader.loadImage(url);
            const shown = reader.isImageLoaded(url) && !TrayRules.checkerboard(context.createImageData(url));
            // The canvas keeps every image it loaded until unloaded, and an app may send a new picture each second.
            reader.unloadImage(url);
            return shown ? url : "";
        }

        objectName: "pictureCheck"
        visible: false

        // Loads in the GUI thread, where Quickshell's providers expect to be asked.
        Image {
            id: loaded

            objectName: "pictureLoaded"
            source: check.source
            asynchronous: false
            onStatusChanged: check.real = check.verdict()
        }

        Canvas {
            id: reader

            objectName: "pictureReader"
            width: 1
            height: 1
            onAvailableChanged: check.real = check.verdict()
        }
    }

    // A running app. Pressing an app with a menu of its own opens that menu in place, even when the app has a window;
    // pressing one without brings it forward.
    component AppRow: MenuItem {
        id: appRow

        required property int at
        readonly property var app: tray.shown[at] ?? null

        text: app?.word ?? ""
        icon: picture.real
        keyHint: app?.state ?? ""
        opensLevel: app?.hasMenu ?? false
        Accessible.name: keyHint !== "" ? `${text}, ${keyHint}` : text

        PictureCheck {
            id: picture

            source: TrayRules.shownIcon(appRow.app?.icon ?? "", tray.iconKnown)
        }
    }

    // An entry of an app's menu; its words and its icon, if it has one, are the app's own.
    component EntryRow: MenuItem {
        id: row

        required property int at
        readonly property var entry: tray.shown[at] ?? null

        text: entry?.text ?? ""
        icon: picture.real
        kind: entry?.buttonType === 1 ? "checkbox" : entry?.buttonType === 2 ? "radio" : "item"
        checked: entry?.checkState === Qt.Checked
        dimmed: !(entry?.enabled ?? true)
        opensLevel: entry?.hasChildren ?? false

        // The choice flips the box on its own; this lets the app's answer set it right again.
        function follow() {
            checked = Qt.binding(() => entry?.checkState === Qt.Checked);
        }

        PictureCheck {
            id: picture

            source: TrayRules.shownIcon(row.entry?.icon ?? "", tray.iconKnown)
        }
    }
}
