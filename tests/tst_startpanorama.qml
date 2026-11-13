pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Start
import "ContactSheets.js" as ContactSheets

// The start place as a panorama: the strip of section titles, the sections "läuft" and "angeheftet", the wheel and swipe
// at its ends, the keys, and the search in its place. The Start's other behaviour is tst_start.qml.
TestCase {
    id: testCase

    name: "StartPanorama"
    visible: true
    when: windowShown
    width: 1600
    height: 900

    readonly property string pinkIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAGklEQVR4nGN4aTWLbMQwqnlU86jmUc0DqxkAreu3b+7dCC4AAAAASUVORK5CYII="

    function fakeWindow(title: string, lastActivated: real): var {
        return {
            title: title,
            icon: testCase.pinkIcon,
            lastActivated: lastActivated,
            stackingOrder: 0,
            active: false,
            activate: () => {}
        };
    }

    function fakeApp(name: string, columns: int): var {
        return {
            id: name,
            name: name,
            icon: testCase.pinkIcon,
            columns: columns,
            rows: 1,
            launch: () => {}
        };
    }

    function windowsOpen(): var {
        return [fakeWindow("konsole: build", 10), fakeWindow("Rekta Design — docs", 30)];
    }

    function appsPinned(count: int): var {
        return Array.from({
            length: count
        }, (_, i) => fakeApp(`app ${i}`, 1));
    }

    Component {
        id: startComponent

        StartPlace {
            // The panorama these tests measure ends with "heute"; "zuletzt" has tests of its own (tst_startzuletzt).
            showRecent: false
            windows: testCase.windowsOpen()
            pinned: [testCase.fakeApp("systemsettings", 1), testCase.fakeApp("dolphin", 2), testCase.fakeApp("konsole", 1)]
        }
    }

    // A light and a dark window behind the glass.
    Component {
        id: backdropComponent

        Item {
            Rectangle {
                width: parent.width / 2
                height: parent.height
                color: "white"
            }

            Rectangle {
                x: parent.width / 2
                width: parent.width / 2
                height: parent.height
                color: "black"
            }
        }
    }

    SignalSpy {
        id: pastEndSpy

        signalName: "pastEnd"
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var start

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        // Without motion unless a test is about it: the keys and their targets are the same either way.
        Prefs.motion = "off";
        makeStart(1600, 900, {});
    }

    function cleanup() {
        testCase.width = 1600;
        testCase.height = 900;
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    function makeStart(width: real, height: real, props: var) {
        start = createTemporaryObject(startComponent, testCase, Object.assign({
            width: width,
            height: height
        }, props));
        pastEndSpy.target = named("panorama");
        pastEndSpy.clear();
    }

    function named(name: string): var {
        return findChild(start, name);
    }

    function tilesIn(section: string): var {
        return findChild(named(section), "grid").children.filter(item => (item as Tile) !== null);
    }

    // Opens the Start without motion, as a reduced-motion user sees it at once.
    function openNow() {
        const motion = Prefs.motion;
        Prefs.motion = "off";
        start.open();
        Prefs.motion = motion;
        waitForRendering(start);
        tryVerify(() => named("pinned").contentHeight > 0);
    }

    function openAt(width: real, height: real, props: var) {
        makeStart(width, height, props ?? {});
        openNow();
    }

    // A wheel event as Qt hands it over: pixel deltas point against the web's.
    function wheelEvent(dy: real, props: var): var {
        return Object.assign({
            x: 100,
            y: 300,
            angleDelta: Qt.point(0, 0),
            pixelDelta: Qt.point(0, -dy),
            modifiers: 0
        }, props);
    }

    function unit(count: int): real {
        return count * (Tokens.tileUnit + Tokens.spaceS);
    }

    // The sections

    function test_the_start_shows_the_pivot_the_strip_and_the_panorama_with_running_and_pinned() {
        openNow();
        compare(named("sectionStrip").titles, ["läuft", "angeheftet", "heute"]);
        verify(named("running").visible);
        verify(named("pinned").visible);
        const sections = named("panorama").sectionItems();
        compare(sections.length, 3);
        verify(sections[0] === named("running") && sections[1] === named("pinned") && sections[2] === named("today"), "in a fixed order");
    }

    function test_without_windows_running_is_gone_from_the_panorama_and_the_strip() {
        openAt(1600, 900, {
            windows: []
        });
        verify(!named("running").visible);
        compare(named("sectionStrip").titles, ["angeheftet", "heute"]);
        compare(named("panorama").sectionItems(), [named("pinned"), named("today")]);
        compare(named("pinned").x, Tokens.spaceXl, "it takes no room");
    }

    function test_running_is_two_units_wide_and_pinned_four() {
        openNow();
        compare(named("running").width, unit(2));
        compare(named("pinned").width, unit(4));
        compare(unit(2), 2 * (Tokens.tileUnit + Tokens.spaceS));
    }

    function test_pinned_packs_its_tiles_into_four_columns() {
        openAt(1600, 900, {
            pinned: appsPinned(6)
        });
        const tiles = tilesIn("pinned");
        const step = Tokens.tileUnit + Tokens.spaceS;
        compare(findChild(named("pinned"), "grid").columns, 4);
        compare(Qt.point(tiles[3].x, tiles[3].y), Qt.point(3 * step, 0), "the fourth stands in the fourth column");
        compare(Qt.point(tiles[4].x, tiles[4].y), Qt.point(0, step), "the fifth wraps to the next row");
    }

    function tile(name: string, columns: int, rows: int): var {
        return Object.assign(fakeApp(name, columns), {
            rows: rows
        });
    }

    // Two of each size, the user's three repeated: a unit, two units wide, two units square.
    function mixedPinned(count: int): var {
        return Array.from({
            length: count
        }, (_, i) => [tile(`small ${i}`, 1, 1), tile(`wide ${i}`, 2, 1), tile(`large ${i}`, 2, 2)][i % 3]);
    }

    // Its trailing edge stands at most up to the panorama's inset.
    function lastSectionStopsAtTheInset() {
        const today = named("today");
        verify(today.x + today.width <= named("panorama").width - Tokens.spaceXl, `${today.x + today.width} past the inset`);
    }

    function verifyNothingCut() {
        const pinned = named("pinned");
        verify(pinned.contentHeight <= pinned.height, `${pinned.contentHeight} taller than ${pinned.height}`);
    }

    function test_pinned_with_few_tiles_stays_four_units_wide_data() {
        return [
            {
                tag: "1600 × 900",
                width: 1600,
                height: 900
            },
            {
                tag: "2560 × 1440",
                width: 2560,
                height: 1440
            }
        ];
    }

    function test_pinned_with_few_tiles_stays_four_units_wide(data) {
        openAt(data.width, data.height, {
            pinned: [tile("systemsettings", 1, 1), tile("dolphin", 2, 1), tile("konsole", 2, 2)]
        });
        compare(named("pinned").width, unit(4));
        compare(findChild(named("pinned"), "grid").columns, 4);
        verifyNothingCut();
    }

    function test_pinned_with_many_tiles_widens_to_the_fewest_whole_units_that_show_every_row_data() {
        return [
            {
                tag: "single tiles",
                pinned: appsPinned(40)
            },
            {
                tag: "mixed sizes",
                pinned: mixedPinned(24)
            }
        ];
    }

    function test_pinned_with_many_tiles_widens_to_the_fewest_whole_units_that_show_every_row(data) {
        openAt(2560, 1440, {
            windows: [],
            pinned: data.pinned
        });
        const pinned = named("pinned");
        const grid = findChild(pinned, "grid");
        const units = Math.round(pinned.width / unit(1));
        compare(pinned.width, unit(units), "whole units");
        verify(units > 4, `${units} units`);
        compare(grid.columns, units);
        verifyNothingCut();
        verify(grid.rowsOf(data.pinned, units - 1) > start.rowsHeld(named("panorama")), "one unit fewer would cut a row");
        lastSectionStopsAtTheInset();
        verify(named("panorama").fit);
    }

    function test_pinned_with_more_tiles_than_the_window_holds_takes_every_unit_up_to_the_trailing_inset() {
        openAt(1600, 900, {
            windows: [],
            pinned: appsPinned(40)
        });
        const pinned = named("pinned");
        lastSectionStopsAtTheInset();
        const today = named("today");
        verify(today.x + today.width + unit(1) > named("panorama").width - Tokens.spaceXl, "one unit more would push heute past the inset");
        compare(pinned.width, unit(6));
        verify(named("panorama").fit);
    }

    function test_pinned_falls_back_to_four_units_when_the_panorama_runs_past_the_window() {
        openAt(1000, 700, {
            pinned: appsPinned(40)
        });
        compare(named("pinned").width, unit(4));
        compare(findChild(named("pinned"), "grid").columns, 4);
        verify(!named("panorama").fit);
    }

    function test_pinned_keeps_its_width_while_the_start_waits_hidden_for_the_windows() {
        Prefs.motion = "on";
        makeStart(2000, 900, {
            pinned: appsPinned(40)
        });
        start.open();
        verify(!named("running").visible, "the parts wait hidden");
        compare(named("pinned").width, unit(6), "as wide as with running beside it");
    }

    function test_running_tiles_are_two_units_wide_one_to_a_row() {
        openNow();
        const tiles = tilesIn("running");
        compare(findChild(named("running"), "grid").columns, 2);
        compare(tiles[0].width, 2 * Tokens.tileUnit + Tokens.spaceS);
        compare(tiles[1].y, tiles[0].y + Tokens.tileUnit + Tokens.spaceS);
    }

    function test_the_panorama_fits_at_1920_by_1080_and_nothing_scrolls() {
        openAt(1920, 1080);
        const panorama = named("panorama");
        verify(panorama.fit);
        compare(panorama.scroller.contentWidth, panorama.width);
        verify(!panorama.scroller.interactive);
        compare(unit(2) + unit(4) + 3 * Tokens.spaceXl, 1212);
    }

    function test_upright_at_1080_by_1920_the_panorama_scrolls_sideways_and_a_jump_aligns_flush_left() {
        openAt(1080, 1920);
        const panorama = named("panorama");
        verify(panorama.sideways, "1080 px wide is sideways, not compact");
        verify(!panorama.fit);
        named("sectionStrip").select(1);
        tryCompare(panorama.scroller, "contentX", named("pinned").x - Tokens.spaceXl);
        compare(named("pinned").mapToItem(panorama, 0, 0).x, Tokens.spaceXl);
    }

    // Never flush at the edge (layout.md:41–50): the window's edge lies at least space-xl inside a section.
    function edgeInsideASection(panorama: var): bool {
        const edge = panorama.width;
        return panorama.sectionItems().some(section => section.x + Tokens.spaceXl <= edge && edge <= section.x + section.width - Tokens.spaceXl);
    }

    function test_upright_at_1080_px_pinned_runs_past_the_right_edge_by_more_than_space_xl_with_the_gap_unchanged() {
        openAt(1080, 1920);
        const panorama = named("panorama");
        compare(panorama.gap, Tokens.spaceXl);
        const pinned = named("pinned");
        compare(pinned.x, 452);
        compare(pinned.x + pinned.width - panorama.width, 84, "84 px of angeheftet lie past the edge");
        verify(edgeInsideASection(panorama));
    }

    function test_at_1200_px_where_the_edge_would_fall_in_the_gap_before_heute_the_gap_narrows_to_18_and_heute_shows_space_xl() {
        openAt(1200, 1920);
        const panorama = named("panorama");
        compare(panorama.gap, 18);
        compare(named("pinned").x, Tokens.spaceXl + unit(2) + 18);
        compare(named("today").x, 1152);
        compare(panorama.width - named("today").x, Tokens.spaceXl, "heute shows space-xl");
        compare(named("pinned").width, unit(4), "angeheftet keeps its width");
    }

    function test_angeheftet_keeps_its_width_while_the_start_turns_in_where_the_gap_changes() {
        Prefs.motion = "on";
        makeStart(1200, 1920, {});
        const pinned = named("pinned");
        const widths = [pinned.width];
        pinned.widthChanged.connect(() => widths.push(pinned.width));
        start.open();
        tryVerify(() => start.phase === "open", 3000);
        compare(widths, [unit(4)]);
        compare(named("panorama").gap, 18);
    }

    function test_the_strip_follows_the_panorama_as_it_scrolls() {
        openAt(1000, 900);
        const panorama = named("panorama");
        compare(named("sectionStrip").currentIndex, 0);
        panorama.userScroll();
        panorama.scroller.contentX = panorama.mostScroll();
        compare(named("sectionStrip").currentIndex, 2);
        panorama.scroller.contentX = 0;
        compare(named("sectionStrip").currentIndex, 0);
    }

    function test_the_headings_and_spaces_are_the_starts_not_rektas() {
        openNow();
        const section = named("running");
        const heading = findChild(section, "heading");
        compare(section.verticalInset, Tokens.spaceXl);
        compare(section.headingSpacing, Tokens.spaceL);
        compare(heading.font.pixelSize, Math.floor(Tokens.fluid(Tokens.fontSizeXl, start.width)));
    }

    // Every open starts at the first section

    function test_every_open_starts_at_the_first_section_at_once() {
        openAt(1000, 900);
        const panorama = named("panorama");
        named("sectionStrip").select(1);
        tryCompare(panorama.scroller, "contentX", named("pinned").x - Tokens.spaceXl);
        Prefs.motion = "off";
        start.close(null);
        tryVerify(() => !start.shown);
        start.open();
        Prefs.motion = "system";
        compare(panorama.scroller.contentX, 0);
        compare(panorama.currentIndex, 0);
        compare(named("sectionStrip").currentIndex, 0);
    }

    // When "läuft" comes or goes, the strip marks the section the view shows

    function marked(): Item {
        const panorama = named("panorama");
        compare(named("sectionStrip").currentIndex, panorama.currentIndex, "the strip and the panorama agree");
        return panorama.sectionItems()[panorama.currentIndex];
    }

    function test_windows_that_come_to_a_start_standing_without_them_mark_running_where_the_view_begins_data() {
        return [
            {
                tag: "1920 x 1080, where everything fits",
                width: 1920,
                height: 1080
            },
            {
                tag: "1080 x 1920, where the panorama scrolls",
                width: 1080,
                height: 1920
            }
        ];
    }

    function test_windows_that_come_to_a_start_standing_without_them_mark_running_where_the_view_begins(data) {
        openAt(data.width, data.height, {
            windows: []
        });
        compare(marked(), named("pinned"));
        start.windows = windowsOpen();
        compare(named("sectionStrip").titles, ["läuft", "angeheftet", "heute"]);
        compare(named("panorama").scroller.contentX, 0, "the view stays at the start, where running now stands");
        compare(marked(), named("running"));
    }

    function test_running_that_goes_while_pinned_is_read_leaves_pinned_marked_where_the_view_now_begins() {
        openAt(1300, 900);
        const panorama = named("panorama");
        panorama.userScroll();
        panorama.scroller.contentX = named("pinned").x - Tokens.spaceXl;
        compare(marked(), named("pinned"));
        start.windows = [];
        compare(panorama.scroller.contentX, 0);
        compare(marked(), named("pinned"));
    }

    function test_running_that_goes_while_it_is_read_hands_the_mark_to_pinned_and_takes_it_back_when_it_comes_again() {
        openAt(1000, 900);
        compare(marked(), named("running"));
        start.windows = [];
        compare(marked(), named("pinned"));
        start.windows = windowsOpen();
        compare(marked(), named("running"));
    }

    function test_running_that_goes_during_a_jump_to_pinned_ends_the_glide_with_the_view_and_the_mark_on_pinned() {
        openAt(1300, 900);
        Prefs.motion = "on";
        const panorama = named("panorama");
        named("sectionStrip").select(1);
        verify(panorama.gliding);
        start.windows = [];
        tryVerify(() => !panorama.gliding, 2 * Tokens.durationPivotGlide);
        compare(panorama.scroller.contentX, 0, "nothing scrolls past the start of a panorama that now fits");
        compare(marked(), named("pinned"));
    }

    // The wheel

    function test_a_wheel_scrolls_inside_a_section_with_room_first_and_then_sideways() {
        openAt(1000, 700, {
            pinned: appsPinned(40)
        });
        const panorama = named("panorama");
        const pinned = named("pinned");
        const over = wheelEvent(120, {
            x: pinned.x + 100
        });
        verify(panorama.handleWheel(over, 0));
        compare(pinned.contentY, 120, "inside first");
        compare(panorama.scroller.contentX, 0);
        const aside = wheelEvent(120, {
            x: 100
        });
        verify(panorama.handleWheel(aside, 1000), "a section with no room: the panorama");
        compare(panorama.scroller.contentX, 120);
        compare(pastEndSpy.count, 0);
    }

    function test_a_wheel_gesture_that_finds_the_panorama_at_its_end_goes_to_alle_apps_once() {
        openNow();
        const panorama = named("panorama");
        verify(!panorama.handleWheel(wheelEvent(120), 0), "it falls through");
        compare(pastEndSpy.count, 1);
        compare(pastEndSpy.signalArguments[0][0], true);
        compare(named("pivot").currentIndex, 1);
        panorama.handleWheel(wheelEvent(120), 100);
        panorama.handleWheel(wheelEvent(120), 200);
        compare(pastEndSpy.count, 1, "the rest of the gesture is the same gesture");
        panorama.handleWheel(wheelEvent(120), 200 + Tokens.durationWheelLatch + 1);
        compare(pastEndSpy.count, 2, "the next gesture is a new one");
    }

    function test_a_wheel_gesture_at_the_start_goes_nowhere() {
        openNow();
        named("panorama").handleWheel(wheelEvent(-120), 0);
        compare(pastEndSpy.count, 1);
        compare(pastEndSpy.signalArguments[0][0], false);
        compare(named("pivot").currentIndex, 0);
        verify(start.wanted);
    }

    function test_a_gesture_that_reaches_the_end_while_it_goes_on_does_not_change_the_place() {
        openAt(1000, 900);
        const panorama = named("panorama");
        const most = panorama.mostScroll();
        let now = 0;
        for (let moved = 0; moved < most + 400; moved += 100) {
            panorama.handleWheel(wheelEvent(100), now);
            now += 20;
        }
        compare(panorama.scroller.contentX, most);
        compare(pastEndSpy.count, 0);
        compare(named("pivot").currentIndex, 0);
        panorama.handleWheel(wheelEvent(100), now + Tokens.durationWheelLatch + 1);
        compare(pastEndSpy.count, 1, "only a gesture that begins at the end goes on");
        compare(named("pivot").currentIndex, 1);
    }

    function test_shift_wheel_moves_the_panorama_and_at_its_end_goes_on_to_alle_apps() {
        openAt(1000, 900);
        const panorama = named("panorama");
        const shifted = {
            modifiers: Qt.ShiftModifier
        };
        verify(panorama.handleWheel(wheelEvent(120, shifted), 0));
        compare(panorama.scroller.contentX, 120);
        compare(pastEndSpy.count, 0);
        panorama.scroller.contentX = panorama.mostScroll();
        panorama.handleWheel(wheelEvent(120, shifted), 5000);
        compare(pastEndSpy.count, 1);
        compare(named("pivot").currentIndex, 1);
    }

    function test_a_sideways_wheel_through_the_window_moves_the_panorama() {
        openAt(1000, 900);
        const panorama = named("panorama");
        mouseWheel(panorama, 300, 300, -120, 0);
        tryVerify(() => panorama.scroller.contentX > 0);
        compare(named("pivot").currentIndex, 0);
    }

    function test_a_sideways_wheel_over_the_place_pivot_goes_to_alle_apps() {
        openAt(1000, 900);
        mouseWheel(named("pivot"), 300, 10, -120, 0);
        compare(named("pivot").currentIndex, 1);
    }

    function test_a_sideways_wheel_over_the_strip_goes_to_alle_apps() {
        openAt(1000, 900);
        mouseWheel(named("sectionStrip"), 300, 10, -120, 0);
        compare(named("pivot").currentIndex, 1);
    }

    function test_a_sideways_wheel_gesture_that_reaches_the_end_of_the_panorama_on_its_way_changes_no_place() {
        openAt(1000, 900);
        const panorama = named("panorama");
        panorama.scroller.contentX = panorama.mostScroll() - 50;
        mouseWheel(panorama, 300, 300, -120, 0);
        panorama.scroller.cancelFlick();
        panorama.scroller.contentX = panorama.mostScroll();
        mouseWheel(panorama, 300, 300, -120, 0);
        compare(named("pivot").currentIndex, 0);
        compare(pastEndSpy.count, 0);
    }

    function test_a_sideways_wheel_over_the_stacked_panorama_of_a_compact_start_goes_to_alle_apps() {
        openAt(700, 900);
        verify(!named("panorama").sideways);
        mouseWheel(named("panorama"), 100, 100, -120, 0);
        compare(named("pivot").currentIndex, 1);
    }

    function test_a_wheel_past_the_end_as_the_search_comes_in_changes_no_place() {
        Prefs.motion = "on";
        openNow();
        keyClick(Qt.Key_K);
        verify(start.searching);
        mouseWheel(named("panorama"), 300, 300, 0, -120);
        mouseWheel(named("panorama"), 300, 300, -120, 0);
        compare(named("pivot").currentIndex, 0);
    }

    function test_a_click_on_alle_apps_as_the_search_comes_in_changes_no_place() {
        Prefs.motion = "on";
        openNow();
        keyClick(Qt.Key_K);
        verify(start.searching);
        mouseClick(findChild(named("pivot"), "title-1"));
        compare(named("pivot").currentIndex, 0);
        keyClick(Qt.Key_Backspace);
        tryVerify(() => !start.searching);
        compare(named("pivot").currentIndex, 0, "the Start stands in start again");
    }

    function test_the_arrow_keys_on_the_pivot_as_the_search_comes_in_change_no_place() {
        Prefs.motion = "on";
        openNow();
        keyClick(Qt.Key_K);
        verify(start.searching);
        named("pivot").forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(named("pivot").currentIndex, 0);
    }

    function test_a_click_on_alle_apps_while_the_start_closes_changes_no_place() {
        Prefs.motion = "on";
        openNow();
        start.close(null);
        verify(start.turning);
        mouseClick(findChild(named("pivot"), "title-1"));
        compare(named("pivot").currentIndex, 0);
    }

    function test_the_arrow_keys_on_the_pivot_while_the_start_closes_change_no_place() {
        Prefs.motion = "on";
        openNow();
        named("pivot").forceActiveFocus();
        start.close(null);
        verify(start.turning);
        keyClick(Qt.Key_Right);
        compare(named("pivot").currentIndex, 0);
    }

    // A Start closing at the end of its panorama.
    function closeAtTheEnd(): var {
        openAt(1000, 900);
        const panorama = named("panorama");
        panorama.scroller.contentX = panorama.mostScroll();
        start.close(null);
        verify(start.turning);
        return panorama;
    }

    function test_a_wheel_past_the_end_while_the_start_closes_changes_no_place() {
        Prefs.motion = "on";
        mouseWheel(closeAtTheEnd(), 300, 300, -120, 0);
        compare(named("pivot").currentIndex, 0);
        verify(start.turning, "the close turns on");
    }

    function test_a_swipe_past_the_end_while_the_start_closes_changes_no_place() {
        Prefs.motion = "on";
        mouseDrag(closeAtTheEnd(), 800, 600, -200, 0);
        compare(named("pivot").currentIndex, 0);
        verify(start.turning, "the close turns on");
    }

    // The swipe

    function test_a_swipe_moves_the_panorama_and_past_its_end_goes_to_alle_apps() {
        openAt(1000, 900);
        const panorama = named("panorama");
        mouseDrag(panorama, 800, 600, -200, 0);
        tryVerify(() => panorama.scroller.contentX > 0);
        tryVerify(() => !panorama.scroller.moving);
        compare(named("pivot").currentIndex, 0, "inside it, a swipe only scrolls");
        panorama.scroller.contentX = panorama.mostScroll();
        mouseDrag(panorama, 800, 600, -200, 0);
        compare(named("pivot").currentIndex, 1);
        compare(pastEndSpy.count, 1);
    }

    function test_a_swipe_that_starts_inside_and_ends_past_the_end_stays_in_the_start_place() {
        openAt(1000, 900);
        const panorama = named("panorama");
        panorama.scroller.contentX = panorama.mostScroll() - 50;
        mouseDrag(panorama, 800, 600, -300, 0);
        compare(named("pivot").currentIndex, 0);
        compare(pastEndSpy.count, 0);
    }

    function test_a_swipe_over_a_panorama_that_fits_goes_to_alle_apps_and_presses_nothing() {
        openNow();
        mouseDrag(tilesIn("pinned")[0], 60, 60, -200, 0);
        compare(named("pivot").currentIndex, 1);
    }

    function test_a_swipe_over_the_strip_changes_the_place() {
        openAt(1000, 900);
        mouseDrag(named("sectionStrip"), 300, 10, -200, 0);
        compare(named("pivot").currentIndex, 1);
    }

    // The keys

    function test_tab_runs_pivot_strip_panorama_then_the_tiles_in_reading_order() {
        openNow();
        named("pivot").forceActiveFocus();
        keyClick(Qt.Key_Tab);
        verify(named("sectionStrip").activeFocus, "the strip");
        keyClick(Qt.Key_Tab);
        verify(named("panorama").activeFocus, "the panorama");
        keyClick(Qt.Key_Tab);
        verify(tilesIn("running")[0].activeFocus, "the first tile");
        keyClick(Qt.Key_Tab);
        verify(tilesIn("running")[1].activeFocus);
        keyClick(Qt.Key_Tab);
        verify(tilesIn("pinned")[0].activeFocus, "on into the next section");
    }

    function test_the_strip_chooses_with_arrows_home_and_end_and_enter_puts_the_focus_on_the_heading() {
        openAt(1000, 900);
        const strip = named("sectionStrip");
        strip.forceActiveFocus();
        keyClick(Qt.Key_Right);
        tryCompare(named("panorama").scroller, "contentX", named("pinned").x - Tokens.spaceXl);
        compare(strip.currentIndex, 1);
        keyClick(Qt.Key_Home);
        tryCompare(named("panorama").scroller, "contentX", 0);
        compare(strip.currentIndex, 0);
        keyClick(Qt.Key_End);
        tryCompare(named("panorama"), "gliding", false);
        compare(strip.currentIndex, 2);
        keyClick(Qt.Key_Return);
        verify(named("today").headingFocused);
    }

    function test_the_panorama_takes_arrows_page_keys_home_and_end_and_the_last_section_has_no_place_beyond() {
        openAt(1000, 900);
        const panorama = named("panorama");
        panorama.forceActiveFocus();
        keyClick(Qt.Key_Right);
        tryCompare(panorama, "gliding", false);
        compare(panorama.currentIndex, 1);
        keyClick(Qt.Key_Right);
        tryCompare(panorama, "gliding", false);
        compare(panorama.currentIndex, 2);
        keyClick(Qt.Key_Right);
        tryCompare(panorama, "gliding", false);
        compare(panorama.currentIndex, 2, "no section beyond the last");
        compare(named("pivot").currentIndex, 0, "and no place either");
        keyClick(Qt.Key_PageUp);
        tryCompare(panorama, "gliding", false);
        compare(panorama.currentIndex, 1);
        keyClick(Qt.Key_PageDown);
        tryCompare(panorama, "gliding", false);
        compare(panorama.currentIndex, 2);
        keyClick(Qt.Key_Home);
        tryCompare(panorama, "gliding", false);
        compare(panorama.currentIndex, 0);
        keyClick(Qt.Key_End);
        tryCompare(panorama, "gliding", false);
        compare(panorama.currentIndex, 2);
    }

    function test_arrows_go_from_the_pivot_to_the_strip_and_on_to_the_first_tile_of_the_section_read_and_back() {
        openNow();
        named("pivot").forceActiveFocus();
        keyClick(Qt.Key_Down);
        verify(named("sectionStrip").activeFocus);
        keyClick(Qt.Key_Down);
        verify(tilesIn("running")[0].activeFocus);
        keyClick(Qt.Key_Up);
        verify(named("sectionStrip").activeFocus, "up from the top row");
        keyClick(Qt.Key_Up);
        verify(named("pivot").activeFocus);
        named("sectionStrip").forceActiveFocus();
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Down);
        verify(tilesIn("pinned")[0].activeFocus, "the first tile of the section chosen");
    }

    function test_down_with_nothing_in_focus_goes_to_the_first_tile() {
        openNow();
        keyClick(Qt.Key_Down);
        verify(tilesIn("running")[0].activeFocus);
    }

    function test_an_arrow_to_a_tile_beyond_the_edge_brings_it_into_view_with_space_xl_clear() {
        openAt(1000, 900);
        const panorama = named("panorama");
        const far = tilesIn("pinned")[2];
        keyClick(Qt.Key_Down);
        for (let i = 0; i < 3 && !far.activeFocus; i++)
            keyClick(Qt.Key_Right);
        verify(far.activeFocus);
        const left = far.mapToItem(panorama, 0, 0).x;
        verify(panorama.scroller.contentX > 0);
        verify(left >= 0 && left + far.width <= panorama.width - Tokens.spaceXl + 1, `in view at ${left}`);
    }

    function test_the_arrow_past_the_last_tile_goes_to_alle_apps() {
        openNow();
        keyClick(Qt.Key_Down);
        for (let i = 0; i < 4; i++)
            keyClick(Qt.Key_Right);
        compare(named("pivot").currentIndex, 1);
    }

    function test_a_tall_section_rolls_the_tile_into_view_and_the_panorama_stays() {
        openAt(1600, 500, {
            pinned: appsPinned(40)
        });
        const last = tilesIn("pinned")[36];
        named("sectionStrip").forceActiveFocus();
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Down);
        for (let i = 0; i < 9; i++)
            keyClick(Qt.Key_Down);
        verify(last.activeFocus);
        verify(named("pinned").contentY > 0);
        compare(named("panorama").scroller.contentX, 0);
    }

    // Compact

    function windowsCount(count: int): var {
        return Array.from({
            length: count
        }, (_, i) => fakeWindow(`window ${i}`, i));
    }

    // A compact Start that holds more than its height: six windows and fifteen pinned apps at 720 × 1280.
    function openCompactAndTall() {
        testCase.width = 720;
        testCase.height = 1280;
        openAt(720, 1280, {
            windows: windowsCount(6),
            pinned: appsPinned(15)
        });
    }

    function shownInPanorama(item: Item): bool {
        const top = item.mapToItem(named("panorama"), 0, 0).y;
        return top >= 0 && top + item.height <= named("panorama").height + 1;
    }

    function test_compact_at_720_by_1280_the_sections_stack_and_the_strip_stays_on_top_as_the_panorama_scrolls() {
        openCompactAndTall();
        const panorama = named("panorama");
        const strip = named("sectionStrip");
        const running = named("running");
        const pinned = named("pinned");
        verify(!panorama.sideways);
        compare(panorama.inset, Tokens.spaceM);
        verify([running, pinned].every(section => section.x === Tokens.spaceM && section.width === 720 - 2 * Tokens.spaceM), "as wide as the panorama");
        compare(pinned.y, running.y + running.height, "one below the other");
        verify(pinned.separated && !running.separated, "a hairline between them");
        verify(panorama.mostScroll() > 0);
        const stripAt = strip.mapToItem(start, 0, 0);
        panorama.userScroll();
        panorama.scroller.contentY = panorama.mostScroll();
        compare(strip.mapToItem(start, 0, 0), stripAt, "the strip stands where it stood");
        verify(strip.visible && strip.y + strip.height <= panorama.y, "above the panorama");
        compare(strip.currentIndex, 1, "and marks the section scrolled to");
    }

    function test_compact_the_strips_stand_space_m_in_with_a_hairline_under_the_section_strip_and_sideways_neither() {
        openCompactAndTall();
        const line = named("stripLine");
        compare(named("pivot").x, Tokens.spaceM);
        compare(named("sectionStrip").x, Tokens.spaceM);
        verify(line.visible);
        compare(line.y, named("sectionStrip").y + named("sectionStrip").height, "under the strip");
        compare(Qt.rect(line.x, line.y + line.height, line.width, line.height), Qt.rect(0, named("panorama").y, 720, Geometry.hairline), "the sections below it");
        start.width = 1600;
        start.height = 900;
        verify(named("panorama").sideways);
        compare(named("pivot").x, Tokens.spaceXl);
        compare(named("sectionStrip").x, Tokens.spaceXl);
        verify(!line.visible);
    }

    function test_compact_a_vertical_wheel_scrolls_the_stacked_panorama_and_changes_no_place_even_at_its_end() {
        openCompactAndTall();
        const panorama = named("panorama");
        verify(!panorama.handleWheel(wheelEvent(120), 0), "the panorama leaves the wheel alone");
        mouseWheel(panorama, 300, 300, 0, -120);
        tryVerify(() => panorama.scroller.contentY > 0, 1000, "the wheel scrolls it down");
        panorama.scroller.contentY = panorama.mostScroll();
        for (let i = 0; i < 3; i++)
            mouseWheel(panorama, 300, 300, 0, -120);
        compare(named("pivot").currentIndex, 0, "past its end the place stays");
        compare(pastEndSpy.count, 0);
        compare(panorama.scroller.contentX, 0);
    }

    function test_compact_the_grids_fill_their_sections_with_as_many_tile_units_as_fit_stretched_and_wide_tiles_span_two() {
        openCompactAndTall();
        const width = 720 - 2 * Tokens.spaceM;
        const cell = (width - 2 * Tokens.spaceS) / 3;
        const running = tilesIn("running");
        const pinned = tilesIn("pinned");
        compare(findChild(named("pinned"), "grid").across, 3, "three tile units fit in 688 px, four do not");
        compare(pinned[2].x + pinned[2].width, width, "three to a row, stretched to fill it");
        compare(pinned[3].y, Tokens.tileUnit + Tokens.spaceS, "rows a tile unit high");
        compare(running[0].width, 2 * cell + Tokens.spaceS);
        compare(running[1].y, running[0].y + Tokens.tileUnit + Tokens.spaceS, "two units wide, one to a row of three");
    }

    function test_compact_a_narrow_start_still_has_two_columns() {
        openAt(360, 800, {
            pinned: appsPinned(3)
        });
        const width = 360 - 2 * Tokens.spaceM;
        compare(findChild(named("pinned"), "grid").across, 2);
        compare(tilesIn("pinned")[0].width, (width - Tokens.spaceS) / 2, "narrower than a tile unit");
        compare(tilesIn("running")[0].width, width, "a running tile takes the whole row");
    }

    function test_compact_arrows_go_down_through_the_stacked_sections_and_the_focused_tile_rolls_into_view() {
        openCompactAndTall();
        const panorama = named("panorama");
        const running = tilesIn("running");
        const pinned = tilesIn("pinned");
        keyClick(Qt.Key_Down);
        verify(running[0].activeFocus);
        for (let i = 1; i < running.length; i++) {
            keyClick(Qt.Key_Down);
            verify(running[i].activeFocus, `running ${i}`);
            verify(shownInPanorama(running[i]), `running ${i} in view`);
        }
        keyClick(Qt.Key_Down);
        verify(pinned[0].activeFocus, "on into the next section");
        for (let i = 0; i < 4; i++)
            keyClick(Qt.Key_Down);
        verify(pinned[12].activeFocus, "the last row");
        verify(shownInPanorama(pinned[12]));
        compare(named("sectionStrip").currentIndex, 1, "the strip follows");
        for (let i = 0; i < 4; i++)
            keyClick(Qt.Key_Up);
        verify(pinned[0].activeFocus);
        keyClick(Qt.Key_Up);
        verify(running[5].activeFocus, "up into the section above");
        verify(shownInPanorama(running[5]));
        for (let i = 0; i < 5; i++)
            keyClick(Qt.Key_Up);
        verify(running[0].activeFocus);
        verify(shownInPanorama(running[0]), "back at the top");
        compare(named("sectionStrip").currentIndex, 0);
    }

    // The search, Escape and back

    function test_typing_replaces_the_strip_and_the_panorama_with_the_search_and_clearing_brings_them_back() {
        openNow();
        start.searchEscape = "back";
        verify(named("sectionStrip").visible);
        keyClick(Qt.Key_K);
        verify(start.searching);
        tryVerify(() => named("searchTitle").visible);
        verify(!named("sectionStrip").visible);
        verify(!named("panorama").visible);
        verify(!named("startPlace").visible);
        verify(named("results").visible);
        compare(named("searchTitle").x, named("pivot").x);
        compare(named("searchTitle").width, 6 * start.unitStep - Tokens.spaceS, "six units at 1600");
        compare(named("results").width, named("searchTitle").width + 2 * named("results").ringRoom);
        keyClick(Qt.Key_Escape);
        tryVerify(() => !start.searching);
        tryVerify(() => named("sectionStrip").visible);
        verify(named("panorama").visible);
        verify(start.wanted);
    }

    function test_escape_in_a_search_closes_the_start_and_it_opens_on_the_first_section() {
        openAt(1000, 900);
        named("sectionStrip").select(1);
        keyClick(Qt.Key_K);
        verify(start.searching);
        Prefs.motion = "off";
        keyClick(Qt.Key_Escape);
        tryVerify(() => !start.shown);
        start.open();
        Prefs.motion = "system";
        verify(!start.searching);
        compare(named("panorama").currentIndex, 0);
        compare(named("panorama").scroller.contentX, 0);
    }

    function test_back_from_alle_apps_goes_to_start_then_closes() {
        openNow();
        named("pivot").select(1);
        tryVerify(() => !start.turning, 3000);
        keyClick(Qt.Key_Escape);
        compare(named("pivot").currentIndex, 0, "from alle apps back to start");
        tryVerify(() => !start.turning, 3000);
        keyClick(Qt.Key_Escape);
        verify(!start.wanted, "then the Start closes");
    }

    function test_escape_after_jumping_between_sections_closes_the_start() {
        openNow();
        named("sectionStrip").select(1);
        keyClick(Qt.Key_Escape);
        verify(!start.wanted);
    }

    // The turn

    function test_the_titles_of_both_pivots_turn_with_the_start_place() {
        Prefs.motion = "on";
        start.open();
        const turner = findChild(start, "turn");
        tryVerify(() => turner.running, 2000);
        const items = turner.arrivingTurns.map(turn => turn.part.item);
        verify(items.includes(named("pivot")), "the place pivot");
        verify(items.includes(named("sectionStrip")), "the strip");
    }

    function test_a_change_of_place_takes_the_strip_out_and_back_in() {
        Prefs.motion = "on";
        openNow();
        named("pivot").select(1);
        const going = findChild(start, "turn").leavingTurns.map(turn => turn.part.item);
        verify(going.includes(named("sectionStrip")), "the strip leaves with the start place");
        verify(!going.includes(named("pivot")), "the place pivot stays");
        tryVerify(() => !start.turning, 3000);
        named("pivot").select(0);
        tryVerify(() => findChild(start, "turn").arrivingTurns.length > 0, 3000);
        verify(findChild(start, "turn").arrivingTurns.map(turn => turn.part.item).includes(named("sectionStrip")));
    }

    function test_under_reduced_motion_the_start_place_stands_at_once_and_a_place_change_lands_at_once() {
        Prefs.motion = "off";
        start.open();
        compare(start.phase, "open");
        verify(!findChild(start, "turn").running);
        named("pivot").select(1);
        verify(!start.turning);
        verify(!named("startPlace").visible);
        verify(named("apps").visible);
    }

    // Contact sheets

    function test_contact_sheets_of_the_panorama_in_both_themes_at_three_sizes() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        const sizes = [Qt.size(1920, 1080), Qt.size(2560, 1440), Qt.size(1080, 1920)];
        for (const theme of ["light", "dark"]) {
            for (const size of sizes) {
                Prefs.theme = theme;
                // The window takes the surface's size, as the grab shows only what the window holds.
                testCase.width = size.width;
                testCase.height = size.height;
                const backdrop = createTemporaryObject(backdropComponent, testCase, {
                    width: size.width,
                    height: size.height
                });
                const sheet = createTemporaryObject(startComponent, backdrop, {
                    width: size.width,
                    height: size.height,
                    pinned: [fakeApp("systemsettings", 1), fakeApp("dolphin", 2), fakeApp("konsole", 1), fakeApp("kate", 1), fakeApp("okular", 2), fakeApp("gwenview", 1)]
                });
                Prefs.motion = "off";
                sheet.open();
                Prefs.motion = "system";
                waitForRendering(backdrop);
                wait(Tokens.durationShort);
                grabImage(backdrop).save(`start-panorama-${theme}-${size.width}x${size.height}.png`);
                verify(sheet.wanted, `${theme} ${size.width}`);
            }
        }
    }

    function test_contact_sheets_of_the_compact_start_in_both_themes_at_720_by_1280() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            testCase.width = 720;
            testCase.height = 1280;
            const backdrop = createTemporaryObject(backdropComponent, testCase, {
                width: 720,
                height: 1280
            });
            const sheet = createTemporaryObject(startComponent, backdrop, {
                width: 720,
                height: 1280,
                pinned: [fakeApp("systemsettings", 1), fakeApp("dolphin", 2), fakeApp("konsole", 1), fakeApp("kate", 1), fakeApp("okular", 2), fakeApp("gwenview", 1)]
            });
            Prefs.motion = "off";
            sheet.open();
            Prefs.motion = "system";
            waitForRendering(backdrop);
            wait(Tokens.durationShort);
            grabImage(backdrop).save(`start-compact-${theme}.png`);
            verify(!findChild(sheet, "panorama").sideways, theme);
        }
    }
}
