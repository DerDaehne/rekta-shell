pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The Start, after the shell's decision for it: one column at the leading edge, six tile units wide, scrolling down,
// on glass over the windows. Its pivot "start · alle apps" picks the place; the start place shows "läuft", a tile for
// each open window, the most recent first, then the pinned apps; "alle apps" shows the installed apps A–Z as one row of
// tiles that scrolls sideways, where a typed letter jumps to the next app it starts. It opens once the windows are
// three quarters back (Rekta's hand-over between places), its parts turning in as a place arrives, and closes turning
// them out: back the way they came, or forward after a press, the pressed tile last. While it turns its places take no
// input. A letter typed in the start place searches the apps: what is typed becomes the title, "suche" beside it, and
// the apps that match stand below as tiles. The title is a line edited as a field is; Escape there closes the Start.
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
    // How often each app was started from the Start, by id: {id: count}; the more often, the nearer the front of the hits.
    property var starts: ({})
    // The unseen notifications by app id: {id: count}.
    property var unseen: ({})
    // The System Settings pages, shaped as `apps` are; they are found, not listed.
    property var settings: []
    // The shell's commands: {text, keywords, run}, or {word, at(n)} for one that takes an amount (Rules.commandHits).
    property var commands: []
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
    // The wheel gesture over the apps' row started at the row's end its way, and goes on to the place beside.
    property bool wheelPastTheRow: false
    readonly property Item focusItem: Window.activeFocusItem
    // What was typed: the text of the search's line.
    property alias query: line.text
    // The search shows, or is on its way, in place of the pivot and the places.
    property bool searching: false
    // What the search finds besides apps: [{name, rows: [{text, lead, icon, run, best}]}] (Rules.rowGroups).
    property var rowGroups: []
    // What Escape does in a search: "close" closes the Start at once, "back" clears the search first like the other ways
    // back.
    property string searchEscape: "close"

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
            tempo: Prefs.startTempo
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
            tempo: Prefs.startTempo
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
        closed();
    }

    // A Start that opens again, or has closed, shows no search.
    function endSearch() {
        presence.complete();
        searching = false;
        query = "";
        showSearchView(false);
        found.clear();
        rowGroups = [];
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

    // The search's line has the keys while it shows.
    function showSearchView(shown: bool) {
        pivot.visible = !shown;
        searchTitle.visible = shown;
        results.visible = shown;
        line.focus = shown;
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
        const rows = matchingRows(shown);
        swap(() => {
            showSearchView(true);
            showHits(shown, rows);
        }, shown.length + countRows(rows));
    }

    // ponytail: the parts the place brings back are counted only once it shows, so past sixty the hits still leave in
    // motion before the place stands at once; count them beforehand if that shows.
    function hideSearch() {
        searching = false;
        swap(() => {
            showSearchView(false);
            found.clear();
            rowGroups = [];
        }, 0);
    }

    // The apps that match what was typed, read here and not bound: a binding on `query` may lag behind its handler.
    function matching(): var {
        return query === "" ? [] : Rules.hits(apps ?? [], query, starts);
    }

    // The rows below the tiles, read fresh like the apps; the first is the best hit when no app matches.
    function matchingRows(appHits: var): var {
        if (query === "")
            return [];
        return Rules.rowGroups({
            windows: windows,
            settings: settings,
            commands: commands
        }, query, starts, appHits.length === 0);
    }

    function countRows(groups: var): int {
        return groups.reduce((count, group) => count + group.rows.length, 0);
    }

    // Going on typing or erasing: the hits that no longer match go, the new ones come, and the rest close up.
    function filter() {
        presence.finish();
        const shown = matching();
        const rows = matchingRows(shown);
        const kept = new Set(shown.map(app => app.id));
        const tiles = hitTiles();
        const before = new Set(tiles.map(tile => tile.appId));
        const coming = shown.filter(app => !before.has(app.id)).map(app => app.id);
        const going = tiles.filter(tile => !kept.has(tile.appId));
        const staying = tiles.filter(tile => kept.has(tile.appId));
        presence.change(going, staying, () => showHits(shown, rows), () => hitTiles().filter(tile => coming.includes(tile.appId)), coming.length);
    }

    // Brings the hit tiles in line with `shown`, step by step, so that a tile that stays is the same tile. The rows are
    // made anew; ponytail: they change without motion while typing on, give them Presence like the tiles if that shows.
    function showHits(shown: var, rows: var) {
        rowGroups = rows;
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

    // Enter without a tile or row in focus acts on the best hit: the first tile, pressed in its centre, else the first row.
    function pressFirstHit() {
        presence.finish();
        (hitTiles()[0] ?? searchRows()[0])?.activated();
    }

    // A row of the search was chosen: it acts and the Start turns out forward, with no tile pressed.
    function chooseRow(row: var) {
        row.run();
        leave({
            back: false,
            pressed: null
        });
    }

    // The search's rows in reading order, under their headings.
    function searchRows(): var {
        const rows = [];
        for (const group of rowsColumn.children) {
            for (const item of group.children) {
                if ((item as SearchRow) !== null)
                    rows.push(item);
            }
        }
        return rows;
    }

    function press(tile: Tile, act: var) {
        act();
        close(tile);
    }

    function allTiles(): var {
        return [...runningGrid.children, ...pinnedGrid.children, ...hitsGrid.children, ...appTiles.children].filter(item => (item as Tile) !== null);
    }

    // The apps' row, in the app model's order.
    function rowTiles(): var {
        return appTiles.children.filter(item => (item as Tile) !== null);
    }

    function inTheRow(): bool {
        return !searching && pivot.currentIndex === 1;
    }

    // A key typed in the apps' row jumps to the next app it starts; a turn still running ends first, as typing ends it.
    function jump(key: string) {
        turner.finish();
        const tiles = rowTiles();
        const at = Rules.jumpTarget(tiles.map(tile => tile.name), tiles.findIndex(tile => tile.activeFocus), key);
        if (at >= 0)
            tiles[at].forceActiveFocus();
    }

    // The tiles a key can reach, in reading order of their sections; those of a hidden view are not visible.
    function reachableTiles(): var {
        return [...allTiles(), ...searchRows()].filter(tile => tile.opens && tile.visible);
    }

    // A tile, or the list, keeps its focus in the Start's scope while hidden or disabled and takes keys again once
    // shown, so the Start opens, and goes to another place or view, with nothing in focus.
    function forgetTileFocus() {
        for (const tile of [...allTiles(), ...searchRows()])
            tile.focus = false;
        if (!pivot.activeFocus)
            forceActiveFocus();
    }

    // Past the tiles, right goes to "alle apps", left back to "start" and up to the pivot; a search has none of them,
    // and up goes to its line.
    function pastTheTiles(direction: string) {
        if (searching && direction === "up")
            line.forceActiveFocus();
        else if (searching)
            return;
        else if (direction === "right")
            pivot.select(1);
        else if (direction === "left")
            pivot.select(0);
        else if (direction === "up")
            pivot.forceActiveFocus();
    }

    // Arrows move the focus to the nearest tile that way: in the apps' row up and down a column, left and right to the
    // column beside, an interim rule while Rekta has none for a tile grid.
    function moveFocus(direction: string) {
        const tiles = reachableTiles();
        const from = tiles.find(tile => tile.activeFocus);
        if (!from) {
            if (direction === "down" && tiles.length > 0)
                tiles[0].forceActiveFocus();
            else if (direction !== "up")
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

    // Scrolls the column, the hits or the apps' row just far enough that what takes the focus there is whole in view, by
    // arrow, by Tab or by a typed letter.
    function reveal(item: Item) {
        const view = item ? [column, results, appRow].find(scroller => isIn(item, scroller.contentItem)) : undefined;
        if (!view)
            return;
        const at = item.mapToItem(view.contentItem, 0, 0);
        view.contentY = shownFrom(view.contentY, view.height, view.contentHeight, at.y, item.height);
        view.contentX = shownFrom(view.contentX, view.width, view.contentWidth, at.x, item.width);
    }

    // Where a scroller showing `size` of `content` from `scrolled` scrolls to, so that `length` from `start` shows whole.
    function shownFrom(scrolled: real, size: real, content: real, start: real, length: real): real {
        if (start < scrolled)
            return Math.max(0, start);
        if (start + length > scrolled + size)
            return Math.min(Math.max(0, content - size), start + length - size);
        return scrolled;
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

    // Over the apps' row any wheel moves it sideways, a plain vertical one down along it, as over a panorama. A gesture
    // that starts with room to move the row its way is the row's, and its rest is swallowed at the row's end; one that
    // starts at that end goes on to the place beside (layout.md:48–62, rules 1, 2 and 4). It moves by the pixels the
    // device gives, or else by the wheel's angle, a notch being 120 eighths of a degree, taken as pixels.
    function rowWheel(event: WheelEvent) {
        const now = Date.now();
        const fresh = now - lastWheel > Tokens.durationWheelLatch;
        lastWheel = now;
        const x = event.pixelDelta.x || event.angleDelta.x;
        const y = event.pixelDelta.y || event.angleDelta.y;
        const along = -(Math.abs(x) >= Math.abs(y) ? x : y);
        if (fresh)
            wheelPastTheRow = along > 0 ? appRow.atXEnd : appRow.atXBeginning;
        if (!wheelPastTheRow)
            appRow.contentX = Math.max(0, Math.min(appRow.contentWidth - appRow.width, appRow.contentX + along));
        else if (fresh)
            pivot.select(along > 0 ? 1 : 0);
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

    // A key that acts on the hits makes their change first.
    function arrow(direction: string) {
        presence.finish();
        moveFocus(direction);
    }

    // In the apps' row a key that prints, other than a space, jumps (rekta.js:2810); elsewhere it would search.
    function jumpsInTheRow(event: KeyEvent): bool {
        return inTheRow() && event.text.length === 1 && /\S/.test(event.text) && (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) === 0;
    }

    // Home and End go to the first and the last app of the row.
    function toTheRowsEnd(event: KeyEvent): bool {
        const tiles = rowTiles();
        if (!inTheRow() || (event.key !== Qt.Key_Home && event.key !== Qt.Key_End) || tiles.length === 0)
            return false;
        tiles[event.key === Qt.Key_Home ? 0 : tiles.length - 1].forceActiveFocus();
        return true;
    }

    // Typing shows the search at once: a turn still running, or the parts still waiting to turn in, ends in its end
    // state first, as a navigation that comes while a turn runs finishes it (rekta.js:349–350, :557–558). What is typed
    // goes in at the line's caret.
    function typeOn(text: string) {
        if (waitForWindows.running) {
            waitForWindows.stop();
            turnIn();
        }
        turner.finish();
        takeKeysToLine();
        line.insert(line.cursorPosition, text);
    }

    // Backspace while a hit has the focus erases in the line as it would there.
    function eraseBack() {
        takeKeysToLine();
        eraseTo(Math.max(0, line.cursorPosition - 1));
    }

    // Erases from the caret to `to`, a step of its own for Ctrl+Z: moving the caret ends the step before, where a
    // removal alone would join the typing before it.
    function eraseTo(to: int) {
        line.deselect();
        line.moveCursorSelection(to);
        line.remove(line.selectionStart, line.selectionEnd);
    }

    // Typing on from a hit goes back to the line, which then takes the keys. A line that loses the focus loses its
    // selection, so there is none to replace here.
    function takeKeysToLine() {
        if (line.visible)
            line.forceActiveFocus();
    }

    // The line's keys a terminal has, the same on every desktop: Qt binds Ctrl+U and Ctrl+K per platform, and its
    // Ctrl+U copies the whole line before erasing it. Ctrl+W erases the spaces before the caret and the word before
    // them. A paste keeps its first line, a search being one line.
    function editLine(event: KeyEvent): bool {
        if (line.readOnly)
            return false;
        const ctrl = event.modifiers === Qt.ControlModifier;
        if (ctrl && event.key === Qt.Key_U)
            eraseTo(0);
        else if (ctrl && event.key === Qt.Key_K)
            eraseTo(line.length);
        else if (ctrl && event.key === Qt.Key_W)
            eraseTo(line.text.slice(0, line.cursorPosition).search(/\S*\s*$/));
        else if (event.matches(StandardKey.Paste))
            pasteFirstLine();
        else
            return false;
        return true;
    }

    // ponytail: the lines after the first go in and out again, so Ctrl+Z after pasting several brings them back before
    // it takes the paste; read the clipboard through a hidden line first if that shows.
    function pasteFirstLine() {
        const from = line.selectionStart;
        line.paste();
        const pasted = line.text.slice(from, line.cursorPosition);
        line.remove(from + pasted.split(/[\r\n]/)[0].length, line.cursorPosition);
    }

    function isEnter(event: KeyEvent): bool {
        return event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
    }

    // Back goes even while the Start turns, as a navigation always does, and so does typing, to search or to jump, which
    // ends the turn; nothing else does. Escape in a search closes the Start at once unless searchEscape says back; the
    // other ways back clear the search first.
    function useKey(event: KeyEvent): bool {
        const directions = {
            [Qt.Key_Left]: "left",
            [Qt.Key_Right]: "right",
            [Qt.Key_Up]: "up",
            [Qt.Key_Down]: "down"
        };
        if (event.key === Qt.Key_Escape && query !== "" && searchEscape !== "back")
            close(null);
        else if (goesBack(event))
            back();
        else if (jumpsInTheRow(event))
            jump(event.text);
        else if (typesText(event))
            typeOn(event.text);
        else if (event.key === Qt.Key_Backspace && query !== "")
            eraseBack();
        else if (turning)
            return false;
        else if (event.key in directions)
            arrow(directions[event.key]);
        else if (isEnter(event) && searching)
            pressFirstHit();
        else
            return toTheRowsEnd(event);
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
        // search stays where it is. In "alle apps" it takes no swipe over from what was pressed, so one that starts on
        // the apps' row is the row's.
        DragHandler {
            property real dx: 0

            target: null
            enabled: start.wanted && !start.searching
            yAxis.enabled: false
            grabPermissions: (pivot.currentIndex === 1 ? 0 : PointerHandler.CanTakeOverFromItems) | PointerHandler.CanTakeOverFromHandlersOfDifferentType | PointerHandler.ApprovesTakeOverByAnything
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

        // A place's strip along the top, the space-xl in from the edge of a sideways place (rekta.css:1180). Its inactive
        // title is one step up from Rekta's (rekta.css:53), so both titles stay above the section headings.
        Pivot {
            id: pivot

            objectName: "pivot"
            x: Tokens.spaceXl
            width: parent.width - 2 * Tokens.spaceXl
            enabled: start.wanted
            level: "nav"
            activeToken: Tokens.fontSizeNavActive
            inactiveToken: Tokens.fontSizeTitle
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

            // Sections stack down the column, each space-xl above and below, a hairline between, the heading space-l before
            // its tiles, the headings one step up from Rekta's: the Start is airier and larger than a compact panorama
            // (rekta.css:854–856, :53, :50).
            Column {
                id: sections

                width: column.width

                Column {
                    objectName: "running"
                    width: parent.width
                    visible: start.running.length > 0
                    topPadding: Tokens.spaceXl
                    bottomPadding: Tokens.spaceXl
                    spacing: Tokens.spaceL

                    GroupHeading {
                        objectName: "heading"
                        sizeToken: Tokens.fontSizeXl
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
                                unseen: start.unseen[modelData.appId] ?? 0
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
                    topPadding: Tokens.spaceXl
                    bottomPadding: Tokens.spaceXl
                    spacing: Tokens.spaceL

                    GroupHeading {
                        objectName: "heading"
                        sizeToken: Tokens.fontSizeXl
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
                                unseen: start.unseen[modelData.id] ?? 0
                                columns: modelData.columns
                                rows: modelData.rows
                                onActivated: start.press(appTile, () => appTile.modelData.launch())
                            }
                        }
                    }
                }
            }
        }

        // "alle apps": its own place beside the start place, the place's one section, space-l above and below
        // (rekta.css:852). Every installed app A–Z is a tile one unit square, space-s apart (layout.md, "Tile grids"),
        // in one row that fills each column top down, as many tiles as the column's height holds, and scrolls sideways
        // within the column.
        // ponytail: a tile for every app, made once the apps are known; a view that makes only the tiles in sight if
        // hundreds of apps make the Start slow.
        Item {
            id: appsPlace

            objectName: "apps"
            x: column.x
            y: column.y
            width: column.width
            height: column.height
            visible: false
            enabled: !start.turning

            Flickable {
                id: appRow

                // Where a swipe started: at the row's start or at its end, or both when it all fits.
                property bool swipeFromStart: false
                property bool swipeFromEnd: false

                objectName: "appRow"
                y: Tokens.spaceL
                width: parent.width
                height: parent.height - 2 * Tokens.spaceL
                clip: true
                contentWidth: appTiles.width
                flickableDirection: Flickable.HorizontalFlick
                // The row stops at its ends, and tells how far a swipe went on past one.
                boundsBehavior: Flickable.DragOverBounds
                boundsMovement: Flickable.StopAtBounds

                // A swipe that starts at an end of the row and goes on past it goes on to the place beside, as the
                // wheel does there (layout.md:48–62, rules 1 and 4).
                onDraggingChanged: {
                    if (dragging) {
                        swipeFromStart = atXBeginning;
                        swipeFromEnd = atXEnd;
                    } else if (horizontalOvershoot < 0 && swipeFromStart) {
                        pivot.select(0);
                    } else if (horizontalOvershoot > 0 && swipeFromEnd) {
                        pivot.select(1);
                    }
                }

                Item {
                    id: appTiles

                    readonly property real step: Tokens.tileUnit + Tokens.spaceS
                    readonly property int rows: Math.max(1, Math.floor((appRow.height + Tokens.spaceS) / step))
                    readonly property int columns: Math.ceil(repeater.count / rows)

                    objectName: "appTiles"
                    width: Math.max(0, columns * step - Tokens.spaceS)
                    height: appRow.height

                    Repeater {
                        id: repeater

                        model: start.apps ?? []

                        delegate: AppTile {
                            id: rowTile

                            required property var modelData
                            required property int index

                            x: Math.floor(index / appTiles.rows) * appTiles.step
                            y: index % appTiles.rows * appTiles.step
                            name: modelData.name
                            icon: modelData.icon
                            onActivated: start.press(rowTile, () => rowTile.modelData.launch())
                        }
                    }
                }
            }

            // The wheel over the row is the Start's, so that it can go on past the row's ends; a press goes by.
            MouseArea {
                anchors.fill: appRow
                acceptedButtons: Qt.NoButton
                onWheel: wheel => start.rowWheel(wheel)
            }

            // Loading, the line runs on the region's first hairline; without apps a sentence there says so (states.md,
            // "Data states"; rekta.css:675).
            Hairline {
                objectName: "appsLine"
                y: Tokens.spaceL
                width: parent.width
                visible: repeater.count === 0
            }

            BusyLine {
                objectName: "appsBusy"
                y: Tokens.spaceL
                width: parent.width
                busy: start.apps === null
            }

            Body {
                objectName: "noApps"
                y: Tokens.spaceL + Geometry.hairline + Tokens.spaceM
                width: parent.width
                visible: start.apps !== null && repeater.count === 0
                text: "keine apps installiert."
                color: Tokens.color.textContrastHigh
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

            // The line box of an active title at the strip's foot, as the pivot's titles stand: it sets the type and
            // the baseline of what was typed.
            NavTitle {
                id: lineBox

                anchors.bottom: parent.bottom
                visible: false
                font.pixelSize: pivot.activeSize
            }

            // What was typed is a line edited as a field is. Its caret is a field's, one pixel in the text's colour
            // (`caret-color: auto` on `.rk-input`, rekta.css:267; rekta-core field.c:472, :503), as high and blinking as
            // the platform draws it, as on the web. Its selection takes the accent with on-accent text, as any selection
            // does (rekta.css:722; field.c:497–498).
            // ponytail: past the column's edge the caret goes out of sight with the text; cap the width at the column
            // and let the line scroll if queries get that long.
            TextInput {
                id: line

                objectName: "typed"
                anchors.baseline: lineBox.baseline
                font: lineBox.font
                color: lineBox.color
                selectionColor: Tokens.color.accent
                selectedTextColor: Tokens.color.textOnAccent
                readOnly: !start.wanted
                activeFocusOnTab: true
                Accessible.name: "suche"

                Keys.onPressed: event => event.accepted = start.editLine(event)
            }

            NavTitle {
                objectName: "suche"
                x: line.width + Tokens.spaceL
                anchors.baseline: lineBox.baseline
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
            contentHeight: rowsColumn.y + rowsColumn.height + Tokens.spaceL
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
                        required property int index

                        name: label
                        icon: image
                        best: index === 0
                        columns: best ? 2 : 1
                        onActivated: start.press(hitTile, () => start.launchApp(hitTile.appId))
                    }
                }
            }

            // Below the tiles, the other kinds of hit as rows (palette entries) under their heading, space-l apart; a group
            // without a hit has no heading.
            Column {
                id: rowsColumn

                objectName: "rows"
                y: hitsGrid.y + hitsGrid.height + (found.count > 0 ? Tokens.spaceL : 0)
                width: results.width

                Repeater {
                    model: start.rowGroups

                    delegate: Column {
                        id: group

                        required property var modelData

                        objectName: group.modelData.name
                        width: rowsColumn.width

                        MenuLabel {
                            objectName: "heading"
                            text: group.modelData.name
                        }

                        Repeater {
                            model: group.modelData.rows

                            delegate: SearchRow {
                                id: searchRow

                                required property var modelData

                                text: searchRow.modelData.text
                                lead: searchRow.modelData.lead
                                icon: searchRow.modelData.icon
                                best: searchRow.modelData.best === true
                                onActivated: start.chooseRow(searchRow.modelData)
                            }
                        }
                    }
                }
            }

            // Without a match, a sentence on the region's first hairline says so (states.md, "Empty"; rekta.css:675).
            Empty {
                objectName: "noHits"
                y: Tokens.spaceL
                width: results.width
                visible: found.count === 0 && start.rowGroups.length === 0
                text: `nichts passt zu „${start.query.trim()}“.`
            }
        }
    }
}
