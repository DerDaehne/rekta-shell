pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The Start, after the shell's decision for it: one column at the leading edge, six tile units wide, scrolling down,
// on glass over the windows. Its pivot "start · alle apps" picks the place; the start place shows "läuft", a tile for
// each open window, the most recent first, then the pinned apps; "alle apps" lists the installed apps A–Z. It opens
// once the windows are three quarters back (Rekta's hand-over between places), its parts turning in as a place
// arrives, and closes turning them out: back the way they came, or forward after a press or a choice, the pressed tile
// last. While it turns its places take no input. A letter typed in either place searches the apps: what is typed
// becomes the title, "suche" beside it, and the apps that match stand below as tiles.
FocusScope {
    id: start

    // The open windows: {title, icon, lastActivated, stackingOrder, active, activate()}.
    property var windows: []
    // The window that had the keyboard when the Start opened; it gets it back unless a press chose where to go.
    property var returnTo: null
    // The pinned apps: {name, icon, columns, rows, launch()}.
    property var pinned: []
    // The installed apps, A–Z: {id, name, genericName, keywords, exec, icon, launch()}; null until they are known.
    property var apps: null
    // Draws a window's preview on its tile (RunningTile.preview); null for none.
    property Component preview: null
    // closed, opening (the glass comes, then the parts turn in), open, or closing (the parts turn out, the glass goes).
    property string phase: "closed"
    // From opening until it has closed; the host shows its surface while this holds.
    readonly property bool shown: phase !== "closed"
    // From open() to close(): the Start is open or on its way.
    readonly property bool wanted: phase === "opening" || phase === "open"
    // From open() to the hand-over, when the glass starts to go. KWin's fade-back steps the windows back when the
    // surface takes the keyboard and brings them forward when it gives it back; the surface, glass and blur, fades
    // along with them.
    readonly property bool holdsKeyboard: wanted || (phase === "closing" && !glassOut.running)
    readonly property bool turning: turner.running || waitForWindows.running
    readonly property var running: Rules.recentFirst(windows)
    // The time of the last wheel event, to tell one gesture from the next.
    property double lastWheel: 0
    readonly property Item focusItem: Window.activeFocusItem
    // What was typed.
    property string query: ""
    // The search shows, or is on its way, in place of the pivot and the places.
    property bool searching: false

    signal closed

    function open() {
        if (wanted)
            return;
        quietly(() => turner.finish());
        endSearch();
        returnTo = windows.find(window => window.active) ?? null;
        phase = "opening";
        glassOut.stop();
        pivot.focus = false;
        forgetTileFocus();
        body.visible = false;
        // The parts wait until the windows are three quarters back, as the next place waits for the last part leaving.
        if (waitForWindows.interval > 0)
            waitForWindows.restart();
        else
            turnIn();
    }

    // The Start's own turns, in and out, run at its tempo; a change of place inside it at Rekta's.
    function turnIn() {
        turn(null, body, {
            tempo: Geometry.startTempo
        });
    }

    // `pressed` is the tile that was pressed to leave; without one the Start goes back the way it came.
    function close(pressed: Tile) {
        leave({
            back: pressed === null,
            pressed: pressed
        });
    }

    // Turns the Start out; forward, after a choice, no window gets the keyboard back.
    function leave(options: var) {
        if (!wanted)
            return;
        phase = "closing";
        if (!options.back)
            returnTo = null;
        if (waitForWindows.running) {
            waitForWindows.stop();
            partsOut();
            return;
        }
        turn(body, null, {
            back: options.back,
            pressed: options.pressed,
            tempo: Geometry.startTempo
        });
    }

    function toggle() {
        if (wanted)
            close(null);
        else
            open();
    }

    // Back clears a search first, then goes to the start place, then out of the Start.
    function back() {
        if (query !== "")
            query = "";
        else if (pivot.currentIndex > 0)
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

    // A turn takes the parts at rest, as a swap does, and holds their opacity alone.
    function turn(from: Item, to: Item, options: var) {
        presence.complete();
        quietly(() => turner.go(from, to, options));
        // Under reduced motion the turn lands at once.
        if (!turner.running)
            landed();
    }

    function landed() {
        if (phase === "closing") {
            partsOut();
            return;
        }
        if (phase === "opening")
            phase = "open";
    }

    // The parts are out: the glass goes, and the keyboard goes back, as KWin hands it on only when a surface goes and the
    // Start's stays mapped. Not earlier: the activated window moves to the front of "läuft", whose tiles are then made
    // anew and would stand still amid the turn.
    function partsOut() {
        if (glassOut.interval > 0)
            glassOut.restart();
        else
            hide();
        if (windows.includes(returnTo))
            returnTo.activate();
        returnTo = null;
    }

    function showPlace(index: int) {
        column.visible = index === 0;
        appsPlace.visible = index !== 0;
    }

    function goToPlace(index: int) {
        forgetTileFocus();
        turn(index === 0 ? appsPlace : column, index === 0 ? column : appsPlace, {
            back: index === 0
        });
    }

    function hide() {
        phase = "closed";
        pivot.currentIndex = 0;
        endSearch();
        appList.clear();
        closed();
    }

    // A Start that opens again, or has closed, shows no search.
    function endSearch() {
        presence.complete();
        searching = false;
        query = "";
        showSearchView(false);
        found.clear();
    }

    // The search is a view of the place, not a place (collections.md, "Search and filters"): it comes and goes without a
    // turn, and what it shows comes and goes as items do (Presence). It follows what was typed, never amid a turn.
    function refresh() {
        if (turning)
            return;
        if (query !== "" && !searching)
            showSearch();
        else if (query === "" && searching)
            hideSearch();
        else if (searching)
            filter();
    }

    function showSearchView(shown: bool) {
        pivot.visible = !shown;
        searchTitle.visible = shown;
        results.visible = shown;
        if (shown) {
            column.visible = false;
            appsPlace.visible = false;
            results.contentY = 0;
        } else {
            showPlace(pivot.currentIndex);
        }
    }

    function partsIn(item: Item): var {
        return turner.partsOf(item).map(part => part.item);
    }

    // What the Start shows changes: the parts in view go, and those in view after `apply` come. The parts are taken
    // with nothing moving: a fading item draws through a layer whose source Qt puts beside it, and that is no part.
    function swap(apply: var, arriving: int) {
        presence.complete();
        forgetTileFocus();
        presence.change(partsIn(body), [], apply, () => partsIn(body), arriving);
    }

    function showSearch() {
        searching = true;
        const shown = matching();
        swap(() => {
            showSearchView(true);
            showHits(shown);
        }, shown.length);
    }

    // ponytail: the parts the place brings back are counted only once it shows, so past sixty the hits still leave in
    // motion before the place stands at once; count them beforehand if that shows.
    function hideSearch() {
        searching = false;
        swap(() => {
            showSearchView(false);
            found.clear();
        }, 0);
    }

    // The apps that match what was typed, read here and not bound: a binding on `query` may lag behind its handler.
    function matching(): var {
        return query === "" ? [] : Rules.hits(apps ?? [], query);
    }

    // Going on typing or erasing: the hits that no longer match go, the new ones come, and the rest close up.
    function filter() {
        presence.finish();
        const shown = matching();
        const kept = new Set(shown.map(app => app.id));
        const tiles = hitTiles();
        const before = new Set(tiles.map(tile => tile.appId));
        const coming = shown.filter(app => !before.has(app.id)).map(app => app.id);
        const going = tiles.filter(tile => !kept.has(tile.appId));
        const staying = tiles.filter(tile => kept.has(tile.appId));
        presence.change(going, staying, () => showHits(shown), () => hitTiles().filter(tile => coming.includes(tile.appId)), coming.length);
    }

    // Brings the hit tiles in line with `shown`, step by step, so that a tile that stays is the same tile.
    function showHits(shown: var) {
        const byId = new Map(shown.map(app => [app.id, app]));
        for (const step of Rules.steps(hitTiles().map(tile => tile.appId), shown.map(app => app.id))) {
            if (step.remove !== undefined)
                found.remove(step.remove);
            else if (step.move !== undefined)
                found.move(step.move, step.to, 1);
            else
                found.insert(step.insert, {
                    appId: step.id,
                    label: byId.get(step.id).name,
                    image: byId.get(step.id).icon
                });
        }
    }

    function hitTiles(): var {
        return hitsGrid.children.filter(item => (item as Tile) !== null);
    }

    function launchApp(appId: string) {
        (apps ?? []).find(app => app.id === appId)?.launch();
    }

    // Enter without a tile in focus presses the first hit, in its centre.
    function pressFirstHit() {
        presence.finish();
        hitTiles()[0]?.activated();
    }

    function press(tile: Tile, act: var) {
        act();
        close(tile);
    }

    // A chosen app starts, and the Start turns out forward. No row stays behind: only a pressed tile goes last
    // (rekta.js:754).
    function launch(index: int) {
        start.apps[index].launch();
        leave({
            back: false,
            pressed: null
        });
    }

    function allTiles(): var {
        return [...runningGrid.children, ...pinnedGrid.children, ...hitsGrid.children].filter(item => (item as Tile) !== null);
    }

    // The tiles a key can reach, in reading order of their sections; those of a hidden view are not visible.
    function reachableTiles(): var {
        return allTiles().filter(tile => tile.opens && tile.visible);
    }

    // A tile, or the list, keeps its focus in the Start's scope while hidden or disabled and takes keys again once
    // shown, so the Start opens, and goes to another place or view, with nothing in focus.
    function forgetTileFocus() {
        for (const tile of allTiles())
            tile.focus = false;
        appList.focus = false;
        if (!pivot.activeFocus)
            forceActiveFocus();
    }

    // Past the tiles, right goes to "alle apps" and up to the pivot; a search has neither.
    function pastTheTiles(direction: string) {
        if (searching)
            return;
        if (direction === "right")
            pivot.select(1);
        else if (direction === "up")
            pivot.forceActiveFocus();
    }

    // Arrows move the focus to the nearest tile that way.
    function moveFocus(direction: string) {
        const tiles = reachableTiles();
        const from = tiles.find(tile => tile.activeFocus);
        if (!from) {
            if (direction === "down" && tiles.length > 0)
                tiles[0].forceActiveFocus();
            else if (direction === "right")
                pastTheTiles(direction);
            return;
        }
        const rects = tiles.map(tile => tile.mapToItem(start, 0, 0, tile.width, tile.height));
        const next = Rules.neighbour(rects[tiles.indexOf(from)], rects, direction);
        if (next >= 0)
            tiles[next].forceActiveFocus();
        else
            pastTheTiles(direction);
    }

    function isIn(item: Item, box: Item): bool {
        for (let at = item; at; at = at.parent) {
            if (at === box)
                return true;
        }
        return false;
    }

    // Scrolls the column, or the hits, just far enough that what takes the focus there is whole in view, by arrow or by
    // Tab.
    function reveal(item: Item) {
        const view = item ? [column, results].find(scroller => isIn(item, scroller.contentItem)) : undefined;
        if (!view)
            return;
        const top = item.mapToItem(view.contentItem, 0, 0).y;
        const most = Math.max(0, view.contentHeight - view.height);
        if (top < view.contentY)
            view.contentY = Math.max(0, top);
        else if (top + item.height > view.contentY + view.height)
            view.contentY = Math.min(most, top + item.height - view.height);
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

    // Text typed without Ctrl, Alt or Meta; Shift only makes a capital. A search starts with a letter, one with a case
    // (QML's regular expressions know no \p{L}; scripts without one come through an input method, not a single key), and
    // goes on with any character that prints, a digit or a space too.
    function typesText(event: KeyEvent): bool {
        const text = event.text;
        if (text === "" || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0)
            return false;
        if (query === "")
            return text.length === 1 && text.toLowerCase() !== text.toUpperCase();
        return !/[\u0000-\u001f\u007f]/.test(text);
    }

    // In "alle apps" left goes back to the start place and down into the list, whose own keys move in it. A key that
    // acts on the hits makes their change first.
    function arrow(direction: string) {
        presence.finish();
        if (searching || pivot.currentIndex === 0)
            moveFocus(direction);
        else if (direction === "left")
            pivot.select(0);
        else if (direction === "down")
            appList.forceActiveFocus();
    }

    // Typing shows the search at once: a turn still running, or the parts still waiting to turn in, ends in its end
    // state first, as a navigation that comes while a turn runs finishes it (rekta.js:349–350, :557–558).
    function typeOn(text: string) {
        if (waitForWindows.running) {
            waitForWindows.stop();
            turnIn();
        }
        turner.finish();
        query += text;
    }

    function isEnter(event: KeyEvent): bool {
        return event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
    }

    // Back goes even while the Start turns, as a navigation always does, and so does typing, which ends the turn;
    // nothing else does.
    function useKey(event: KeyEvent): bool {
        const directions = {
            [Qt.Key_Left]: "left",
            [Qt.Key_Right]: "right",
            [Qt.Key_Up]: "up",
            [Qt.Key_Down]: "down"
        };
        if (goesBack(event))
            back();
        else if (typesText(event))
            typeOn(event.text);
        else if (event.key === Qt.Key_Backspace && query !== "")
            query = query.slice(0, -1);
        else if (turning)
            return false;
        else if (event.key in directions)
            arrow(directions[event.key]);
        else if (isEnter(event) && searching)
            pressFirstHit();
        else
            return false;
        return true;
    }

    focus: true
    Accessible.role: Accessible.Pane
    Accessible.name: "start"

    onFocusItemChanged: reveal(focusItem)
    onQueryChanged: refresh()
    onAppsChanged: refresh()

    Keys.onPressed: event => {
        if (wanted && useKey(event))
            event.accepted = true;
    }

    // The mouse's back button.
    TapHandler {
        acceptedButtons: Qt.BackButton
        onTapped: start.back()
    }

    // Whole while the Start shows: KWin's fade-back fades the surface in as the windows step back and out as they come
    // forward, so the glass and the blur behind it go together.
    Rectangle {
        objectName: "glass"
        anchors.fill: parent
        color: Tokens.color.glass
        visible: start.shown
    }

    // The glass goes as the windows come forward from the hand-over; then the Start empties.
    Timer {
        id: glassOut

        objectName: "glassOut"
        interval: FadeBack.duration
        onTriggered: start.hide()
    }

    Timer {
        id: waitForWindows

        objectName: "waitForWindows"
        interval: Geometry.turnOverlap * FadeBack.duration
        onTriggered: start.turnIn()
    }

    Presence {
        id: presence

        objectName: "presence"
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

    // The Start as one place: its pivot and whichever of its places shows, or the search.
    Item {
        id: body

        objectName: "body"
        anchors.fill: parent
        visible: false

        // A sideways wheel or a swipe goes to the place beside, a navigation like any other, also while a turn runs; a
        // search stays where it is.
        DragHandler {
            property real dx: 0

            target: null
            enabled: start.wanted && !start.searching
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
            enabled: start.wanted && !start.searching
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

        // "alle apps": its own place beside the start place, the installed apps as a long list, the place's one
        // section, space-l above and below (rekta.css:852).
        Item {
            id: appsPlace

            objectName: "apps"
            x: column.x
            y: column.y
            width: column.width
            height: column.height
            visible: false
            enabled: !start.turning

            LongList {
                id: appList

                objectName: "appList"
                y: Tokens.spaceL
                width: parent.width
                height: parent.height - 2 * Tokens.spaceL
                rows: (start.apps ?? []).map(app => ({
                            text: app.name,
                            icon: app.icon
                        }))
                loading: start.apps === null
                empty: "keine apps installiert."
                onShown: index => start.launch(index)
            }
        }

        // The search's title where the pivot stands, as a place's strip is its title (navigation.md, "Pivot"): what was
        // typed, light, and "suche" beside it as an inactive title, on one baseline, space-l apart (rekta.css:152). A
        // title never shrinks (typography.md); one too long for the column is cut at its edge, as the strip is.
        Item {
            id: searchTitle

            objectName: "searchTitle"
            x: pivot.x
            width: column.width
            height: pivot.height
            visible: false
            clip: true

            NavTitle {
                id: typedTitle

                objectName: "typed"
                anchors.bottom: parent.bottom
                text: start.query
                font.pixelSize: pivot.activeSize
            }

            NavTitle {
                objectName: "suche"
                x: typedTitle.width + Tokens.spaceL
                anchors.baseline: typedTitle.baseline
                active: false
                text: "suche"
                font.pixelSize: pivot.inactiveSize
            }
        }

        // The apps that match, as tiles one unit square in the column's grid, space-l above and below as a section
        // (rekta.css:852).
        Flickable {
            id: results

            objectName: "results"
            x: column.x
            y: column.y
            width: column.width
            height: column.height
            visible: false
            enabled: !start.turning
            clip: true
            contentHeight: hitsGrid.y + hitsGrid.height + Tokens.spaceL
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            TileGrid {
                id: hitsGrid

                objectName: "hits"
                y: Tokens.spaceL
                columns: 6

                Repeater {
                    model: ListModel {
                        id: found
                    }

                    delegate: AppTile {
                        id: hitTile

                        required property string appId
                        required property string label
                        required property string image

                        name: label
                        icon: image
                        onActivated: start.press(hitTile, () => start.launchApp(hitTile.appId))
                    }
                }
            }

            // Without a match, a sentence on the region's first hairline says so (states.md, "Empty"; rekta.css:675).
            Hairline {
                objectName: "noHitsLine"
                y: Tokens.spaceL
                width: results.width
                visible: found.count === 0
            }

            Body {
                objectName: "noHits"
                y: Tokens.spaceL + Geometry.hairline + Tokens.spaceM
                width: results.width
                visible: found.count === 0
                text: `keine app passt zu „${start.query.trim()}“.`
                color: Tokens.color.textContrastHigh
            }
        }
    }
}
