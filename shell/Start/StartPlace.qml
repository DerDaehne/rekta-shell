pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The Start, after the shell's decision for it: glass over the windows, across the whole surface. Its pivot
// "start · alle apps" picks the place; the start place is a panorama of sections under a strip of their titles:
// "läuft", a tile for each open window, the most recent first, then "angeheftet", the pinned apps; "alle apps" is a
// panorama of the installed apps A–Z, a section for each initial, where a typed letter jumps to the next app it
// starts. It opens once the windows are three quarters back (Rekta's hand-over between places), its parts turning in
// as a place arrives, and closes turning them out: back the way they came, or forward after a press, the pressed tile
// last. While it turns its places take no input. A letter typed in the start place searches, and so does what a
// calculation starts with: what is typed becomes the title, "suche" beside it, and the apps that match stand below as
// tiles, the other kinds as rows. The title is a line edited as a field is; Escape there closes the Start.
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
    // The search address of KDE's default web search, with \{@} for the text; "" without one.
    property string webSearch: ""
    // Opens an address in the user's browser.
    property var openUrl: null
    // Puts a text on the clipboard.
    property var copy: null
    // The locale's decimal separator, which a calculation writes its numbers with.
    property string decimalPoint: Qt.locale().decimalPoint
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
    // A tile unit and the space after it: a section is as wide as its units (site/site.css:78).
    readonly property real unitStep: Tokens.tileUnit + Tokens.spaceS
    // A search under the place pivot, and the loading line of "alle apps", keep to the leading edge, six units wide.
    readonly property real sixUnits: 6 * Tokens.tileUnit + 5 * Tokens.spaceS
    // The strips stand as far in as the sections: space-xl sideways, space-m compact (rekta.css:1499, :1139).
    readonly property real stripInset: panorama.inset
    readonly property real placeTop: pivot.height
    readonly property real placeHeight: height - placeTop
    // The panorama and the strip of the place the pivot has chosen.
    readonly property Panorama placePanorama: pivot.currentIndex === 0 ? panorama : appsPanorama
    readonly property Pivot placeStrip: pivot.currentIndex === 0 ? strip : appsStrip
    // The sections of "alle apps", [{title, first, count, units}] (Rules.letterSections).
    property var letterSections: []
    // The rows of tiles a section of "alle apps" holds under its heading; stacked, no letter splits.
    readonly property real letterRows: appsPanorama.sideways ? Math.max(1, Math.floor((appsPanorama.height - 2 * Tokens.spaceXl - headingMeasure.height - Tokens.spaceL + Tokens.spaceS) / unitStep)) : Infinity
    // Whether "läuft" stands in the panorama, the first of its sections.
    readonly property bool anyRunning: running.length > 0
    // What was typed: the text of the search's line.
    property alias query: line.text
    // The search shows, or is on its way, in place of the pivot and the places.
    property bool searching: false
    // What the search finds besides apps: [{name, rows: [{text, lead, icon, key, run, best}]}] (Rules.rowGroups).
    property var rowGroups: []
    // Without any hit, the ways on as rows (Rules.waysOut).
    property var waysOut: []
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
        panorama.goTo(0, false, true);
        appsPanorama.goTo(0, false, true);
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
        startPlace.visible = index === 0;
        appsPlace.visible = index !== 0;
    }

    function goToPlace(index: int) {
        forgetTileFocus();
        turn(index === 0 ? appsPlace : startPlace, index === 0 ? startPlace : appsPlace, {
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
        waysOut = [];
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
            startPlace.visible = false;
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
            waysOut = [];
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
            commands: commands,
            decimalPoint: decimalPoint,
            copy: copy
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
        waysOut = shown.length === 0 && rows.length === 0 ? Rules.waysOut(query.trim(), webSearch, openUrl) : [];
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

    // The search's rows in reading order, under their headings, or the ways on below the empty sentence.
    function searchRows(): var {
        const isRow = item => (item as SearchRow) !== null;
        const rows = [];
        for (const group of rowsColumn.children)
            rows.push(...group.children.filter(isRow));
        return rows.concat(waysOutColumn.children.filter(isRow));
    }

    function press(tile: Tile, act: var) {
        act();
        close(tile);
    }

    function allTiles(): var {
        return [...runningGrid.children, ...pinnedGrid.children, ...hitsGrid.children].filter(item => (item as Tile) !== null).concat(letterTiles());
    }

    // The tiles of the section being read, in reading order.
    function readTiles(): var {
        const section = placePanorama.sectionItems()[placePanorama.currentIndex];
        return reachableTiles().filter(tile => isIn(tile, section));
    }

    // The tiles of "alle apps", in the app model's order.
    function letterTiles(): var {
        return appsPanorama.sectionItems().reduce((tiles, section) => tiles.concat(section.tiles()), []);
    }

    // The section of "alle apps" that holds the app at `index` of the app model.
    function sectionOf(index: int): int {
        return letterSections.findIndex(part => index < part.first + part.count);
    }

    // "alle apps" files the apps anew under their sections when the apps change or the rows a section holds do. The app
    // in focus, else the first of the section being read, stays in view.
    function regroup() {
        const kept = keptApp();
        for (const section of [...appsPanorama.sectionParent.children]) {
            // Out of the panorama at once: destroy() takes it only later.
            section.parent = null;
            section.destroy();
        }
        const listed = apps ?? [];
        letterSections = Rules.letterSections(listed.map(app => app.name), letterRows);
        for (const part of letterSections) {
            letterSection.createObject(appsPanorama.sectionParent, {
                part: part,
                partApps: listed.slice(part.first, part.first + part.count)
            });
        }
        keepInView(kept);
    }

    // The app that stays in view when "alle apps" regroups: {id, focused}, or null without one.
    function keptApp(): var {
        const tiles = letterTiles();
        const focused = tiles.findIndex(tile => tile.activeFocus);
        const at = focused >= 0 ? focused : letterSections[appsPanorama.currentIndex]?.first ?? -1;
        return tiles[at] ? {
            id: tiles[at].modelData.id,
            focused: focused >= 0
        } : null;
    }

    function keepInView(kept: var) {
        const at = kept ? (apps ?? []).findIndex(app => app.id === kept.id) : -1;
        if (at < 0)
            return;
        appsPanorama.goTo(sectionOf(at), false, true);
        if (kept.focused)
            letterTiles()[at].forceActiveFocus();
    }

    function inAllApps(): bool {
        return !searching && pivot.currentIndex === 1;
    }

    // A key typed in "alle apps" jumps to the next app it starts, and its section glides flush left; a turn still running
    // ends first, as typing ends it. Stacked, the section goes to the top at once, so that the focus can then bring an app
    // further down it into view.
    function jump(key: string) {
        turner.finish();
        const tiles = letterTiles();
        const at = Rules.jumpTarget(tiles.map(tile => tile.name), tiles.findIndex(tile => tile.activeFocus), key);
        if (at < 0)
            return;
        appsPanorama.goTo(sectionOf(at), false, !appsPanorama.sideways);
        tiles[at].forceActiveFocus();
    }

    // The tiles a key can reach, in reading order of their sections; those of a hidden view are not visible.
    function reachableTiles(): var {
        return [...allTiles(), ...searchRows()].filter(tile => tile.opens && tile.visible);
    }

    // The strip, the panorama and a heading keep it too.
    function loseFocusIn(box: Item) {
        for (const child of box.children) {
            child.focus = false;
            loseFocusIn(child);
        }
    }

    // A tile, or the list, keeps its focus in the Start's scope while hidden or disabled and takes keys again once
    // shown, so the Start opens, and goes to another place or view, with nothing in focus.
    function forgetTileFocus() {
        for (const tile of [...allTiles(), ...searchRows()])
            tile.focus = false;
        loseFocusIn(startPlace);
        loseFocusIn(appsPlace);
        if (!pivot.activeFocus)
            forceActiveFocus();
    }

    // Past the tiles, right goes to "alle apps", left back to "start" and up to the place's strip; a search has none of
    // them, and up goes to its line.
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
            placeStrip.forceActiveFocus();
    }

    // Up and down between the pivot, the strip and the tiles, when no tile has the focus: down goes the way into the place
    // (pivot, strip, first tile of the section being read), up the way back; with nothing in focus, down goes to the
    // first tile.
    function moveBetweenRows(direction: string): bool {
        const onStrip = placeStrip.activeFocus;
        const inPanorama = placePanorama.activeFocus || headingFocused();
        if (direction === "down" && pivot.activeFocus && !searching)
            placeStrip.forceActiveFocus();
        else if (direction === "down" && (onStrip || inPanorama))
            readTiles()[0]?.forceActiveFocus();
        else if (direction === "up" && onStrip)
            pivot.forceActiveFocus();
        else if (direction === "up" && inPanorama)
            placeStrip.forceActiveFocus();
        else
            return false;
        return true;
    }

    // Arrows move the focus to the nearest tile that way, across the sections.
    // ponytail: this rule is the shell's own from before Rekta had one; 0.6.0 has it for a grid of tiles: shared row or
    // column first, of two as near the better aligned, at the edge focus stays (navigation.md:515–528, :461).
    function moveFocus(direction: string) {
        const tiles = reachableTiles();
        const from = tiles.find(tile => tile.activeFocus);
        if (!from) {
            moveFromNoTile(direction, tiles);
            return;
        }
        const rects = tiles.map(tile => tile.mapToItem(start, 0, 0, tile.width, tile.height));
        const next = Rules.neighbour(rects[tiles.indexOf(from)], rects, direction);
        if (next >= 0)
            tiles[next].forceActiveFocus();
        else
            pastTheTiles(direction);
    }

    function moveFromNoTile(direction: string, tiles: var) {
        if (moveBetweenRows(direction))
            return;
        if (direction === "down" && tiles.length > 0)
            tiles[0].forceActiveFocus();
        else if (direction !== "up" && direction !== "down" && !headingFocused())
            pastTheTiles(direction);
    }

    function headingFocused(): bool {
        return placePanorama.sectionItems().some(section => section.headingFocused);
    }

    function isIn(item: Item, box: Item): bool {
        for (let at = item; at; at = at.parent) {
            if (at === box)
                return true;
        }
        return false;
    }

    // Scrolls the nearest scroller just far enough that what takes the focus there is whole in view, by arrow, by Tab or
    // by a typed letter: a section, the hits, or a stacked panorama (a sideways one brings it in itself). A row's ring
    // stands outside it, so the hits keep its room too.
    function reveal(item: Item) {
        const view = scrollerOf(item);
        if (!view)
            return;
        const at = item.mapToItem(view.contentItem, 0, 0);
        const room = view === results ? results.ringRoom : 0;
        view.contentY = shownFrom(view.contentY, view.height, view.contentHeight, at.y - room, item.height + 2 * room);
        view.contentX = shownFrom(view.contentX, view.width, view.contentWidth, at.x, item.width);
    }

    // The nearest scroller around `item`; a stacked section does not scroll, its panorama does.
    function scrollerOf(item: Item): Flickable {
        for (let at = item?.parent ?? null; at; at = at.parent) {
            const view = at as Flickable;
            if (view?.interactive)
                return view;
        }
        return null;
    }

    // Where a scroller showing `size` of `content` from `scrolled` scrolls to, so that `length` from `start` shows whole.
    function shownFrom(scrolled: real, size: real, content: real, start: real, length: real): real {
        if (start < scrolled)
            return Math.max(0, start);
        if (start + length > scrolled + size)
            return Math.min(Math.max(0, content - size), start + length - size);
        return scrolled;
    }

    // One wheel gesture is one step: events less than wheel-latch apart belong together (layout.md). Only a sideways wheel
    // changes the place; over the chosen place's panorama, once it shows and while it is sideways, only the panorama's
    // pastEnd does, so a gesture that reaches the end on its way stops there. A stacked panorama leaves the wheel alone
    // and says nothing.
    function wheel(event: WheelEvent) {
        if (placePanorama.visible && placePanorama.sideways && placePanorama.contains(placePanorama.mapFromItem(body, event.x, event.y)))
            return;
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
    // (QML's regular expressions know no \p{L}; scripts without one come through an input method, not a single key), or
    // with what a calculation starts with, and goes on with any character that prints, a space too.
    function typesText(event: KeyEvent): bool {
        const text = event.text;
        if (text === "" || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0)
            return false;
        if (query === "")
            return text.length === 1 && (text.toLowerCase() !== text.toUpperCase() || Calc.canStart(text, decimalPoint));
        return !/[\u0000-\u001f\u007f]/.test(text);
    }

    // A key that acts on the hits makes their change first.
    function arrow(direction: string) {
        presence.finish();
        moveFocus(direction);
    }

    // In "alle apps" a key that prints, other than a space, jumps; elsewhere it would search.
    // ponytail: jumping on any printing key is Rekta 0.5.0's; 0.6.0 takes letters and digits only (rekta.js:181).
    function jumpsInAllApps(event: KeyEvent): bool {
        return inAllApps() && event.text.length === 1 && /\S/.test(event.text) && (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) === 0;
    }

    // Home and End go to the first and the last app of "alle apps" (the focused panorama and strip take them first).
    function toTheFirstOrLastApp(event: KeyEvent): bool {
        const tiles = letterTiles();
        if (!inAllApps() || (event.key !== Qt.Key_Home && event.key !== Qt.Key_End) || tiles.length === 0)
            return false;
        tiles[event.key === Qt.Key_Home ? 0 : tiles.length - 1].forceActiveFocus();
        return true;
    }

    // Typing shows the search at once: a turn still running, or the parts still waiting to turn in, ends in its end
    // state first, as a navigation that comes while a turn runs finishes it (rekta.js:379–380, :669–670). What is typed
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
        else if (jumpsInAllApps(event))
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
            return toTheFirstOrLastApp(event);
        return true;
    }

    focus: true
    Accessible.role: Accessible.Pane
    Accessible.name: "start"

    onFocusItemChanged: reveal(focusItem)
    onQueryChanged: refresh()
    // The section being read stays the one read when "läuft" comes before it or goes.
    onAnyRunningChanged: panorama.mark(Math.max(0, panorama.currentIndex + (anyRunning ? 1 : -1)))
    onAppsChanged: {
        refresh();
        regroup();
    }
    onLetterRowsChanged: regroup()

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
        interval: Tokens.turnOverlap * FadeBack.duration
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
        // search, or a Start on its way out, stays where it is. Over a place's sideways panorama the panorama says when a
        // gesture goes past its end (Panorama.pastEnd): the wheel there is its alone, and so is a swipe while it scrolls;
        // one that fits has nothing to flick, and a swipe over its sections is the Start's.
        DragHandler {
            property real dx: 0

            target: null
            enabled: start.wanted && !start.searching
            yAxis.enabled: false
            grabPermissions: (start.placePanorama.fit ? PointerHandler.CanTakeOverFromItems : 0) | PointerHandler.CanTakeOverFromHandlersOfDifferentType | PointerHandler.ApprovesTakeOverByAnything
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

        // The place's strip along the top. Its titles are larger than Rekta's, the inactive one at the title size
        // (rekta.css:52), also compact where Rekta takes the facet sizes (rekta.css:1141–1142): both titles stay above
        // the section headings.
        Pivot {
            id: pivot

            objectName: "pivot"
            x: start.stripInset
            width: parent.width - 2 * start.stripInset
            enabled: start.wanted && !start.searching
            level: "nav"
            activeToken: Tokens.fontSizeNavActive
            inactiveToken: Tokens.fontSizeTitle
            titles: ["start", "alle apps"]
            placeWidth: start.width
            viewportHeight: start.height
            onSelected: index => start.goToPlace(index)
        }

        // The start place: the strip of its sections' titles and the panorama of the sections below it, as wide as the
        // surface (layout.md:19–40). The sections stand in a fixed order, "läuft" only while a window is open.
        Item {
            id: startPlace

            objectName: "startPlace"
            anchors.fill: parent

            Pivot {
                id: strip

                objectName: "sectionStrip"
                x: start.stripInset
                y: start.placeTop
                width: parent.width - 2 * start.stripInset
                enabled: start.wanted
                titles: start.running.length > 0 ? ["läuft", "angeheftet"] : ["angeheftet"]
                placeWidth: start.width
                viewportHeight: start.height
            }

            Panorama {
                id: panorama

                objectName: "panorama"
                y: strip.y + strip.height
                width: parent.width
                height: parent.height - y
                placeWidth: start.width
                viewportHeight: start.height
                sectionStrip: strip
                onPastEnd: forward => {
                    if (forward && start.wanted && !start.searching)
                        pivot.select(1);
                }

                // The sections stand space-xl above and below, the heading space-l before the tiles, the headings one step
                // up from Rekta's: the Start is airier and larger than a compact panorama (rekta.css:1125–1127, :55, :52).
                Section {
                    id: runningSection

                    objectName: "running"
                    title: "läuft"
                    sectionWidth: 2 * start.unitStep
                    verticalInset: Tokens.spaceXl
                    headingSpacing: Tokens.spaceL
                    headingToken: Tokens.fontSizeXl
                    placeWidth: start.width
                    visible: start.running.length > 0
                    enabled: !start.turning

                    TileGrid {
                        id: runningGrid

                        objectName: "grid"
                        width: parent.width
                        columns: 2
                        placeWidth: start.width
                        viewportHeight: start.height

                        Repeater {
                            model: start.running

                            delegate: RunningTile {
                                id: runningTile

                                required property var modelData

                                title: modelData.title
                                icon: modelData.icon
                                // Its preview streams only while the Start shows, from its opening until it has gone.
                                window: start.shown ? modelData : null
                                unseen: start.unseen[modelData.appId] ?? 0
                                preview: start.preview
                                onActivated: start.press(runningTile, () => runningTile.modelData.activate())
                            }
                        }
                    }
                }

                Section {
                    id: pinnedSection

                    objectName: "pinned"
                    title: "angeheftet"
                    sectionWidth: 4 * start.unitStep
                    verticalInset: Tokens.spaceXl
                    headingSpacing: Tokens.spaceL
                    headingToken: Tokens.fontSizeXl
                    placeWidth: start.width
                    enabled: !start.turning

                    TileGrid {
                        id: pinnedGrid

                        objectName: "grid"
                        width: parent.width
                        columns: 4
                        placeWidth: start.width
                        viewportHeight: start.height

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

            // Compact the strip stays above the stacked sections with a hairline under it (rekta.css:1134–1140).
            Hairline {
                objectName: "stripLine"
                y: panorama.y - height
                visible: !panorama.sideways
            }
        }

        // "alle apps": the installed apps A–Z as a panorama under the strip of its sections' titles, as wide as the
        // surface (layout.md:19–40). A section for each initial, as many tile units wide as its apps need in the rows the
        // panorama holds, at most six; a letter with more apps splits into near equal parts (Rules.letterSections). Its
        // tiles are one unit, row by row, and the sections have the start place's spaces and headings.
        // ponytail: a tile for every app, made anew whenever the apps or the rows change; a view that makes only the
        // tiles in sight if hundreds of apps make the Start slow.
        Item {
            id: appsPlace

            objectName: "apps"
            anchors.fill: parent
            visible: false

            Pivot {
                id: appsStrip

                objectName: "appsStrip"
                x: start.stripInset
                y: start.placeTop
                width: parent.width - 2 * start.stripInset
                // As high as the start place's strip, which always has a title: a strip without titles is lower, and the
                // rows its sections hold would change as their titles came.
                height: strip.height
                enabled: start.wanted
                titles: start.letterSections.map(part => part.title)
                placeWidth: start.width
                viewportHeight: start.height
            }

            Panorama {
                id: appsPanorama

                objectName: "appsPanorama"
                y: appsStrip.y + appsStrip.height
                width: parent.width
                height: parent.height - y
                placeWidth: start.width
                viewportHeight: start.height
                sectionStrip: appsStrip
                // "alle apps" is the last place: only a gesture back past its start goes on, to "start".
                onPastEnd: forward => {
                    if (!forward && start.wanted && !start.searching)
                        pivot.select(0);
                }
            }

            Hairline {
                objectName: "appsStripLine"
                y: appsPanorama.y - height
                visible: !appsPanorama.sideways
            }

            // Loading, the line runs on the region's first hairline; without apps a sentence there says so (states.md,
            // "Data states"; rekta.css:890). Both stand where the first section would.
            Item {
                x: appsPanorama.inset
                y: appsPanorama.y + Tokens.spaceXl
                width: Math.min(start.sixUnits, appsPanorama.width - 2 * appsPanorama.inset)

                Hairline {
                    objectName: "appsLine"
                    width: parent.width
                    visible: start.letterSections.length === 0
                }

                BusyLine {
                    objectName: "appsBusy"
                    width: parent.width
                    busy: start.apps === null
                }

                Body {
                    objectName: "noApps"
                    y: Geometry.hairline + Tokens.spaceM
                    width: parent.width
                    visible: start.apps !== null && start.letterSections.length === 0
                    text: "keine apps installiert."
                    color: Tokens.color.textContrastHigh
                }
            }

            // A section of "alle apps": its part of the apps, as wide as its units, with the start place's spaces and
            // headings, larger than Rekta's (rekta.css:1125–1127, :55, :52). Stacked it is as wide as the panorama, its
            // tiles stretched.
            Component {
                id: letterSection

                Section {
                    id: letterPart

                    // {title, first, count, units} and its apps.
                    required property var part
                    required property var partApps

                    function tiles(): var {
                        return letterGrid.children.filter(item => (item as Tile) !== null);
                    }

                    title: part.title
                    sectionWidth: part.units * start.unitStep
                    verticalInset: Tokens.spaceXl
                    headingSpacing: Tokens.spaceL
                    headingToken: Tokens.fontSizeXl
                    placeWidth: start.width
                    enabled: !start.turning

                    TileGrid {
                        id: letterGrid

                        objectName: "grid"
                        width: parent.width
                        columns: letterPart.part.units
                        placeWidth: start.width
                        viewportHeight: start.height

                        Repeater {
                            model: letterPart.partApps

                            delegate: AppTile {
                                id: letterTile

                                required property var modelData

                                name: modelData.name
                                icon: modelData.icon
                                onActivated: start.press(letterTile, () => letterTile.modelData.launch())
                            }
                        }
                    }
                }
            }

            // How high a section's heading stands, for the rows below it.
            GroupHeading {
                id: headingMeasure

                visible: false
                sizeToken: Tokens.fontSizeXl
                placeWidth: start.width
                text: "a"
            }
        }

        // The search's title where the pivot stands, as a place's strip is its title (navigation.md, "Pivot"): what was
        // typed, light, and "suche" beside it as an inactive title, on one baseline, space-l apart (rekta.css:234). A
        // title never shrinks (typography.md); one too long for the six units is cut at its edge, as the strip is.
        Item {
            id: searchTitle

            objectName: "searchTitle"
            x: pivot.x
            width: start.sixUnits
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
            // (`caret-color: currentColor` on `.rk-input`, rekta.css:395–398; rekta-core field.c:472, :503), as high and
            // blinking as the platform draws it, as on the web. Its selection takes the accent with on-accent text, as any
            // selection does (rekta.css:399; field.c:497–498).
            // ponytail: past the six units' edge the caret goes out of sight with the text; cap the width at them
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

        // The apps that match, as tiles one unit square in the six units' grid, space-l above and below as a section
        // (rekta.css:1125).
        Flickable {
            id: results

            readonly property real ringRoom: Geometry.focusRingOffset + Geometry.focusRingWidth
            objectName: "results"
            x: pivot.x - ringRoom
            y: start.placeTop
            width: start.sixUnits + 2 * ringRoom
            height: start.placeHeight
            visible: false
            enabled: !start.turning
            // The focus ring of a row, outside it, is not clipped at the six units' edge.
            leftMargin: ringRoom
            rightMargin: ringRoom
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
                width: start.sixUnits

                Repeater {
                    model: start.rowGroups

                    delegate: Column {
                        id: group

                        required property var modelData

                        objectName: group.modelData.name
                        width: rowsColumn.width

                        MenuLabel {
                            objectName: "heading"
                            leftPadding: 0
                            rightPadding: 0
                            text: group.modelData.name
                        }

                        Repeater {
                            model: group.modelData.rows
                            delegate: hitRow
                        }
                    }
                }
            }

            // Without a match, a sentence on the region's first hairline says so, and the ways on follow it as rows
            // (states.md, "Empty"; rekta.css:890–891).
            Empty {
                id: noHits

                objectName: "noHits"
                y: Tokens.spaceL
                width: start.sixUnits
                visible: found.count === 0 && start.rowGroups.length === 0
                text: `nichts zum hingehen oder ausführen passt zu „${start.query.trim()}“.`

                Column {
                    id: waysOutColumn

                    objectName: "waysOut"
                    width: parent.width

                    Repeater {
                        model: start.waysOut
                        delegate: hitRow
                    }
                }
            }

            Component {
                id: hitRow

                SearchRow {
                    id: searchRow

                    required property var modelData

                    text: searchRow.modelData.text
                    lead: searchRow.modelData.lead
                    icon: searchRow.modelData.icon
                    best: searchRow.modelData.best === true
                    keyHint: searchRow.modelData.key ?? ""
                    onActivated: start.chooseRow(searchRow.modelData)
                }
            }
        }
    }
}
