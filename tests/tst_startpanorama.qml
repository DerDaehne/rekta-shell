pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Start

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
        Prefs.motion = "off";
        start.open();
        Prefs.motion = "system";
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
        compare(named("sectionStrip").titles, ["läuft", "angeheftet"]);
        verify(named("running").visible);
        verify(named("pinned").visible);
        const sections = named("panorama").sectionItems();
        compare(sections.length, 2);
        verify(sections[0] === named("running") && sections[1] === named("pinned"), "in a fixed order");
    }

    function test_without_windows_running_is_gone_from_the_panorama_and_the_strip() {
        openAt(1600, 900, {
            windows: []
        });
        verify(!named("running").visible);
        compare(named("sectionStrip").titles, ["angeheftet"]);
        compare(named("panorama").sectionItems(), [named("pinned")]);
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

    function test_the_strip_follows_the_panorama_as_it_scrolls() {
        openAt(1000, 900);
        const panorama = named("panorama");
        compare(named("sectionStrip").currentIndex, 0);
        panorama.userScroll();
        panorama.scroller.contentX = panorama.mostScroll();
        compare(named("sectionStrip").currentIndex, 1);
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

    function test_a_section_read_stays_the_one_read_when_running_comes_and_goes() {
        openAt(1600, 900, {
            windows: []
        });
        compare(named("sectionStrip").currentIndex, 0);
        start.windows = windowsOpen();
        compare(named("sectionStrip").titles, ["läuft", "angeheftet"]);
        compare(named("panorama").currentIndex, 1, "angeheftet is still the one read");
        compare(named("sectionStrip").currentIndex, 1);
        start.windows = [];
        compare(named("panorama").currentIndex, 0);
        compare(named("sectionStrip").currentIndex, 0);
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
        compare(strip.currentIndex, 1);
        tryCompare(named("panorama").scroller, "contentX", named("pinned").x - Tokens.spaceXl);
        keyClick(Qt.Key_Home);
        compare(strip.currentIndex, 0);
        tryCompare(named("panorama").scroller, "contentX", 0);
        keyClick(Qt.Key_End);
        compare(strip.currentIndex, 1);
        keyClick(Qt.Key_Return);
        verify(named("pinned").headingFocused);
    }

    function test_the_panorama_takes_arrows_page_keys_home_and_end_and_the_last_section_has_no_place_beyond() {
        openAt(1000, 900);
        const panorama = named("panorama");
        panorama.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(panorama.currentIndex, 1);
        keyClick(Qt.Key_Right);
        compare(panorama.currentIndex, 1, "no section beyond the last");
        compare(named("pivot").currentIndex, 0, "and no place either");
        keyClick(Qt.Key_PageUp);
        compare(panorama.currentIndex, 0);
        keyClick(Qt.Key_PageDown);
        compare(panorama.currentIndex, 1);
        keyClick(Qt.Key_Home);
        compare(panorama.currentIndex, 0);
        keyClick(Qt.Key_End);
        compare(panorama.currentIndex, 1);
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
        compare(named("searchTitle").width, start.sixUnits);
        compare(named("results").width, start.sixUnits + 2 * named("results").ringRoom);
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
        start.open();
        const turner = findChild(start, "turn");
        tryVerify(() => turner.running, 2000);
        const items = turner.arrivingTurns.map(turn => turn.part.item);
        verify(items.includes(named("pivot")), "the place pivot");
        verify(items.includes(named("sectionStrip")), "the strip");
    }

    function test_a_change_of_place_takes_the_strip_out_and_back_in() {
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
}
