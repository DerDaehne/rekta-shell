pragma ComponentBehavior: Bound

import QtQuick
import Notices
import Rekta
import State

// The Start, after the shell's decision for it: glass over the windows, across the whole surface. Its pivot
// "start · alle apps" picks the place; the start place is a panorama of sections under a strip of their titles:
// "läuft", a tile for each open window, the most recent first, then "angeheftet", the pinned apps, then "heute", what
// plays and the newest notifications (Today), then "zuletzt", the files used last (Recent); "alle apps" is a
// panorama of the installed apps A–Z, a section for each initial, where a typed letter jumps to the next app it
// starts. It opens once the windows are three quarters of their way back (Rekta's hand-over between places), its
// parts folding up in reading order, and closes folding them away: back the way they came, the last part in first, or
// forward after a press, the pressed tile last. While it turns in, its tiles take keys and presses; while it turns out,
// none. A letter typed in the start place searches, and so does what a calculation starts with: what is typed becomes
// the title, "suche" beside it, and the apps that match stand below as tiles, the other kinds as rows. The title is a
// line edited as a field is; Escape there closes the Start. An app's tile has a context menu that pins or unpins the
// app and, in "angeheftet", sizes its tile; each change offers undo in a toast, and Delete unpins the focused pinned
// tile.
FocusScope {
    id: start

    // The open windows: {title, icon, lastActivated, stackingOrder, active, minimized, activate()}.
    property var windows: []
    // The window that had the keyboard when the Start opened; it gets it back unless a press chose where to go.
    property var returnTo: null
    // The pinned apps: {id, name, icon, columns, rows, index, launch()}, `index` counting in start.json's list.
    property var pinned: []
    // The pinned apps as "angeheftet" shows them: `pinned` once its change has been made.
    property var shownPins: []
    // Writes start.json (StartFile): pin(id), unpin(index), resize(index, columns, rows), insert(index, entry),
    // replace(index, entry), entry(index), and its fault, "broken" while nothing may write over it. Null: no menus.
    property var pinFile: null
    // Shows the toast that offers undo after a change (Toaster); null for none.
    property var toaster: null
    // What the context menu acts on: {id, name, index, columns, rows, sized}; `id` is "" when no app is known, `index`
    // -1 when the app is not pinned, and `sized` holds in "angeheftet", where the sizes are offered.
    property var menuApp: null
    // Where the menu's tile stood as the menu opened; a scroll that moves it closes the menu.
    property point menuTileAt
    // The scrollers that hold the menu's tile, followed while the menu is open.
    property var menuScrollers: []
    // The last pinned tile was unpinned with the focus on it: the focus goes to the empty section's way on.
    property bool focusEmptyPins: false
    // The installed apps, A–Z: {id, name, genericName, keywords, exec, icon, launch()}; null until they are known.
    property var apps: null
    // How often each app was started from the Start, by id: {id: count}; the more often, the nearer the front of the hits.
    property var starts: ({})
    // The unseen notifications by app id: {id: count}.
    property var unseen: ({})
    // The newest line by app id, such as what its player plays: {id: text}.
    property var lines: ({})
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
    // What "heute" shows: the notifications and the choice of player.
    property NoticeBoard board: null
    property PlayerChoice playerChoice: null
    // "zuletzt" shows; off, it is not there and nothing reads the files used.
    property bool showRecent: true
    // closed, opening (the glass comes, then the parts turn in), open, or closing (the parts turn out, the glass goes); or
    // following a finger that swipes it open, and returning when the finger let go short of half its way; from open,
    // followingOut a finger that draws it down, and returningIn when that finger let go short of half its way.
    property string phase: "closed"
    // From opening until it has closed; the host shows its surface while this holds.
    readonly property bool shown: phase !== "closed"
    // From open() to close(): the Start is open or on its way.
    readonly property bool wanted: phase === "opening" || phase === "open"
    // A finger has taken the closing along: the Start keeps the keyboard and its focus, but takes no keys or presses.
    readonly property bool fingerCloses: phase === "followingOut" || phase === "returningIn"
    // From open() to the hand-over, when the glass starts to go. KWin's fade-back steps the windows back when the
    // surface takes the keyboard and brings them forward when it gives it back; the surface, glass and blur, fades
    // along with them. A finger taking the closing along keeps it. Read from the phase itself: `wanted` and
    // `fingerCloses` change one after the other, and the keyboard must not drop between them.
    readonly property bool holdsKeyboard: wanted || phase === "followingOut" || phase === "returningIn" || (phase === "closing" && !glassOut.running)
    readonly property bool turning: turner.running || waitForWindows.running
    readonly property var running: Rules.recentFirst(windows)
    // The time of the last wheel event, to tell one gesture from the next.
    property double lastWheel: 0
    readonly property Item focusItem: Window.activeFocusItem
    // A tile unit and the space after it: a section is as wide as its units (site/site.css:78).
    readonly property real unitStep: Tokens.tileUnit + Tokens.spaceS
    // The loading line of "alle apps" keeps to the leading edge, at most six units wide.
    readonly property real sixUnits: 6 * Tokens.tileUnit + 5 * Tokens.spaceS
    // The strips stand as far in as the sections: space-xl sideways, space-m compact (rekta.css:1499, :1139).
    readonly property real stripInset: panorama.inset
    // The search keeps between the sections' edges. Sideways it is as many whole tile units as fit there, at most six,
    // in fixed cells (layout.md:115–116); compact it takes the whole width between them, its grid stretched as the
    // sections' grids are (layout.md:112–114).
    readonly property int searchUnits: Math.min(6, Math.floor((width - 2 * stripInset + Tokens.spaceS) / unitStep))
    readonly property real searchWidth: panorama.sideways ? searchUnits * unitStep - Tokens.spaceS : width - 2 * stripInset
    readonly property real placeTop: pivot.height
    readonly property real placeHeight: height - placeTop
    // The panorama and the strip of the place the pivot has chosen.
    readonly property Panorama placePanorama: pivot.currentIndex === 0 ? panorama : appsPanorama
    readonly property Pivot placeStrip: pivot.currentIndex === 0 ? strip : appsStrip
    // The sections of "alle apps", [{title, first, count, units}] (Rules.letterSections).
    property var letterSections: []
    // The rows of tiles a section of "alle apps" holds under its heading; stacked, no letter splits.
    readonly property real letterRows: rowsHeld(appsPanorama)
    // "angeheftet" is as many units wide as its tiles need in the rows it holds, at least four and only while it fits
    // with "heute" and "zuletzt" before the trailing inset; on a panorama past the window it keeps four (layout.md:146–148 against :31–32).
    readonly property int pinnedUnits: fittedPinnedUnits()
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
    // The height of the screen the Start covers: a finger swiping up from its bottom edge opens the Start all the way
    // at half of it.
    property real screenHeight: height
    // How far of that way the finger has come, 0 to 1.
    property real fingerShare: 0
    // The opening a finger takes along, in ms since it began: where it stands, and its end, the last part landed.
    property real openingAt: 0
    property real openingTime: 0
    // The same for the closing back a finger takes along; its windows come forward from the hand-over on.
    property real closingAt: 0
    property real closingTime: 0

    signal closed
    // The windows behind the Start stand `time` ms into its opening and go on from there: held (0), on (1) or back to
    // its beginning (-1). KWin's fade-back moves them, and the glass with them.
    signal windowsAt(real time, int pace)
    // The same on the way the windows come forward as the Start closes, from all the way back.
    signal windowsOutAt(real time, int pace)

    // The rows of tiles a section of `place` holds under its heading; stacked, as many as it has.
    function rowsHeld(place: Panorama): real {
        if (!place.sideways)
            return Infinity;
        return Math.max(1, Math.floor((place.height - 2 * Tokens.spaceXl - headingMeasure.height - Tokens.spaceL + Tokens.spaceS) / unitStep));
    }

    function fittedPinnedUnits(): int {
        // Not runningSection.visible: that is false while the Start is hidden, and the width would change as it shows.
        // Rekta's own gap, not panorama.gap: that one follows from the sections' widths, this one's among them.
        const before = running.length > 0 ? runningSection.sectionWidth + Tokens.spaceXl : 0;
        const after = todaySection.sectionWidth + Tokens.spaceXl + (showRecent ? recentSection.sectionWidth + Tokens.spaceXl : 0);
        const room = Math.floor((panorama.width - 2 * panorama.inset - before - after) / unitStep);
        const rows = rowsHeld(panorama);
        let units = 4;
        while (units < room && pinnedGrid.rowsOf(shownPins, units) > rows)
            units++;
        return units;
    }

    // An opening a finger has taken along goes on from where it stands.
    function open() {
        if (wanted || fingerCloses)
            return;
        if (phase === "following" || phase === "returning") {
            goOn();
            return;
        }
        setOut("opening");
        // The parts wait until the windows are three quarters of their way back, as the next place waits for the last
        // part leaving.
        if (waitForWindows.interval > 0)
            waitForWindows.restart();
        else
            turnIn();
    }

    // The Start sets out to open, `how`: "opening", or "following" a finger.
    function setOut(how: string) {
        quietly(() => turner.finish());
        endSearch();
        returnTo = windows.find(window => window.active) ?? null;
        panorama.goTo(0, false, true);
        appsPanorama.goTo(0, false, true);
        phase = how;
        glassOut.stop();
        pivot.focus = false;
        forgetTileFocus();
        body.visible = false;
    }

    // A finger `distance` px up from where it set down on the screen's bottom edge: the whole opening, windows, glass and
    // parts, stands where the finger has taken it. Under reduced motion nothing follows it.
    // ponytail: Rekta has no rule for a place that follows a finger; the way is half the screen's height and the finger
    // decides at half of it, as a dragged row does (motion.md:25). Take Rekta's rule once it gives one.
    function followFinger(distance: real) {
        fingerShare = Math.min(1, Math.max(0, distance / (screenHeight / 2)));
        if (Tokens.reducedMotion)
            return;
        if (phase === "closed")
            setOut("following");
        standWithFinger();
    }

    // The opening where the finger has taken it, once its parts are planned. They are as the Start has its size: under a
    // full-screen window its surface maps only as the finger comes.
    function standWithFinger() {
        if (phase !== "following" || width <= 0 || height <= 0)
            return;
        if (!turner.running)
            planFollowing();
        showAt(fingerShare * openingTime);
        windowsAt(openingAt, 0);
    }

    // Let go past half its way, the opening goes on from where it stands; short of it, it runs back to its beginning.
    function letFingerGo() {
        const past = fingerShare >= 0.5;
        fingerShare = 0;
        if (phase === "following") {
            if (past)
                goOn();
            else
                runBack();
        } else if (past && Tokens.reducedMotion) {
            open();
        }
    }

    // The parts stand ready to turn in, held at whatever moment the finger names; not one lets go before the end, so
    // the opening can go back.
    function planFollowing() {
        turnIn();
        turner.paused = true;
        turner.keepsLanded = true;
        openingTime = waitForWindows.interval + Math.max(0, ...turner.arrivingTurns.map(turn => turn.at + turn.duration));
    }

    // The opening `time` ms after it began: the parts turn in from when the windows are three quarters of their way
    // back.
    function showAt(time: real) {
        openingAt = time;
        turner.elapsed = Math.max(0, time - waitForWindows.interval);
    }

    // On in its own times, and the Start takes the keyboard as after Meta. Let go before its parts were planned, it
    // opens as Meta opens it.
    function goOn() {
        if (!turner.running) {
            phase = "closed";
            open();
            return;
        }
        phase = "opening";
        windowsAt(openingAt, 1);
        runFinger(openingAt, 1, false);
    }

    // Back the same way in the same times; the Start never takes the keyboard.
    function runBack() {
        if (!turner.running) {
            returned();
            return;
        }
        phase = "returning";
        windowsAt(openingAt, -1);
        runFinger(openingAt, -1, false);
    }

    // The clock runs the opening, or with `closes` the closing, from `from` on or back.
    function runFinger(from: real, pace: int, closes: bool) {
        fingerClock.from = from;
        fingerClock.pace = pace;
        fingerClock.closes = closes;
        fingerClock.reset();
        fingerClock.start();
    }

    function fingerTick(time: real) {
        // Typing or a press has ended the turn meanwhile.
        if (!turner.running) {
            fingerClock.stop();
            return;
        }
        showAt(Math.min(openingTime, Math.max(0, time)));
        if (fingerClock.pace > 0 && openingAt >= openingTime)
            landFinger();
        else if (fingerClock.pace < 0 && openingAt <= 0)
            returned();
    }

    function landFinger() {
        fingerClock.stop();
        turner.paused = false;
        turner.finish();
    }

    // At its beginning the Start is gone again, and the window that had the keyboard has kept it.
    function returned() {
        fingerClock.stop();
        quietly(() => turner.finish());
        turner.paused = false;
        body.visible = false;
        returnTo = null;
        hide();
    }

    // A finger `distance` px down from where it set down over the open Start: the whole closing back, parts, windows and
    // glass, stands where the finger has taken it, the Start keeping the keyboard. Under reduced motion nothing follows.
    // ponytail: as for followFinger, Rekta has no rule for it; the way is half the screen's height and the finger decides
    // at half of it (motion.md:25). Take Rekta's rule once it gives one.
    function followFingerOut(distance: real) {
        fingerShare = Math.min(1, Math.max(0, distance / (screenHeight / 2)));
        if (Tokens.reducedMotion)
            return;
        if (phase === "open")
            planClosing();
        if (phase !== "followingOut")
            return;
        showClosingAt(fingerShare * closingTime);
        windowsOutAt(windowsComeAt(), 0);
    }

    // Let go past half its way, the closing goes on from where it stands; short of it, it runs back to the open Start.
    function letFingerGoOut() {
        const past = fingerShare >= 0.5;
        fingerShare = 0;
        if (phase === "followingOut") {
            if (past)
                goOut();
            else
                runBackIn();
        } else if (past && Tokens.reducedMotion) {
            close(null);
        }
    }

    // The parts stand ready to turn out as Escape turns them, held at whatever moment the finger names.
    function planClosing() {
        phase = "followingOut";
        turnOut(true, null);
        turner.paused = true;
        turner.keepsLanded = true;
        closingTime = turner.handOverAt + FadeBack.duration;
    }

    // The closing `time` ms after it began: from the hand-over on the parts are gone and the windows come forward.
    function showClosingAt(time: real) {
        closingAt = time;
        turner.elapsed = Math.min(time, turner.handOverAt);
        body.opacity = time < turner.handOverAt ? 1 : 0;
    }

    function windowsComeAt(): real {
        return Math.max(0, closingAt - turner.handOverAt);
    }

    // On in its own times; once the parts are out, the glass goes and the keyboard goes back as after Escape.
    function goOut() {
        phase = "closing";
        runFinger(closingAt, 1, true);
        if (closingAt >= turner.handOverAt)
            partsGone();
    }

    // Back the same way in the same times; the Start stays open with the keyboard and the focus it had.
    function runBackIn() {
        phase = "returningIn";
        windowsOutAt(windowsComeAt(), -1);
        runFinger(closingAt, -1, true);
    }

    function closingTick(time: real) {
        showClosingAt(Math.min(closingTime, Math.max(0, time)));
        if (fingerClock.pace > 0 && closingAt >= turner.handOverAt)
            partsGone();
        else if (fingerClock.pace < 0 && closingAt <= 0)
            stayed();
    }

    // The windows come forward from where they stand, and the glass goes with them for the rest of their way.
    function partsGone() {
        fingerClock.stop();
        glassOut.ahead = windowsComeAt();
        windowsOutAt(glassOut.ahead, 1);
        turner.paused = false;
        turner.keepsLanded = false;
        turner.finish();
        body.opacity = 1;
    }

    function stayed() {
        fingerClock.stop();
        quietly(() => turner.drop());
        turner.paused = false;
        body.opacity = 1;
        phase = "open";
    }

    // Under the press at `point` in the Start the nearest scroller is off its top: a finger moving down scrolls it.
    function scrollsDownAt(point: point): bool {
        return scrollerAt(body, point)?.atYBeginning === false;
    }

    // The innermost scroller under `point` in `item`, or null. Not by childAt: an overlay that only reads the wheel lies
    // above the panorama's scroller.
    function scrollerAt(item: Item, point: point): Flickable {
        for (const child of item.children) {
            const at = item.mapToItem(child, point.x, point.y);
            if (!child.visible || !child.contains(at))
                continue;
            const view = scrollerAt(child, at) ?? (child as Flickable);
            if (view?.interactive)
                return view;
        }
        return null;
    }

    // The Start's own turns, in and out, run at its tempo and fold its parts up from the bottom it is swiped up from; a
    // change of place inside it at Rekta's, about the leading edge.
    function turnIn() {
        turn(null, body, {
            tempo: Geometry.startTempo,
            edge: "bottom"
        });
    }

    // `pressed` is the tile that was pressed to leave; without one the Start goes back the way it came.
    function close(pressed: Tile) {
        if (fingerCloses) {
            goOut();
            return;
        }
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
        turnOut(options.back, options.pressed);
    }

    function turnOut(back: bool, pressed: Tile) {
        turn(body, null, {
            back: back,
            pressed: pressed,
            tempo: Geometry.startTempo,
            edge: "bottom"
        });
    }

    function toggle() {
        if (wanted || fingerCloses)
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
        fingerClock.stop();
        turner.paused = false;
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
        if (returnTo !== null)
            giveKeyboardBack();
        returnTo = null;
    }

    // To the window that had it; when that one has closed or been minimised meanwhile, to the most recent window that
    // still shows, as KWin hands it on when the active window goes. Activating a minimised window would bring it back.
    // ponytail: windows on other virtual desktops count too; the shell follows no virtual desktops yet.
    function giveKeyboardBack() {
        const shown = running.filter(window => !window.minimized);
        (shown.includes(returnTo) ? returnTo : shown[0])?.activate();
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
        glassOut.ahead = 0;
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

    // The tiles of "angeheftet", in its order.
    function pinTiles(): var {
        return Array.from({
            length: pinnedRepeater.count
        }, (_, k) => pinnedRepeater.itemAt(k));
    }

    // The pinned apps change: the tiles of apps no longer pinned leave, the others glide to their places and sizes, and
    // those of newly pinned apps arrive (motion.md:22–24); at once while the Start is hidden or turns, the turn being
    // the arrival.
    function followPinned() {
        // A change still waiting is made first, as it was meant: its tiles leave before this one is weighed.
        presence.finish();
        const next = pinned;
        const tiles = pinTiles();
        const kept = new Set(next.map(app => app.id));
        const before = new Set(tiles.map(tile => tile.appId));
        const coming = next.filter(app => !before.has(app.id)).map(app => app.id);
        const going = tiles.filter(tile => !kept.has(tile.appId));
        // What the menu offers was read from the list as it was.
        menu.close(false);
        if (!shown || turning) {
            showPins(next);
            return;
        }
        presence.change(going, tiles.filter(tile => kept.has(tile.appId)), () => showPins(next), () => pinTiles().filter(tile => coming.includes(tile.appId)), coming.length);
    }

    // Brings the tiles in line with `list`, step by step, so that a tile that stays is the same tile.
    function showPins(list: var) {
        shownPins = list;
        for (const step of Rules.steps(pinTiles().map(tile => tile.appId), list.map(app => app.id))) {
            if (step.remove !== undefined)
                pinnedModel.remove(step.remove);
            else if (step.move !== undefined)
                pinnedModel.move(step.move, step.to, 1);
            else
                pinnedModel.insert(step.insert, { appId: step.id });
        }
        pinnedGrid.order = pinTiles();
        if (focusEmptyPins && pinnedModel.count === 0)
            toAllApps.forceActiveFocus();
        focusEmptyPins = false;
    }

    // A tile asks for its context menu at `at`, in the tile. `id` is its app's, "" when none is known; `inPinned` offers
    // the sizes too. The menu opens at that point, turned to stay in the Start, with the first item it may choose in focus.
    function openMenu(tile: Tile, at: point, id: string, inPinned: bool) {
        const app = (apps ?? []).find(known => Rules.sameApp(known.id, id)) ?? null;
        const pin = pinned.find(known => Rules.sameApp(known.id, id)) ?? null;
        menuApp = {
            id: app?.id ?? pin?.id ?? "",
            name: app?.name ?? pin?.name ?? "",
            index: pin?.index ?? -1,
            columns: pin?.columns ?? 1,
            rows: pin?.rows ?? 1,
            sized: inPinned && pin !== null
        };
        sizeRows().forEach((row, k) => row.checked = Rules.pinSizes[k].columns === menuApp.columns && Rules.pinSizes[k].rows === menuApp.rows);
        menu.close(false);
        menu.control = tile;
        menu.openAt(Math.max(0, menu.items().findIndex(item => !item.disabled)));
        const place = Placement.at(tile.mapToItem(start, at.x, at.y), menu.measured(), Qt.size(width, height));
        menu.x = place.x;
        menu.y = place.y;
        menu.side = place.side;
        followMenuTile(tile);
    }

    // The menu's size items, in the order of Rules.pinSizes.
    function sizeRows(): var {
        return Array.from(menu.rows).filter(row => row.objectName === "size");
    }

    // A scroll that moves the menu's tile closes the menu; one that leaves the tile where it was does not (rekta.js:3190).
    function followMenuTile(tile: Tile) {
        menuTileAt = tile.mapToItem(start, 0, 0);
        const scrollers = [];
        for (let at = tile.parent; at; at = at.parent) {
            if (at instanceof Flickable)
                scrollers.push(at);
        }
        for (const scroller of scrollers) {
            scroller.contentXChanged.connect(menuTileMoved);
            scroller.contentYChanged.connect(menuTileMoved);
        }
        menuScrollers = scrollers;
    }

    function menuTileMoved() {
        const now = menu.control?.mapToItem(start, 0, 0) ?? null;
        if (!now || Math.abs(now.x - menuTileAt.x) > Geometry.contextMenuScrollSlop || Math.abs(now.y - menuTileAt.y) > Geometry.contextMenuScrollSlop)
            menu.close(false);
    }

    function forgetMenuTile() {
        for (const scroller of menuScrollers) {
            scroller.contentXChanged.disconnect(menuTileMoved);
            scroller.contentYChanged.disconnect(menuTileMoved);
        }
        menuScrollers = [];
    }

    // Why the menu cannot do what an item says, or "" when it can.
    function menuBlocked(): string {
        if (menuApp?.id === "")
            return "keine app bekannt";
        return pinFile?.fault === "broken" ? "start.json ist beschädigt" : "";
    }

    function choose(item: MenuItem) {
        const app = menuApp;
        const size = sizeRows().indexOf(item);
        if (size >= 0)
            resizeApp(app, Rules.pinSizes[size]);
        else if (app.index >= 0)
            unpinApp(app, menu.control);
        else
            pinApp(app);
    }

    // A change to start.json shows a toast that offers to undo it.
    function tell(text: string, undo: var) {
        toaster?.show(text, {
            undo: undo
        });
    }

    // A newly pinned app goes to the end, one unit.
    function pinApp(app: var) {
        if (!pinFile.pin(app.id))
            return;
        tell(`${app.name} angeheftet`, () => {
            const at = pinned.find(known => Rules.sameApp(known.id, app.id))?.index ?? -1;
            if (at >= 0)
                pinFile.unpin(at);
        });
    }

    // Unpinning the focused tile hands the focus to the next tile, at the end to the one before, and without any to the
    // empty section's way on (collections.md:167–169).
    // ponytail: an undo counts by the index the entry had; a change made meanwhile elsewhere can shift it; look the place up by app id once pins can be reordered.
    function unpinApp(app: var, tile: Tile) {
        const focused = tile?.activeFocus ?? false;
        const tiles = pinTiles();
        const at = tiles.indexOf(tile);
        const next = focused ? tiles[at + 1] ?? tiles[at - 1] ?? null : null;
        const entry = pinFile.entry(app.index);
        // Set before the change, which may show at once.
        focusEmptyPins = focused && next === null;
        if (!pinFile.unpin(app.index)) {
            focusEmptyPins = false;
            return;
        }
        next?.forceActiveFocus();
        tell(`${app.name} gelöst`, () => pinFile.insert(app.index, entry));
    }

    function resizeApp(app: var, size: var) {
        if (size.columns === app.columns && size.rows === app.rows)
            return;
        const entry = pinFile.entry(app.index);
        if (pinFile.resize(app.index, size.columns, size.rows))
            tell(`${app.name}: ${size.name}`, () => pinFile.replace(app.index, entry));
    }

    // Delete unpins the focused tile of "angeheftet" (navigation.md:475).
    function unpinFocused() {
        const tile = pinTiles().find(pinTile => pinTile.activeFocus);
        const app = pinned.find(known => known.id === tile?.appId);
        if (!app || !pinFile)
            return;
        unpinApp({
            id: app.id,
            name: app.name,
            index: app.index
        }, tile);
    }

    // Ctrl+Z goes to the key layers, where an open undo toast takes it.
    function passUndo(event: KeyEvent): bool {
        const command = (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) !== 0;
        return event.key === Qt.Key_Z && command && !(event.modifiers & Qt.ShiftModifier) && KeyLayers.dispatch(event, focusItem);
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

    // A press ends a turn still running before it acts, as a navigation does (rekta.js turn.leave()).
    function press(tile: Tile, act: var) {
        quietly(() => turner.finish());
        act();
        close(tile);
    }

    function allTiles(): var {
        return [...runningGrid.children, ...pinnedGrid.children, ...hitsGrid.children].filter(item => (item as Tile) !== null).concat(today.entries(), recent.entries(), letterTiles());
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
        bringPlaceIn();
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
        bringPlaceIn();
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

    // Every key goes while the Start turns in, as a navigation always does: typing, to search or to jump, ends the turn,
    // arrows move the focus while it runs on, and Enter on a tile ends it and acts. Escape in a search closes the Start
    // at once unless searchEscape says back; the other ways back clear the search first.
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
        else if (event.key in directions)
            arrow(directions[event.key]);
        else if (isEnter(event) && searching)
            pressFirstHit();
        else if (event.key === Qt.Key_Delete)
            unpinFocused();
        else
            return toTheFirstOrLastApp(event) || pagesThePlace(event);
        return true;
    }

    // PageUp and PageDown scroll a stacked place from anywhere, as they scroll a page wherever the focus is.
    function pagesThePlace(event: KeyEvent): bool {
        return placePanorama.visible && placePanorama.pageKey(event, false);
    }

    // A key for the tiles finds the chosen place in view: the parts waiting for the windows turn in now, and a place
    // change still turning the last place out ends, as a navigation ends it (navigation.md:103–105).
    function bringPlaceIn() {
        if (waitForWindows.running) {
            waitForWindows.stop();
            turnIn();
        } else if (turner.running && !turner.handedOver) {
            turner.finish();
        }
    }

    focus: true
    Accessible.role: Accessible.Pane
    Accessible.name: "start"

    onFocusItemChanged: reveal(focusItem)
    onPinnedChanged: followPinned()
    onWantedChanged: menu.close(false)
    onWidthChanged: {
        menu.close(false);
        standWithFinger();
    }
    onHeightChanged: {
        menu.close(false);
        standWithFinger();
    }
    Component.onCompleted: showPins(pinned)
    onQueryChanged: refresh()
    onAppsChanged: {
        refresh();
        regroup();
    }
    onLetterRowsChanged: regroup()

    // An open menu keeps every key; Ctrl+Z goes on to the undo toast.
    Keys.onPressed: event => {
        if (menu.open || (wanted && (passUndo(event) || useKey(event))))
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

    // The glass goes as the windows come forward from the hand-over, or from `ahead` ms into their way, where a finger
    // let them go; then the Start empties.
    Timer {
        id: glassOut

        property real ahead: 0

        objectName: "glassOut"
        interval: FadeBack.duration - ahead
        onTriggered: start.hide()
    }

    Timer {
        id: waitForWindows

        objectName: "waitForWindows"
        interval: Math.round(FadeBack.stepBackTime(Tokens.turnOverlap))
        onTriggered: start.turnIn()
    }

    // Runs the opening or the closing a finger has let go on or back from where it stood.
    FrameAnimation {
        id: fingerClock

        property real from: 0
        property int pace: 1
        property bool closes: false

        onTriggered: {
            const time = from + pace * elapsedTime * 1000;
            if (closes)
                start.closingTick(time);
            else
                start.fingerTick(time);
        }
    }

    Presence {
        id: presence

        objectName: "presence"
    }

    // A change of place, or a turn to the other one, closes the menu.
    Connections {
        target: pivot

        function onCurrentIndexChanged() {
            menu.close(false);
        }
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

        // A finger drawing down over the open Start takes its closing back along; a mouse scrolls or selects. Only a
        // gesture that sets out mostly down is the Start's (collections.md:170–177), and none over a scroller off its
        // top: a gesture belongs to one scroller (layout.md:54–68), so a scroll that reaches the top on the way does
        // not close. Taking the finger over cancels a tile's press (platforms.md:197–198).
        DragHandler {
            property bool closes: false
            property bool scrollsHere: false

            objectName: "drawDown"
            target: null
            acceptedDevices: PointerDevice.TouchScreen
            xAxis.enabled: false
            enabled: active || (!scrollsHere && start.phase === "open" && !start.turning && !line.activeFocus && line.selectedText === "")
            onGrabChanged: (transition, point) => {
                if (transition === PointerDevice.GrabPassive)
                    scrollsHere = start.scrollsDownAt(body.mapFromItem(null, point.scenePressPosition));
                else if (transition === PointerDevice.UngrabPassive || transition === PointerDevice.CancelGrabPassive)
                    scrollsHere = false;
            }
            onActiveChanged: {
                if (active)
                    closes = centroid.scenePosition.y > centroid.scenePressPosition.y && !scrollsHere;
                else if (closes)
                    start.letFingerGoOut();
                if (!active)
                    closes = false;
            }
            onActiveTranslationChanged: {
                if (active && closes)
                    start.followFingerOut(activeTranslation.y);
            }
        }

        WheelHandler {
            enabled: start.wanted && !start.searching
            orientation: Qt.Horizontal
            onWheel: event => start.wheel(event)
        }

        // The place's strip along the top. Its titles are larger than Rekta's, the inactive one at the title size
        // (rekta.css:53), also compact where Rekta takes the facet sizes (rekta.css:1141–1142): both titles stay above
        // the section headings.
        Pivot {
            id: pivot

            objectName: "pivot"
            x: start.stripInset
            width: parent.width - 2 * start.stripInset
            enabled: start.wanted && !start.searching
            level: "nav"
            onGlass: true
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
                onGlass: true
                x: start.stripInset
                y: start.placeTop
                width: parent.width - 2 * start.stripInset
                enabled: start.wanted
                titles: (start.running.length > 0 ? ["läuft"] : []).concat(["angeheftet", "heute"], start.showRecent ? ["zuletzt"] : [])
                placeWidth: start.width
                viewportHeight: start.height
            }

            Panorama {
                id: panorama

                objectName: "panorama"
                y: strip.y + strip.height + (panorama.sideways ? 0 : Geometry.hairline)
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
                    enabled: start.wanted

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
                                preview: start.preview
                                hasMenu: start.pinFile !== null
                                onActivated: start.press(runningTile, () => runningTile.modelData.activate())
                                onMenuAsked: at => start.openMenu(runningTile, at, runningTile.modelData.appId ?? "", false)
                            }
                        }
                    }
                }

                Section {
                    id: pinnedSection

                    objectName: "pinned"
                    title: "angeheftet"
                    sectionWidth: start.pinnedUnits * start.unitStep
                    verticalInset: Tokens.spaceXl
                    headingSpacing: Tokens.spaceL
                    headingToken: Tokens.fontSizeXl
                    placeWidth: start.width
                    enabled: start.wanted

                    TileGrid {
                        id: pinnedGrid

                        objectName: "grid"
                        width: parent.width
                        columns: start.pinnedUnits
                        placeWidth: start.width
                        viewportHeight: start.height
                        visible: pinnedModel.count > 0

                        // A tile for each app as long as it stays pinned, so a change moves the tiles it keeps.
                        Repeater {
                            id: pinnedRepeater

                            model: ListModel {
                                id: pinnedModel
                            }

                            delegate: AppTile {
                                id: appTile

                                required property string appId
                                readonly property var app: start.shownPins.find(pin => pin.id === appId) ?? null

                                name: app?.name ?? ""
                                icon: app?.icon ?? ""
                                unseen: start.unseen[appId] ?? 0
                                line: start.lines[appId] ?? ""
                                columns: app?.columns ?? 1
                                rows: app?.rows ?? 1
                                hasMenu: start.pinFile !== null
                                onActivated: start.press(appTile, () => appTile.app?.launch())
                                onMenuAsked: at => start.openMenu(appTile, at, appTile.appId, true)
                            }
                        }
                    }

                    // Nothing pinned: the sentence and the way to the apps (states.md:12).
                    Empty {
                        objectName: "noPins"
                        width: parent.width
                        visible: pinnedModel.count === 0
                        text: "nichts angeheftet."

                        Button {
                            id: toAllApps

                            objectName: "allApps"
                            text: "alle apps"
                            onClicked: pivot.select(1)
                        }
                    }
                }

                // Always there, empty too, two units wide; a press there leaves forward, as a row of the search does.
                Section {
                    id: todaySection

                    objectName: "today"
                    title: "heute"
                    sectionWidth: 2 * start.unitStep
                    verticalInset: Tokens.spaceXl
                    headingSpacing: Tokens.spaceL
                    headingToken: Tokens.fontSizeXl
                    placeWidth: start.width
                    enabled: start.wanted

                    Today {
                        id: today

                        board: start.board
                        choice: start.playerChoice
                        windows: start.windows
                        onChosen: start.leave({
                            back: false,
                            pressed: null
                        })
                    }
                }

                // The last section, two units wide; its rows scroll within it. A press opens the file and leaves forward. Off,
                // it is out of the panorama, which counts every section while it is hidden itself.
                Section {
                    id: recentSection

                    objectName: "recent"
                    title: "zuletzt"
                    sectionWidth: 2 * start.unitStep
                    verticalInset: Tokens.spaceXl
                    headingSpacing: Tokens.spaceL
                    headingToken: Tokens.fontSizeXl
                    placeWidth: start.width
                    parent: start.showRecent ? panorama.sectionParent : null
                    enabled: start.wanted

                    Recent {
                        id: recent

                        active: start.showRecent
                        inSight: start.wanted
                        openUrl: start.openUrl
                        onChosen: start.leave({
                            back: false,
                            pressed: null
                        })
                    }
                }
            }

            // Compact the strip stays above the stacked sections with a hairline under it (rekta.css:1134–1140).
            Hairline {
                objectName: "stripLine"
                y: strip.y + strip.height
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
                onGlass: true
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
                y: appsStrip.y + appsStrip.height + (appsPanorama.sideways ? 0 : Geometry.hairline)
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
                y: appsStrip.y + appsStrip.height
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
                    enabled: start.wanted

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
                                unseen: start.unseen[modelData.id] ?? 0
                                line: start.lines[modelData.id] ?? ""
                                hasMenu: start.pinFile !== null
                                onActivated: start.press(letterTile, () => letterTile.modelData.launch())
                                onMenuAsked: at => start.openMenu(letterTile, at, letterTile.modelData.id, false)
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
        // title never shrinks (typography.md); one too long for the search is cut at its edge, as the strip is.
        Item {
            id: searchTitle

            objectName: "searchTitle"
            x: pivot.x
            width: start.searchWidth
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
            // ponytail: past the search's edge the caret goes out of sight with the text; cap the width at it and
            // let the line scroll if queries get that long.
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
                onGlass: true
                text: "suche"
                font.pixelSize: pivot.inactiveSize
            }
        }

        // The apps that match, as tiles in the search's grid, space-l above and below as a section (rekta.css:1125).
        Flickable {
            id: results

            readonly property real ringRoom: Geometry.focusRingOffset + Geometry.focusRingWidth
            objectName: "results"
            x: pivot.x - ringRoom
            y: start.placeTop
            width: start.searchWidth + 2 * ringRoom
            height: start.placeHeight
            visible: false
            enabled: start.wanted
            // The focus ring of a row, outside it, is not clipped at the search's edge.
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
                width: start.searchWidth
                columns: start.searchUnits
                placeWidth: start.width
                viewportHeight: start.height

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
                        unseen: start.unseen[appId] ?? 0
                        line: start.lines[appId] ?? ""
                        best: index === 0
                        columns: best ? 2 : 1
                        hasMenu: start.pinFile !== null
                        onActivated: start.press(hitTile, () => start.launchApp(hitTile.appId))
                        onMenuAsked: at => start.openMenu(hitTile, at, hitTile.appId, false)
                    }
                }
            }

            // Below the tiles, the other kinds of hit as rows (palette entries) under their heading, space-l apart; a group
            // without a hit has no heading.
            Column {
                id: rowsColumn

                objectName: "rows"
                y: hitsGrid.y + hitsGrid.height + (found.count > 0 ? Tokens.spaceL : 0)
                width: start.searchWidth

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
                width: start.searchWidth
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

    // A press outside the menu closes it and goes on to what lies beneath (rekta.js contextMenu(), `outside`).
    MouseArea {
        objectName: "outsideMenu"
        anchors.fill: parent
        z: Tokens.layerFloat
        visible: menu.open
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            menu.close(false);
            mouse.accepted = false;
        }
        onWheel: wheel => wheel.accepted = false
    }

    // An app tile's context menu (collections.md, "Context menus"): pin or unpin the app, and in "angeheftet" a group
    // of the sizes its tile may take under a hairline, the current one chosen (states.md:131–137). It stands in the
    // Start's surface, over everything in it.
    Menu {
        id: menu

        objectName: "menu"
        width: implicitWidth
        height: implicitHeight
        area: Qt.size(start.width, start.height)
        onChosen: item => start.choose(item)
        onOpenChanged: {
            if (!open)
                start.forgetMenuTile();
        }
        // Its tile has gone.
        onControlChanged: {
            if (!control)
                close(false);
        }

        MenuItem {
            objectName: "pin"
            text: (start.menuApp?.index ?? -1) >= 0 ? "lösen" : "anheften"
            disabledReason: start.menuBlocked()
        }

        MenuSeparator {
            visible: start.menuApp?.sized ?? false
        }

        MenuLabel {
            text: "größe"
            visible: start.menuApp?.sized ?? false
        }

        Repeater {
            model: Rules.pinSizes

            delegate: MenuItem {
                required property var modelData

                objectName: "size"
                kind: "radio"
                text: modelData.name
                visible: start.menuApp?.sized ?? false
                disabledReason: start.menuBlocked()
            }
        }
    }
}
