pragma ComponentBehavior: Bound

import QtQuick
import Notices
import Panel
import Rekta
import State

// "heute" in the Start: what plays, then the newest three notifications, each a row as in the centre (live.md:78–82),
// on hairlines. It is a view of them, not a second centre: no ×, no actions, and nothing is seen here. A press
// brings the player's window to the front, or does what a press on the centre's row does. A new notification enters at
// the top and the oldest of the three leaves (motion.md, "Arriving, leaving"); a new track peeks in (motion.md, "Live
// tile news"). While the pointer rests on it or the focus is in it, it holds still, a quiet button counts the waiting
// updates, and it catches up once let go or the button is pressed (live.md, "Holding still"). The times are told
// against `now`, renewed once a minute while it is in sight. With nothing to show, a sentence says so (states.md,
// "Data states").
Column {
    id: today

    property NoticeBoard board: null
    property PlayerChoice choice: null
    // The open windows, for a player that cannot raise its own: {appId, activate()}.
    property var windows: []
    property var locale: Qt.locale()
    // The wall clock, replaceable for tests.
    property var clock: () => new Date()
    property var now: clock()
    readonly property int notices: 3
    readonly property var player: choice?.player ?? null
    // "title · artist", as the bar's middle has it without the time.
    readonly property string track: Middle.musicParts(player?.trackTitle ?? "", player?.trackArtist ?? "", 0, 0)[0] ?? ""
    // The track the row shows, which follows `track` through its news.
    property string shownTrack: ""
    readonly property bool holdsFocus: {
        let item = Window.window?.activeFocusItem;
        while (item && item !== today)
            item = item.parent;
        return item === today;
    }
    readonly property bool held: hover.hovered || holdsFocus
    readonly property bool idle: shownTrack === "" && shown.count === 0
    // How many updates wait while it is held, one per notification that came, changed or closed, and one for the track
    // (rekta.js:3760: the same key replaces a waiting update).
    readonly property int waiting: held ? waitingCount() : 0

    // An entry was pressed: what it brought forward has the screen now.
    signal chosen

    // What a key or a press reaches, from the top.
    function entries(): var {
        return [music, ...Array.from({ length: rowItems.count }, (_, k) => rowItems.itemAt(k))].filter(entry => entry?.visible && !entry.going);
    }

    // The rows follow the newest notifications by their order of arrival, newest first, so rows that stay keep their item
    // and its focus: those no longer among them leave, new ones come in where their order puts them.
    function follow() {
        if (!held)
            showNewest();
    }

    // What the button that counts the waiting updates does: they show while it stays held.
    function catchUp() {
        showNewest();
        news.catchUp();
    }

    function showNewest() {
        const wanted = (board?.rows ?? []).slice(0, notices);
        const orders = wanted.map(row => row.order);
        for (let k = 0; k < shown.count; k++) {
            if (!orders.includes(shown.get(k).order))
                (rowItems.itemAt(k) as MessageRow)?.leave();
        }
        for (const row of wanted) {
            const at = indexOf(row.order);
            if (at >= 0)
                shown.set(at, fields(row));
            else
                shown.insert(insertionPoint(row.order), fields(row));
        }
    }

    function indexOf(order: int): int {
        for (let k = 0; k < shown.count; k++) {
            if (shown.get(k).order === order)
                return k;
        }
        return -1;
    }

    function insertionPoint(order: int): int {
        let k = 0;
        while (k < shown.count && shown.get(k).order > order)
            k++;
        return k;
    }

    function waitingCount(): int {
        const live = board?.rows ?? [];
        const newest = shown.count > 0 ? shown.get(0).order : -1;
        const came = live.slice(0, notices).filter(row => {
            const at = indexOf(row.order);
            // An older one that moves up as a newer closes is no news of its own.
            return at < 0 ? row.order > newest : !sameFields(shown.get(at), fields(row));
        });
        const closed = Array.from({ length: shown.count }, (_, k) => k).filter(k => {
            const staying = !(rowItems.itemAt(k) as MessageRow)?.going;
            return staying && !live.some(row => row.order === shown.get(k).order);
        });
        return came.length + closed.length + (track !== shownTrack ? 1 : 0);
    }

    function sameFields(entry: var, wanted: var): bool {
        return Object.keys(wanted).every(key => entry[key] === wanted[key]);
    }

    function fields(row: var): var {
        return {
            order: row.order,
            app: row.appName || row.desktopEntry,
            summary: row.summary,
            body: row.body,
            icon: row.icon.toString(),
            stamp: row.time.getTime(),
            actions: "[]"
        };
    }

    function recordOf(order: int): var {
        return (board?.rows ?? []).find(row => row.order === order) ?? null;
    }

    function showTrack() {
        news.tell(track !== "" && shownTrack !== "" ? "peek" : "", () => today.shownTrack = today.track);
    }

    // Through MPRIS where the player lets itself be raised, else its window.
    function raisePlayer() {
        if (player?.canRaise)
            player.raise();
        else
            windows.find(window => window.appId === player?.desktopEntry)?.activate();
        chosen();
    }

    objectName: "heute"
    width: parent ? parent.width : 0
    // The first track is no news.
    Component.onCompleted: {
        shownTrack = track;
        follow();
    }
    onTrackChanged: showTrack()
    onHeldChanged: follow()

    Connections {
        target: today.board

        function onRowsChanged() {
            today.follow();
        }
    }

    HoverHandler {
        id: hover
    }

    // Once a minute while in sight; coming into sight it catches up at once.
    Timer {
        objectName: "tick"
        interval: Calendar.untilNextMinute(today.now)
        running: today.visible
        repeat: true
        onTriggered: today.now = today.clock()
        onRunningChanged: {
            if (running)
                today.now = today.clock();
        }
    }

    // "läuft gerade" over the cover, or the music icon without one, and "title · artist" beside it, one line, cut.
    Item {
        id: music

        readonly property bool opens: true
        readonly property string artUrl: today.player?.trackArtUrl ?? ""
        readonly property bool covered: artUrl !== "" && cover.status !== Image.Error

        objectName: "music"
        width: today.width
        height: Geometry.hairline + 2 * Tokens.spaceS + kicker.height + Tokens.spaceS + line.height
        visible: today.shownTrack !== ""
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: `läuft gerade: ${today.shownTrack}`
        Accessible.onPressAction: today.raisePlayer()

        Keys.onPressed: event => {
            if (![Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key))
                return;
            // A held key presses once.
            if (!event.isAutoRepeat)
                today.raisePlayer();
            event.accepted = true;
        }

        Hairline {
            width: music.width
        }

        Kicker {
            id: kicker

            objectName: "kicker"
            y: Geometry.hairline + Tokens.spaceS
            text: "läuft gerade"
        }

        // The figures stand space-s under the kicker, as in a status region (rekta.css:115–116); the news peeks within.
        Item {
            id: line

            y: kicker.y + kicker.height + Tokens.spaceS
            width: music.width
            height: words.height
            clip: true

            // On the Start's glass a ring in `bg` would show: the cover keeps Rekta's square crop (states.md:92–98).
            Picture {
                id: cover

                objectName: "cover"
                y: (line.height - height) / 2
                visible: music.covered
                source: music.artUrl
                ground: "transparent"
            }

            Icon {
                objectName: "musicIcon"
                y: (line.height - height) / 2
                visible: !music.covered
                name: "music"
            }

            Body {
                id: words

                objectName: "track"
                x: Geometry.iconSize + Tokens.spaceS
                width: line.width - x
                text: today.shownTrack
                textFormat: Text.PlainText
                font.weight: Tokens.fontWeightSemibold
                wrapMode: Text.NoWrap
                elide: Text.ElideRight

                OverflowTip {}
            }

            TileNews {
                id: news

                anchors.fill: parent
                content: line
                marked: words
                held: today.held
            }
        }

        // Hover and press lay `hover` over it, as over the rows below.
        Rectangle {
            anchors.fill: parent
            color: Tokens.color.hover
            opacity: musicHover.hovered || musicTap.pressed ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.durationShort
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.easeBase
                }
            }
        }

        FocusRing {
            shown: music.activeFocus
        }

        HoverHandler {
            id: musicHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: musicTap

            // A slow click is still a click.
            longPressThreshold: 0
            onTapped: today.raisePlayer()
        }
    }

    Column {
        objectName: "todayRows"
        width: today.width
        add: RowArrival {}
        move: RowsMakeRoom {}

        Repeater {
            id: rowItems

            model: ListModel {
                id: shown
            }

            delegate: MessageRow {
                id: row

                readonly property bool opens: true

                now: today.now
                locale: today.locale
                removable: false
                // On the Start's glass a ring in `bg` would show: the picture keeps Rekta's square crop.
                ground: "transparent"
                // A held row whose notification closed meanwhile is stale: the press shows the waiting updates instead.
                onPressed: {
                    const record = today.recordOf(row.order);
                    if (!record) {
                        today.catchUp();
                        return;
                    }
                    today.board.press(record);
                    today.chosen();
                }
                // A row that left and is wanted again comes back in.
                onGone: {
                    shown.remove(today.indexOf(row.order));
                    today.follow();
                }
            }
        }
    }

    Hairline {
        width: today.width
        visible: !today.idle
    }

    Empty {
        id: empty

        objectName: "todayEmpty"
        width: today.width
        visible: today.idle
        text: "nichts läuft, keine meldungen."
    }

    LiveMore {
        objectName: "waiting"
        count: today.waiting
        onClicked: {
            const hadFocus = activeFocus;
            today.catchUp();
            // The button goes once nothing waits; the focus stays in the region.
            if (hadFocus)
                today.entries()[0]?.forceActiveFocus();
        }
    }
}
