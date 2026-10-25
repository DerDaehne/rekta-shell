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
        id: typedSpy

        signalName: "typed"
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
        typedSpy.target = start;
        typedSpy.clear();
        closedSpy.target = start;
        closedSpy.clear();
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
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

    function test_a_section_has_space_l_above_and_below_and_space_m_under_its_heading() {
        openNow();
        const section = named("pinned");
        const heading = findChild(section, "heading");
        const grid = findChild(section, "grid");
        compare(heading.y, Tokens.spaceL);
        compare(grid.y, heading.y + heading.height + Tokens.spaceM);
        compare(section.height, grid.y + grid.height + Tokens.spaceL);
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
        compare(findChild(start, "glass").opacity, 0);
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

    function test_the_parts_turn_in_once_the_windows_are_three_quarters_back() {
        const started = Date.now();
        start.open();
        verify(start.shown);
        verify(!turner.running, "first only the glass");
        verify(!named("body").visible);
        tryVerify(() => turner.running, 2000);
        verify(Date.now() - started >= Geometry.turnOverlap * Tokens.durationModerate - 2);
        verify(turner.arrivingTurns.length > 0);
        tryVerify(() => start.phase === "open", 3000);
    }

    function test_the_glass_comes_over_moderate_with_ease_out_and_goes_with_ease_in() {
        const glassIn = findChild(start, "glassIn");
        const glassOut = findChild(start, "glassOut");
        compare(glassIn.duration, Tokens.durationModerate);
        compare(glassIn.easing.bezierCurve, Tokens.easeOut);
        compare(glassOut.easing.bezierCurve, Tokens.easeIn);
        compare(findChild(start, "glass").color, Tokens.color.glass);
    }

    function test_escape_turns_the_start_out_back_the_way_it_came() {
        openNow();
        keyClick(Qt.Key_Escape);
        verify(turner.running);
        verify(turner.back);
        verify(turner.pressedTile === null);
        tryVerify(() => closedSpy.count === 1, 3000);
        verify(!start.shown);
        compare(findChild(start, "glass").opacity, 0);
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

    function test_while_the_start_turns_a_key_other_than_back_does_nothing() {
        start.open();
        tryVerify(() => turner.running, 2000);
        keyClick(Qt.Key_K);
        keyClick(Qt.Key_Right);
        compare(typedSpy.count, 0);
        compare(named("pivot").currentIndex, 0);
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
        compare(findChild(start, "glass").opacity, 1);
    }

    function test_under_reduced_motion_the_start_stands_and_goes_at_once() {
        Prefs.motion = "off";
        start.open();
        compare(start.phase, "open");
        verify(named("body").visible);
        compare(findChild(start, "glass").opacity, 1);
        keyClick(Qt.Key_Escape);
        compare(start.phase, "closed");
        compare(closedSpy.count, 1);
    }

    function test_a_letter_typed_in_the_open_start_goes_to_the_palette() {
        openNow();
        keyClick(Qt.Key_K);
        compare(typedSpy.count, 1);
        compare(typedSpy.signalArguments[0][0], "k");
        keyClick(Qt.Key_K, Qt.ControlModifier);
        keyClick(Qt.Key_5);
        compare(typedSpy.count, 1, "a shortcut or a digit is no typing");
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

    function appRow(index: int): var {
        return findChild(named("appList"), "view").itemAtIndex(index);
    }

    function test_alle_apps_lists_the_installed_apps_as_a_long_list_in_the_column_under_the_pivot() {
        openOnAllApps(["ark", "Blender", "konsole"]);
        const list = named("appList");
        verify(list.visible);
        compare(list.mapToItem(start, 0, 0).x, Tokens.spaceXl);
        compare(list.width, named("column").width, "six units, as the start place");
        compare(list.mapToItem(start, 0, 0).y, named("pivot").height + Tokens.spaceL);
        compare([0, 1, 2].map(index => findChild(appRow(index), "text").text), ["ark", "Blender", "konsole"]);
        compare(findChild(appRow(0), "icon").source.toString(), pinkIcon);
    }

    function test_before_the_apps_are_known_alle_apps_loads_and_without_any_it_says_so() {
        Prefs.motion = "off";
        start.open();
        named("pivot").select(1);
        verify(named("appList").loading);
        start.apps = [];
        verify(!named("appList").loading);
        verify(findChild(named("appList"), "empty").visible);
        compare(findChild(named("appList"), "empty").text, "keine apps installiert.");
    }

    function test_down_or_tab_from_the_pivot_goes_into_the_list_and_left_back_to_start() {
        openOnAllApps(["ark", "Blender", "konsole"]);
        keyClick(Qt.Key_Down);
        verify(named("appList").activeFocus, "down with nothing in focus");
        compare(named("appList").active, 0);
        keyClick(Qt.Key_Down);
        compare(named("appList").active, 1, "the list's own keys move in it");
        keyClick(Qt.Key_Left);
        compare(named("pivot").currentIndex, 0);
        tryVerify(() => !start.turning, 3000);
        keyClick(Qt.Key_Right);
        tryVerify(() => !start.turning, 3000);
        verify(!named("appList").activeFocus, "back on alle apps, the list waits for the keys");
        named("pivot").forceActiveFocus();
        keyClick(Qt.Key_Tab);
        verify(named("appList").activeFocus, "tab from the pivot");
    }

    function test_clicking_an_app_presses_and_chooses_its_row_launches_it_once_and_turns_the_start_out_forward() {
        openOnAllApps(["ark", "Blender", "konsole"]);
        const row = appRow(1);
        mousePress(row);
        verify(row.held);
        mouseRelease(row);
        compare(calls, ["launch Blender"]);
        compare(named("appList").chosen, 1);
        verify(turner.running);
        verify(!turner.back, "forward");
        verify(turner.pressedTile === null, "no row stays behind");
        verify(turner.leavingTurns.some(turn => turn.part.item === row), "the row turns out with the rest");
        mouseClick(appRow(2));
        compare(calls, ["launch Blender"], "once");
        tryVerify(() => closedSpy.count === 1, 3000);
        compare(named("appList").chosen, -1, "the choice holds until the Start is closed");
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

    function test_after_an_app_launch_the_window_that_had_the_keyboard_is_not_activated() {
        start.windows = windowsWithTheDocsActive();
        openOnAllApps(["ark"]);
        mouseClick(appRow(0));
        tryVerify(() => closedSpy.count === 1, 3000);
        compare(calls, ["launch ark"]);
    }

    function test_going_to_alle_apps_turns_each_row_in_view_as_one_part() {
        start.apps = Array.from({ length: 60 }, (_, i) => installedApp(`app ${i}`));
        openNow();
        named("pivot").select(1);
        tryVerify(() => turner.arrivingTurns.length > 0, 3000);
        const rows = turner.arrivingTurns.map(turn => turn.part.item).filter(item => item.turnsWhole === true && item.text !== undefined);
        verify(rows.length >= 10, `${rows.length} rows turn`);
        verify(rows.includes(appRow(0)));
        verify(!turner.arrivingTurns.some(turn => turn.part.item === named("appList")), "the list is a scroller, not a part");
        tryVerify(() => !start.turning, 3000);
        named("pivot").select(0);
        verify(turner.leavingTurns.some(turn => turn.part.item === appRow(0)), "and turn out the same way");
    }

    function test_under_reduced_motion_alle_apps_stands_at_once() {
        openNow();
        start.apps = [installedApp("ark")];
        Prefs.motion = "off";
        named("pivot").select(1);
        verify(named("apps").visible);
        verify(!start.turning);
        compare(appRow(0).opacity, 1);
    }

    function test_an_upright_wheel_scrolls_the_list_a_sideways_one_goes_back_to_start() {
        openOnAllApps(Array.from({ length: 60 }, (_, i) => `app ${i}`));
        const view = findChild(named("appList"), "view");
        mouseWheel(view, 100, 100, 0, -480);
        tryVerify(() => view.contentY > 0);
        compare(named("pivot").currentIndex, 1);
        wait(Tokens.durationWheelLatch + 50);
        mouseWheel(view, 100, 100, 120, 0);
        compare(named("pivot").currentIndex, 0);
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
            wait(Geometry.turnOverlap * Tokens.durationModerate / 2);
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
}
