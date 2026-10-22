pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The Start, after the shell's decision for it: one column at the leading edge, six tile units wide, scrolling down,
// on glass over the windows. Its pivot "start · alle apps" picks the place; the start place shows "läuft", a tile for
// each open window, the most recent first, then the pinned apps. It opens once the windows are three quarters back
// (Rekta's hand-over between places), its parts turning in as a place arrives, and closes turning them out: back the
// way they came, or forward after a press, the pressed tile last. While it turns its places take no input.
FocusScope {
    id: start

    // The open windows: {title, icon, lastActivated, stackingOrder, activate()}.
    property var windows: []
    // The pinned apps: {name, icon, columns, rows, launch()}.
    property var pinned: []
    // Draws a window's preview on its tile (RunningTile.preview); null for none.
    property Component preview: null
    // closed, opening (the glass comes, then the parts turn in), open, or closing (the parts turn out, the glass goes).
    property string phase: "closed"
    // From opening until it has closed; the host shows its surface while this holds.
    readonly property bool shown: phase !== "closed"
    // From open() to close(): the Start is open or on its way.
    readonly property bool wanted: phase === "opening" || phase === "open"
    readonly property bool turning: turner.running || waitForWindows.running
    readonly property var running: Rules.recentFirst(windows)
    // The time of the last wheel event, to tell one gesture from the next.
    property double lastWheel: 0
    readonly property Item focusItem: Window.activeFocusItem

    // A key typed in the open Start, for the palette to take over.
    signal typed(string text)
    signal closed

    function open() {
        if (wanted)
            return;
        quietly(() => turner.finish());
        phase = "opening";
        glassOut.stop();
        glassIn.restart();
        forceActiveFocus();
        body.visible = false;
        // The parts wait until the windows are three quarters back, as the next place waits for the last part leaving.
        if (waitForWindows.interval > 0)
            waitForWindows.restart();
        else
            turn(null, body, {});
    }

    // `pressed` is the tile that was pressed to leave; without one the Start goes back the way it came.
    function close(pressed: Tile) {
        if (!wanted)
            return;
        phase = "closing";
        if (waitForWindows.running) {
            waitForWindows.stop();
            glassOut.restart();
            return;
        }
        turn(body, null, {
            back: pressed === null,
            pressed: pressed
        });
    }

    function toggle() {
        if (wanted)
            close(null);
        else
            open();
    }

    // Back goes to the start place first, then out of the Start.
    function back() {
        if (pivot.currentIndex > 0)
            pivot.select(0);
        else
            close(null);
    }

    // A navigation during a turn ends that turn first; that landing is not the new turn's.
    function quietly(work: var) {
        turner.going = true;
        work();
        turner.going = false;
    }

    function turn(from: Item, to: Item, options: var) {
        quietly(() => turner.go(from, to, options));
        // Under reduced motion the turn lands at once.
        if (!turner.running)
            landed();
    }

    function landed() {
        if (phase === "opening")
            phase = "open";
        else if (phase === "closing")
            glassOut.restart();
    }

    function showPlace(index: int) {
        column.visible = index === 0;
        apps.visible = index !== 0;
    }

    function goToPlace(index: int) {
        turn(index === 0 ? apps : column, index === 0 ? column : apps, {
            back: index === 0
        });
    }

    function hide() {
        phase = "closed";
        pivot.currentIndex = 0;
        showPlace(0);
        closed();
    }

    function press(tile: Tile, act: var) {
        act();
        close(tile);
    }

    // The tiles a key can reach, in reading order of their sections.
    function reachableTiles(): var {
        return [...runningGrid.children, ...pinnedGrid.children].filter(item => (item as Tile)?.opens && item.visible);
    }

    // Arrows move the focus to the nearest tile that way; past the last one, right goes to "alle apps" and up to the
    // pivot.
    function moveFocus(direction: string) {
        const tiles = reachableTiles();
        const from = tiles.find(tile => tile.activeFocus);
        if (!from) {
            if (direction === "down" && tiles.length > 0)
                tiles[0].forceActiveFocus();
            else if (direction === "right")
                pivot.select(1);
            return;
        }
        const rects = tiles.map(tile => tile.mapToItem(start, 0, 0, tile.width, tile.height));
        const next = Rules.neighbour(rects[tiles.indexOf(from)], rects, direction);
        if (next >= 0)
            tiles[next].forceActiveFocus();
        else if (direction === "right")
            pivot.select(1);
        else if (direction === "up")
            pivot.forceActiveFocus();
    }

    function isIn(item: Item, box: Item): bool {
        for (let at = item; at; at = at.parent) {
            if (at === box)
                return true;
        }
        return false;
    }

    // Scrolls the column just far enough that what takes the focus in it is whole in view, by arrow or by Tab.
    function reveal(item: Item) {
        if (!item || !isIn(item, sections))
            return;
        const top = item.mapToItem(sections, 0, 0).y;
        const most = Math.max(0, column.contentHeight - column.height);
        if (top < column.contentY)
            column.contentY = Math.max(0, top);
        else if (top + item.height > column.contentY + column.height)
            column.contentY = Math.min(most, top + item.height - column.height);
    }

    // One wheel gesture is one step: events less than wheel-latch apart belong together (layout.md). Only a sideways
    // wheel changes the place; an upright one scrolls the column.
    function wheel(event: WheelEvent) {
        const now = Date.now();
        const fresh = now - lastWheel > Tokens.durationWheelLatch;
        lastWheel = now;
        if (fresh)
            pivot.select((event.angleDelta.x || event.pixelDelta.x) < 0 ? 1 : 0);
    }

    function goesBack(event: KeyEvent): bool {
        return event.key === Qt.Key_Escape || event.key === Qt.Key_Back || (event.key === Qt.Key_Left && (event.modifiers & Qt.AltModifier) !== 0);
    }

    // A letter without Ctrl, Alt or Meta; Shift only makes it a capital. A letter has a case (QML's regular expressions
    // know no \p{L}); scripts without one come through an input method, not a single key.
    function types(event: KeyEvent): bool {
        const letter = event.text.length === 1 && event.text.toLowerCase() !== event.text.toUpperCase();
        return letter && (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) === 0;
    }

    // In "alle apps" only left leads anywhere: back to the start place.
    function arrow(direction: string) {
        if (pivot.currentIndex === 0)
            moveFocus(direction);
        else if (direction === "left")
            pivot.select(0);
    }

    // Back goes even while the Start turns, as a navigation always does; nothing else does.
    function useKey(event: KeyEvent): bool {
        const directions = {
            [Qt.Key_Left]: "left",
            [Qt.Key_Right]: "right",
            [Qt.Key_Up]: "up",
            [Qt.Key_Down]: "down"
        };
        if (goesBack(event))
            back();
        else if (turning)
            return false;
        else if (event.key in directions)
            arrow(directions[event.key]);
        else if (types(event))
            typed(event.text);
        else
            return false;
        return true;
    }

    focus: true
    Accessible.role: Accessible.Pane
    Accessible.name: "start"

    onFocusItemChanged: reveal(focusItem)

    Keys.onPressed: event => {
        if (wanted && useKey(event))
            event.accepted = true;
    }

    // The mouse's back button.
    TapHandler {
        acceptedButtons: Qt.BackButton
        onTapped: start.back()
    }

    Rectangle {
        id: glass

        objectName: "glass"
        anchors.fill: parent
        color: Tokens.color.glass
        opacity: 0
    }

    // The glass comes as the windows step back and goes as they come forward (the shell's decision for the Start).
    NumberAnimation {
        id: glassIn

        objectName: "glassIn"
        target: glass
        property: "opacity"
        to: 1
        duration: Tokens.durationModerate
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeOut
    }

    NumberAnimation {
        id: glassOut

        objectName: "glassOut"
        target: glass
        property: "opacity"
        to: 0
        duration: Tokens.durationModerate
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
        onFinished: {
            if (start.phase === "closing")
                start.hide();
        }
    }

    Timer {
        id: waitForWindows

        interval: Geometry.turnOverlap * Tokens.durationModerate
        onTriggered: start.turn(null, body, {})
    }

    PlaceTurn {
        id: turner

        // While one turn is ended to start the next: that landing is not the Start's.
        property bool going: false

        objectName: "turn"

        onLanded: {
            if (!going)
                start.landed();
        }
    }

    // The Start as one place: its pivot and whichever of its places shows.
    Item {
        id: body

        objectName: "body"
        anchors.fill: parent
        visible: false

        // A sideways wheel or a swipe goes to the place beside, a navigation like any other, also while a turn runs.
        DragHandler {
            property real dx: 0

            target: null
            enabled: start.wanted
            yAxis.enabled: false
            onActiveTranslationChanged: {
                if (active)
                    dx = activeTranslation.x;
            }
            onActiveChanged: {
                if (!active && dx !== 0)
                    pivot.select(dx < 0 ? 1 : 0);
                dx = 0;
            }
        }

        WheelHandler {
            enabled: start.wanted
            orientation: Qt.Horizontal
            onWheel: event => start.wheel(event)
        }

        // A place's strip along the top, the space-xl in from the edge of a sideways place (rekta.css:1180).
        Pivot {
            id: pivot

            objectName: "pivot"
            x: Tokens.spaceXl
            width: parent.width - 2 * Tokens.spaceXl
            enabled: start.wanted
            level: "nav"
            titles: ["start", "alle apps"]
            placeWidth: start.width
            viewportHeight: start.height
            onSelected: index => start.goToPlace(index)
        }

        Flickable {
            id: column

            objectName: "column"
            x: Tokens.spaceXl
            y: pivot.height
            width: runningGrid.implicitWidth
            height: parent.height - y
            enabled: !start.turning
            clip: true
            contentHeight: sections.height
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            // Sections stack down the column, each space-l above and below, a hairline between (rekta.css:854–856).
            Column {
                id: sections

                width: column.width

                Column {
                    objectName: "running"
                    width: parent.width
                    visible: start.running.length > 0
                    topPadding: Tokens.spaceL
                    bottomPadding: Tokens.spaceL
                    spacing: Tokens.spaceM

                    GroupHeading {
                        objectName: "heading"
                        width: parent.width
                        text: "läuft"
                        placeWidth: start.width
                    }

                    TileGrid {
                        id: runningGrid

                        objectName: "grid"
                        columns: 6

                        Repeater {
                            model: start.running

                            delegate: RunningTile {
                                id: runningTile

                                required property var modelData

                                title: modelData.title
                                icon: modelData.icon
                                window: modelData
                                preview: start.preview
                                onActivated: start.press(runningTile, () => runningTile.modelData.activate())
                            }
                        }
                    }
                }

                Hairline {
                    visible: start.running.length > 0
                }

                Column {
                    objectName: "pinned"
                    width: parent.width
                    topPadding: Tokens.spaceL
                    bottomPadding: Tokens.spaceL
                    spacing: Tokens.spaceM

                    GroupHeading {
                        objectName: "heading"
                        width: parent.width
                        text: "angeheftet"
                        placeWidth: start.width
                    }

                    TileGrid {
                        id: pinnedGrid

                        objectName: "grid"
                        columns: 6

                        Repeater {
                            model: start.pinned

                            delegate: AppTile {
                                id: appTile

                                required property var modelData

                                name: modelData.name
                                icon: modelData.icon
                                columns: modelData.columns
                                rows: modelData.rows
                                onActivated: start.press(appTile, () => appTile.modelData.launch())
                            }
                        }
                    }
                }
            }
        }

        // "alle apps": its own place beside the start place, still empty.
        Item {
            id: apps

            objectName: "apps"
            x: column.x
            y: column.y
            width: column.width
            height: column.height
            visible: false
            enabled: !start.turning
        }
    }
}
