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
    // 128 × 128, larger than a launch tile's largest icon, as an icon theme offers it.
    readonly property string largeIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAACWElEQVR42u3dUU7DQAwEUJ+ME3JQbgG/VCBoaRJsz6vk/92Z1wjRZFNvL6910LybS+eQ3pQejkHx4RAUHw5B8eEQlB+OQPnhCJQfjkD54QiUH44AAACUn4wAAACUn4wAAACUn4wAAAAASAcgiOABAAAhAGAAMACsnkc/AASVnYyilJ6NoRSfDaGUno2hlJ+NoBSfDaEUnw2hlJ+NoJSfjaCUn42glJ+NoJSfjaBSyp++ntUAJgS8FUFtK996BwGYHOQWBDW9/C1XMAAG/yEFQHD50/c0EsDWf19HANj+69q0/ZVwsvc5BkDSnUsALLnxEoDg8qfsGwAAhJC8fwAA6BmA5xWXAEj/9nfPoXz7s68CAAAAAAAAAKD8TAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgR+DAAAAAAAAAMBNoW4KdRVwW7irgAdDAAAAAg+HAgAABA6IcESMI2IcEuWQKAgcEwfBxH05KjZ8Tw6LDt+L4+LD9+GFEYFrbwPg6CCvCHPaetsDOCPUM4KdsMaxAM4K+Jmwu61nPYArQu/y6ZS5V8cGl98SwGYEHbP2+vjg8lsD2ISgc8atAWxA0D3f9gCmQpiS6xgAUyBMy3McgM4IJmY5EkAnDNPzGw/gvyBsyW0NgCswbMxqJYAjUKTkEgPAAGAAMAAYAMwtAAhypwAAAAAAIIgsHwAAbgBAEFY+AAB8AQBBUPkAAPAtAAhCyv8JAAQB5f8GAILl5d8DAILF5d8LAIKl5T8CAIRlxf8VAAhLin8WAAjDiz8KAAwDS/88H4wqiKkZ03rgAAAAAElFTkSuQmCC"

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
            id: `org.example.${name}`,
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

    // Stands where a window's preview goes; it knows the window it shows and reports the size of the window's picture
    // once there is one, as kpipewire does. A bar along its top and a ring in its middle show how it is cut.
    Component {
        id: previewComponent

        Rectangle {
            property var window
            readonly property size pictureSize: window?.pictureSize ?? Qt.size(0, 0)

            objectName: `preview of ${window?.title}`
            color: "steelblue"

            Rectangle {
                width: parent.width
                height: parent.height / 8
                color: "midnightblue"
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) / 2
                height: width
                radius: width / 2
                color: "transparent"
                border.color: "white"
                border.width: 4
            }
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
        testCase.width = 1600;
        testCase.height = 900;
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
        Prefs.startPace = "fast";
        Tokens.moreContrast = false;
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

    function test_the_start_place_is_a_panorama_as_wide_as_the_surface_under_the_pivots() {
        openNow();
        const panorama = named("panorama");
        compare(panorama.mapToItem(start, 0, 0).x, 0);
        compare(panorama.width, start.width);
        compare(named("pivot").x, Tokens.spaceXl);
        compare(named("sectionStrip").x, Tokens.spaceXl);
        compare(named("sectionStrip").y, named("pivot").height);
        compare(panorama.y, named("sectionStrip").y + named("sectionStrip").height);
    }

    function test_the_pivot_leads_then_the_strip_then_running_beside_pinned_in_the_panorama() {
        openNow();
        compare(named("pivot").titles, ["start", "alle apps"]);
        compare(named("pivot").currentIndex, 0);
        compare(named("sectionStrip").titles, ["läuft", "angeheftet"]);
        compare(named("sectionStrip").level, "facet");
        const running = named("running").mapToItem(start, 0, 0);
        const pinned = named("pinned").mapToItem(start, 0, 0);
        verify(named("panorama").y <= running.y, "below the strip");
        compare(running.y, pinned.y);
        compare(running.x, Tokens.spaceXl);
        compare(pinned.x, running.x + named("running").width + Tokens.spaceXl, "running first, a space-xl apart");
        compare(findChild(named("running"), "heading").text, "läuft");
        compare(findChild(named("pinned"), "heading").text, "angeheftet");
    }

    function test_a_section_has_space_xl_above_and_below_and_space_l_under_its_heading() {
        openNow();
        const section = named("pinned");
        const heading = findChild(section, "heading");
        const grid = findChild(section, "grid");
        compare(heading.mapToItem(section, 0, 0).y, Tokens.spaceXl);
        compare(grid.y, heading.y + heading.height + Tokens.spaceL);
        compare(section.implicitHeight, grid.mapToItem(section, 0, 0).y + grid.height + Tokens.spaceXl);
    }

    function test_the_pivot_is_light_and_larger_than_the_section_headings_which_are_larger_than_the_tile_names() {
        openNow();
        const pivot = named("pivot");
        const active = findChild(pivot, "word");
        const names = tilesIn("pinned").map(tile => findChild(tile, "name"));
        const heading = findChild(named("pinned"), "heading");
        compare(active.font.weight, Tokens.fontWeightLight);
        compare(heading.font.pixelSize, Math.floor(Tokens.fluid(Tokens.fontSizeXl, start.width)));
        compare(names[0].font.pixelSize, Tokens.fontSizeXs);
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
        compare(findChild(tiles[0], "title").lineCount, 1);
        compare(findChild(tiles[0], "title").color, Tokens.color.textPrimary);
        compare(findChild(tiles[0], "icon").width, Geometry.iconSize);
    }

    function test_without_windows_the_running_section_is_gone() {
        openNow();
        start.windows = [];
        verify(!named("running").visible);
        compare(named("sectionStrip").titles, ["angeheftet"], "its title leaves the strip too");
        tryCompare(named("pinned"), "x", Tokens.spaceXl);
    }

    function test_without_a_preview_the_upper_part_shows_the_tile_surface() {
        openNow();
        const tile = tilesIn("running")[0];
        verify(findChild(tile, "preview").item === null);
        compare(findChild(tile, "fill").color, Tokens.color.surface);
    }

    function test_a_preview_fills_the_whole_width_down_to_the_foot_without_padding() {
        start.preview = previewComponent;
        openNow();
        const tile = tilesIn("running")[0];
        const upper = findChild(tile, "upper");
        const foot = findChild(tile, "foot");
        compare(Qt.rect(upper.x, upper.y, upper.width, upper.height), Qt.rect(0, 0, tile.width, foot.y));
        compare(foot.y + foot.height, tile.height, "the foot ends with the tile");
        const preview = findChild(tile, "preview");
        compare(preview.item.window.title, "Rekta Design — docs");
        compare(Qt.rect(preview.x, preview.y, preview.width, preview.height), Qt.rect(0, 0, upper.width, upper.height), "before its first picture it covers the upper part");
        compare(preview.item.width, preview.width);
    }

    // A preview streams its window while it has it, so the stream ends with the Start.
    function test_a_preview_has_its_window_from_the_opening_until_the_start_has_gone() {
        start.preview = previewComponent;
        const window = () => findChild(tilesIn("running")[0], "preview").item.window;
        compare(window(), null, "not while the Start is closed");
        start.open();
        compare(start.phase, "opening");
        compare(window()?.title, "Rekta Design — docs", "from the opening, so the first frame comes as the tiles turn in");
        tryVerify(() => start.phase === "open", 3000);
        keyClick(Qt.Key_Escape);
        compare(start.phase, "closing");
        compare(window()?.title, "Rekta Design — docs", "while the tiles turn out");
        tryVerify(() => !start.shown, 3000);
        compare(window(), null, "not once the Start has gone");
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
        compare(icon.width, Tokens.tileIcon);
        compare(findChild(dolphin, "name").color, Tokens.color.textPrimary);
    }

    // The launch tile (tiles.md:141–156; rekta.css:176–187).

    function test_an_app_tile_has_its_icon_at_tile_icon_in_its_padding_and_its_name_at_the_foot_in_xs_semibold() {
        start.pinned = [Object.assign(fakeApp("dolphin", 1), { icon: largeIcon })];
        openNow();
        const tile = tilesIn("pinned")[0];
        const icon = findChild(tile, "icon");
        compare(Qt.rect(icon.x, icon.y, icon.width, icon.height), Qt.rect(Geometry.tilePadding, Geometry.tilePadding, Tokens.tileIcon, Tokens.tileIcon));
        const name = findChild(tile, "name");
        compare(name.text, "dolphin", "as the app writes it");
        compare(name.font.pixelSize, Tokens.fontSizeXs);
        compare(name.font.weight, Tokens.fontWeightSemibold);
        compare(name.font.letterSpacing, 0, "no kicker's tracking");
        compare(name.lineHeight, Tokens.fontSizeXs * Tokens.lineHeightCompact);
        compare(name.color, Tokens.color.textPrimary);
        compare(name.mapToItem(tile, 0, 0).x, Geometry.tilePadding);
        compare(name.mapToItem(tile, 0, name.height).y, tile.height - Geometry.tilePadding, "at the foot");
        compare(findChild(tile, "fill").color, Tokens.color.surface);
    }

    function test_an_app_tile_two_units_high_has_its_icon_at_tile_icon_large_and_one_unit_high_at_tile_icon() {
        start.pinned = [Object.assign(fakeApp("kate", 2), { rows: 2, icon: largeIcon }), Object.assign(fakeApp("dolphin", 2), { icon: largeIcon })];
        openNow();
        const [kate, dolphin] = tilesIn("pinned").map(tile => findChild(tile, "icon"));
        compare(Qt.size(kate.width, kate.height), Qt.size(Tokens.tileIconLarge, Tokens.tileIconLarge));
        compare(Qt.size(dolphin.width, dolphin.height), Qt.size(Tokens.tileIcon, Tokens.tileIcon), "two units wide, one high");
    }

    function test_an_app_icon_is_asked_of_its_source_at_its_size_and_never_stretched_up() {
        start.pinned = [Object.assign(fakeApp("kate", 2), { rows: 2, icon: largeIcon }), fakeApp("konsole", 1)];
        openNow();
        const [kate, konsole] = tilesIn("pinned").map(tile => findChild(tile, "icon"));
        const large = findChild(kate, "picture");
        const small = findChild(konsole, "picture");
        tryCompare(large, "status", Image.Ready);
        tryCompare(small, "status", Image.Ready);
        compare(large.sourceSize, Qt.size(Tokens.tileIconLarge, Tokens.tileIconLarge));
        compare(Qt.size(large.width, large.height), Qt.size(Tokens.tileIconLarge, Tokens.tileIconLarge), "a larger picture comes down to its size");
        compare(small.sourceSize, Qt.size(Tokens.tileIcon, Tokens.tileIcon));
        compare(Qt.size(small.width, small.height), Qt.size(20, 20), "a 20px picture stays 20px");
        compare(small.mapToItem(konsole, 0, 0), Qt.point((Tokens.tileIcon - 20) / 2, (Tokens.tileIcon - 20) / 2), "in the middle of its place");
    }

    function test_a_long_app_name_stays_on_one_line_cut_at_its_end() {
        start.pinned = [fakeApp("Systemeinstellungen und noch viel mehr", 1)];
        openNow();
        const tile = tilesIn("pinned")[0];
        const name = findChild(tile, "name");
        compare(name.lineCount, 1);
        compare(name.elide, Text.ElideRight);
        verify(name.truncated);
        compare(name.width, tile.width - 2 * Geometry.tilePadding);
    }

    function countOn(tile: var): string {
        const count = findChild(tile, "count");
        return count.visible ? count.text : "";
    }

    function test_a_pinned_tile_carries_its_apps_count_at_its_top_trailing_corner_and_none_at_zero() {
        start.pinned = [fakeApp("Konsole", 1), fakeApp("Kate", 2)];
        start.unseen = { "org.example.Konsole": 4 };
        openNow();
        const [konsole, kate] = tilesIn("pinned");
        compare([countOn(konsole), countOn(kate)], ["4", ""]);
        const count = findChild(konsole, "count");
        compare(count.mapToItem(konsole, count.width, 0), Qt.point(konsole.width - Geometry.tilePadding, Geometry.tilePadding));
        compare(konsole.Accessible.name, "Konsole, 4 ungelesen");
        compare(kate.Accessible.name, "Kate");
    }

    function test_an_app_tile_in_alle_apps_carries_its_apps_count() {
        start.unseen = { "org.example.Konsole": 4 };
        openOnAllApps(["Kate", "Konsole"]);
        compare(start.letterTiles().map(tile => [tile.name, countOn(tile)]), [["Kate", ""], ["Konsole", "4"]]);
    }

    function test_an_app_tile_among_the_hits_carries_its_apps_count_the_best_hit_too() {
        start.unseen = { "org.example.Konsole": 4, "org.example.Kate": 1 };
        openWithApps();
        typeNow("k");
        const counts = start.hitTiles().reduce((all, tile) => Object.assign(all, {
                [tile.name]: countOn(tile)
            }), {});
        compare(counts, { "Kate": "1", "Konsole": "4", "KWrite": "" });
        verify(start.hitTiles()[0].best);
        compare(countOn(start.hitTiles()[0]), counts[start.hitTiles()[0].name]);
    }

    function test_a_new_count_on_a_tile_in_the_start_peeks_and_under_reduced_motion_stands_at_once() {
        mouseMove(testCase, testCase.width - 1, testCase.height - 1);
        start.pinned = [fakeApp("Konsole", 1)];
        start.unseen = { "org.example.Konsole": 2 };
        openNow();
        const tile = tilesIn("pinned")[0];
        const ghost = findChild(tile, "markedGhost");
        start.unseen = { "org.example.Konsole": 3 };
        compare(countOn(tile), "3");
        verify(ghost.visible, "a number replacing a number peeks");
        compare(ghost.text, "2");
        tryCompare(ghost, "visible", false, 3 * Tokens.durationModerate);
        Prefs.motion = "off";
        start.unseen = { "org.example.Konsole": 5 };
        compare(countOn(tile), "5");
        verify(!ghost.visible, "under reduced motion it stands at once");
    }

    function test_the_best_hit_carries_enter_and_bester_treffer_after_its_name_cut_short() {
        start.apps = [searchableApp("Kontrollzentrum für alle Einstellungen des Systems", "Settings", [])];
        start.unseen = { "org.example.Kontrollzentrum für alle Einstellungen des Systems": 2 };
        openNow();
        typeNow("kontroll");
        const best = start.hitTiles()[0];
        verify(best.best);
        const name = findChild(best, "name");
        const hint = findChild(best, "bestHit");
        verify(name.truncated, "the name is cut, never the hint");
        compare(hint.x, name.width + Tokens.spaceS);
        compare(hint.x + hint.width, best.width - 2 * Geometry.tilePadding);
        compare(hint.mapToItem(best, 0, hint.height).y, name.mapToItem(best, 0, name.height).y, "in the foot beside the name");
        compare(best.Accessible.name, "Kontrollzentrum für alle Einstellungen des Systems, 2 ungelesen");
        compare(best.Accessible.description, "bester treffer");
    }

    // The preview tile (tiles.md:123–132; rekta.css:132–136).

    function test_a_running_tiles_foot_holds_the_apps_icon_at_20_and_the_title_in_s_on_the_tile_surface_without_a_count() {
        start.windows = [Object.assign(fakeWindow("Rekta Design — docs, a title longer than the tile", 30), { icon: largeIcon })];
        openNow();
        const tile = tilesIn("running")[0];
        const foot = findChild(tile, "foot");
        const icon = findChild(tile, "icon");
        const title = findChild(tile, "title");
        compare(Qt.size(icon.width, icon.height), Qt.size(Geometry.iconSize, Geometry.iconSize));
        tryCompare(findChild(icon, "picture"), "status", Image.Ready);
        compare(findChild(icon, "picture").width, Geometry.iconSize, "a larger picture comes down to 20px");
        compare(icon.mapToItem(tile, 0, 0).x, Geometry.tilePadding);
        compare(title.mapToItem(tile, 0, 0).x, Geometry.tilePadding + Geometry.iconSize + Tokens.spaceS);
        compare(title.mapToItem(tile, title.width, 0).x, tile.width - Geometry.tilePadding);
        compare(foot.height, 2 * Tokens.spaceS + Math.max(Geometry.iconSize, title.height));
        fuzzyCompare(icon.y + icon.height / 2, title.y + title.height / 2, 0.5, "both in the middle of the foot, to the pixel");
        compare(title.font.pixelSize, Tokens.fontSizeS);
        compare(title.font.weight, Tokens.fontWeightRegular);
        compare(title.lineHeight, Tokens.fontSizeS * Tokens.lineHeightCompact);
        compare(title.color, Tokens.color.textPrimary);
        compare(title.lineCount, 1);
        verify(title.truncated, "one line, cut at its end");
        compare(findChild(tile, "count"), null, "the count stands on the app's launch tile");
        compare(findChild(tile, "fill").color, Tokens.color.surface);
        compare(tile.Accessible.name, "Rekta Design — docs, a title longer than the tile");
    }

    function test_the_focus_ring_of_a_running_tile_lies_over_its_preview() {
        start.preview = previewComponent;
        openNow();
        const tile = tilesIn("running")[0];
        const ring = tile.children.find(item => (item as FocusRing) !== null);
        verify(ring.z > findChild(tile, "upper").z);
    }

    // object-fit: cover (rekta.css:134)
    function test_a_preview_in_other_proportions_than_its_place_fills_it_whole_from_its_middle_and_the_rest_is_cut_off() {
        start.preview = previewComponent;
        start.windows = [Object.assign(fakeWindow("wide", 30), {
                pictureSize: Qt.size(4000, 1000)
            }), Object.assign(fakeWindow("landscape", 20), {
                pictureSize: Qt.size(1600, 900)
            }), Object.assign(fakeWindow("portrait", 10), {
                pictureSize: Qt.size(900, 1600)
            }), Object.assign(fakeWindow("odd", 5), {
                pictureSize: Qt.size(641, 361)
            })];
        openNow();
        for (const tile of tilesIn("running")) {
            const upper = findChild(tile, "upper");
            const preview = findChild(tile, "preview");
            const picture = preview.item.pictureSize;
            const what = tile.title;
            compare(preview.item.width, preview.width, what);
            verify(upper.clip, `${what}: what stands out is cut off`);
            verify(preview.x <= 0 && preview.y <= 0, `${what}: from the top leading corner`);
            verify(preview.x + preview.width >= upper.width && preview.y + preview.height >= upper.height, `${what}: to the bottom trailing one`);
            fuzzyCompare(preview.x + preview.width / 2, upper.width / 2, 0.5, `${what}: in the middle across`);
            fuzzyCompare(preview.y + preview.height / 2, upper.height / 2, 0.5, `${what}: in the middle down`);
            fuzzyCompare(preview.width / preview.height, picture.width / picture.height, 0.01, `${what}: in its picture's proportions`);
            verify(preview.width - upper.width <= 1 || preview.height - upper.height <= 1, `${what}: no larger than covers it, rounded up to whole pixels`);
        }
    }

    function test_a_section_scrolls_down_when_its_tiles_are_longer_than_the_screen() {
        start.pinned = Array.from({ length: 40 }, (_, i) => fakeApp(`app ${i}`, 1));
        openNow();
        const section = named("pinned");
        verify(section.contentHeight > section.height);
        mouseWheel(section, 100, 100, 0, -480);
        tryVerify(() => section.contentY > 0);
        compare(named("pivot").currentIndex, 0, "an upright wheel with room inside changes no place");
    }

    function test_clicking_alle_apps_turns_to_that_place() {
        openNow();
        const pivot = named("pivot");
        mouseClick(findChild(pivot, "title-1"));
        compare(pivot.currentIndex, 1);
        tryVerify(() => named("apps").visible && !named("startPlace").visible, 3000);
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
        verify(named("startPlace").visible);
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
        mouseWheel(named("panorama"), 100, 100, -120, 0);
        compare(named("pivot").currentIndex, 1);
        mouseWheel(named("panorama"), 100, 100, 120, 0);
        compare(named("pivot").currentIndex, 1, "within wheel-latch it is still the same gesture");
        wait(Tokens.durationWheelLatch + 50);
        mouseWheel(named("panorama"), 100, 100, 120, 0);
        compare(named("pivot").currentIndex, 0);
    }

    function test_the_parts_turn_in_once_the_windows_are_three_quarters_back_in_half_a_moderate() {
        const started = Date.now();
        start.open();
        verify(start.shown);
        verify(!turner.running, "first only the glass");
        verify(!named("body").visible);
        compare(named("waitForWindows").interval, Tokens.turnOverlap * Tokens.durationModerate / 2);
        tryVerify(() => turner.running, 2000);
        verify(Date.now() - started >= Tokens.turnOverlap * Tokens.durationModerate / 2 - 2);
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
        tryVerify(() => named("startPlace").visible);
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
        keyClick(Qt.Key_Down);
        verify(running[1].activeFocus, "down the section's own tiles");
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Right);
        verify(pinned[0].activeFocus, "across the sections, to the tile in line");
        keyClick(Qt.Key_Right);
        verify(pinned[1].activeFocus);
        keyClick(Qt.Key_Right);
        verify(pinned[2].activeFocus);
        keyClick(Qt.Key_Left);
        verify(pinned[1].activeFocus);
        keyClick(Qt.Key_Left);
        keyClick(Qt.Key_Left);
        verify(running[0].activeFocus, "back across the sections");
        keyClick(Qt.Key_Up);
        verify(named("sectionStrip").activeFocus, "up from the first row reaches the strip");
        keyClick(Qt.Key_Up);
        verify(named("pivot").activeFocus, "up from the strip reaches the pivot");
    }

    function test_right_past_the_last_tile_of_a_row_goes_to_alle_apps() {
        openNow();
        keyClick(Qt.Key_Down);
        for (let i = 0; i < 3; i++)
            keyClick(Qt.Key_Right);
        verify(tilesIn("pinned")[2].activeFocus);
        keyClick(Qt.Key_Right);
        compare(named("pivot").currentIndex, 1);
    }

    function test_a_tile_that_takes_the_focus_scrolls_into_view() {
        start.pinned = Array.from({ length: 40 }, (_, i) => fakeApp(`app ${i}`, 1));
        openNow();
        const section = named("pinned");
        // The first tile of the tenth row, below the screen.
        const last = tilesIn("pinned")[36];
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Right);
        for (let i = 0; i < 9; i++)
            keyClick(Qt.Key_Down);
        verify(last.activeFocus);
        const top = last.mapToItem(section, 0, 0).y;
        verify(top >= 0 && top + last.height <= section.height, `whole in view at ${top}`);
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
        for (let i = 0; i < 4; i++)
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

    function letterTile(index: int): var {
        return start.letterTiles()[index];
    }

    function appNames(count: int): var {
        return Array.from({ length: count }, (_, i) => `app ${String(i).padStart(2, "0")}`);
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
        const panorama = named("appsPanorama");
        const place = named("apps");
        const line = named("appsLine").mapToItem(place, 0, 0);
        compare(line, Qt.point(panorama.inset, panorama.y + Tokens.spaceXl), "where the first section would stand");
        compare(named("appsBusy").mapToItem(place, 0, 0), line);
        compare(sentence.mapToItem(place, 0, 0), Qt.point(line.x, line.y + Geometry.hairline + Tokens.spaceM));
    }

    function test_enter_or_space_on_an_app_launches_it_once() {
        openOnAllApps(["ark", "Blender", "konsole"]);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Right);
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
        verify(letterTile(2).activeFocus, "the first that starts with it");
        keyClick("d");
        verify(letterTile(3).activeFocus, "the same letter again, the next");
        keyClick("D");
        verify(letterTile(4).activeFocus, "a capital counts the same");
        keyClick("d");
        verify(letterTile(2).activeFocus, "round past the last");
        keyClick("q");
        verify(letterTile(2).activeFocus, "without a match nothing happens");
        compare(start.query, "", "and nothing is searched");
        verify(named("apps").visible);
        verify(!named("results").visible);
        keyClick("e");
        verify(letterTile(5).activeFocus);
    }

    function test_a_letter_typed_while_the_start_turns_to_alle_apps_ends_the_turn_and_jumps() {
        start.apps = ["ark", "Blender", "konsole"].map(name => installedApp(name));
        openNow();
        keyClick(Qt.Key_Right);
        verify(start.turning);
        keyClick("k");
        verify(!start.turning);
        verify(named("apps").visible);
        verify(letterTile(2).activeFocus);
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
        const pressed = letterTile(1);
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
        mouseClick(letterTile(2));
        compare(calls, ["launch Blender"], "once");
        tryVerify(() => closedSpy.count === 1, 3000);
    }

    function test_after_an_app_launch_the_window_that_had_the_keyboard_is_not_activated() {
        start.windows = windowsWithTheDocsActive();
        openOnAllApps(["ark"]);
        mouseClick(letterTile(0));
        tryVerify(() => closedSpy.count === 1, 3000);
        compare(calls, ["launch ark"]);
    }

    function test_going_to_alle_apps_turns_each_tile_in_view_as_one_part() {
        start.apps = appNames(60).map(name => installedApp(name));
        openNow();
        named("pivot").select(1);
        tryVerify(() => turner.arrivingTurns.length > 0, 3000);
        const parts = turner.arrivingTurns.map(turn => turn.part.item);
        tryVerify(() => !start.turning, 3000);
        const tiles = start.letterTiles();
        const shown = tiles.filter(tile => tile.mapToItem(null, 0, 0).x < start.width);
        verify(shown.length > 0 && shown.length < tiles.length);
        verify(shown.every(tile => parts.includes(tile)), "each tile in the window");
        verify(tiles.every(tile => shown.includes(tile) || !parts.includes(tile)), "none beyond its edge");
        verify(!parts.includes(named("appsPanorama")) && named("appsPanorama").sectionItems().every(section => !parts.includes(section)), "the panorama and its sections are scrollers, not parts");
        named("pivot").select(0);
        verify(turner.leavingTurns.some(turn => turn.part.item === letterTile(0)), "and turn out the same way");
    }

    function test_under_reduced_motion_alle_apps_stands_at_once() {
        openNow();
        start.apps = [installedApp("ark")];
        Prefs.motion = "off";
        named("pivot").select(1);
        verify(named("apps").visible);
        verify(!start.turning);
        compare(letterTile(0).opacity, 1);
    }

    function test_a_swipe_over_a_tile_of_the_start_place_goes_to_alle_apps_and_presses_nothing() {
        openNow();
        mouseDrag(tilesIn("pinned")[0], 60, 60, -200, 0);
        compare(named("pivot").currentIndex, 1);
        compare(calls, []);
    }

    function test_an_upright_drag_over_the_tiles_scrolls_their_section() {
        start.pinned = Array.from({ length: 40 }, (_, i) => fakeApp(`app ${i}`, 1));
        openNow();
        const section = named("pinned");
        mouseDrag(section, 60, section.height - 60, 0, -300);
        tryVerify(() => !section.moving, 3000);
        verify(section.contentY > 0, `scrolled to ${section.contentY}`);
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
        verify(!named("startPlace").visible);
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
        compare(suche.color, Tokens.color.textContrastHigh, "an inactive title on glass");
        compare(suche.x, typed.width + Tokens.spaceL);
        compare(suche.y + suche.baselineOffset, typed.y + typed.baselineOffset, "on one baseline");
        const word = findChild(named("pivot"), "word");
        const baselineOf = item => item.mapToItem(start, 0, item.baselineOffset).y;
        compare(baselineOf(typed), baselineOf(word), "the pivot's");
    }

    function test_a_title_too_long_for_the_search_keeps_its_size_and_is_cut_at_its_edge() {
        openWithApps();
        typeNow("firefox firefox firefox firefox firefox firefox");
        const title = named("searchTitle");
        compare(named("typed").font.pixelSize, findChild(named("pivot"), "word").font.pixelSize);
        verify(named("typed").width > title.width);
        compare(title.width, start.searchWidth);
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

    // The searchable apps and four more that "k" finds, A–Z: seven hits, more than six units hold in a row.
    function manyKApps(): var {
        return [
            ...searchableApps(),
            searchableApp("KCalc", "Scientific Calculator", ["calculator"]),
            searchableApp("KDE Connect", "Device Synchronization", ["phone"]),
            searchableApp("Kdenlive", "Video Editor", ["video"]),
            searchableApp("Krita", "Digital Painting", ["paint"])
        ].sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
    }

    // The Start at `width` × `height`, open with those apps and a window "k" finds, searching for `text`.
    function searchAt(width: real, height: real, text: string) {
        start.width = width;
        start.height = height;
        start.apps = manyKApps();
        start.webSearch = "https://search.example/?q=\\{@}";
        openNow();
        typeNow(text);
    }

    // The search's parts: its title, the hits, the rows and the sentence for no match.
    function searchParts(): var {
        return [named("searchTitle"), ...start.hitTiles(), ...start.searchRows(), named("noHits")];
    }

    // Whether an item lies whole between the sections' edges, as far in from either side of the Start as the strips.
    function withinTheEdges(item: Item): bool {
        const left = item.mapToItem(start, 0, 0).x;
        return left >= start.stripInset - 0.001 && left + item.width <= start.width - start.stripInset + 0.001;
    }

    function outsideTheEdges(): var {
        return searchParts().filter(part => !withinTheEdges(part)).map(part => `${part.objectName} ${part.text ?? part.name ?? ""}`);
    }

    function test_compact_the_search_takes_the_width_between_the_sections_edges_and_its_grid_stretches_as_theirs_three_columns_at_720() {
        searchAt(720, 1280, "k");
        verify(!named("panorama").sideways);
        const edges = 720 - 2 * Tokens.spaceM;
        const cell = (edges - 2 * Tokens.spaceS) / 3;
        compare(cell, 224);
        compare([named("searchTitle").width, named("hits").width, named("rows").width, named("noHits").width], [edges, edges, edges, edges]);
        const tiles = start.hitTiles();
        compare(tiles.length, 7);
        compare(named("hits").across, 3);
        compare(Qt.rect(tiles[0].x, tiles[0].y, tiles[0].width, tiles[0].height), Qt.rect(0, 0, 2 * cell + Tokens.spaceS, Tokens.tileUnit), "the best hit over two columns");
        compare(Qt.rect(tiles[1].x, tiles[1].y, tiles[1].width, tiles[1].height), Qt.rect(2 * (cell + Tokens.spaceS), 0, cell, Tokens.tileUnit), "stretched to the edge");
        compare(tiles[2].x, 0, "three to a row");
        verify(start.searchRows().length > 0, "a window's row");
        compare(outsideTheEdges(), []);
        start.query = "";
        typeNow("q");
        verify(findChild(named("noHits"), "sentence").visible);
        compare(start.searchRows().length, 1, "the web's way on");
        compare(outsideTheEdges(), []);
    }

    function test_sideways_the_search_is_as_many_whole_tile_units_as_fit_between_the_edges_at_most_six() {
        searchAt(1920, 1080, "k");
        const units = count => count * Tokens.tileUnit + (count - 1) * Tokens.spaceS;
        compare([named("searchTitle").width, named("hits").width, named("rows").width], [units(6), units(6), units(6)]);
        const tiles = start.hitTiles();
        verify(tiles.slice(1).every(tile => tile.width === Tokens.tileUnit && tile.height === Tokens.tileUnit), "fixed cells");
        compare(tiles[4].mapToItem(named("hits"), 0, 0), Qt.point(units(6) - Tokens.tileUnit, 0), "six units in a row");
        start.width = 1080;
        start.height = 1920;
        verify(named("panorama").sideways);
        compare(units(5), 882);
        compare([named("searchTitle").width, named("hits").width, named("rows").width, named("noHits").width], [units(5), units(5), units(5), units(5)]);
        compare(tiles[4].mapToItem(named("hits"), 0, 0), Qt.point(0, Tokens.tileUnit + Tokens.spaceS), "five units in a row");
        verify(tiles.slice(1).every(tile => tile.width === Tokens.tileUnit), "never wider tiles");
        compare(outsideTheEdges(), []);
        start.width = 2 * Tokens.spaceXl + units(6);
        compare(named("hits").width, units(6), "six units from 1156 on");
        start.width -= 1;
        compare(named("hits").width, units(5));
    }

    function test_from_720_to_1600_wide_no_part_of_the_search_runs_past_the_sections_edges() {
        searchAt(720, 1000, "k");
        compare(start.hitTiles().length, 7);
        const results = named("results");
        for (let width = 720; width <= 1600; width++) {
            start.width = width;
            compare(outsideTheEdges(), [], `at ${width}`);
            verify(results.x >= 0 && results.x + results.width <= width, `the hits' view inside the Start at ${width}`);
        }
        compare(named("hits").across, 6, "at most six");
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

    function test_a_shortcut_a_space_or_a_sign_no_calculation_starts_with_starts_no_search() {
        openWithApps();
        keyClick(Qt.Key_K, Qt.ControlModifier);
        keyClick(Qt.Key_Space);
        keyClick("*");
        keyClick(")");
        compare(start.query, "");
        verify(named("pivot").visible);
    }

    function test_a_digit_a_bracket_or_a_minus_starts_a_search_as_a_calculation_starts_with_them() {
        openWithApps();
        for (const character of ["5", "(", "-"]) {
            typeNow(character);
            compare(start.query, character);
            verify(!named("pivot").visible, `${character} shows the search`);
            Prefs.motion = "off";
            start.query = "";
            Prefs.motion = "system";
        }
    }

    function test_the_locale_s_decimal_separator_starts_a_search_and_a_full_stop_beside_it_does_not() {
        start.decimalPoint = ",";
        openWithApps();
        keyClick(".");
        compare(start.query, "");
        verify(named("pivot").visible);
        typeNow(",");
        compare(start.query, ",");
        verify(!named("pivot").visible);
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
        verify(named("startPlace").visible);
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
        compare(named("waitForWindows").interval, Tokens.turnOverlap * FadeBack.duration, "the windows come back at the effect's pace");
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
        verify(named("startPlace").visible);
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
        verify(named("startPlace").visible);
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
        const earliestLanding = Tokens.turnOverlap * FadeBack.duration + Geometry.startTempo * Tokens.heftMin * Tokens.durationModerate;
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
        tryVerify(() => named("startPlace").visible && !named("presence").running, 2000);
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
        verify(named("startPlace").visible);
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
        verify(named("startPlace").visible);
        compare(start.hitTiles().length, 0);
    }

    function wordOf(strip: string, index: int): var {
        return findChild(findChild(named(strip), `title-${index}`), "word");
    }

    function test_on_the_glass_inactive_titles_take_text_contrast_high_and_active_ones_and_those_under_the_pointer_text_primary() {
        openWithApps();
        mouseMove(testCase, testCase.width - 1, testCase.height - 1);
        for (const strip of ["pivot", "sectionStrip", "appsStrip"]) {
            compare(wordOf(strip, 0).color, Tokens.color.textPrimary, `${strip}: the active title`);
            compare(wordOf(strip, 1).color, Tokens.color.textContrastHigh, `${strip}: an inactive title`);
        }
        mouseMove(findChild(named("pivot"), "title-1"));
        tryCompare(wordOf("pivot", 1), "color", Tokens.color.textPrimary, Tokens.durationShort * 3);
    }

    // [name, item] of the titles on the glass: each strip's active and an inactive title, what was typed and "suche".
    function titlesOnTheGlass(): var {
        const titles = [["typed", named("typed")], ["suche", named("suche")]];
        for (const strip of ["pivot", "sectionStrip", "appsStrip"])
            titles.push([`${strip} active`, wordOf(strip, 0)], [`${strip} inactive`, wordOf(strip, 1)]);
        return titles;
    }

    // Whatever the windows show lies under the glass, its blur averaging it, so white and black are the limits; Rekta
    // asks 4.5:1 there, 7:1 under more contrast, large type too (colour.md:65–75). Measured at each title's own colour.
    function test_every_title_on_the_glass_keeps_4_5_to_1_over_white_and_black_and_7_to_1_under_more_contrast() {
        const luminance = colour => {
            const channel = c => c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
            return 0.2126 * channel(colour.r) + 0.7152 * channel(colour.g) + 0.0722 * channel(colour.b);
        };
        const over = (top, below) => Qt.rgba(top.r * top.a + below.r * (1 - top.a), top.g * top.a + below.g * (1 - top.a), top.b * top.a + below.b * (1 - top.a), 1);
        const ratio = (a, b) => (Math.max(luminance(a), luminance(b)) + 0.05) / (Math.min(luminance(a), luminance(b)) + 0.05);
        mouseMove(testCase, testCase.width - 1, testCase.height - 1);
        for (const [theme, moreContrast] of [["light", false], ["dark", false], ["light", true], ["dark", true]]) {
            Prefs.theme = theme;
            Tokens.moreContrast = moreContrast;
            // A Start made in the scheme: its colours stand at once, with no change to ease.
            start = createTemporaryObject(startComponent, testCase);
            openWithApps();
            const glass = named("glass").color;
            for (const [title, item] of titlesOnTheGlass()) {
                const measured = Math.min(ratio(item.color, over(glass, Qt.rgba(1, 1, 1, 1))), ratio(item.color, over(glass, Qt.rgba(0, 0, 0, 1))));
                verify(measured >= (moreContrast ? 7 : 4.5), `${theme}${moreContrast ? " under more contrast" : ""}: ${title} at ${measured.toFixed(2)}:1 on glass over white or black`);
            }
        }
    }

    // Launch tiles 1 × 1, 2 × 1 and 2 × 2, with and without a count, and preview tiles cut from a tall and a wide window.
    function sheetStart(backdrop: Item): var {
        return createTemporaryObject(startComponent, backdrop, {
            width: backdrop.width,
            height: backdrop.height,
            windows: [Object.assign(fakeWindow("konsole: build", 10), {
                    pictureSize: Qt.size(900, 1600),
                    icon: largeIcon
                }), Object.assign(fakeWindow("Rekta Design — docs", 30), {
                    pictureSize: Qt.size(1600, 900)
                })],
            pinned: [Object.assign(fakeApp("Systemeinstellungen", 1), {
                    icon: largeIcon
                }), Object.assign(fakeApp("Dolphin", 2), {
                    icon: largeIcon
                }), fakeApp("Konsole", 1), Object.assign(fakeApp("Kate", 2), {
                    rows: 2,
                    icon: largeIcon
                }), Object.assign(fakeApp("Elisa", 1), {
                    icon: largeIcon
                })],
            unseen: {
                "org.example.Systemeinstellungen": 3,
                "org.example.Kate": 12,
                "org.example.Elisa": 128
            },
            preview: previewComponent
        });
    }

    function test_contact_sheet() {
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const backdrop = createTemporaryObject(backdropComponent, testCase);
                const sheet = sheetStart(backdrop);
                // No pointer left over a tile: the focus ring shows the keyboard, not a hover tint.
                mouseMove(backdrop, backdrop.width - 1, backdrop.height - 1);
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

    function test_contact_sheet_of_the_compact_start_at_720_by_1280() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            // The window takes the surface's size, as the grab shows only what the window holds.
            testCase.width = 720;
            testCase.height = 1280;
            const backdrop = createTemporaryObject(backdropComponent, testCase);
            const sheet = sheetStart(backdrop);
            mouseMove(backdrop, backdrop.width - 1, backdrop.height - 1);
            Prefs.motion = "off";
            sheet.open();
            Prefs.motion = "system";
            wait(Tokens.durationShort);
            waitForRendering(backdrop);
            grabImage(backdrop).save(`start-sheet-${theme}-720x1280.png`);
            verify(!findChild(sheet, "panorama").sideways, theme);
        }
        testCase.width = 1600;
        testCase.height = 900;
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
            sheet.apps = searchableApps().map(app => app.name === "Konsole" ? Object.assign(app, {
                    icon: largeIcon
                }) : app);
            sheet.unseen = {
                "org.example.Kate": 2,
                "org.example.KWrite": 14
            };
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

    // The search for "k", seven hits and a window's row: compact at 720 × 1280 between the sections' edges, its grid
    // stretched; sideways at 1080 × 1920 five whole units, as many as fit there.
    function test_contact_sheets_of_the_search_compact_and_sideways_at_1080_by_1920() {
        const sizes = [["compact", Qt.size(720, 1280)], ["1080x1920", Qt.size(1080, 1920)]];
        for (const theme of ["light", "dark"]) {
            for (const [name, size] of sizes) {
                Prefs.theme = theme;
                // The window takes the surface's size, as the grab shows only what the window holds.
                testCase.width = size.width;
                testCase.height = size.height;
                const backdrop = createTemporaryObject(backdropComponent, testCase);
                const sheet = createTemporaryObject(startComponent, backdrop, {
                    apps: manyKApps(),
                    unseen: {
                        "org.example.KWrite": 4
                    }
                });
                mouseMove(backdrop, backdrop.width - 1, backdrop.height - 1);
                Prefs.motion = "off";
                sheet.open();
                keyClick("k");
                Prefs.motion = "system";
                waitForRendering(backdrop);
                grabImage(backdrop).save(`start-search-${name}-${theme}.png`);
                compare(findChild(sheet, "hits").across, name === "compact" ? 3 : 5, `${theme} ${name}`);
            }
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
            wait(Tokens.turnOverlap * FadeBack.duration / 2);
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
            Object.assign(say("sperren", ["lock"]), { key: "Meta L" }),
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

    function test_a_calculation_shows_its_result_as_the_best_hit_and_enter_copies_it_and_closes_the_start() {
        openWithEverything();
        start.copy = text => testCase.calls = [...testCase.calls, `copy ${text}`];
        typeNow("2+3*4");
        compare(groupNames(), ["rechnen"]);
        compare(rowTexts("rechnen"), ["= 14"]);
        const row = start.searchRows()[0];
        verify(row.best);
        verify(findChild(row, "enterKey").visible);
        verify(!named("noHits").visible);
        keyClick(Qt.Key_Return);
        compare(calls, ["copy 14"]);
        verify(!turner.back, "forward");
        tryVerify(() => closedSpy.count === 1, 3000);
    }

    function test_a_calculation_reads_and_writes_the_locale_s_decimal_separator() {
        start.decimalPoint = ",";
        openWithApps();
        typeNow("1,5*3");
        compare(rowTexts("rechnen"), ["= 4,5"]);
    }

    function test_a_division_by_zero_shows_no_result_and_nothing_found() {
        openWithApps();
        typeNow("1/0");
        compare(groupNames(), []);
        verify(named("noHits").visible);
    }

    // KDE's default web search, as WebSearch reads it, and the browser it opens in.
    function openWithAWebSearch() {
        start.webSearch = "https://search.example/?q=\\{@}&t=kde";
        start.openUrl = url => testCase.calls = [...testCase.calls, `open ${url}`];
        openWithEverything();
    }

    function test_with_nothing_found_a_web_search_for_the_text_without_its_outer_spaces_stands_below_rekta_s_sentence_with_enter() {
        openWithAWebSearch();
        typeNow("qq x ");
        verify(named("noHits").visible);
        compare(findChild(named("noHits"), "sentence").text, "nichts zum hingehen oder ausführen passt zu „qq x“.");
        const rows = start.searchRows();
        compare(rows.map(row => row.text), ["„qq x“ im web suchen"]);
        verify(rows[0].best);
        verify(findChild(rows[0], "enterKey").visible);
        keyClick(Qt.Key_Return);
        compare(calls, ["open https://search.example/?q=qq%20x&t=kde"]);
        verify(!turner.back, "forward");
        tryVerify(() => closedSpy.count === 1, 3000);
    }

    function test_the_way_on_stands_space_s_below_the_sentence_within_the_empty_region_at_the_line_s_edge() {
        openWithAWebSearch();
        typeNow("qq");
        const empty = named("noHits");
        const sentence = findChild(empty, "sentence");
        const row = start.searchRows()[0];
        const top = row.mapToItem(empty, 0, 0).y;
        compare(top, sentence.y + sentence.height + Tokens.spaceS);
        compare(empty.height, top + row.height + Tokens.spaceM);
        compare(row.mapToItem(start, 0, 0).x, named("typed").mapToItem(start, 0, 0).x);
    }

    function test_down_goes_from_the_line_into_the_way_on_up_back_and_enter_there_acts_on_it() {
        openWithAWebSearch();
        typeNow("qq");
        const row = start.searchRows()[0];
        keyClick(Qt.Key_Down);
        verify(row.activeFocus);
        keyClick(Qt.Key_Up);
        verify(named("typed").activeFocus);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(calls, ["open https://search.example/?q=qq&t=kde"]);
    }

    function test_escape_on_the_way_on_closes_the_start_without_searching_the_web() {
        openWithAWebSearch();
        typeNow("qq");
        keyClick(Qt.Key_Down);
        verify(start.searchRows()[0].activeFocus);
        keyClick(Qt.Key_Escape);
        tryVerify(() => closedSpy.count === 1, 3000);
        compare(calls, []);
    }

    function test_a_hit_of_any_kind_takes_the_way_on_away() {
        openWithAWebSearch();
        typeNow("qq");
        compare(start.searchRows().length, 1);
        Prefs.motion = "off";
        start.query = "";
        Prefs.motion = "system";
        typeNow("sp");
        compare(start.searchRows().map(row => row.text), ["sperren"]);
    }

    function test_without_a_web_search_nothing_found_has_no_way_on() {
        openWithEverything();
        typeNow("qq");
        verify(named("noHits").visible);
        compare(start.searchRows(), []);
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

    // The search for `text` as start-search-<name>-<theme>.png, with the first hit in focus if `focusFirst`.
    function saveSearchSheet(theme: string, text: string, name: string, focusFirst: bool) {
        Prefs.theme = theme;
        const backdrop = createTemporaryObject(backdropComponent, testCase);
        const sheet = createTemporaryObject(startComponent, backdrop);
        sheet.apps = searchableApps();
        sheet.webSearch = "https://search.example/?q=\\{@}";
        Prefs.motion = "off";
        sheet.open();
        for (const character of text)
            keyClick(character);
        if (focusFirst)
            keyClick(Qt.Key_Down);
        Prefs.motion = "system";
        waitForRendering(backdrop);
        grabImage(backdrop).save(`start-search-${name}-${theme}.png`);
        compare(sheet.query, text, `${name} ${theme}`);
    }

    function test_contact_sheet_of_a_calculation_and_of_the_way_on() {
        for (const theme of ["light", "dark"]) {
            saveSearchSheet(theme, "(2+3)*4", "calc", false);
            saveSearchSheet(theme, "qq x", "way-on", true);
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
        verify(findChild(keyed, "key").visible);
        compare(findChild(keyed, "key").text, "Meta L");
        const plain = start.searchRows().find(row => row.text === "dunkel an") ?? start.searchRows().find(row => row.text !== "sperren");
        verify(!findChild(plain, "key").visible);
        for (const row of start.searchRows().filter(candidate => candidate.text !== "sperren"))
            verify(!findChild(row, "key").visible, row.text);
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

    function test_a_row_scrolled_to_the_list_s_edge_keeps_its_whole_ring_in_view() {
        start.windows = Array.from({ length: 40 }, (_, i) => fakeWindow(`fenster ${i}`, i));
        openWithApps();
        typeNow("fenster");
        const results = named("results");
        for (let i = 0; i < 30; i++)
            keyClick(Qt.Key_Down);
        const ring = findChild(start.searchRows().find(row => row.activeFocus), "ring");
        const top = ring.mapToItem(results, 0, 0).y;
        verify(top >= 0 && top + ring.height <= results.height, `the ring from ${top} to ${top + ring.height} of ${results.height}`);
    }
}
