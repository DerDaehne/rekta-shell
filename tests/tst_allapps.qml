pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Start

// "alle apps" as a panorama: a section for each initial under the strip of their names, their widths and rows, a split
// letter, the letter jump, the wheel and swipe at its ends, the keys, a change of height, and compact. The start place is
// tst_startpanorama.qml, the rest of the Start tst_start.qml.
TestCase {
    id: testCase

    name: "AllApps"
    visible: true
    when: windowShown
    width: 1600
    height: 900

    // What the fake apps were asked to do, oldest first.
    property var calls: []

    readonly property string pinkIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAGklEQVR4nGN4aTWLbMQwqnlU86jmUc0DqxkAreu3b+7dCC4AAAAASUVORK5CYII="

    // Sixty-five apps A–Z as a Plasma desktop has them; "k" has twenty-seven, more than six units hold at four rows.
    readonly property var desktopApps: ["Akregator", "Ark", "Audacity", "Blender", "Chromium", "Deja Dup", "digiKam", "Discover", "Dolphin", "Dragon Player", "Elisa", "Emacs", "Falkon", "Filelight", "Firefox", "GIMP", "Gwenview", "Haruna", "Inkscape", "Kaddressbook", "Kalgebra", "Kate", "KCalc", "KCharSelect", "Kdenlive", "KDiskFree", "KFind", "KGeography", "KHelpCenter", "KInfoCenter", "Kleopatra", "KMahjongg", "KMail", "KolourPaint", "Konsole", "Konversation", "KPat", "Krita", "KRuler", "KSnapshot", "KStars", "KSudoku", "KSysGuard", "KTorrent", "KTurtle", "KWrite", "LibreOffice Calc", "LibreOffice Writer", "Okular", "Partition Manager", "qBittorrent", "Spectacle", "Steam", "System Monitor", "System Settings", "Thunderbird", "Umbrello", "VLC", "Wireshark", "Xournal++", "Yakuake", "Zeal", "Zettlr"]

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

    Component {
        id: startComponent

        StartPlace {}
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

    SignalSpy {
        id: closedSpy

        signalName: "closed"
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var start

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        calls = [];
    }

    function cleanup() {
        testCase.width = 1600;
        testCase.height = 900;
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    // A Start of this size (the window too, so that a pointer reaches all of it) open on "alle apps" with these apps, at
    // once.
    function openOnAllApps(names: var, width: real, height: real) {
        testCase.width = width;
        testCase.height = height;
        start = createTemporaryObject(startComponent, testCase, {
            width: width,
            height: height
        });
        start.apps = names.map(name => installedApp(name));
        pastEndSpy.target = named("appsPanorama");
        pastEndSpy.clear();
        closedSpy.target = start;
        closedSpy.clear();
        showAllApps();
    }

    function showAllApps() {
        Prefs.motion = "off";
        start.open();
        named("pivot").select(1);
        Prefs.motion = "system";
        waitForRendering(start);
    }

    function named(name: string): var {
        return findChild(start, name);
    }

    function sections(): var {
        return named("appsPanorama").sectionItems();
    }

    function titled(title: string): var {
        return sections().find(section => section.title === title);
    }

    function tileOf(name: string): var {
        return start.letterTiles().find(tile => tile.name === name);
    }

    function sectionOfApp(name: string): var {
        return sections()[start.sectionOf(start.letterTiles().indexOf(tileOf(name)))];
    }

    function focusedTile(): var {
        return start.letterTiles().find(tile => tile.activeFocus);
    }

    function unit(count: int): real {
        return count * (Tokens.tileUnit + Tokens.spaceS);
    }

    // Whole in sight in the panorama.
    function inView(item: var): bool {
        const panorama = named("appsPanorama");
        const left = item.mapToItem(panorama, 0, 0).x;
        return left >= 0 && left + item.width <= panorama.width;
    }

    // Where a jump to the section leaves the panorama: flush left, or as far as it scrolls.
    function flushLeft(section: var): real {
        const panorama = named("appsPanorama");
        return Math.min(section.x - Tokens.spaceXl, panorama.mostScroll());
    }

    // A wheel event as Qt hands it over: pixel deltas point against the web's.
    function wheelEvent(dy: real): var {
        return {
            x: 300,
            y: 300,
            angleDelta: Qt.point(0, 0),
            pixelDelta: Qt.point(0, -dy),
            modifiers: 0
        };
    }

    // The place

    function test_alle_apps_shows_the_place_pivot_the_strip_and_a_panorama_across_the_whole_width() {
        openOnAllApps(desktopApps, 1920, 1080);
        const strip = named("appsStrip");
        const panorama = named("appsPanorama");
        verify(named("apps").visible && strip.visible && panorama.visible);
        verify(!named("startPlace").visible);
        compare(strip.y, named("pivot").height);
        compare(panorama.y, strip.y + strip.height);
        compare(panorama.width, start.width);
        compare(panorama.height, start.height - panorama.y);
        verify(panorama.sideways);
        compare(sections()[0].x, Tokens.spaceXl);
        compare(strip.x, Tokens.spaceXl);
        verify(!named("appsStripLine").visible, "no hairline under a sideways strip");
    }

    function test_there_is_a_section_for_each_initial_a_to_z_an_accent_under_its_letter_and_digits_and_signs_first_in_hash() {
        const names = ["3D Viewer", "_scratch", "ark", "Ärger", "Audacity", "Blender", "Écran", "elisa", "Zeal"];
        openOnAllApps(names, 1600, 900);
        compare(sections().map(section => section.title), ["#", "a", "b", "e", "z"]);
        compare(sections().map(section => section.tiles().map(tile => tile.name)), [["3D Viewer", "_scratch"], ["ark", "Ärger", "Audacity"], ["Blender"], ["Écran", "elisa"], ["Zeal"]]);
        compare(start.letterTiles().map(tile => findChild(tile, "name").text), names, "every app a tile, in the app model's order");
        verify(start.letterTiles().every(tile => tile.opens && tile.width === Tokens.tileUnit && tile.height === Tokens.tileUnit));
    }

    function test_the_sections_have_the_start_place_s_spaces_and_headings() {
        openOnAllApps(desktopApps, 1600, 900);
        const section = sections()[0];
        compare(section.verticalInset, Tokens.spaceXl);
        compare(section.headingSpacing, Tokens.spaceL);
        compare(findChild(section, "heading").font.pixelSize, Math.floor(Tokens.fluid(Tokens.fontSizeXl, start.width)));
    }

    // Widths and rows

    function test_at_1920_by_1080_a_section_holds_four_rows_and_is_as_many_units_wide_as_its_apps_need_at_most_six() {
        openOnAllApps(desktopApps, 1920, 1080);
        compare(start.letterRows, 4);
        compare(titled("a").width, unit(1), "three apps");
        compare(titled("s").width, unit(1), "four apps");
        compare(titled("d").width, unit(2), "five apps");
        compare(titled("ka–km").width, unit(4), "fourteen apps");
        compare(findChild(titled("ka–km"), "grid").columns, 4, "a column for each unit");
        verify(sections().every(section => section.width <= unit(6)));
    }

    function test_the_tiles_flow_row_by_row_and_the_last_row_is_whole_in_the_section() {
        openOnAllApps(desktopApps, 1920, 1080);
        const section = titled("ka–km");
        const tiles = section.tiles();
        compare(Qt.point(tiles[1].x, tiles[1].y), Qt.point(unit(1), 0));
        compare(Qt.point(tiles[4].x, tiles[4].y), Qt.point(0, unit(1)), "the fifth starts the second row");
        compare(Qt.point(tiles[13].x, tiles[13].y), Qt.point(unit(1), unit(3)));
        verify(tiles[13].mapToItem(section, 0, 0).y + Tokens.tileUnit <= section.height);
        compare(section.contentY, 0);
        verify(section.contentHeight <= section.height + 1, "nothing to scroll inside");
    }

    function test_the_rows_are_as_many_as_fit_under_a_section_s_heading() {
        // At 640 a count without the heading or the space under it would make one row more.
        for (const size of [Qt.size(1920, 1080), Qt.size(2560, 1440), Qt.size(1600, 700), Qt.size(1920, 640)]) {
            openOnAllApps(desktopApps, size.width, size.height);
            const panorama = named("appsPanorama");
            const room = panorama.height - 2 * Tokens.spaceXl - findChild(sections()[0], "heading").height - Tokens.spaceL;
            const rows = start.letterRows;
            verify(rows >= 1);
            verify(unit(rows) - Tokens.spaceS <= room, `${rows} rows fit at ${size.height}`);
            verify(unit(rows + 1) - Tokens.spaceS > room, `one more would not at ${size.height}`);
        }
    }

    // A strip without titles is lower than one with them: at these heights the panorama would hold a row less once the
    // titles came.
    function test_at_any_height_every_app_has_one_tile_and_the_strip_names_exactly_the_sections() {
        for (const height of [1013, 1190]) {
            openOnAllApps(desktopApps, 1920, height);
            compare(start.letterTiles().map(tile => tile.name), desktopApps, `every app once at ${height}`);
            compare(named("appsStrip").titles, sections().map(section => section.title));
            compare(named("appsPanorama").y, named("panorama").y, "where the start place's panorama begins");
        }
    }

    function test_a_letter_with_more_apps_than_six_units_hold_splits_into_parts_named_by_their_first_and_last_app() {
        openOnAllApps(desktopApps, 1920, 1080);
        const titles = named("appsStrip").titles;
        verify(titles.includes("ka–km") && titles.includes("ko–kw"));
        verify(!titles.includes("k"));
        compare(titled("ka–km").tiles().length, 14);
        compare(titled("ko–kw").tiles().length, 13);
    }

    // The strip

    function test_the_strip_shows_the_section_names_and_follows_the_panorama_as_it_scrolls() {
        openOnAllApps(desktopApps, 1920, 1080);
        const strip = named("appsStrip");
        const panorama = named("appsPanorama");
        compare(strip.titles, sections().map(section => section.title));
        compare(strip.currentIndex, 0);
        panorama.userScroll();
        panorama.scroller.contentX = panorama.mostScroll();
        compare(strip.currentIndex, sections().length - 1, "at the end, the last");
        // Rekta's rule (rekta.js:979–980): the last section whose left edge lies within a third of the width.
        const at = flushLeft(titled("l"));
        panorama.scroller.contentX = at;
        compare(strip.currentIndex, sections().filter(section => section.x - at <= panorama.width / 3).length - 1);
        verify(strip.titles[strip.currentIndex] !== "ka–km");
    }

    function test_the_strip_jumps_with_the_arrows_and_enter_puts_the_focus_on_the_heading() {
        openOnAllApps(desktopApps, 1920, 1080);
        const strip = named("appsStrip");
        const panorama = named("appsPanorama");
        strip.forceActiveFocus();
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Right);
        tryCompare(panorama.scroller, "contentX", flushLeft(sections()[2]));
        compare(strip.currentIndex, 2);
        keyClick(Qt.Key_Left);
        tryCompare(panorama.scroller, "contentX", flushLeft(sections()[1]));
        compare(strip.currentIndex, 1);
        keyClick(Qt.Key_Return);
        verify(sections()[1].headingFocused);
    }

    // The letter jump

    function test_a_typed_letter_focuses_the_first_app_it_starts_and_its_section_glides_flush_left() {
        openOnAllApps(desktopApps, 1920, 1080);
        const panorama = named("appsPanorama");
        keyClick("o");
        verify(tileOf("Okular").activeFocus);
        verify(panorama.gliding, "it glides");
        const section = sectionOfApp("Okular");
        compare(named("appsStrip").currentIndex, sections().indexOf(section));
        tryCompare(panorama.scroller, "contentX", flushLeft(section), Tokens.durationPivotGlide + 1000);
        verify(inView(tileOf("Okular")));
        compare(start.query, "", "nothing is searched");
    }

    function test_the_glide_takes_rekta_s_pivot_glide() {
        openOnAllApps(desktopApps, 1920, 1080);
        const panorama = named("appsPanorama");
        keyClick("w");
        const began = Date.now();
        tryVerify(() => !panorama.gliding, Tokens.durationPivotGlide + 1000);
        verify(Date.now() - began >= Tokens.durationPivotGlide - 50, `${Date.now() - began} ms`);
    }

    function test_the_same_letter_again_goes_to_the_next_app_into_the_next_part_and_round_past_the_last() {
        openOnAllApps(desktopApps, 1920, 1080);
        const strip = named("appsStrip");
        for (let i = 0; i < 14; i++)
            keyClick("k");
        verify(tileOf("KMail").activeFocus, "the last of the first part");
        keyClick("k");
        verify(tileOf("KolourPaint").activeFocus, "on into the next part");
        compare(strip.titles[strip.currentIndex], "ko–kw");
        for (let i = 0; i < 12; i++)
            keyClick("K");
        verify(tileOf("KWrite").activeFocus, "a capital counts the same");
        keyClick("k");
        verify(tileOf("Kaddressbook").activeFocus, "round past the last");
        compare(strip.titles[strip.currentIndex], "ka–km");
    }

    function test_a_letter_that_starts_no_app_does_nothing() {
        openOnAllApps(desktopApps, 1920, 1080);
        const panorama = named("appsPanorama");
        keyClick("o");
        tryVerify(() => !panorama.gliding, Tokens.durationPivotGlide + 1000);
        const at = panorama.scroller.contentX;
        keyClick("j");
        verify(tileOf("Okular").activeFocus);
        verify(!panorama.gliding);
        compare(panorama.scroller.contentX, at);
        compare(start.query, "");
        verify(named("apps").visible);
        verify(!named("results").visible);
    }

    function test_a_letter_typed_while_the_start_turns_to_alle_apps_ends_the_turn_and_jumps() {
        openOnAllApps(desktopApps, 1600, 900);
        named("pivot").select(0);
        tryVerify(() => !start.turning, 3000);
        keyClick(Qt.Key_Right);
        verify(start.turning);
        keyClick("z");
        verify(!start.turning);
        verify(named("apps").visible);
        verify(tileOf("Zeal").activeFocus);
        compare(start.query, "");
    }

    function test_in_the_start_place_typing_still_searches() {
        openOnAllApps(desktopApps, 1600, 900);
        Prefs.motion = "off";
        keyClick(Qt.Key_Left);
        compare(named("pivot").currentIndex, 0);
        keyClick("o");
        compare(start.query, "o");
        verify(named("results").visible);
    }

    // The wheel and the swipe (layout.md:52–81)

    function test_a_vertical_wheel_moves_the_panorama_sideways_and_a_gesture_back_past_its_start_goes_to_start_once() {
        openOnAllApps(desktopApps, 1920, 1080);
        const panorama = named("appsPanorama");
        verify(panorama.handleWheel(wheelEvent(120), 0));
        compare(panorama.scroller.contentX, 120, "down along it");
        compare(pastEndSpy.count, 0);
        panorama.scroller.contentX = 0;
        verify(!panorama.handleWheel(wheelEvent(-120), 1000), "at its start the gesture falls through");
        compare(pastEndSpy.count, 1);
        compare(pastEndSpy.signalArguments[0][0], false);
        compare(named("pivot").currentIndex, 0);
        panorama.handleWheel(wheelEvent(-120), 1100);
        panorama.handleWheel(wheelEvent(-120), 1200);
        compare(pastEndSpy.count, 1, "the rest of the gesture is the same gesture");
    }

    function test_a_wheel_gesture_at_the_end_does_nothing_as_alle_apps_is_the_last_place() {
        openOnAllApps(desktopApps, 1920, 1080);
        const panorama = named("appsPanorama");
        panorama.scroller.contentX = panorama.mostScroll();
        verify(!panorama.handleWheel(wheelEvent(120), 0));
        compare(pastEndSpy.count, 1);
        compare(pastEndSpy.signalArguments[0][0], true);
        compare(named("pivot").currentIndex, 1);
        verify(start.wanted);
    }

    function test_a_gesture_that_reaches_the_start_on_its_way_does_not_change_the_place() {
        openOnAllApps(desktopApps, 1920, 1080);
        const panorama = named("appsPanorama");
        panorama.scroller.contentX = 300;
        let now = 0;
        for (let moved = 0; moved < 700; moved += 100) {
            panorama.handleWheel(wheelEvent(-100), now);
            now += 20;
        }
        compare(panorama.scroller.contentX, 0);
        compare(pastEndSpy.count, 0);
        compare(named("pivot").currentIndex, 1);
        panorama.handleWheel(wheelEvent(-100), now + Tokens.durationWheelLatch + 1);
        compare(named("pivot").currentIndex, 0, "the next gesture begins at the start");
    }

    function test_a_sideways_wheel_through_the_window_moves_the_panorama_and_over_the_strip_goes_back_to_start() {
        openOnAllApps(desktopApps, 1600, 900);
        const panorama = named("appsPanorama");
        mouseWheel(panorama, 300, 300, -120, 0);
        tryVerify(() => panorama.scroller.contentX > 0);
        compare(named("pivot").currentIndex, 1);
        wait(Tokens.durationWheelLatch + 50);
        mouseWheel(named("appsStrip"), 300, 10, 120, 0);
        compare(named("pivot").currentIndex, 0);
    }

    function test_a_swipe_moves_the_panorama_and_one_from_its_start_back_past_it_goes_to_start() {
        openOnAllApps(desktopApps, 1600, 900);
        const panorama = named("appsPanorama");
        mouseDrag(panorama, 800, 400, -400, 0);
        tryVerify(() => !panorama.scroller.moving, 3000);
        verify(panorama.scroller.contentX > 0, `scrolled to ${panorama.scroller.contentX}`);
        compare(named("pivot").currentIndex, 1);
        panorama.scroller.contentX = 100;
        mouseDrag(panorama, 300, 400, 400, 0);
        tryVerify(() => !panorama.scroller.moving, 3000);
        compare(panorama.scroller.contentX, 0);
        compare(named("pivot").currentIndex, 1, "a swipe that reaches the start stays");
        mouseDrag(panorama, 300, 400, 400, 0);
        compare(named("pivot").currentIndex, 0);
        compare(calls, [], "no tile pressed");
    }

    function test_a_swipe_over_a_panorama_that_fits_goes_back_to_start_and_presses_nothing() {
        openOnAllApps(["ark", "Blender", "konsole"], 1600, 900);
        verify(named("appsPanorama").fit);
        mouseDrag(start.letterTiles()[0], 60, 60, 200, 0);
        compare(named("pivot").currentIndex, 0);
        compare(calls, []);
    }

    // The keys

    function test_tab_runs_pivot_strip_panorama_then_the_tiles_in_reading_order() {
        openOnAllApps(desktopApps, 1600, 900);
        named("pivot").forceActiveFocus();
        keyClick(Qt.Key_Tab);
        verify(named("appsStrip").activeFocus, "the strip");
        keyClick(Qt.Key_Tab);
        verify(named("appsPanorama").activeFocus, "the panorama");
        keyClick(Qt.Key_Tab);
        verify(tileOf("Akregator").activeFocus, "the first app");
        keyClick(Qt.Key_Tab);
        verify(tileOf("Ark").activeFocus);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Tab);
        verify(tileOf("Blender").activeFocus, "on into the next section");
    }

    function test_arrows_move_across_the_sections_and_the_panorama_brings_the_tile_into_view() {
        openOnAllApps(desktopApps, 1600, 900);
        const panorama = named("appsPanorama");
        keyClick(Qt.Key_Down);
        verify(tileOf("Akregator").activeFocus, "down with nothing in focus");
        keyClick(Qt.Key_Down);
        verify(tileOf("Ark").activeFocus, "down its section's column");
        keyClick(Qt.Key_Right);
        const beside = focusedTile();
        verify(start.sectionOf(start.letterTiles().indexOf(beside)) > 0, "into a section further along");
        compare(beside.mapToItem(start, 0, 0).y, tileOf("Ark").mapToItem(start, 0, 0).y, "in the same row");
        for (let i = 0; i < 30 && panorama.scroller.contentX === 0; i++)
            keyClick(Qt.Key_Right);
        verify(panorama.scroller.contentX > 0);
        const focused = focusedTile();
        verify(start.letterTiles().indexOf(focused) > 2, "past the first section");
        const left = focused.mapToItem(panorama, 0, 0).x;
        verify(left >= 0 && left + focused.width <= panorama.width - Tokens.spaceXl + 1, `in view at ${left}`);
    }

    function test_left_before_the_first_tile_or_with_nothing_in_focus_goes_to_start() {
        openOnAllApps(desktopApps, 1600, 900);
        keyClick(Qt.Key_Left);
        compare(named("pivot").currentIndex, 0, "with nothing in focus");
        tryVerify(() => !start.turning, 3000);
        keyClick(Qt.Key_Right);
        compare(named("pivot").currentIndex, 1);
        tryVerify(() => !start.turning, 3000);
        verify(start.letterTiles().every(tile => !tile.activeFocus), "back on alle apps, no app waits in the ring");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Left);
        compare(named("pivot").currentIndex, 0, "before the first tile");
    }

    function test_up_goes_to_the_strip_and_the_place_pivot_and_down_back_to_the_first_tile_of_the_section_read() {
        openOnAllApps(desktopApps, 1600, 900);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Up);
        verify(named("appsStrip").activeFocus, "up from the top row");
        keyClick(Qt.Key_Up);
        verify(named("pivot").activeFocus);
        keyClick(Qt.Key_Down);
        verify(named("appsStrip").activeFocus);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Down);
        verify(tileOf("Blender").activeFocus, "the first tile of the section chosen");
    }

    function test_home_and_end_on_a_tile_go_to_the_first_and_the_last_app_and_bring_it_into_view() {
        openOnAllApps(desktopApps, 1600, 900);
        const panorama = named("appsPanorama");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_End);
        verify(tileOf("Zettlr").activeFocus);
        verify(inView(tileOf("Zettlr")));
        keyClick(Qt.Key_Home);
        verify(tileOf("Akregator").activeFocus);
        compare(panorama.scroller.contentX, 0);
    }

    function test_home_and_end_on_the_focused_panorama_go_to_the_first_and_the_last_section() {
        openOnAllApps(desktopApps, 1600, 900);
        const panorama = named("appsPanorama");
        panorama.forceActiveFocus();
        // A key's jump is followed as it glides, so the section is read once it lands (Rekta 0.5.0's rule, kept by the
        // panorama).
        keyClick(Qt.Key_End);
        tryCompare(panorama, "gliding", false);
        compare(panorama.scroller.contentX, panorama.mostScroll());
        compare(panorama.currentIndex, sections().length - 1);
        verify(panorama.activeFocus, "no app takes the focus");
        keyClick(Qt.Key_Home);
        tryCompare(panorama, "gliding", false);
        compare(panorama.scroller.contentX, 0, "the first section flush left");
        // The strip marks what Rekta 0.5.0's follow rule says there, kept by the panorama.
        compare(panorama.currentIndex, sections().filter(section => section.x <= panorama.width / 3).length - 1);
    }

    function test_down_from_a_focused_heading_goes_to_the_first_tile_of_its_section_and_up_to_the_strip() {
        openOnAllApps(desktopApps, 1920, 1080);
        const strip = named("appsStrip");
        strip.forceActiveFocus();
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Return);
        verify(sections()[2].headingFocused);
        keyClick(Qt.Key_Down);
        verify(sections()[2].tiles()[0].activeFocus, focusedTile()?.name);
        sections()[2].focusHeading();
        keyClick(Qt.Key_Up);
        verify(strip.activeFocus);
    }

    function test_enter_or_space_on_an_app_launches_it_once() {
        openOnAllApps(desktopApps, 1600, 900);
        keyClick("b");
        keyClick(Qt.Key_Return);
        compare(calls, ["launch Blender"]);
        verify(!start.wanted);
        keyClick(Qt.Key_Return);
        compare(calls, ["launch Blender"], "once");
        tryVerify(() => closedSpy.count === 1, 3000);
        showAllApps();
        keyClick("c");
        keyClick(Qt.Key_Space);
        compare(calls, ["launch Blender", "launch Chromium"]);
    }

    function test_the_start_opens_again_on_the_first_section_of_alle_apps() {
        openOnAllApps(desktopApps, 1920, 1080);
        const panorama = named("appsPanorama");
        keyClick("w");
        tryVerify(() => !panorama.gliding, Tokens.durationPivotGlide + 1000);
        start.close(null);
        tryVerify(() => closedSpy.count === 1, 3000);
        showAllApps();
        compare(panorama.scroller.contentX, 0);
        compare(panorama.currentIndex, 0);
        compare(named("appsStrip").currentIndex, 0);
    }

    // A change of height

    function test_a_change_of_height_regroups_the_sections_and_the_app_in_focus_stays_in_view_and_in_focus() {
        openOnAllApps(desktopApps, 1920, 1080);
        const panorama = named("appsPanorama");
        compare(titled("ka–km").width, unit(4));
        keyClick("w");
        tryVerify(() => !panorama.gliding, Tokens.durationPivotGlide + 1000);
        start.height = 800;
        verify(start.letterRows < 4);
        verify(titled("ka–km") === undefined || titled("ka–km").width > unit(4), "fewer rows, wider or more parts");
        verify(tileOf("Wireshark").activeFocus);
        verify(inView(tileOf("Wireshark")));
    }

    function test_without_focus_the_app_in_front_stays_in_view_when_the_height_changes() {
        openOnAllApps(desktopApps, 1920, 1080);
        const panorama = named("appsPanorama");
        const strip = named("appsStrip");
        strip.select(strip.titles.indexOf("ko–kw"));
        tryVerify(() => !panorama.gliding, Tokens.durationPivotGlide + 1000);
        start.height = 800;
        const section = sectionOfApp("KolourPaint");
        compare(panorama.currentIndex, sections().indexOf(section));
        compare(panorama.scroller.contentX, flushLeft(section));
        verify(inView(tileOf("KolourPaint")));
        verify(start.letterTiles().every(tile => !tile.activeFocus));
    }

    // Compact

    function test_compact_each_letter_is_one_section_unsplit_stacked_its_tiles_stretched_and_the_wheel_is_not_redirected() {
        openOnAllApps(desktopApps, 720, 1280);
        const panorama = named("appsPanorama");
        verify(!panorama.sideways);
        const k = titled("k");
        verify(k !== undefined, "one section for k");
        compare(k.tiles().length, 27);
        verify(!named("appsStrip").titles.includes("ka–km"));
        const all = sections();
        verify(all.every(section => section.x === panorama.inset && section.width === panorama.width - 2 * panorama.inset), "stacked, as wide as the panorama");
        verify(all[1].y >= all[0].y + all[0].height);
        const across = Math.max(2, Math.floor((k.width + Tokens.spaceS) / unit(1)));
        compare(findChild(k, "grid").across, across);
        compare(k.tiles()[across - 1].x + k.tiles()[across - 1].width, k.width, "stretched to fill the row");
        compare(named("appsStrip").x, Tokens.spaceM, "the strip as far in as the sections");
        verify(named("appsStripLine").visible, "a hairline under it");
        compare(named("appsStripLine").y, named("appsStrip").y + named("appsStrip").height);
        compare(panorama.y, named("appsStripLine").y + Geometry.hairline, "the sections below the hairline");
        verify(!panorama.handleWheel(wheelEvent(120), 0), "the wheel is left alone");
        compare(pastEndSpy.count, 0);
        compare(panorama.scroller.contentX, 0);
    }

    function test_compact_a_typed_letter_marks_its_section_and_brings_its_app_into_view_even_far_down_the_section() {
        openOnAllApps(desktopApps, 720, 1280);
        const panorama = named("appsPanorama");
        const strip = named("appsStrip");
        const shown = item => {
            const top = item.mapToItem(panorama, 0, 0).y;
            return top >= 0 && top + item.height <= panorama.height + 1;
        };
        keyClick("k");
        verify(!panorama.gliding, "stacked, the jump goes at once");
        verify(tileOf("Kaddressbook").activeFocus);
        compare(strip.titles[strip.currentIndex], "k");
        verify(shown(tileOf("Kaddressbook")));
        for (let i = 1; i < 27; i++)
            keyClick("k");
        verify(tileOf("KWrite").activeFocus);
        verify(shown(tileOf("KWrite")), "the last of twenty-seven");
        keyClick("z");
        verify(tileOf("Zeal").activeFocus);
        verify(shown(tileOf("Zeal")));
        compare(strip.titles[strip.currentIndex], "z");
    }

    // Contact sheets

    function test_contact_sheets_of_alle_apps_in_both_themes_at_four_sizes() {
        const sizes = [Qt.size(1920, 1080), Qt.size(2560, 1440), Qt.size(1080, 1920), Qt.size(720, 1280)];
        for (const theme of ["light", "dark"]) {
            for (const size of sizes) {
                Prefs.theme = theme;
                testCase.width = size.width;
                testCase.height = size.height;
                const backdrop = createTemporaryObject(backdropComponent, testCase, {
                    width: size.width,
                    height: size.height
                });
                const sheet = createTemporaryObject(startComponent, backdrop, {
                    width: size.width,
                    height: size.height
                });
                sheet.apps = desktopApps.map(name => installedApp(name));
                Prefs.motion = "off";
                sheet.open();
                findChild(sheet, "pivot").select(1);
                waitForRendering(backdrop);
                keyClick("k");
                Prefs.motion = "system";
                waitForRendering(backdrop);
                wait(Tokens.durationShort);
                grabImage(backdrop).save(`start-allapps-panorama-${theme}-${size.width}x${size.height}.png`);
                verify(sheet.letterTiles().some(tile => tile.activeFocus), `${theme} ${size.width}`);
            }
        }
    }
}
