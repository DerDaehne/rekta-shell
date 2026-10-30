pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Start

TestCase {
    id: testCase

    name: "Start"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1600
    height: 900

    // What the fake windows and apps were asked to do, oldest first.
    property var calls: []

    // Coloured 20 × 20 squares as PNG (the check has no SVG image plugin), as an app's own icon is coloured.
    readonly property string blueIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAGklEQVR4nGOQnfmZbMQwqnlU86jmUc0DqxkAaSeYL8S+KvQAAAAASUVORK5CYII="
    readonly property string pinkIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAGklEQVR4nGN4aTWLbMQwqnlU86jmUc0DqxkAreu3b+7dCC4AAAAASUVORK5CYII="

    function fakeWindow(title: string, lastActivated: real): var {
        return {
            title: title,
            icon: testCase.blueIcon,
            lastActivated: lastActivated,
            stackingOrder: 0,
            active: false,
            activate: () => testCase.calls = [...testCase.calls, `activate ${title}`]
        };
    }

    // Konsole and the docs, the docs with the keyboard.
    function windowsWithTheDocsActive(): var {
        const docs = fakeWindow("Rekta Design — docs", 30);
        docs.active = true;
        return [fakeWindow("konsole: build", 10), docs];
    }

    function fakeApp(name: string, columns: int): var {
        return {
            name: name,
            icon: testCase.pinkIcon,
            columns: columns,
            rows: 1,
            launch: () => testCase.calls = [...testCase.calls, `launch ${name}`]
        };
    }

    Component {
        id: startComponent

        StartPlace {
            width: testCase.width
            height: testCase.height
            windows: [testCase.fakeWindow("konsole: build", 10), testCase.fakeWindow("Rekta Design — docs", 30)]
            pinned: [testCase.fakeApp("systemsettings", 1), testCase.fakeApp("dolphin", 2), testCase.fakeApp("konsole", 1)]
        }
    }

    // Stands where a window's preview goes; it knows the window it shows.
    Component {
        id: previewComponent

        Rectangle {
            property var window
            objectName: `preview of ${window?.title}`
            color: "steelblue"
        }
    }

    SignalSpy {
        id: closedSpy

        signalName: "closed"
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var start
    property var turner

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        calls = [];
        start = createTemporaryObject(startComponent, testCase);
        turner = findChild(start, "turn");
        closedSpy.target = start;
        closedSpy.clear();
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
        Prefs.startPace = "fast";
    }

    function named(name: string): var {
        return findChild(start, name);
    }

    function tilesIn(section: string): var {
        return findChild(named(section), "grid").children.filter(item => (item as Tile) !== null);
    }

    // Opens the Start without motion, as a reduced-motion user sees it at once.
    function openNow() {
        Prefs.motion = "off";
        start.open();
        Prefs.motion = "system";
        waitForRendering(start);
    }

    function test_the_start_is_one_column_at_the_leading_edge_six_tile_units_wide() {
        openNow();
        const column = named("column");
        compare(column.mapToItem(start, 0, 0).x, Tokens.spaceXl);
        compare(column.width, 6 * Tokens.tileUnit + 5 * Tokens.spaceS);
        compare(named("pivot").x, Tokens.spaceXl);
    }

    function test_the_pivot_leads_then_running_then_pinned_down_the_column() {
        openNow();
        compare(named("pivot").titles, ["start", "alle apps"]);
        compare(named("pivot").currentIndex, 0);
        const running = named("running").mapToItem(start, 0, 0).y;
        const pinned = named("pinned").mapToItem(start, 0, 0).y;
        verify(named("pivot").height <= running, "below the pivot");
        verify(running < pinned, "running first");
        compare(findChild(named("running"), "heading").text, "läuft");
        compare(findChild(named("pinned"), "heading").text, "angeheftet");
    }

    function test_a_section_has_space_xl_above_and_below_and_space_l_under_its_heading() {
        openNow();
        const section = named("pinned");
        const heading = findChild(section, "heading");
        const grid = findChild(section, "grid");
        compare(heading.y, Tokens.spaceXl);
        compare(grid.y, heading.y + heading.height + Tokens.spaceL);
        compare(section.height, grid.y + grid.height + Tokens.spaceXl);
    }

    function test_the_pivot_is_light_and_larger_than_the_section_headings_which_are_larger_than_the_tile_names() {
        openNow();
        const pivot = named("pivot");
        const active = findChild(pivot, "word");
        const names = tilesIn("pinned").map(tile => findChild(tile, "name"));
        const heading = findChild(named("pinned"), "heading");
        compare(active.font.weight, Tokens.fontWeightLight);
        compare(heading.font.pixelSize, Math.floor(Tokens.fluid(Tokens.fontSizeXl, start.width)));
        compare(names[0].font.pixelSize, Tokens.fontSizeS);
        verify(pivot.inactiveSize > heading.font.pixelSize, "the inactive title above the heading");
        verify(active.font.pixelSize > pivot.inactiveSize, "the active title above the inactive one");
        verify(heading.font.pixelSize > names[0].font.pixelSize, "the heading above the tile names");
        compare(findChild(tilesIn("running")[0], "title").font.pixelSize, Tokens.fontSizeS);
    }

    function test_each_window_gets_a_two_unit_tile_the_most_recent_first_with_its_title() {
        openNow();
        const tiles = tilesIn("running");
        compare(tiles.length, 2);
        compare(tiles[0].title, "Rekta Design — docs");
        compare(tiles[1].title, "konsole: build");
        compare(tiles[0].columns, 2);
        compare(tiles[0].width, 2 * Tokens.tileUnit + Tokens.spaceS);
        compare(findChild(tiles[0], "title").text, "Rekta Design — docs");
        compare(findChild(tiles[0], "title").maximumLineCount, 1);
        compare(findChild(tiles[0], "title").color, Tokens.color.textPrimary);
        compare(findChild(tiles[0], "icon").width, 2 * Geometry.iconSize);
    }

    function test_without_windows_the_running_section_is_gone() {
        openNow();
        start.windows = [];
        verify(!named("running").visible);
        tryCompare(named("pinned"), "y", 0);
    }

    function test_without_a_preview_the_upper_part_shows_the_tile_surface() {
        openNow();
        const tile = tilesIn("running")[0];
        verify(findChild(tile, "preview").item === null);
        compare(findChild(tile, "fill").color, Tokens.color.surface);
    }

    function test_a_preview_fills_the_upper_part_above_the_icon_and_title() {
        start.preview = previewComponent;
        openNow();
        const tile = tilesIn("running")[0];
        const preview = findChild(tile, "preview").item;
        compare(preview.window.title, "Rekta Design — docs");
        compare(preview.width, tile.width);
        compare(preview.y, 0);
        compare(preview.height, findChild(tile, "label").mapToItem(tile, 0, 0).y - Geometry.tilePadding);
    }

    function test_pressing_a_window_tile_brings_the_window_forward_and_closes_the_start() {
        openNow();
        mouseClick(tilesIn("running")[1]);
        compare(calls, ["activate konsole: build"]);
        verify(!start.wanted);
        tryVerify(() => closedSpy.count === 1, 3000);
    }

    function test_pressing_a_pinned_tile_launches_its_app_and_closes_the_start() {
        openNow();
        mouseClick(tilesIn("pinned")[1]);
        compare(calls, ["launch dolphin"]);
        verify(!start.wanted);
    }

    function test_closing_without_a_press_gives_the_keyboard_back_to_the_window_that_had_it_once_the_parts_are_out() {
        start.windows = windowsWithTheDocsActive();
        openNow();
        keyClick(Qt.Key_Escape);
        compare(calls, [], "not while its tiles still turn");
        tryVerify(() => closedSpy.count === 1, 3000);
        compare(calls, ["activate Rekta Design — docs"]);
    }

    function test_after_a_launch_or_a_window_choice_the_window_that_had_the_keyboard_is_not_activated() {
        start.windows = windowsWithTheDocsActive();
        Prefs.motion = "off";
        start.open();
        waitForRendering(start);
        mouseClick(tilesIn("pinned")[1]);
        start.open();
        waitForRendering(start);
        mouseClick(tilesIn("running")[1]);
        compare(calls, ["launch dolphin", "activate konsole: build"]);
    }

    // A launched app's window comes while the Start turns out, and the running tiles are made anew.
    function test_a_window_that_comes_while_the_start_turns_out_after_a_launch_leaves_no_glass() {
        openNow();
        mouseClick(tilesIn("pinned")[1]);
        verify(turner.running);
        start.windows = [...start.windows, fakeWindow("dolphin", 40)];
        tryVerify(() => closedSpy.count === 1, 3000);
        verify(!start.shown);
        verify(!findChild(start, "glass").visible);
    }

    // Opaque, with no turn's rotation left on it.
    function atRest(item: Item): bool {
        return item.opacity === 1 && Array.from(item.transform).every(transform => (transform as Rotation) === null);
    }

    function pinnedAtRest(): bool {
        return [findChild(named("pinned"), "heading"), ...tilesIn("pinned")].every(atRest);
    }

    function test_window_tiles_made_anew_while_the_start_turns_out_leave_the_pinned_apps_whole_at_the_next_opening() {
        openNow();
        mouseClick(tilesIn("pinned")[1]);
        start.windows = [...start.windows, fakeWindow("dolphin", 40)];
        tryVerify(() => !start.shown, 3000);
        start.open();
        tryVerify(() => start.phase === "open", 3000);
        verify(pinnedAtRest());
    }

    // Desktop entries that come late, or a new start.json, make the pinned tiles anew.
    function test_pinned_apps_that_come_while_the_start_turns_in_all_show() {
        start.open();
        tryVerify(() => turner.running, 2000);
        start.pinned = [fakeApp("kate", 1), ...start.pinned];
        tryVerify(() => start.phase === "open", 3000);
        compare(tilesIn("pinned").length, 4);
        verify(pinnedAtRest());
    }

    function test_a_pinned_tile_shows_its_name_along_the_bottom_and_spans_its_units() {
        openNow();
        const dolphin = tilesIn("pinned")[1];
        compare(dolphin.columns, 2);
        compare(findChild(dolphin, "name").text, "dolphin");
        const icon = findChild(dolphin, "icon");
        compare(Qt.point(icon.x, icon.y), Qt.point(Geometry.tilePadding, Geometry.tilePadding));
        compare(icon.width, 2 * Geometry.iconSize);
        compare(findChild(dolphin, "name").color, Tokens.color.textPrimary);
    }

    function test_the_column_scrolls_down_when_its_tiles_are_longer_than_the_screen() {
        start.pinned = Array.from({ length: 40 }, (_, i) => fakeApp(`app ${i}`, 1));
        openNow();
        const column = named("column");
        verify(column.contentHeight > column.height);
        mouseWheel(column, 100, 100, 0, -480);
        tryVerify(() => column.contentY > 0);
        compare(named("pivot").currentIndex, 0, "an upright wheel never changes the place");
    }

    function test_clicking_alle_apps_turns_to_that_place() {
        openNow();
        const pivot = named("pivot");
        mouseClick(findChild(pivot, "title-1"));
        compare(pivot.currentIndex, 1);
        tryVerify(() => named("apps").visible && !named("column").visible, 3000);
    }

    function test_the_right_arrow_goes_to_alle_apps_and_back_returns() {
        openNow();
        keyClick(Qt.Key_Right);
        compare(named("pivot").currentIndex, 1);
        tryVerify(() => !start.turning, 3000);
        keyClick(Qt.Key_Escape);
        compare(named("pivot").currentIndex, 0, "back goes to the start place first");
        verify(start.wanted);
    }

    function test_closed_from_alle_apps_the_start_opens_again_on_its_start_place() {
        Prefs.motion = "off";
        start.open();
        named("pivot").select(1);
        start.toggle();
        start.toggle();
        compare(named("pivot").currentIndex, 0);
        verify(named("column").visible);
        verify(!named("apps").visible);
    }

    function test_a_swipe_goes_to_alle_apps() {
        openNow();
        const from = Qt.point(start.width - 100, start.height - 100);
        mouseDrag(start, from.x, from.y, -300, 0);
        compare(named("pivot").currentIndex, 1);
    }

    function test_a_sideways_wheel_goes_to_alle_apps_once_per_gesture() {
        openNow();
        mouseWheel(named("column"), 100, 100, -120, 0);
        compare(named("pivot").currentIndex, 1);
        mouseWheel(named("column"), 100, 100, 120, 0);
        compare(named("pivot").currentIndex, 1, "within wheel-latch it is still the same gesture");
        wait(Tokens.durationWheelLatch + 50);
        mouseWheel(named("column"), 100, 100, 120, 0);
        compare(named("pivot").currentIndex, 0);
    }

    function test_the_parts_turn_in_once_the_windows_are_three_quarters_back_in_half_a_moderate() {
        const started = Date.now();
        start.open();
        verify(start.shown);
        verify(!turner.running, "first only the glass");
        verify(!named("body").visible);
        compare(named("waitForWindows").interval, Geometry.turnOverlap * Tokens.durationModerate / 2);
        tryVerify(() => turner.running, 2000);
        verify(Date.now() - started >= Geometry.turnOverlap * Tokens.durationModerate / 2 - 2);
        verify(turner.arrivingTurns.length > 0);
        tryVerify(() => start.phase === "open", 3000);
    }

    // The turns against Rekta's plan for the same parts from `from`: each part's time and the starts after `from` are
    // `pace` of Rekta's. The starts are compared as a set: parts alike in row, place and heft may swap their order.
    function verifyPace(turns: var, rektaDuration: real, from: real, pace: real) {
        const rekta = Turnstile.plan(turns.map(turn => turn.part), rektaDuration, from);
        verify(turns.length > 0);
        for (const turn of turns)
            fuzzyCompare(turn.duration, pace * rekta.find(planned => planned.part === turn.part).duration, 1e-9, "times");
        const starts = plan => plan.map(turn => turn.at - from).sort((a, b) => a - b);
        const rektaStarts = starts(rekta);
        starts(turns).forEach((at, index) => fuzzyCompare(at, pace * rektaStarts[index], 1e-9, "starts"));
    }

    function test_the_start_s_parts_turn_in_at_half_rekta_s_pace() {
        start.open();
        tryVerify(() => turner.running, 2000);
        verifyPace(turner.arrivingTurns, Tokens.durationModerate, turner.handOverAt, 0.5);
    }

    function test_closed_the_start_s_parts_turn_out_at_half_rekta_s_pace() {
        openNow();
        keyClick(Qt.Key_Escape);
        verifyPace(turner.leavingTurns, Tokens.durationShort, 0, 0.5);
    }

    function test_after_a_tile_press_the_start_turns_out_at_half_rekta_s_pace_the_pressed_tile_once_its_press_is_through() {
        openNow();
        const pressed = tilesIn("pinned")[0];
        mouseClick(pressed);
        const others = turner.leavingTurns.filter(turn => turn.part.item !== pressed);
        const last = turner.leavingTurns.find(turn => turn.part.item === pressed);
        verifyPace(others, Tokens.durationShort, 0, 0.5);
        fuzzyCompare(last.duration, Turnstile.plan([last.part], Tokens.durationShort, 0)[0].duration / 2, 1e-9);
        verify(last.at >= Tokens.durationPress - 20, "the press keeps its own time");
    }

    function test_a_change_of_place_inside_the_start_keeps_rekta_s_pace() {
        openNow();
        keyClick(Qt.Key_Right);
        verifyPace(turner.leavingTurns, Tokens.durationShort, 0, 1);
        tryVerify(() => turner.arrivingTurns.length > 0, 3000);
        verifyPace(turner.arrivingTurns, Tokens.durationModerate, turner.handOverAt, 1);
    }

    // KWin's fade-back fades the whole surface, glass and blur together; a glass that faded itself would stand at p².
    function glassWhole(): bool {
        const glass = findChild(start, "glass");
        return glass.visible && glass.opacity === 1 && Qt.colorEqual(glass.color, Tokens.color.glass);
    }

    function test_the_glass_stands_whole_from_the_opening_and_leaves_the_fade_to_kwin() {
        start.open();
        verify(glassWhole(), "whole in the frame the windows start to step back");
        tryVerify(() => start.phase === "open", 3000);
        verify(glassWhole());
    }

    function test_the_start_empties_half_a_moderate_after_the_hand_over_with_the_glass_whole_until_then() {
        openNow();
        keyClick(Qt.Key_Escape);
        turner.paused = true;
        turner.elapsed = turner.handOverAt;
        const handedOver = Date.now();
        verify(!start.holdsKeyboard);
        compare(findChild(start, "glassOut").interval, Tokens.durationModerate / 2);
        wait(Tokens.durationModerate / 4);
        verify(glassWhole(), "the windows come forward under it as KWin fades it");
        compare(closedSpy.count, 0);
        tryVerify(() => closedSpy.count === 1, 2000);
        verify(Date.now() - handedOver >= Tokens.durationModerate / 2 - 2);
        verify(!findChild(start, "glass").visible);
    }

    function test_escape_turns_the_start_out_back_the_way_it_came() {
        openNow();
        keyClick(Qt.Key_Escape);
        verify(turner.running);
        verify(turner.back);
        verify(turner.pressedTile === null);
        tryVerify(() => closedSpy.count === 1, 3000);
        verify(!start.shown);
        verify(!findChild(start, "glass").visible);
    }

    function test_after_a_press_the_start_turns_out_forward_with_the_pressed_tile_last() {
        openNow();
        const pressed = tilesIn("pinned")[0];
        mouseClick(pressed);
        verify(turner.running);
        verify(!turner.back);
        compare(turner.pressedTile, pressed);
        const others = turner.leavingTurns.filter(turn => turn.part.item !== pressed);
        const last = turner.leavingTurns.find(turn => turn.part.item === pressed);
        verify(others.every(turn => turn.at <= last.at));
    }

    function test_the_glass_goes_once_the_last_part_is_three_quarters_out() {
        openNow();
        keyClick(Qt.Key_Escape);
        turner.paused = true;
        turner.elapsed = turner.handOverAt - 1;
        compare(findChild(start, "glassOut").running, false);
        turner.elapsed = turner.handOverAt;
        verify(findChild(start, "glassOut").running);
        turner.paused = false;
    }

    function test_the_start_holds_the_keyboard_from_opening_until_the_hand_over() {
        verify(!start.holdsKeyboard);
        start.open();
        verify(start.holdsKeyboard, "the windows step back as it takes the keyboard");
        tryVerify(() => start.phase === "open", 3000);
        keyClick(Qt.Key_Escape);
        turner.paused = true;
        turner.elapsed = turner.handOverAt - 1;
        verify(start.holdsKeyboard, "the parts turn out in front of the windows");
        turner.elapsed = turner.handOverAt;
        verify(!start.holdsKeyboard, "the windows come forward from the hand-over");
        turner.paused = false;
        tryVerify(() => closedSpy.count === 1, 3000);
        verify(!start.holdsKeyboard);
    }

    function test_closed_before_its_parts_came_the_start_hands_over_at_once() {
        start.open();
        keyClick(Qt.Key_Escape);
        verify(!start.holdsKeyboard);
    }

    function test_while_the_start_turns_a_tile_takes_no_press() {
        openNow();
        keyClick(Qt.Key_Right);
        verify(start.turning);
        keyClick(Qt.Key_Left);
        tryVerify(() => named("column").visible);
        verify(start.turning);
        mouseClick(tilesIn("pinned")[0]);
        compare(calls, []);
        verify(start.wanted);
    }

    function test_while_the_start_turns_a_key_other_than_back_or_typing_does_nothing() {
        start.open();
        tryVerify(() => turner.running, 2000);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Down);
        compare(named("pivot").currentIndex, 0);
        verify(tilesIn("running").concat(tilesIn("pinned")).every(tile => !tile.activeFocus), "no tile took the focus");
    }

    function test_closing_during_the_opening_ends_that_turn_and_goes_out() {
        start.open();
        tryVerify(() => turner.running, 2000);
        keyClick(Qt.Key_Escape);
        verify(!start.wanted);
        verify(turner.leavingTurns.length > 0, "it turns out from where it is");
        verify(!findChild(start, "glassOut").running, "the glass waits for the parts to turn out");
        tryVerify(() => closedSpy.count === 1, 3000);
    }

    function test_opening_again_while_closing_ends_the_close_and_comes_back() {
        openNow();
        keyClick(Qt.Key_Escape);
        start.open();
        verify(start.wanted);
        tryVerify(() => start.phase === "open", 3000);
        compare(closedSpy.count, 0);
        verify(glassWhole());
    }

    function test_under_reduced_motion_the_start_stands_and_goes_at_once() {
        Prefs.motion = "off";
        start.open();
        compare(start.phase, "open");
        verify(named("body").visible);
        verify(glassWhole());
        keyClick(Qt.Key_Escape);
        compare(start.phase, "closed");
        compare(closedSpy.count, 1);
    }

    function test_the_mouse_s_back_button_closes_the_start() {
        openNow();
        mouseClick(start, start.width - 50, 50, Qt.BackButton);
        verify(!start.wanted);
    }

    function test_arrows_move_the_focus_through_the_tiles_and_the_ring_shows_only_then() {
        openNow();
        const running = tilesIn("running");
        const pinned = tilesIn("pinned");
        mouseClick(pinned[2]);
        verify(!pinned[2].activeFocus, "a click gives no focus");
        calls = [];
        Prefs.motion = "off";
        start.open();
        keyClick(Qt.Key_Down);
        verify(running[0].activeFocus);
        keyClick(Qt.Key_Right);
        verify(running[1].activeFocus);
        keyClick(Qt.Key_Down);
        verify(pinned[1].activeFocus, "the first pinned tile under the second window");
        keyClick(Qt.Key_Right);
        verify(pinned[2].activeFocus);
        keyClick(Qt.Key_Left);
        verify(pinned[1].activeFocus);
        keyClick(Qt.Key_Up);
        verify(running[0].activeFocus, "of the two windows above, the one in line with its start");
        keyClick(Qt.Key_Up);
        verify(named("pivot").activeFocus, "up from the first row reaches the pivot");
    }

    function test_right_past_the_last_tile_of_a_row_goes_to_alle_apps() {
        openNow();
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Right);
        verify(tilesIn("running")[1].activeFocus);
        keyClick(Qt.Key_Right);
        compare(named("pivot").currentIndex, 1);
    }

    function test_a_tile_that_takes_the_focus_scrolls_into_view() {
        start.pinned = Array.from({ length: 40 }, (_, i) => fakeApp(`app ${i}`, 1));
        openNow();
        const column = named("column");
        // The first tile of the seventh row, below the screen.
        const last = tilesIn("pinned")[36];
        for (let i = 0; i < 8; i++)
            keyClick(Qt.Key_Down);
        verify(last.activeFocus);
        const top = last.mapToItem(column, 0, 0).y;
        verify(top >= 0 && top + last.height <= column.height, `whole in view at ${top}`);
    }

        function test_the_start_opens_again_with_no_tile_in_focus() {
        openNow();
        keyClick(Qt.Key_Down);
        verify(tilesIn("running")[0].activeFocus);
        Prefs.motion = "off";
        keyClick(Qt.Key_Escape);
        start.open();
        verify(start.activeFocus);
        verify(tilesIn("running").concat(tilesIn("pinned")).every(tile => !tile.focus));
    }

    function test_in_alle_apps_enter_presses_no_tile_of_the_start_place() {
        Prefs.motion = "off";
        start.open();
        waitForRendering(start);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Right);
        compare(named("pivot").currentIndex, 1);
        keyClick(Qt.Key_Return);
        compare(calls, []);
        verify(start.wanted);
    }

    function test_enter_presses_the_tile_in_focus() {
        Prefs.motion = "off";
        start.open();
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(calls, ["activate Rekta Design — docs"]);
    }

    function installedApp(name: string): var {
        return {
            id: `org.example.${name}`,
            name: name,
            genericName: "",
            keywords: [],
            exec: name,
            icon: testCase.pinkIcon,
            launch: () => testCase.calls = [...testCase.calls, `launch ${name}`]
        };
    }

    // The Start open on "alle apps" with these apps, at once.
    function openOnAllApps(names: var) {
        start.apps = names.map(name => installedApp(name));
        Prefs.motion = "off";
        start.open();
        named("pivot").select(1);
        Prefs.motion = "system";
        waitForRendering(start);
    }

    function rowTile(index: int): var {
        return start.rowTiles()[index];
    }

    function appNames(count: int): var {
        return Array.from({ length: count }, (_, i) => `app ${String(i).padStart(2, "0")}`);
    }

    readonly property real step: Tokens.tileUnit + Tokens.spaceS

    function test_alle_apps_shows_every_app_a_to_z_as_a_one_unit_tile_with_its_icon_and_name_under_the_pivot() {
        openOnAllApps(["ark", "Blender", "konsole"]);
        const tiles = start.rowTiles();
        compare(tiles.map(tile => findChild(tile, "name").text), ["ark", "Blender", "konsole"]);
        compare(Qt.size(tiles[0].width, tiles[0].height), Qt.size(Tokens.tileUnit, Tokens.tileUnit));
        compare(tiles[0].mapToItem(start, 0, 0), Qt.point(Tokens.spaceXl, named("pivot").height + Tokens.spaceL));
        compare(findChild(tiles[0], "icon").source.toString(), pinkIcon);
        compare(named("appRow").width, named("column").width, "six units, as the start place");
        verify(tiles.every(tile => tile.opens));
    }

    function test_the_row_fills_each_column_top_down_with_as_many_tiles_as_the_column_s_height_holds() {
        openOnAllApps(appNames(20));
        const tiles = start.rowTiles();
        const row = named("appRow");
        const rows = tiles.findIndex(tile => tile.x > 0);
        verify(rows > 1, `${rows} rows`);
        for (let i = 1; i < rows; i++)
            compare(Qt.point(tiles[i].x, tiles[i].y), Qt.point(0, i * step), `down the first column: ${i}`);
        compare(Qt.point(tiles[rows].x, tiles[rows].y), Qt.point(step, 0), "then the next column from the top");
        verify(tiles[rows - 1].y + Tokens.tileUnit <= row.height, "the last of a column is whole");
        verify(rows * step + Tokens.tileUnit > row.height, "and one more would not fit");
        compare(row.height, start.height - named("pivot").height - 2 * Tokens.spaceL);
        start.height = 600;
        tryVerify(() => start.rowTiles().findIndex(tile => tile.x > 0) < rows, 1000, "a lower Start holds fewer rows");
    }

    function test_the_row_scrolls_sideways_within_the_column() {
        openOnAllApps(appNames(60));
        const row = named("appRow");
        verify(row.clip);
        verify(row.contentWidth > row.width);
        compare(row.contentWidth, Math.ceil(60 / start.rowTiles().findIndex(tile => tile.x > 0)) * step - Tokens.spaceS);
    }

    function test_before_the_apps_are_known_alle_apps_loads_and_without_any_it_says_so() {
        Prefs.motion = "off";
        start.open();
        named("pivot").select(1);
        verify(named("appsBusy").busy);
        verify(named("appsLine").visible, "the line runs on the region's first hairline");
        verify(!named("noApps").visible);
        start.apps = [];
        verify(!named("appsBusy").busy);
        const sentence = named("noApps");
        verify(sentence.visible);
        compare(sentence.text, "keine apps installiert.");
        compare(sentence.color, Tokens.color.textContrastHigh);
        compare(sentence.y, Tokens.spaceL + Geometry.hairline + Tokens.spaceM);
    }

    function test_down_or_tab_from_the_pivot_goes_to_the_first_app_and_left_from_the_first_column_back_to_start() {
        openOnAllApps(appNames(20));
        keyClick(Qt.Key_Down);
        verify(rowTile(0).activeFocus, "down with nothing in focus");
        keyClick(Qt.Key_Left);
        compare(named("pivot").currentIndex, 0);
        tryVerify(() => !start.turning, 3000);
        keyClick(Qt.Key_Right);
        tryVerify(() => !start.turning, 3000);
        verify(start.rowTiles().every(tile => !tile.activeFocus), "back on alle apps, no app waits in the ring");
        named("pivot").forceActiveFocus();
        keyClick(Qt.Key_Tab);
        verify(rowTile(0).activeFocus, "tab from the pivot");
    }

    function test_up_and_down_move_within_a_column_left_and_right_to_the_column_beside() {
        openOnAllApps(appNames(20));
        const rows = start.rowTiles().findIndex(tile => tile.x > 0);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        verify(rowTile(1).activeFocus);
        keyClick(Qt.Key_Right);
        verify(rowTile(1 + rows).activeFocus, "the same row of the next column");
        keyClick(Qt.Key_Up);
        verify(rowTile(rows).activeFocus);
        keyClick(Qt.Key_Left);
        verify(rowTile(0).activeFocus);
        for (let i = 0; i < rows + 2; i++)
            keyClick(Qt.Key_Down);
        verify(rowTile(rows - 1).activeFocus, "down stays in its column");
        keyClick(Qt.Key_Home);
        keyClick(Qt.Key_Up);
        verify(named("pivot").activeFocus, "up from the first row reaches the pivot");
    }

    function test_home_and_end_go_to_the_first_and_the_last_app_and_the_row_scrolls_with_them() {
        openOnAllApps(appNames(60));
        const row = named("appRow");
        keyClick(Qt.Key_End);
        const last = rowTile(59);
        verify(last.activeFocus);
        const left = last.mapToItem(row, 0, 0).x;
        verify(left >= 0 && left + last.width <= row.width, `whole in view at ${left}`);
        keyClick(Qt.Key_Home);
        verify(rowTile(0).activeFocus);
        compare(row.contentX, 0);
    }

    function test_enter_or_space_on_an_app_launches_it_once() {
        openOnAllApps(["ark", "Blender", "konsole"]);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(calls, ["launch Blender"]);
        verify(!start.wanted);
        keyClick(Qt.Key_Return);
        compare(calls, ["launch Blender"], "once");
        tryVerify(() => closedSpy.count === 1, 3000);
        openOnAllApps(["ark", "Blender", "konsole"]);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Space);
        compare(calls, ["launch Blender", "launch ark"]);
    }

    function test_a_typed_letter_jumps_to_the_next_app_it_starts_whatever_the_case_and_again_to_the_one_after() {
        openOnAllApps(["ark", "Blender", "Dateien", "Dolphin", "dragon", "Elisa"]);
        keyClick("d");
        verify(rowTile(2).activeFocus, "the first that starts with it");
        keyClick("d");
        verify(rowTile(3).activeFocus, "the same letter again, the next");
        keyClick("D");
        verify(rowTile(4).activeFocus, "a capital counts the same");
        keyClick("d");
        verify(rowTile(2).activeFocus, "round past the last");
        keyClick("q");
        verify(rowTile(2).activeFocus, "without a match nothing happens");
        compare(start.query, "", "and nothing is searched");
        verify(named("apps").visible);
        verify(!named("results").visible);
        keyClick("e");
        verify(rowTile(5).activeFocus);
    }

    function test_a_letter_for_an_app_far_along_scrolls_the_row_to_it() {
        openOnAllApps([...appNames(59), "zed"]);
        const row = named("appRow");
        keyClick("z");
        const zed = rowTile(59);
        verify(zed.activeFocus);
        const left = zed.mapToItem(row, 0, 0).x;
        verify(left >= 0 && left + zed.width <= row.width, `whole in view at ${left}`);
    }

    function test_a_letter_typed_while_the_start_turns_to_alle_apps_ends_the_turn_and_jumps() {
        start.apps = ["ark", "Blender", "konsole"].map(name => installedApp(name));
        openNow();
        keyClick(Qt.Key_Right);
        verify(start.turning);
        keyClick("k");
        verify(!start.turning);
        verify(named("apps").visible);
        verify(rowTile(2).activeFocus);
        compare(start.query, "");
    }

    function test_in_the_start_place_typing_still_searches() {
        openOnAllApps(["Kate", "Konsole", "Okular"]);
        Prefs.motion = "off";
        keyClick(Qt.Key_Left);
        compare(named("pivot").currentIndex, 0);
        keyClick("k");
        compare(start.query, "k");
        verify(named("results").visible);
        compare(hitNames(), ["Kate", "Konsole", "Okular"]);
    }

    function test_pressing_an_app_launches_it_once_and_turns_the_start_out_forward_at_half_rekta_s_pace_with_it_last() {
        openOnAllApps(["ark", "Blender", "konsole"]);
        const pressed = rowTile(1);
        mouseClick(pressed);
        compare(calls, ["launch Blender"]);
        verify(turner.running);
        verify(!turner.back, "forward");
        compare(turner.pressedTile, pressed);
        const others = turner.leavingTurns.filter(turn => turn.part.item !== pressed);
        const last = turner.leavingTurns.find(turn => turn.part.item === pressed);
        verify(others.every(turn => turn.at <= last.at), "the pressed tile last");
        verifyPace(others, Tokens.durationShort, 0, 0.5);
        fuzzyCompare(last.duration, Turnstile.plan([last.part], Tokens.durationShort, 0)[0].duration / 2, 1e-9);
        mouseClick(rowTile(2));
        compare(calls, ["launch Blender"], "once");
        tryVerify(() => closedSpy.count === 1, 3000);
    }

    function test_after_an_app_launch_the_window_that_had_the_keyboard_is_not_activated() {
        start.windows = windowsWithTheDocsActive();
        openOnAllApps(["ark"]);
        mouseClick(rowTile(0));
        tryVerify(() => closedSpy.count === 1, 3000);
        compare(calls, ["launch ark"]);
    }

    function test_going_to_alle_apps_turns_each_tile_in_view_as_one_part() {
        start.apps = appNames(60).map(name => installedApp(name));
        openNow();
        named("pivot").select(1);
        tryVerify(() => turner.arrivingTurns.length > 0, 3000);
        const parts = turner.arrivingTurns.map(turn => turn.part.item);
        verify(parts.includes(rowTile(0)));
        verify(parts.every(item => (item as Tile) !== null), "only tiles");
        verify(!parts.includes(named("appRow")), "the row is a scroller, not a part");
        tryVerify(() => !start.turning, 3000);
        named("pivot").select(0);
        verify(turner.leavingTurns.some(turn => turn.part.item === rowTile(0)), "and turn out the same way");
    }

    function test_under_reduced_motion_alle_apps_stands_at_once() {
        openNow();
        start.apps = [installedApp("ark")];
        Prefs.motion = "off";
        named("pivot").select(1);
        verify(named("apps").visible);
        verify(!start.turning);
        compare(rowTile(0).opacity, 1);
    }

    function test_a_wheel_over_the_row_moves_it_sideways_and_its_end_swallows_the_rest_of_that_gesture() {
        openOnAllApps(appNames(60));
        const row = named("appRow");
        mouseWheel(row, 100, 100, 0, -120);
        compare(row.contentX, 120, "a plain vertical wheel, down along the row");
        mouseWheel(row, 100, 100, -120, 0);
        compare(row.contentX, 240, "a sideways one too");
        mouseWheel(row, 100, 100, 0, 960);
        compare(row.contentX, 0, "up to the row's start");
        mouseWheel(row, 100, 100, 0, 120);
        compare(named("pivot").currentIndex, 1, "the same gesture stays the row's");
    }

    function test_a_wheel_that_starts_at_the_row_s_start_goes_on_back_to_start_one_at_its_end_stays() {
        openOnAllApps(appNames(60));
        const row = named("appRow");
        row.contentX = row.contentWidth - row.width;
        mouseWheel(row, 100, 100, 0, -120);
        compare(named("pivot").currentIndex, 1, "past the end there is no place beside");
        mouseWheel(row, 100, 100, 0, 120);
        compare(row.contentX, row.contentWidth - row.width, "and the rest of that gesture is not the row's");
        wait(Tokens.durationWheelLatch + 50);
        row.contentX = 0;
        mouseWheel(row, 100, 100, 120, 0);
        compare(named("pivot").currentIndex, 0);
    }

    function test_when_every_app_fits_a_wheel_goes_on_to_the_place_beside_at_once() {
        openOnAllApps(["ark", "Blender", "konsole"]);
        mouseWheel(named("appRow"), 100, 100, 0, 120);
        compare(named("pivot").currentIndex, 0);
    }

    function test_a_swipe_over_the_apps_scrolls_the_row_and_launches_nothing() {
        openOnAllApps(appNames(60));
        const row = named("appRow");
        mouseDrag(row, row.width - 60, 60, -400, 0);
        tryVerify(() => !row.moving, 3000);
        verify(row.contentX > 0, `scrolled to ${row.contentX}`);
        compare(calls, []);
        compare(named("pivot").currentIndex, 1);
    }

    function test_a_swipe_that_starts_at_the_row_s_start_goes_on_back_to_start_one_that_reaches_it_stays() {
        openOnAllApps(appNames(60));
        const row = named("appRow");
        row.contentX = 100;
        mouseDrag(row, 60, 60, 400, 0);
        tryVerify(() => !row.moving, 3000);
        compare(row.contentX, 0);
        compare(named("pivot").currentIndex, 1, "the swipe that reached the start stays the row's");
        mouseDrag(row, 60, 60, 400, 0);
        compare(named("pivot").currentIndex, 0);
        compare(calls, []);
    }

    function test_in_alle_apps_a_swipe_beside_the_row_goes_back_to_start() {
        openOnAllApps(appNames(60));
        mouseDrag(start, start.width - 300, start.height / 2, 200, 0);
        compare(named("pivot").currentIndex, 0);
    }

    function test_a_swipe_over_a_tile_of_the_start_place_goes_to_alle_apps_and_presses_nothing() {
        openNow();
        mouseDrag(tilesIn("pinned")[0], 60, 60, -200, 0);
        compare(named("pivot").currentIndex, 1);
        compare(calls, []);
    }

    function test_an_upright_drag_over_the_tiles_scrolls_the_column() {
        start.pinned = Array.from({ length: 40 }, (_, i) => fakeApp(`app ${i}`, 1));
        openNow();
        const column = named("column");
        mouseDrag(column, 60, column.height - 60, 0, -300);
        tryVerify(() => !column.moving, 3000);
        verify(column.contentY > 0, `scrolled to ${column.contentY}`);
        compare(calls, []);
        compare(named("pivot").currentIndex, 0);
    }

    function searchableApp(name: string, genericName: string, keywords: var): var {
        return Object.assign(installedApp(name), {
            genericName: genericName,
            keywords: keywords
        });
    }

    // A–Z, as the app model gives them.
    function searchableApps(): var {
        return [
            searchableApp("Dateien", "Dateiverwaltung", ["files"]),
            searchableApp("Filelight", "Disk Usage", ["disk"]),
            searchableApp("Firefox", "Web Browser", ["internet", "web"]),
            searchableApp("Kate", "Text Editor", ["text"]),
            searchableApp("Konsole", "Terminal", ["terminal", "shell"]),
            searchableApp("KWrite", "Text Editor", ["text"])
        ];
    }

    // The Start open on its start place with the searchable apps, at once.
    function openWithApps() {
        start.apps = searchableApps();
        openNow();
    }

    // Types without motion, so the search stands at once.
    function typeNow(text: string) {
        Prefs.motion = "off";
        for (const character of text)
            keyClick(character);
        Prefs.motion = "system";
        waitForRendering(start);
    }

    function hitNames(): var {
        return start.hitTiles().map(tile => findChild(tile, "name").text);
    }

    function motionsOf(items: var): var {
        return named("presence").moving.filter(motion => items.includes(motion.item));
    }

    function test_a_letter_shows_what_was_typed_as_the_title_with_suche_beside_it_where_the_pivot_stood() {
        openWithApps();
        typeNow("fi");
        verify(!named("pivot").visible);
        verify(!named("column").visible);
        const title = named("searchTitle");
        const typed = named("typed");
        const suche = named("suche");
        compare(Qt.point(title.x, title.y), Qt.point(named("pivot").x, named("pivot").y));
        compare(typed.text, "fi");
        compare(typed.font.pixelSize, findChild(named("pivot"), "word").font.pixelSize, "the pivot's active size");
        compare(typed.font.weight, Tokens.fontWeightLight);
        compare(typed.color, Tokens.color.textPrimary);
        compare(suche.text, "suche");
        compare(suche.font.pixelSize, Math.round(named("pivot").inactiveSize));
        compare(suche.color, Tokens.color.textContrastMedium);
        compare(suche.x, typed.width + Tokens.spaceL);
        compare(suche.y + suche.baselineOffset, typed.y + typed.baselineOffset, "on one baseline");
        const word = findChild(named("pivot"), "word");
        const baselineOf = item => item.mapToItem(start, 0, item.baselineOffset).y;
        compare(baselineOf(typed), baselineOf(word), "the pivot's");
    }

    function test_a_title_too_long_for_the_column_keeps_its_size_and_is_cut_at_the_column_s_edge() {
        openWithApps();
        typeNow("firefox firefox firefox firefox firefox firefox");
        const title = named("searchTitle");
        compare(named("typed").font.pixelSize, findChild(named("pivot"), "word").font.pixelSize);
        verify(named("typed").width > title.width);
        compare(title.width, named("column").width);
        verify(title.clip);
    }

    function test_the_apps_that_match_stand_in_the_column_s_grid_the_best_first_as_a_wide_tile_and_the_rest_as_one_unit_tiles() {
        openWithApps();
        typeNow("fi");
        compare(hitNames(), ["Filelight", "Firefox", "Dateien"]);
        const tiles = start.hitTiles();
        compare(Qt.size(tiles[0].width, tiles[0].height), Qt.size(2 * Tokens.tileUnit + Tokens.spaceS, Tokens.tileUnit));
        compare(Qt.size(tiles[1].width, tiles[1].height), Qt.size(Tokens.tileUnit, Tokens.tileUnit));
        compare(tiles[1].x - tiles[0].x, 2 * (Tokens.tileUnit + Tokens.spaceS));
        compare(named("hits").mapToItem(start, 0, 0), Qt.point(Tokens.spaceXl, named("pivot").height + Tokens.spaceL));
        compare(findChild(tiles[0], "icon").source.toString(), pinkIcon);
    }

    function test_without_a_match_a_sentence_on_the_first_hairline_says_so() {
        openWithApps();
        typeNow("q");
        compare(hitNames(), []);
        const sentence = findChild(named("noHits"), "sentence");
        verify(sentence.visible);
        compare(sentence.text, "nichts zum hingehen oder ausführen passt zu „q“.");
        compare(sentence.color, Tokens.color.textContrastHigh);
        compare(named("noHits").y, Tokens.spaceL);
        compare(findChild(named("noHits"), "line").y, 0);
        compare(sentence.y, Geometry.hairline + Tokens.spaceM);
    }

    function test_typing_on_or_erasing_changes_the_hits_and_a_digit_or_a_space_types_on() {
        openWithApps();
        typeNow("k");
        compare(hitNames(), ["Kate", "Konsole", "KWrite"]);
        typeNow("o");
        compare(hitNames(), ["Konsole"]);
        Prefs.motion = "off";
        keyClick(Qt.Key_Backspace);
        compare(hitNames(), ["Kate", "Konsole", "KWrite"]);
        keyClick(Qt.Key_Space);
        compare(start.query, "k ");
        compare(hitNames(), ["Kate", "Konsole", "KWrite"], "space around the text does not count");
        keyClick(Qt.Key_5);
        compare(start.query, "k 5");
        compare(hitNames(), []);
    }

    function test_a_shortcut_a_digit_or_a_space_starts_no_search() {
        openWithApps();
        keyClick(Qt.Key_K, Qt.ControlModifier);
        keyClick(Qt.Key_5);
        keyClick(Qt.Key_Space);
        compare(start.query, "");
        verify(named("pivot").visible);
    }

    function test_enter_presses_the_first_hit_in_its_centre_launches_it_once_and_turns_the_start_out_forward_with_it_last() {
        openWithApps();
        typeNow("ko");
        const first = start.hitTiles()[0];
        keyClick(Qt.Key_Return);
        compare(calls, ["launch Konsole"]);
        verify(turner.running);
        verify(!turner.back, "forward");
        compare(turner.pressedTile, first);
        verify(first.pressed);
        compare(Qt.point(first.pressX, first.pressY), Qt.point(0, 0), "in its centre");
        const last = turner.leavingTurns.find(turn => turn.part.item === first);
        verify(turner.leavingTurns.every(turn => turn.at <= last.at), "the pressed tile last");
        keyClick(Qt.Key_Return);
        compare(calls, ["launch Konsole"], "once");
        tryVerify(() => closedSpy.count === 1, 3000);
    }

    function test_arrows_move_through_the_hits_and_enter_or_space_presses_the_one_in_focus() {
        openWithApps();
        typeNow("k");
        const tiles = start.hitTiles();
        keyClick(Qt.Key_Down);
        verify(tiles[0].activeFocus);
        keyClick(Qt.Key_Right);
        verify(tiles[1].activeFocus);
        keyClick(Qt.Key_Up);
        verify(named("typed").activeFocus, "a search has no pivot; up goes to its line");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Return);
        compare(calls, ["launch Konsole"]);
        tryVerify(() => closedSpy.count === 1, 3000);
        openNow();
        typeNow("k");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Right);
        verify(start.hitTiles()[2].activeFocus, "nor alle apps to go right to");
        keyClick(Qt.Key_Space);
        compare(calls, ["launch Konsole", "launch KWrite"]);
        compare(start.query, "k", "the space pressed the tile and typed nothing");
    }

    function test_the_first_hit_is_a_wide_tile_with_the_enter_key_and_bester_treffer_and_the_rest_are_single() {
        openWithApps();
        typeNow("k");
        const tiles = start.hitTiles();
        compare(tiles.length, 3);
        compare(tiles[0].columns, 2);
        compare(tiles[0].rows, 1);
        verify(tiles[0].best);
        const hint = findChild(tiles[0], "bestHit");
        verify(hint.visible);
        compare(findChild(hint, "key").children[0].text, "enter");
        compare(hint.children[1].text, "bester treffer");
        verify(hint.x >= findChild(tiles[0], "name").width, "after the name");
        verify(hint.x + hint.width <= tiles[0].width, "inside the tile");
        for (const tile of tiles.slice(1)) {
            compare(tile.columns, 1);
            verify(!findChild(tile, "bestHit").visible);
        }
        compare(tiles[1].x, 2 * (Tokens.tileUnit + Tokens.spaceS), "the next hit follows the wide one");
    }

    function test_enter_from_the_line_starts_exactly_the_marked_best_hit_and_arrows_move_on_from_it() {
        openWithApps();
        typeNow("k");
        const tiles = start.hitTiles();
        verify(tiles[0].best);
        keyClick(Qt.Key_Down);
        verify(tiles[0].activeFocus, "the arrows start at the best hit");
        keyClick(Qt.Key_Right);
        verify(tiles[1].activeFocus);
        keyClick(Qt.Key_Left);
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Return);
        compare(calls, ["launch Kate"]);
    }

    function test_enter_starts_the_tile_in_focus_when_it_is_not_the_best_hit() {
        openWithApps();
        typeNow("k");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Right);
        verify(start.hitTiles()[1].activeFocus);
        keyClick(Qt.Key_Return);
        compare(calls, ["launch Konsole"]);
    }

    function test_an_app_started_more_often_stands_first_and_wide_among_equal_hits() {
        start.starts = { "org.example.KWrite": 2, "org.example.Konsole": 1 };
        openWithApps();
        typeNow("k");
        compare(hitNames(), ["KWrite", "Konsole", "Kate"]);
        verify(start.hitTiles()[0].best);
        keyClick(Qt.Key_Return);
        compare(calls, ["launch KWrite"]);
    }

    function test_the_best_hit_changes_with_the_text_and_the_wide_tile_goes_to_the_new_first() {
        openWithApps();
        typeNow("k");
        compare(hitNames(), ["Kate", "Konsole", "KWrite"]);
        typeNow("o");
        compare(hitNames(), ["Konsole"]);
        const only = start.hitTiles();
        compare(only[0].columns, 2);
        verify(only[0].best);
    }

    function test_a_hit_that_takes_the_focus_scrolls_into_view() {
        start.apps = Array.from({ length: 40 }, (_, i) => installedApp(`app ${i}`));
        openNow();
        typeNow("app");
        const results = named("results");
        for (let i = 0; i < 7; i++)
            keyClick(Qt.Key_Down);
        const last = start.hitTiles()[35];
        verify(last.activeFocus);
        const top = last.mapToItem(results, 0, 0).y;
        verify(top >= 0 && top + last.height <= results.height, `whole in view at ${top}`);
    }

    function test_escape_in_a_search_closes_the_start_back_the_way_it_came_and_it_opens_again_without_the_search() {
        openWithApps();
        typeNow("ko");
        keyClick(Qt.Key_Escape);
        verify(!start.wanted);
        verify(turner.running);
        verify(turner.back);
        tryVerify(() => closedSpy.count === 1, 3000);
        openNow();
        compare(start.query, "");
        verify(named("pivot").visible);
        verify(named("column").visible);
        verify(!named("results").visible);
    }

    function test_escape_closes_the_start_from_a_hit_in_focus_too() {
        openWithApps();
        typeNow("k");
        keyClick(Qt.Key_Down);
        verify(start.hitTiles()[0].activeFocus);
        keyClick(Qt.Key_Escape);
        verify(!start.wanted);
    }

    function test_at_rekta_s_own_pace_the_parts_turn_in_and_out_at_full_length_while_the_windows_stay_at_the_effect_s_pace() {
        Prefs.startPace = "rekta";
        start.open();
        compare(named("waitForWindows").interval, Geometry.turnOverlap * FadeBack.duration, "the windows come back at the effect's pace");
        tryVerify(() => turner.running, 2000);
        verifyPace(turner.arrivingTurns, Tokens.durationModerate, turner.handOverAt, 1);
        tryVerify(() => start.phase === "open", 3000);
        keyClick(Qt.Key_Escape);
        verifyPace(turner.leavingTurns, Tokens.durationShort, 0, 1);
    }

    function test_the_pace_set_while_the_start_is_open_acts_on_the_next_turn_out() {
        openNow();
        Prefs.startPace = "rekta";
        keyClick(Qt.Key_Escape);
        verifyPace(turner.leavingTurns, Tokens.durationShort, 0, 1);
    }

    function test_escape_in_a_search_clears_it_and_stays_when_the_setting_says_back() {
        start.searchEscape = "back";
        openWithApps();
        typeNow("ko");
        keyClick(Qt.Key_Escape);
        compare(start.query, "");
        verify(start.wanted);
        keyClick(Qt.Key_Escape);
        verify(!start.wanted, "a second Escape closes it from the start place");
    }

    function test_back_clears_the_search_and_shows_the_place_before_and_a_second_back_closes() {
        openWithApps();
        typeNow("k");
        Prefs.motion = "off";
        keyClick(Qt.Key_Back);
        compare(start.query, "");
        verify(named("pivot").visible);
        verify(named("column").visible);
        verify(!named("results").visible);
        verify(start.wanted);
        keyClick(Qt.Key_Back);
        verify(!start.wanted);
    }

    function test_back_alt_left_and_the_mouse_back_button_clear_the_search_first() {
        openWithApps();
        Prefs.motion = "off";
        for (const goBack of [() => keyClick(Qt.Key_Back), () => keyClick(Qt.Key_Left, Qt.AltModifier), () => mouseClick(start, start.width - 50, 50, Qt.BackButton)]) {
            keyClick("k");
            goBack();
            compare(start.query, "");
            verify(named("pivot").visible);
            verify(start.wanted);
        }
    }

    function test_erasing_to_nothing_clears_the_search() {
        openWithApps();
        typeNow("ko");
        Prefs.motion = "off";
        keyClick(Qt.Key_Backspace);
        keyClick(Qt.Key_Backspace);
        verify(named("pivot").visible);
        verify(named("column").visible);
        verify(start.wanted);
    }

    // The search's line, edited as a field is, with the motion off so that each key's change stands at once.
    function openSearchFor(text: string): var {
        openWithApps();
        Prefs.motion = "off";
        for (const character of text)
            keyClick(character);
        return named("typed");
    }

    function keyClicks(key: int, times: int, modifiers: int) {
        for (let i = 0; i < times; i++)
            keyClick(key, modifiers);
    }

    function test_the_line_has_the_keys_once_the_search_shows_its_caret_after_what_was_typed_in_rekta_s_colours() {
        const line = openSearchFor("fi");
        verify(line.activeFocus);
        compare(line.cursorPosition, 2);
        verify(line.cursorVisible);
        compare(line.color, Tokens.color.textPrimary);
        compare(line.selectionColor, Tokens.color.accent);
        compare(line.selectedTextColor, Tokens.color.textOnAccent);
    }

    function test_ctrl_a_selects_the_whole_line_typing_replaces_it_and_backspace_or_delete_erase_it() {
        const line = openSearchFor("kate");
        keyClick(Qt.Key_A, Qt.ControlModifier);
        compare(line.selectedText, "kate");
        keyClick("w");
        compare(start.query, "w");
        keyClick(Qt.Key_A, Qt.ControlModifier);
        keyClick(Qt.Key_Backspace);
        compare(start.query, "");
        verify(named("pivot").visible, "the search ends");
        keyClick("k");
        keyClick(Qt.Key_A, Qt.ControlModifier);
        keyClick(Qt.Key_Delete);
        compare(start.query, "");
        verify(named("pivot").visible);
    }

    function test_ctrl_u_erases_to_the_line_s_start_and_ctrl_k_to_its_end() {
        const line = openSearchFor("kon sole");
        keyClicks(Qt.Key_Left, 4, Qt.NoModifier);
        keyClick(Qt.Key_U, Qt.ControlModifier);
        compare(start.query, "sole");
        compare(line.cursorPosition, 0);
        keyClick(Qt.Key_End);
        keyClicks(Qt.Key_Left, 2, Qt.NoModifier);
        keyClick(Qt.Key_K, Qt.ControlModifier);
        compare(start.query, "so");
        compare(line.cursorPosition, 2);
    }

    function test_ctrl_w_and_ctrl_backspace_erase_the_word_before_the_caret_and_ctrl_delete_the_word_after() {
        const line = openSearchFor("kate kon sole");
        keyClick(Qt.Key_W, Qt.ControlModifier);
        compare(start.query, "kate kon ");
        keyClick(Qt.Key_Backspace, Qt.ControlModifier);
        compare(start.query, "kate ");
        keyClick("w");
        keyClick(Qt.Key_Home);
        keyClick(Qt.Key_Delete, Qt.ControlModifier);
        compare(start.query, "w");
        compare(line.cursorPosition, 0);
    }

    function test_arrows_ctrl_arrows_home_and_end_move_the_caret_and_with_shift_they_select() {
        const line = openSearchFor("kate kon");
        keyClick(Qt.Key_Home);
        compare(line.cursorPosition, 0);
        keyClick(Qt.Key_End);
        compare(line.cursorPosition, 8);
        keyClick(Qt.Key_Left);
        compare(line.cursorPosition, 7);
        keyClick(Qt.Key_Left, Qt.ControlModifier);
        compare(line.cursorPosition, 5);
        keyClick(Qt.Key_Right, Qt.ControlModifier);
        compare(line.cursorPosition, 8);
        keyClicks(Qt.Key_Left, 3, Qt.ShiftModifier);
        compare(line.selectedText, "kon");
        keyClick(Qt.Key_Left, Qt.ShiftModifier | Qt.ControlModifier);
        compare(line.selectedText, "kate kon");
        keyClick(Qt.Key_Right);
        compare(line.selectedText, "");
        compare(line.cursorPosition, 8);
        keyClick(Qt.Key_Home, Qt.ShiftModifier);
        compare(line.selectedText, "kate kon");
        keyClick(Qt.Key_Left);
        keyClick(Qt.Key_End, Qt.ShiftModifier);
        compare(line.selectedText, "kate kon");
        verify(line.activeFocus, "the arrows stay in the line");
    }

    function test_ctrl_c_ctrl_x_and_ctrl_v_copy_cut_and_paste_and_a_paste_keeps_its_first_line() {
        const line = openSearchFor("kon sole");
        keyClick(Qt.Key_Left, Qt.ShiftModifier | Qt.ControlModifier);
        keyClick(Qt.Key_C, Qt.ControlModifier);
        compare(start.query, "kon sole");
        keyClick(Qt.Key_X, Qt.ControlModifier);
        compare(start.query, "kon ");
        keyClick(Qt.Key_V, Qt.ControlModifier);
        keyClick(Qt.Key_V, Qt.ControlModifier);
        compare(start.query, "kon solesole");
        const lines = createTemporaryQmlObject("import QtQuick; TextEdit { text: 'kate\\nkonsole\\n' }", testCase);
        lines.selectAll();
        lines.copy();
        line.forceActiveFocus();
        keyClick(Qt.Key_Home);
        keyClick(Qt.Key_V, Qt.ControlModifier);
        compare(start.query, "katekon solesole");
        compare(line.cursorPosition, 4);
    }

    function test_ctrl_z_takes_back_the_last_change() {
        openSearchFor("kate kon");
        keyClick(Qt.Key_W, Qt.ControlModifier);
        compare(start.query, "kate ");
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(start.query, "kate kon");
        keyClick(Qt.Key_End);
        keyClicks(Qt.Key_Left, 2, Qt.NoModifier);
        keyClick(Qt.Key_K, Qt.ControlModifier);
        compare(start.query, "kate k");
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(start.query, "kate kon");
    }

    function test_a_double_click_on_the_line_selects_a_word() {
        const line = openSearchFor("kate kon");
        const kon = line.positionToRectangle(6);
        mouseDoubleClickSequence(line, kon.x, kon.y + kon.height / 2);
        compare(line.selectedText, "kon");
    }

    function test_down_or_tab_go_on_to_the_hits_and_up_or_shift_tab_back_to_the_line() {
        const line = openSearchFor("k");
        const first = start.hitTiles()[0];
        keyClick(Qt.Key_Tab);
        verify(first.activeFocus);
        keyClick(Qt.Key_Backtab);
        verify(line.activeFocus);
        keyClick(Qt.Key_Down);
        verify(first.activeFocus);
        keyClick(Qt.Key_Up);
        verify(line.activeFocus);
        keyClick(Qt.Key_Return);
        compare(calls, ["launch Kate"], "enter in the line presses the first hit");
    }

    function test_typing_or_erasing_with_a_hit_in_focus_goes_on_in_the_line_at_its_caret() {
        const line = openSearchFor("ons");
        keyClick(Qt.Key_Home);
        keyClick(Qt.Key_Down);
        verify(start.hitTiles()[0].activeFocus);
        keyClick("k");
        compare(start.query, "kons");
        verify(line.activeFocus);
        compare(line.cursorPosition, 1);
        keyClick(Qt.Key_Down);
        verify(start.hitTiles()[0].activeFocus);
        keyClick(Qt.Key_Backspace);
        compare(start.query, "ons");
        verify(line.activeFocus);
        compare(line.cursorPosition, 0);
    }

    function test_while_the_start_turns_out_the_line_takes_no_edit() {
        const line = openSearchFor("kate");
        Prefs.motion = "system";
        keyClick(Qt.Key_Escape);
        verify(turner.running);
        keyClick("x");
        keyClick(Qt.Key_U, Qt.ControlModifier);
        compare(start.query, "kate");
        verify(line.readOnly);
    }

    function test_a_letter_typed_right_after_opening_shows_the_title_and_the_hits_before_the_opening_could_have_landed() {
        start.apps = searchableApps();
        start.open();
        keyClick("k");
        verify(!start.turning, "the opening stands at its end");
        compare(start.phase, "open");
        verify(start.holdsKeyboard, "the windows stay back");
        const earliestLanding = Geometry.turnOverlap * FadeBack.duration + Geometry.startTempo * Geometry.heftMin * Tokens.durationModerate;
        tryVerify(() => named("searchTitle").visible, earliestLanding);
        compare(named("typed").text, "k");
        compare(hitNames(), ["Kate", "Konsole", "KWrite"]);
    }

    function test_a_letter_typed_while_the_parts_turn_in_ends_the_turn_in_its_end_state_and_the_search_follows() {
        start.apps = searchableApps();
        start.open();
        tryVerify(() => turner.running, 2000);
        turner.paused = true;
        turner.elapsed = 1;
        const parts = [named("pivot"), ...tilesIn("pinned")];
        keyClick("k");
        turner.paused = false;
        verify(!turner.running);
        compare(start.phase, "open");
        verify(parts.every(part => Array.from(part.transform).every(transform => (transform as Rotation) === null)), "turned all the way in");
        compare(motionsOf(parts).length, parts.length, "and leave from there");
        tryVerify(() => named("searchTitle").visible, 1000, "the paused turn would never have landed");
        compare(hitNames(), ["Kate", "Konsole", "KWrite"]);
    }

    function test_arrows_and_enter_act_on_the_hits_right_after_a_letter_typed_while_the_start_opens() {
        start.apps = searchableApps();
        start.open();
        keyClick("k");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Right);
        verify(start.hitTiles()[1].activeFocus);
        keyClick(Qt.Key_Return);
        compare(calls, ["launch Konsole"]);
        tryVerify(() => closedSpy.count === 1, 3000);
        start.open();
        tryVerify(() => turner.running, 2000);
        keyClick("k");
        keyClick(Qt.Key_Return);
        compare(calls, ["launch Konsole", "launch Kate"], "enter presses the first hit");
    }

    function test_the_place_s_parts_leave_then_the_title_and_the_hits_arrive() {
        openWithApps();
        const presence = named("presence");
        const pinned = tilesIn("pinned");
        keyClick("k");
        verify(named("pivot").visible, "the place leaves first");
        const leaving = motionsOf([named("pivot"), ...pinned]);
        compare(leaving.length, pinned.length + 1);
        verify(leaving.every(motion => motion.duration === Geometry.leaveShare * Tokens.durationShort && motion.to.opacity === 0));
        tryVerify(() => named("searchTitle").visible, 1000);
        const tiles = start.hitTiles();
        const arriving = motionsOf([named("typed"), ...tiles]);
        compare(arriving.length, tiles.length + 1);
        verify(motionsOf(tiles).every(motion => motion.from.scale === Geometry.arriveTileScale && motion.duration === Tokens.durationModerate));
        compare(motionsOf([named("typed")])[0].from.y, -Geometry.arriveShift, "a line of text arrives as a row");
        tryVerify(() => !presence.running, 1000);
        verify(tiles.every(tile => tile.opacity === 1));
    }

    function test_typing_on_the_hits_that_no_longer_match_leave_and_the_rest_close_up() {
        openWithApps();
        typeNow("k");
        const [kate, konsole, kwrite] = start.hitTiles();
        keyClick("w");
        compare(motionsOf([kate, konsole]).length, 2);
        verify(motionsOf([kate, konsole]).every(motion => motion.to.scale === Geometry.leaveTileScale));
        tryVerify(() => motionsOf([kwrite]).length === 1, 1000);
        const glide = motionsOf([kwrite])[0];
        compare(glide.from.x, 3 * (Tokens.tileUnit + Tokens.spaceS));
        compare(glide.duration, Tokens.durationModerate);
        compare(glide.curve, Tokens.easeBase);
        tryVerify(() => !named("presence").running, 1000);
        compare(start.hitTiles(), [kwrite], "the same tile");
        compare(kwrite.x, 0);
    }

    function test_erasing_brings_back_the_hits_that_match_again_rising_into_their_place() {
        openWithApps();
        typeNow("kw");
        keyClick(Qt.Key_Backspace);
        tryVerify(() => start.hitTiles().length === 3, 1000);
        const [kate, konsole] = start.hitTiles();
        const arriving = motionsOf([kate, konsole]);
        compare(arriving.length, 2);
        for (const motion of arriving) {
            compare(motion.from.y, Geometry.arriveShift);
            compare(motion.from.opacity, 0);
            compare(motion.curve, Tokens.easeIn);
        }
    }

    // A fading item draws through a layer whose source Qt puts beside it, among the parts of the view.
    function test_clearing_while_hits_still_fade_in_takes_only_the_hits_and_title_as_parts() {
        openWithApps();
        typeNow("kx");
        keyClick(Qt.Key_Backspace);
        tryVerify(() => start.hitTiles().some(tile => tile.opacity > 0 && tile.opacity < 1), 1000);
        keyClick(Qt.Key_Backspace);
        verify(named("presence").moving.every(motion => motion.item !== null));
        tryVerify(() => named("column").visible && !named("presence").running, 2000);
    }

    function test_more_than_sixty_changes_apply_at_once() {
        start.apps = Array.from({ length: 61 }, (_, i) => installedApp(`app ${i}`));
        openNow();
        keyClick("a");
        verify(!named("presence").running);
        verify(named("results").visible);
        compare(start.hitTiles().length, 61);
    }

    function test_under_reduced_motion_the_search_comes_and_goes_at_once() {
        openWithApps();
        Prefs.motion = "off";
        keyClick("k");
        verify(named("results").visible);
        verify(!named("presence").running);
        verify(start.hitTiles().every(tile => tile.opacity === 1));
        keyClick(Qt.Key_Back);
        verify(named("column").visible);
        verify(tilesIn("pinned").every(tile => tile.opacity === 1));
    }

    function test_a_search_stays_where_it_is_under_a_sideways_wheel() {
        openWithApps();
        typeNow("k");
        mouseWheel(named("results"), 100, 100, -120, 0);
        compare(named("pivot").currentIndex, 0);
        verify(named("results").visible);
    }

    function test_the_start_opens_again_without_the_search() {
        openWithApps();
        typeNow("k");
        Prefs.motion = "off";
        start.toggle();
        start.toggle();
        compare(start.query, "");
        verify(named("pivot").visible);
        verify(named("column").visible);
        compare(start.hitTiles().length, 0);
    }

    // The headings and the active title take the primary text colour; the inactive title (text-contrast-medium) is large
    // text, at least 24px on a sideways Start, where WCAG asks 3:1 (1.4.3).
    function test_text_on_the_glass_keeps_its_contrast_before_a_white_and_a_black_window() {
        const luminance = colour => {
            const channel = c => c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
            return 0.2126 * channel(colour.r) + 0.7152 * channel(colour.g) + 0.0722 * channel(colour.b);
        };
        const over = (top, below) => Qt.rgba(top.r * top.a + below.r * (1 - top.a), top.g * top.a + below.g * (1 - top.a), top.b * top.a + below.b * (1 - top.a), 1);
        const ratio = (a, b) => (Math.max(luminance(a), luminance(b)) + 0.05) / (Math.min(luminance(a), luminance(b)) + 0.05);
        openNow();
        verify(named("pivot").inactiveSize >= 24, "large text");
        for (const theme of ["light", "dark"]) {
            const colours = theme === "light" ? Tokens.light : Tokens.dark;
            for (const window of [Qt.rgba(1, 1, 1, 1), Qt.rgba(0, 0, 0, 1)]) {
                const ground = over(colours.glass, window);
                verify(ratio(colours.textPrimary, ground) >= 4.5, `${theme}: headings on glass over ${window}`);
                verify(ratio(colours.textContrastMedium, ground) >= 3, `${theme}: the inactive title on glass over ${window}`);
            }
        }
    }

    function test_contact_sheet() {
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const backdrop = createTemporaryObject(backdropComponent, testCase);
                const sheet = createTemporaryObject(startComponent, backdrop);
                sheet.preview = previewComponent;
                Prefs.motion = "off";
                sheet.open();
                Prefs.motion = "system";
                keyClick(Qt.Key_Down);
                wait(Tokens.durationShort);
                waitForRendering(backdrop);
                grabImage(backdrop).save(`start-sheet-${theme}-${density}.png`);
                verify(sheet.wanted, `${theme} ${density}`);
            }
        }
    }

    function test_contact_sheet_of_the_search() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const backdrop = createTemporaryObject(backdropComponent, testCase);
            const sheet = createTemporaryObject(startComponent, backdrop);
            sheet.apps = searchableApps();
            Prefs.motion = "off";
            sheet.open();
            keyClick("f");
            keyClick("i");
            keyClick(Qt.Key_Down);
            Prefs.motion = "system";
            waitForRendering(backdrop);
            grabImage(backdrop).save(`start-search-sheet-${theme}.png`);
            compare(sheet.query, "fi", theme);
        }
    }


    function test_contact_sheet_of_the_search_with_the_best_hit() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const backdrop = createTemporaryObject(backdropComponent, testCase);
            const sheet = createTemporaryObject(startComponent, backdrop);
            sheet.apps = searchableApps();
            Prefs.motion = "off";
            sheet.open();
            keyClick("k");
            keyClick(Qt.Key_Down);
            Prefs.motion = "system";
            waitForRendering(backdrop);
            grabImage(backdrop).save(`start-search-best-${theme}.png`);
            compare(sheet.query, "k", theme);
        }
    }
    // The caret inside "fire|fox", then "fire" selected. Each is taken right after a key, which lights the caret.
    function test_contact_sheet_of_the_search_line() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const backdrop = createTemporaryObject(backdropComponent, testCase);
            const sheet = createTemporaryObject(startComponent, backdrop);
            sheet.apps = searchableApps();
            Prefs.motion = "off";
            sheet.open();
            for (const character of "firefox")
                keyClick(character);
            keyClicks(Qt.Key_Left, 3, Qt.NoModifier);
            waitForRendering(backdrop);
            grabImage(backdrop).save(`start-search-caret-${theme}.png`);
            keyClick(Qt.Key_Home, Qt.ShiftModifier);
            waitForRendering(backdrop);
            grabImage(backdrop).save(`start-search-selection-${theme}.png`);
            Prefs.motion = "system";
            compare(findChild(sheet, "typed").selectedText, "fire", theme);
        }
    }

    // "alle apps" with forty-three apps, one taken by a typed letter.
    function test_contact_sheet_of_alle_apps() {
        const names = ["Akregator", "Ark", "Audacity", "Blender", "Chromium", "digiKam", "Discover", "Dolphin", "Elisa", "Emacs", "Falkon", "Filelight", "Firefox", "GIMP", "Gwenview", "Haruna", "Inkscape", "Kate", "KCalc", "KCharSelect", "Kdenlive", "Kleopatra", "KMail", "KolourPaint", "Konsole", "Krita", "KWrite", "LibreOffice Writer", "Okular", "Partition Manager", "qBittorrent", "Spectacle", "Steam", "System Monitor", "System Settings", "Thunderbird", "Umbrello", "VLC", "Wireshark", "Xournal++", "Yakuake", "Zeal", "Zettlr"];
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const backdrop = createTemporaryObject(backdropComponent, testCase);
            const sheet = createTemporaryObject(startComponent, backdrop);
            sheet.apps = names.map(name => installedApp(name)).sort(Rules.byName);
            Prefs.motion = "off";
            sheet.open();
            findChild(sheet, "pivot").select(1);
            keyClick("k");
            Prefs.motion = "system";
            waitForRendering(backdrop);
            grabImage(backdrop).save(`start-allapps-sheet-${theme}.png`);
            verify(sheet.rowTiles().some(tile => tile.activeFocus), theme);
        }
    }

    // Moments of the turn, each a third of the size: opening (the glass alone, a quarter, half, landed), then closing
    // after a press (as the pressed tile starts, the last to start, and halfway through its turn). The glass alone is taken
    // last, as its parts start on the clock.
    function test_contact_sheet_of_the_turn() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const sheet = createTemporaryObject(framesComponent, testCase);
            const turners = [
                openingFrame(sheet, 1, 0.25),
                openingFrame(sheet, 2, 0.5),
                openingFrame(sheet, 3, 1),
                closingFrame(sheet, 4, 0),
                closingFrame(sheet, 5, 0.5),
                openingFrame(sheet, 0, -1)
            ];
            waitForRendering(sheet);
            grabImage(sheet).save(`start-turn-sheet-${theme}.png`);
            turners.forEach(turner => turner.paused = false);
            verify(turners.every(turner => turner !== null), theme);
        }
    }

    function placeOf(sheet: var, index: int): var {
        return findChild(findChild(sheet, `frame${index}`), "place");
    }

    function lengthOf(turns: var): real {
        return Math.max(...turns.map(turn => turn.at + turn.duration));
    }

    // Opens a frame's Start and holds its turn at a share of its length; below 0, halfway to the parts' start.
    function openingFrame(sheet: var, index: int, share: real): var {
        const place = placeOf(sheet, index);
        const turner = findChild(place, "turn");
        place.open();
        if (share < 0) {
            wait(Geometry.turnOverlap * FadeBack.duration / 2);
            return turner;
        }
        tryVerify(() => turner.running, 2000);
        turner.paused = true;
        turner.elapsed = share * lengthOf(turner.arrivingTurns);
        return turner;
    }

    // Presses a frame's dolphin tile and holds the turn out at a share of that tile's own turn.
    function closingFrame(sheet: var, index: int, share: real): var {
        const place = placeOf(sheet, index);
        const turner = findChild(place, "turn");
        Prefs.motion = "off";
        place.open();
        Prefs.motion = "system";
        const dolphin = findChild(findChild(place, "pinned"), "grid").children[1];
        place.press(dolphin, () => {});
        turner.paused = true;
        const turn = turner.leavingTurns.find(leaving => leaving.part.item === dolphin);
        turner.elapsed = turn.at + share * turn.duration;
        return turner;
    }

    Component {
        id: framesComponent

        Grid {
            columns: 3

            Repeater {
                model: 6

                delegate: Item {
                    required property int index

                    objectName: `frame${index}`
                    width: testCase.width / 3
                    height: testCase.height / 3
                    clip: true

                    Rectangle {
                        width: testCase.width
                        height: testCase.height
                        scale: 1 / 3
                        transformOrigin: Item.TopLeft
                        color: "white"

                        Rectangle {
                            x: parent.width / 2
                            width: parent.width / 2
                            height: parent.height
                            color: "black"
                        }

                        StartPlace {
                            objectName: "place"
                            anchors.fill: parent
                            windows: [testCase.fakeWindow("konsole: build", 10), testCase.fakeWindow("Rekta Design — docs", 30)]
                            pinned: [testCase.fakeApp("systemsettings", 1), testCase.fakeApp("dolphin", 2), testCase.fakeApp("konsole", 1)]
                            preview: previewComponent
                        }
                    }
                }
            }
        }
    }

    // A light and a dark window behind the glass, as the Start shows over them.
    Component {
        id: backdropComponent

        Rectangle {
            width: testCase.width
            height: testCase.height
            color: "white"

            Rectangle {
                x: parent.width / 2
                width: parent.width / 2
                height: parent.height
                color: "black"
            }
        }
    }

    // Pages of System Settings, as the app model shapes them.
    function settingsPages(): var {
        return [
            Object.assign(installedApp("Bluetooth"), { id: "kcm_bluetooth" }),
            Object.assign(installedApp("Datum und Zeit"), { id: "kcm_clock" }),
            Object.assign(installedApp("Tastatur"), { id: "kcm_keyboard" })
        ];
    }

    function fakeCommands(): var {
        const say = (text, keywords) => ({
                text: text,
                keywords: keywords,
                run: () => testCase.calls = [...testCase.calls, `command ${text}`]
            });
        return [
            Object.assign(say("sperren", ["lock"]), { key: "Meta+L" }),
            say("dunkel an", ["dark"]),
            say("dateien schließen", []),
            say("zeit anzeigen", []),
            {
                word: "ton",
                at: percent => say(`ton auf ${percent} %`, [])
            }
        ];
    }

    // The Start open with every kind of thing to find.
    function openWithEverything() {
        start.windows = [fakeWindow("konsole: build", 10), fakeWindow("Dateien — home", 30)];
        start.settings = settingsPages();
        start.commands = fakeCommands();
        openWithApps();
    }

    function rowTexts(group: string): var {
        return start.searchRows().filter(row => row.parent.objectName === group).map(row => row.text);
    }

    function groupNames(): var {
        return start.rowGroups.map(group => group.name);
    }

    function test_every_kind_is_found_by_the_first_letters_of_a_word() {
        openWithEverything();
        typeNow("sp");
        compare(rowTexts("befehle"), ["sperren"]);
        start.query = "";
        typeNow("dun");
        compare(rowTexts("befehle"), ["dunkel an"]);
        start.query = "";
        typeNow("blue");
        compare(rowTexts("einstellungen"), ["Bluetooth"]);
        start.query = "";
        typeNow("build");
        compare(rowTexts("fenster"), ["konsole: build"]);
    }

    function test_apps_stand_as_tiles_and_the_other_kinds_as_rows_below_under_their_headings_in_order() {
        openWithEverything();
        typeNow("da");
        compare(hitNames(), ["Dateien"]);
        compare(groupNames(), ["fenster", "einstellungen", "befehle"]);
        compare(rowTexts("fenster"), ["Dateien — home"]);
        compare(rowTexts("einstellungen"), ["Datum und Zeit"]);
        compare(rowTexts("befehle"), ["dateien schließen", "dunkel an"]);
        const tile = start.hitTiles()[0];
        let above = tile.mapToItem(named("results").contentItem, 0, tile.height).y;
        for (const name of groupNames()) {
            const heading = findChild(findChild(named("rows"), name), "heading");
            verify(heading.visible);
            compare(heading.text, name);
            const top = heading.mapToItem(named("results").contentItem, 0, 0).y;
            verify(top > above, `${name} below the one before`);
            above = top;
        }
    }

    function test_a_group_without_a_hit_has_no_heading() {
        openWithEverything();
        typeNow("blue");
        compare(groupNames(), ["einstellungen"]);
        compare(findChild(named("rows"), "fenster"), null);
        compare(findChild(named("rows"), "befehle"), null);
        compare(hitNames(), []);
    }

    function test_without_an_app_the_first_row_is_the_best_hit_with_enter_and_enter_acts_on_it() {
        openWithEverything();
        typeNow("sp");
        const rows = start.searchRows();
        verify(rows[0].best);
        verify(findChild(rows[0], "enterKey").visible);
        compare(findChild(rows[0], "enterKey").text, "enter");
        compare(findChild(rows[0], "bestWord").text, "bester treffer");
        keyClick(Qt.Key_Return);
        compare(calls, ["command sperren"]);
        verify(!turner.back, "forward");
        tryVerify(() => closedSpy.count === 1, 3000);
    }

    function test_with_an_app_the_best_hit_is_the_app_and_the_rows_carry_no_enter() {
        openWithEverything();
        typeNow("da");
        verify(start.hitTiles()[0].best);
        for (const row of start.searchRows())
            verify(!row.best && !findChild(row, "enterKey").visible, row.text);
        keyClick(Qt.Key_Return);
        compare(calls, ["launch Dateien"]);
    }

    function test_the_best_row_is_the_first_of_the_first_group_that_has_one() {
        openWithEverything();
        typeNow("zeit");
        compare(groupNames(), ["einstellungen", "befehle"]);
        verify(start.searchRows()[0].best);
        compare(start.searchRows()[0].text, "Datum und Zeit");
        compare(start.searchRows().filter(row => row.best).length, 1);
    }

    function test_a_window_hit_brings_the_window_forward_and_the_start_turns_out_forward() {
        openWithEverything();
        typeNow("build");
        keyClick(Qt.Key_Return);
        compare(calls, ["activate konsole: build"]);
        verify(turner.running);
        verify(!turner.back, "forward");
        tryVerify(() => closedSpy.count === 1, 3000);
        compare(calls, ["activate konsole: build"], "the window that had the keyboard is not activated");
    }

    function test_ton_and_a_number_is_a_command_that_says_what_it_sets() {
        openWithEverything();
        typeNow("ton 30");
        compare(rowTexts("befehle"), ["ton auf 30 %"]);
        keyClick(Qt.Key_Return);
        compare(calls, ["command ton auf 30 %"]);
    }

    function test_settings_pages_start_through_the_model_and_the_start_closes() {
        openWithEverything();
        typeNow("blue");
        keyClick(Qt.Key_Return);
        compare(calls, ["launch Bluetooth"]);
        tryVerify(() => closedSpy.count === 1, 3000);
    }

    function test_arrows_go_from_the_line_into_the_tiles_and_on_into_the_rows_and_back() {
        openWithEverything();
        typeNow("da");
        const tile = start.hitTiles()[0];
        const rows = start.searchRows();
        keyClick(Qt.Key_Down);
        verify(tile.activeFocus);
        keyClick(Qt.Key_Down);
        verify(rows[0].activeFocus, "from the tiles into the first row");
        keyClick(Qt.Key_Down);
        verify(rows[1].activeFocus);
        keyClick(Qt.Key_Down);
        verify(rows[2].activeFocus);
        keyClick(Qt.Key_Down);
        verify(rows[3].activeFocus);
        keyClick(Qt.Key_Down);
        verify(rows[3].activeFocus, "the last row stays");
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Up);
        verify(tile.activeFocus, "up through the rows back to the tiles");
        keyClick(Qt.Key_Up);
        verify(named("typed").activeFocus, "and on to the line");
    }

    function test_without_an_app_up_from_the_first_row_goes_to_the_line_and_enter_or_space_acts_on_the_row_in_focus() {
        openWithEverything();
        typeNow("zeit");
        const rows = start.searchRows();
        keyClick(Qt.Key_Down);
        verify(rows[0].activeFocus);
        keyClick(Qt.Key_Up);
        verify(named("typed").activeFocus);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        verify(rows[1].activeFocus);
        keyClick(Qt.Key_Space);
        compare(calls, ["command zeit anzeigen"]);
        compare(start.query, "zeit", "the space acted and typed nothing");
    }

    function test_typing_from_a_row_goes_on_in_the_line_and_escape_closes() {
        openWithEverything();
        typeNow("zeit");
        keyClick(Qt.Key_Down);
        verify(start.searchRows()[0].activeFocus);
        typeNow("x");
        compare(start.query, "zeitx");
        verify(named("typed").activeFocus);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Escape);
        tryVerify(() => closedSpy.count === 1, 3000);
    }

    function test_a_click_on_a_row_acts_on_it() {
        openWithEverything();
        typeNow("blue");
        mouseClick(start.searchRows()[0]);
        compare(calls, ["launch Bluetooth"]);
    }

    function test_with_nothing_found_of_any_kind_rekta_s_empty_sentence_stands_and_with_a_row_it_does_not() {
        openWithEverything();
        typeNow("q");
        verify(named("noHits").visible);
        compare(findChild(named("noHits"), "sentence").text, "nichts zum hingehen oder ausführen passt zu „q“.");
        compare(start.searchRows().length, 0);
        start.query = "";
        typeNow("blue");
        verify(!named("noHits").visible, "a settings page is something");
    }

    function test_erasing_the_text_takes_the_rows_with_it() {
        openWithEverything();
        typeNow("sp");
        verify(start.searchRows().length > 0);
        Prefs.motion = "off";
        start.query = "";
        Prefs.motion = "system";
        compare(start.searchRows().length, 0);
        compare(groupNames(), []);
    }

    function test_a_row_that_takes_the_focus_scrolls_into_view() {
        start.windows = Array.from({ length: 40 }, (_, i) => fakeWindow(`fenster ${i}`, i));
        openWithApps();
        typeNow("fenster");
        const results = named("results");
        for (let i = 0; i < 30; i++)
            keyClick(Qt.Key_Down);
        const row = start.searchRows().find(candidate => candidate.activeFocus);
        verify(row);
        const top = row.mapToItem(results, 0, 0).y;
        verify(top >= 0 && top + row.height <= results.height, `whole in view at ${top}`);
    }

    function test_contact_sheet_of_the_search_with_every_kind() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const backdrop = createTemporaryObject(backdropComponent, testCase);
            const sheet = createTemporaryObject(startComponent, backdrop);
            sheet.windows = [fakeWindow("konsole: build", 10), fakeWindow("Dateien — home", 30)];
            sheet.settings = settingsPages();
            sheet.commands = fakeCommands();
            sheet.apps = searchableApps();
            Prefs.motion = "off";
            sheet.open();
            keyClick("d");
            keyClick("a");
            Prefs.motion = "system";
            waitForRendering(backdrop);
            grabImage(backdrop).save(`start-search-everything-${theme}.png`);
            compare(sheet.query, "da", theme);
        }
    }

    function test_contact_sheet_of_the_search_with_a_row_as_the_best_hit() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const backdrop = createTemporaryObject(backdropComponent, testCase);
            const sheet = createTemporaryObject(startComponent, backdrop);
            sheet.windows = [fakeWindow("konsole: build", 10), fakeWindow("Dateien — home", 30)];
            sheet.settings = settingsPages();
            sheet.commands = fakeCommands();
            sheet.apps = searchableApps();
            Prefs.motion = "off";
            sheet.open();
            for (const letter of "zeit")
                keyClick(letter);
            keyClick(Qt.Key_Down);
            Prefs.motion = "system";
            waitForRendering(backdrop);
            grabImage(backdrop).save(`start-search-row-best-${theme}.png`);
            compare(sheet.query, "zeit", theme);
        }
    }

    function test_the_rows_and_their_headings_stand_at_the_edge_of_the_line_and_the_tiles_without_an_indent() {
        openWithEverything();
        typeNow("da");
        const edge = named("typed").mapToItem(start, 0, 0).x;
        compare(start.hitTiles()[0].mapToItem(start, 0, 0).x, edge, "the tile");
        for (const name of groupNames())
            compare(findChild(findChild(named("rows"), name), "heading").mapToItem(start, 0, 0).x, edge, `heading ${name}`);
        for (const row of start.searchRows())
            compare(row.mapToItem(start, 0, 0).x, edge, `row ${row.text}`);
    }

    function test_every_text_of_the_rows_starts_at_one_edge_with_an_icon_or_without() {
        openWithEverything();
        typeNow("da");
        const edges = start.searchRows().map(row => findChild(row, "label").mapToItem(start, 0, 0).x);
        verify(edges.length >= 4, `${edges.length} rows`);
        verify(edges.every(x => x === edges[0]), `${edges}`);
        compare(findChild(start.searchRows()[0], "icon").mapToItem(start, 0, 0).x, named("typed").mapToItem(start, 0, 0).x, "the icon at the edge");
    }

    function test_the_empty_sentence_stands_only_when_no_kind_has_a_hit() {
        openWithEverything();
        for (const text of ["fi", "build", "blue", "sp", "da"]) {
            Prefs.motion = "off";
            start.query = "";
            Prefs.motion = "system";
            typeNow(text);
            verify(!named("noHits").visible, `"${text}" finds something and shows no sentence`);
        }
        Prefs.motion = "off";
        start.query = "";
        Prefs.motion = "system";
        typeNow("qq");
        verify(named("noHits").visible);
    }

    function test_the_focus_ring_of_a_row_stands_outside_it_clear_of_the_icon_and_whole_in_view() {
        openWithEverything();
        typeNow("zeit");
        keyClick(Qt.Key_Down);
        const row = start.searchRows()[0];
        verify(row.activeFocus);
        const ring = findChild(row, "ring");
        verify(ring.visible);
        const icon = findChild(row, "icon");
        const outer = ring.mapToItem(start, 0, 0).x;
        verify(outer + ring.border.width <= icon.mapToItem(start, 0, 0).x, "the ring's inner edge is left of the icon");
        verify(outer >= named("results").mapToItem(start, 0, 0).x, "not clipped at the left");
    }

    function test_a_command_with_a_key_shows_it_as_a_key_hint_and_one_without_shows_none() {
        openWithEverything();
        typeNow("s");
        const keyed = start.searchRows().find(row => row.text === "sperren");
        verify(findChild(keyed, "commandKey").visible);
        compare(findChild(keyed, "commandKey").text, "Meta+L");
        const plain = start.searchRows().find(row => row.text === "dunkel an") ?? start.searchRows().find(row => row.text !== "sperren");
        verify(!findChild(plain, "commandKey").visible);
        for (const row of start.searchRows().filter(candidate => candidate.text !== "sperren"))
            verify(!findChild(row, "commandKey").visible, row.text);
    }

    function test_contact_sheet_of_a_command_with_its_key_as_the_best_hit() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const backdrop = createTemporaryObject(backdropComponent, testCase);
            const sheet = createTemporaryObject(startComponent, backdrop);
            sheet.commands = fakeCommands();
            sheet.apps = searchableApps();
            Prefs.motion = "off";
            sheet.open();
            keyClick("s");
            keyClick("p");
            keyClick(Qt.Key_Down);
            Prefs.motion = "system";
            waitForRendering(backdrop);
            grabImage(backdrop).save(`start-search-command-key-${theme}.png`);
            compare(sheet.query, "sp", theme);
        }
    }
}
