pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Settings
import Start
import "ContactSheets.js" as ContactSheets

// Pinning, unpinning and sizing apps in the Start through an app tile's context menu, with undo in a toast.
TestCase {
    id: testCase

    name: "StartPins"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1600
    height: 900

    // What the fake apps and windows were asked to do, oldest first.
    property var calls: []
    readonly property string pinkIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAGklEQVR4nGN4aTWLbMQwqnlU86jmUc0DqxkAreu3b+7dCC4AAAAASUVORK5CYII="

    function installedApp(id: string, name: string): var {
        return {
            id: id,
            name: name,
            genericName: "",
            keywords: [],
            exec: "",
            icon: testCase.pinkIcon,
            launch: () => testCase.calls = [...testCase.calls, `launch ${name}`]
        };
    }

    // A–Z, as the app model lists them.
    readonly property var installed: [installedApp("org.kde.dolphin", "Dolphin"), installedApp("org.kde.kate", "Kate"), installedApp("org.kde.konsole", "Konsole"), installedApp("systemsettings", "Systemeinstellungen")]

    function fakeWindow(title: string, lastActivated: real, appId: string): var {
        return {
            title: title,
            appId: appId,
            icon: testCase.pinkIcon,
            lastActivated: lastActivated,
            stackingOrder: 0,
            active: false,
            activate: () => testCase.calls = [...testCase.calls, `activate ${title}`]
        };
    }

    // start.json as the shell writes it, with a key of the user's own on the file and on an entry.
    function fileText(pinned: var): string {
        return JSON.stringify({
            theme: "kept",
            pinned: pinned
        }, null, 2) + "\n";
    }

    readonly property string usersFile: fileText([
        { id: "systemsettings" },
        { id: "org.kde.dolphin", columns: 2, rows: 1, group: "files" },
        { id: "org.kde.konsole", columns: 1, rows: 1 }
    ])

    Component {
        id: fileComponent

        FakeStartFile {}
    }

    Component {
        id: toasterComponent

        Toaster {
            width: testCase.width
            undoWord: "rückgängig"
        }
    }

    // The Start as StartSurface sets it up: its pinned apps follow the file.
    Component {
        id: startComponent

        StartPlace {
            id: place

            required property var file

            width: testCase.width
            height: testCase.height
            windows: [testCase.fakeWindow("konsole: build", 10, "org.kde.konsole"), testCase.fakeWindow("a window", 20, "")]
            apps: testCase.installed
            pinFile: file
            pinned: Rules.pinnedTiles(file.list, id => testCase.installed.some(app => app.id === id)).map(tile => Object.assign({}, testCase.installed.find(app => app.id === tile.id), tile))
        }
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var file
    property var toaster
    property var start
    property var menu

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        calls = [];
        file = createTemporaryObject(fileComponent, testCase, { text: usersFile });
        toaster = createTemporaryObject(toasterComponent, testCase);
        start = createTemporaryObject(startComponent, testCase, { file: file, toaster: toaster });
        menu = findChild(start, "menu");
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    function named(name: string): var {
        return findChild(start, name);
    }

    function tilesIn(section: string): var {
        return findChild(named(section), "grid").children.filter(item => (item as Tile) !== null);
    }

    function pinnedTile(name: string): var {
        return tilesIn("pinned").find(tile => tile.name === name);
    }

    function pinnedNames(): var {
        return tilesIn("pinned").map(tile => tile.name);
    }

    function listed(): var {
        return JSON.parse(file.text).pinned;
    }

    function rowsShown(): var {
        return menu.items().map(item => item.label);
    }

    function sizeRows(): var {
        return menu.items().filter(item => item.objectName === "size");
    }

    function moving(tile: var): var {
        return named("presence").moving.find(motion => motion.item === tile);
    }

    // Opens the Start without motion, as a reduced-motion user sees it at once.
    function openNow() {
        Prefs.motion = "off";
        start.open();
        Prefs.motion = "system";
        waitForRendering(start);
    }

    function goToAllApps() {
        Prefs.motion = "off";
        findChild(start, "pivot").select(1);
        Prefs.motion = "system";
        waitForRendering(start);
    }

    function letterTile(name: string): var {
        return start.letterTiles().find(tile => tile.name === name);
    }

    function search(text: string) {
        Prefs.motion = "off";
        for (const letter of text)
            keyClick(letter);
        Prefs.motion = "system";
        waitForRendering(start);
    }

    function rightClick(tile: var, x: real, y: real) {
        mouseClick(tile, x, y, Qt.RightButton);
    }

    function choose(label: string) {
        const item = menu.items().find(row => row.text === label);
        verify(item, `no item ${label} in ${rowsShown()}`);
        mouseClick(item);
    }

    // Menus

    function test_a_right_click_opens_the_menu_at_the_pointer_on_an_app_tile_in_every_section_data() {
        return [
            { tag: "angeheftet", where: "pinned", name: "Dolphin" },
            { tag: "alle apps", where: "apps", name: "Kate" },
            { tag: "a search hit", where: "search", name: "Konsole" },
            { tag: "the best hit", where: "best", name: "Kate" },
            { tag: "läuft", where: "running", name: "konsole: build" }
        ];
    }

    function tileFor(data: var): var {
        if (data.where === "pinned")
            return pinnedTile(data.name);
        if (data.where === "apps") {
            goToAllApps();
            return letterTile(data.name);
        }
        if (data.where === "running")
            return tilesIn("running").find(tile => tile.title === data.name);
        search("k");
        const hits = findChild(start, "hits").children.filter(item => (item as Tile) !== null);
        return data.where === "best" ? hits[0] : hits.find(tile => tile.name === data.name);
    }

    function test_a_right_click_opens_the_menu_at_the_pointer_on_an_app_tile_in_every_section(data) {
        openNow();
        const tile = tileFor(data);
        verify(tile, data.tag);
        rightClick(tile, 30, 40);
        verify(menu.open);
        const at = tile.mapToItem(start, 30, 40);
        compare(Qt.point(menu.x, menu.y), Qt.point(Math.round(at.x), Math.round(at.y)));
        verify(!tile.pressed, "the tile does not sink");
        compare(calls, [], "and starts nothing");
        verify(start.wanted, "the Start stays");
    }

    function test_near_the_edge_the_menu_turns_to_stay_in_the_start() {
        openNow();
        start.width = 700;
        start.height = 500;
        waitForRendering(start);
        const tile = pinnedTile("Konsole");
        const at = tile.mapToItem(start, tile.width - 2, tile.height - 2);
        start.openMenu(tile, Qt.point(tile.width - 2, tile.height - 2), "org.kde.konsole", true);
        verify(menu.y + menu.height <= start.height - Tokens.spaceM || menu.y === Math.round(at.y - menu.height), `${menu.y} + ${menu.height}`);
        verify(menu.x + menu.width <= start.width - Tokens.spaceM, `${menu.x} + ${menu.width}`);
        verify(menu.y >= Tokens.spaceM);
    }

    function test_shift_f10_opens_the_menu_below_the_focused_tile_with_its_first_item_in_focus() {
        openNow();
        const tile = pinnedTile("Dolphin");
        tile.forceActiveFocus();
        keyClick(Qt.Key_F10, Qt.ShiftModifier);
        verify(menu.open);
        const at = tile.mapToItem(start, Geometry.contextMenuAtX, Geometry.contextMenuAtY);
        compare(Qt.point(menu.x, menu.y), Qt.point(Math.round(at.x), Math.round(at.y)));
        verify(menu.items()[0].activeFocus, "lösen in focus");
        keyClick(Qt.Key_Escape);
        verify(!menu.open);
        verify(tile.activeFocus, "Escape gives the focus back to the tile");
    }

    function test_the_menu_key_opens_it_and_its_keys_are_a_menus() {
        openNow();
        const tile = pinnedTile("Dolphin");
        tile.forceActiveFocus();
        keyClick(Qt.Key_Menu);
        verify(menu.open);
        keyClick(Qt.Key_Down);
        verify(sizeRows()[0].activeFocus, "down to klein");
        keyClick(Qt.Key_End);
        verify(sizeRows()[3].activeFocus, "End to sehr groß");
        keyClick(Qt.Key_Home);
        verify(menu.items()[0].activeFocus);
        keyClick("g");
        verify(sizeRows()[2].activeFocus, "a letter jumps to groß");
        keyClick(Qt.Key_Return);
        verify(!menu.open);
        verify(tile.activeFocus, "a choice gives the focus back to the tile");
        compare(listed()[1].rows, 2);
    }

    function test_tab_closes_the_menu_and_moves_on() {
        openNow();
        const tile = pinnedTile("Dolphin");
        tile.forceActiveFocus();
        keyClick(Qt.Key_Menu);
        keyClick(Qt.Key_Tab);
        verify(!menu.open);
        verify(!tile.activeFocus && !menu.activeFocus);
    }

    function test_a_letter_while_the_menu_is_open_starts_no_search() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        keyClick("x");
        verify(menu.open);
        compare(start.query, "");
    }

    function test_a_long_press_opens_the_menu_at_the_finger_and_the_release_starts_nothing() {
        openNow();
        const tile = pinnedTile("Konsole");
        const touch = touchEvent(tile);
        touch.press(0, tile, 50, 60).commit();
        tryVerify(() => menu.open, Tokens.durationLongPress * 2);
        const at = tile.mapToItem(start, 50, 60);
        verify(Math.abs(menu.x - at.x) <= 1 && Math.abs(menu.y - at.y) <= 1, `${menu.x}, ${menu.y} at ${at}`);
        touch.release(0, tile, 50, 60).commit();
        wait(Tokens.durationPress * 2);
        compare(calls, []);
        verify(menu.open);
    }

    function test_a_finger_that_moves_exactly_eight_pixels_still_opens_the_menu() {
        openNow();
        const tile = pinnedTile("Konsole");
        const touch = touchEvent(tile);
        touch.press(0, tile, 50, 60).commit();
        touch.move(0, tile, 50, 68).commit();
        tryVerify(() => menu.open, Tokens.durationLongPress * 2);
        touch.release(0, tile, 50, 68).commit();
    }

    function test_a_finger_that_moves_more_than_eight_pixels_opens_no_menu() {
        openNow();
        const tile = pinnedTile("Konsole");
        const touch = touchEvent(tile);
        touch.press(0, tile, 50, 60).commit();
        touch.move(0, tile, 50, 69).commit();
        wait(Tokens.durationLongPress * 1.5);
        touch.release(0, tile, 50, 69).commit();
        verify(!menu.open);
        compare(calls, []);
    }

    // Closing

    function test_a_press_outside_closes_the_menu_and_goes_on_to_what_lies_beneath() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        mouseClick(pinnedTile("Konsole"));
        verify(!menu.open);
        compare(calls, ["launch Konsole"]);
    }

    function test_a_right_click_on_another_tile_moves_the_menu_there() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        rightClick(pinnedTile("Konsole"), 30, 40);
        verify(menu.open);
        compare(menu.control, pinnedTile("Konsole"));
        compare(rowsShown()[0], "lösen");
    }

    function test_a_scroll_that_moves_the_tile_closes_the_menu_and_one_that_does_not_leaves_it() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        const section = named("pinned");
        section.contentY += 2;
        verify(menu.open, "within the slop");
        section.contentY += 1;
        verify(!menu.open, "one pixel past the slop");
        rightClick(pinnedTile("Dolphin"), 30, 40);
        named("running").contentY += 20;
        verify(menu.open, "a scroller that does not hold the tile");
        section.contentY += 10;
        verify(!menu.open);
    }

    function test_a_sideways_scroll_of_the_panorama_that_moves_the_tile_closes_the_menu() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        const scroller = named("panorama").scroller;
        scroller.contentX += Geometry.contextMenuScrollSlop;
        verify(menu.open, "within the slop");
        scroller.contentX += 1;
        verify(!menu.open, "one pixel past the slop");
    }

    function test_closing_the_start_closes_the_menu() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        start.close(null);
        verify(!menu.open);
    }

    function test_a_change_of_place_closes_the_menu() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        findChild(start, "pivot").select(1);
        verify(!menu.open);
    }

    function test_resizing_the_start_closes_the_menu() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        start.width = 1400;
        verify(!menu.open);
    }

    function test_the_menu_closes_when_a_change_from_outside_takes_its_tile_away_or_resizes_it() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        file.text = fileText([{ id: "systemsettings" }, { id: "org.kde.konsole" }]);
        verify(!menu.open, "taken away");
        rightClick(pinnedTile("Konsole"), 30, 40);
        file.text = fileText([{ id: "systemsettings" }, { id: "org.kde.konsole", columns: 2 }]);
        verify(!menu.open, "resized: its sizes are no longer true");
    }

    function test_the_menu_on_an_alle_apps_tile_closes_cleanly_when_new_apps_refile_its_section() {
        openNow();
        goToAllApps();
        rightClick(letterTile("Kate"), 30, 40);
        verify(menu.open);
        start.apps = [...installed, installedApp("org.kde.okular", "Okular")];
        tryVerify(() => !menu.open, 1000, "its tile has gone");
        rightClick(letterTile("Kate"), 30, 40);
        let section = letterTile("Kate").parent;
        while (!(section instanceof Flickable))
            section = section.parent;
        section.contentY += Geometry.contextMenuScrollSlop + 1;
        verify(!menu.open, "the new menu follows its own tile and closes once it moves");
    }

    // Items

    function test_an_app_not_pinned_offers_anheften_without_sizes() {
        openNow();
        goToAllApps();
        rightClick(letterTile("Kate"), 30, 40);
        compare(rowsShown(), ["anheften"]);
    }

    function test_a_pinned_app_offers_losen_and_only_in_angeheftet_its_sizes_the_current_one_chosen() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        compare(rowsShown(), ["lösen", "klein", "breit", "groß", "sehr groß"]);
        verify(findChild(menu, "size") !== null);
        compare(sizeRows().map(row => row.checked), [false, true, false, false], "breit, as start.json has it");
        compare(sizeRows().map(row => row.kind), ["radio", "radio", "radio", "radio"]);
        menu.close(false);
        goToAllApps();
        rightClick(letterTile("Dolphin"), 30, 40);
        compare(rowsShown(), ["lösen"], "in alle apps no sizes");
    }

    function test_the_sizes_stand_under_a_hairline_headed_grosse() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        const rows = Array.from(menu.rows).filter(row => row.visible);
        verify((rows[1] as MenuSeparator) !== null, "a hairline after lösen");
        compare((rows[2] as MenuLabel)?.text, "größe");
    }

    function test_a_running_window_offers_its_apps_menu_and_without_a_known_app_says_why_not() {
        openNow();
        rightClick(tilesIn("running").find(tile => tile.title === "konsole: build"), 30, 40);
        compare(rowsShown(), ["lösen"], "Konsole is pinned");
        menu.close(false);
        rightClick(tilesIn("running").find(tile => tile.title === "a window"), 30, 40);
        compare(rowsShown(), ["anheften (keine app bekannt)"]);
        verify(menu.items()[0].disabled);
        mouseClick(menu.items()[0]);
        compare(file.text, usersFile, "a disabled item does nothing");
    }

    // Pin

    function test_anheften_puts_the_app_at_the_end_as_one_unit_where_it_arrives_and_offers_undo() {
        openNow();
        goToAllApps();
        rightClick(letterTile("Kate"), 30, 40);
        choose("anheften");
        compare(listed()[3], { id: "org.kde.kate", columns: 1, rows: 1 });
        compare(JSON.parse(file.text).theme, "kept");
        const kate = pinnedTile("Kate");
        compare(pinnedNames(), ["Systemeinstellungen", "Dolphin", "Konsole", "Kate"]);
        compare(Qt.size(kate.columns, kate.rows), Qt.size(1, 1));
        const arrival = moving(kate);
        verify(arrival, "it arrives");
        compare(arrival.from.scale, Geometry.arriveTileScale);
        compare(arrival.duration, Tokens.durationModerate);
        compare(toaster.open.text, "Kate angeheftet");
        compare(toaster.open.action, "rückgängig");
        verify(start.wanted, "the Start stays open");
    }

    function test_a_tap_on_anheften_over_its_own_tile_pins_the_app_and_starts_nothing_data() {
        return [
            { tag: "mouse", finger: false },
            { tag: "finger", finger: true }
        ];
    }

    function test_a_tap_on_anheften_over_its_own_tile_pins_the_app_and_starts_nothing(data) {
        openNow();
        goToAllApps();
        const kate = letterTile("Kate");
        rightClick(kate, 30, 40);
        const item = menu.items().find(row => row.text === "anheften");
        const centre = Qt.point(item.width / 2, item.height / 2);
        verify(kate.contains(item.mapToItem(kate, centre)), "anheften lies over the tile");
        if (data.finger)
            touchEvent(item).press(0, item, centre.x, centre.y).commit().release(0, item, centre.x, centre.y).commit();
        else
            mouseClick(item);
        compare(calls, []);
        compare(listed()[3], { id: "org.kde.kate", columns: 1, rows: 1 });
    }

    // Unpin

    function test_losen_lets_the_tile_go_and_the_others_close_the_gap_with_undo_offered() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        const dolphin = pinnedTile("Dolphin");
        const konsole = pinnedTile("Konsole");
        choose("lösen");
        compare(listed().map(entry => entry.id), ["systemsettings", "org.kde.konsole"]);
        const leaving = moving(dolphin);
        verify(leaving, "it leaves");
        compare(leaving.to.scale, Geometry.leaveTileScale);
        compare(leaving.to.opacity, 0);
        compare(leaving.duration, Geometry.leaveShare * Tokens.durationShort);
        compare(leaving.curve, Tokens.easeOut);
        tryVerify(() => moving(konsole) !== undefined, 1000, "then Konsole glides into the gap");
        compare(moving(konsole).duration, Tokens.durationModerate);
        compare(toaster.open.text, "Dolphin gelöst");
        tryVerify(() => !named("presence").running, 2000);
        compare(pinnedNames(), ["Systemeinstellungen", "Konsole"]);
    }

    function test_delete_unpins_the_focused_tile_and_the_focus_goes_to_the_next_at_the_end_to_the_one_before() {
        openNow();
        pinnedTile("Dolphin").forceActiveFocus();
        keyClick(Qt.Key_Delete);
        verify(pinnedTile("Konsole").activeFocus, "the next");
        compare(listed().map(entry => entry.id), ["systemsettings", "org.kde.konsole"]);
        compare(toaster.open.text, "Dolphin gelöst");
        tryVerify(() => !named("presence").running, 2000);
        keyClick(Qt.Key_Delete);
        verify(pinnedTile("Systemeinstellungen").activeFocus, "at the end the one before");
    }

    function test_unpinning_the_last_tile_shows_the_empty_section_with_its_way_on_and_no_defaults() {
        Prefs.motion = "off";
        start.open();
        pinnedTile("Systemeinstellungen").forceActiveFocus();
        for (let k = 0; k < 3; k++)
            keyClick(Qt.Key_Delete);
        compare(listed(), []);
        compare(pinnedNames(), [], "the defaults do not come back");
        const empty = named("noPins");
        verify(empty.visible);
        compare(empty.text, "nichts angeheftet.");
        const way = findChild(empty, "allApps");
        verify(way.activeFocus, "the focus goes to the way on");
        keyClick(Qt.Key_Return);
        compare(findChild(start, "pivot").currentIndex, 1, "to alle apps");
    }

    // Size

    function test_a_size_scales_the_tile_from_its_old_size_its_content_shown_late_and_the_others_glide() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        const dolphin = pinnedTile("Dolphin");
        const konsole = pinnedTile("Konsole");
        const before = konsole.mapToItem(null, 0, 0);
        choose("sehr groß");
        compare(listed()[1], { id: "org.kde.dolphin", columns: 4, rows: 2, group: "files" }, "its own key kept");
        compare(Qt.size(dolphin.columns, dolphin.rows), Qt.size(4, 2));
        const resize = moving(dolphin);
        verify(resize?.resized, "it scales from its old size");
        fuzzyCompare(resize.from.sx, (2 * Tokens.tileUnit + Tokens.spaceS) / dolphin.width, 0.001);
        fuzzyCompare(resize.from.sy, Tokens.tileUnit / dolphin.height, 0.001);
        compare(dolphin.contentOpacity, 0, "its content waits");
        verify(moving(konsole) !== undefined, "Konsole glides to its new place");
        verify(konsole.mapToItem(null, 0, 0).y - before.y < 1, "from where it was");
        compare(toaster.open.text, "Dolphin: sehr groß");
        tryVerify(() => !named("presence").running, 2000);
        compare(dolphin.contentOpacity, 1);
    }

    function test_choosing_the_size_the_tile_has_changes_nothing() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        choose("breit");
        compare(file.text, usersFile);
        compare(toaster.open, null);
    }

    function test_every_size_draws_the_launch_tile_at_its_units() {
        Prefs.motion = "off";
        start.open();
        for (const size of Rules.pinSizes) {
            start.openMenu(pinnedTile("Dolphin"), Qt.point(10, 10), "org.kde.dolphin", true);
            choose(size.name);
            const dolphin = pinnedTile("Dolphin");
            compare(Qt.size(dolphin.width, dolphin.height), Qt.size(size.columns * Tokens.tileUnit + (size.columns - 1) * Tokens.spaceS, size.rows * Tokens.tileUnit + (size.rows - 1) * Tokens.spaceS), size.name);
        }
    }

    // Undo

    function test_undo_in_the_toast_puts_an_unpinned_app_back_in_its_place_with_its_keys() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        choose("lösen");
        mouseClick(findChild(toaster.open, "action"));
        compare(file.text, usersFile);
        compare(pinnedNames(), ["Systemeinstellungen", "Dolphin", "Konsole"]);
        verify(moving(pinnedTile("Dolphin")) !== undefined, "it arrives again");
    }

    function test_ctrl_z_while_the_toast_stands_undoes_from_the_open_start_data() {
        return [
            { tag: "anheften", where: "apps", name: "Kate", item: "anheften" },
            { tag: "lösen", where: "pinned", name: "Dolphin", item: "lösen" },
            { tag: "größe", where: "pinned", name: "Dolphin", item: "groß" }
        ];
    }

    function test_ctrl_z_while_the_toast_stands_undoes_from_the_open_start(data) {
        openNow();
        if (data.where === "apps")
            goToAllApps();
        rightClick(data.where === "apps" ? letterTile(data.name) : pinnedTile(data.name), 30, 40);
        choose(data.item);
        verify(file.text !== usersFile);
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(file.text, usersFile, "entry, place, size and keys as before");
        verify(start.wanted);
        tryVerify(() => !named("presence").running, 2000);
        compare(pinnedNames(), ["Systemeinstellungen", "Dolphin", "Konsole"]);
    }

    function test_a_new_change_replaces_the_toast_and_its_undo_lapses() {
        openNow();
        rightClick(pinnedTile("Dolphin"), 30, 40);
        choose("groß");
        rightClick(pinnedTile("Konsole"), 30, 40);
        choose("breit");
        compare(toaster.open.text, "Konsole: breit");
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(listed()[1].rows, 2, "Dolphin stays large");
        compare(listed()[2].columns, 1, "Konsole is back");
    }

    function test_without_a_list_in_the_file_the_first_change_writes_the_defaults_with_it_and_undo_returns_them() {
        file.text = "";
        openNow();
        compare(pinnedNames(), ["Systemeinstellungen", "Dolphin", "Konsole"]);
        rightClick(pinnedTile("Dolphin"), 30, 40);
        choose("lösen");
        compare(listed(), [{ id: "systemsettings" }, { id: "org.kde.konsole" }]);
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(listed(), [{ id: "systemsettings" }, { id: "org.kde.dolphin" }, { id: "org.kde.konsole" }]);
    }

    // A broken start.json

    function test_over_a_broken_start_json_the_defaults_show_writing_items_say_why_and_delete_does_nothing() {
        file.text = "{ broken";
        openNow();
        compare(pinnedNames(), ["Systemeinstellungen", "Dolphin", "Konsole"]);
        rightClick(pinnedTile("Dolphin"), 30, 40);
        compare(rowsShown(), ["lösen (start.json ist beschädigt)", "klein (start.json ist beschädigt)", "breit (start.json ist beschädigt)", "groß (start.json ist beschädigt)", "sehr groß (start.json ist beschädigt)"]);
        verify(menu.items().every(item => item.disabled));
        mouseClick(menu.items()[0]);
        menu.close(false);
        pinnedTile("Dolphin").forceActiveFocus();
        keyClick(Qt.Key_Delete);
        compare(file.text, "{ broken", "byte for byte");
        compare(pinnedNames(), ["Systemeinstellungen", "Dolphin", "Konsole"]);
        compare(toaster.open, null);
    }

    // From outside

    function test_a_change_to_the_file_from_outside_shows_at_once_in_the_open_start() {
        openNow();
        file.text = fileText([{ id: "org.kde.kate", columns: 2, rows: 2 }, { id: "org.kde.konsole" }]);
        tryVerify(() => !named("presence").running, 2000);
        compare(pinnedNames(), ["Kate", "Konsole"]);
        compare(pinnedTile("Kate").rows, 2);
    }

    function test_the_tiles_are_packed_in_the_order_of_the_file() {
        openNow();
        Prefs.motion = "off";
        file.text = fileText([{ id: "org.kde.kate", columns: 4, rows: 2 }, { id: "org.kde.konsole" }, { id: "systemsettings" }, { id: "org.kde.dolphin" }]);
        tryVerify(() => !named("presence").running, 2000);
        const tiles = ["Kate", "Konsole", "Systemeinstellungen", "Dolphin"].map(pinnedTile);
        compare(Qt.point(tiles[0].x, tiles[0].y), Qt.point(0, 0));
        verify(tiles[1].y > tiles[0].y && tiles[1].x === 0, "below the wide one");
        verify(tiles[2].x > tiles[1].x && tiles[3].x > tiles[2].x, "then on in a row");
    }

    function test_a_change_while_the_start_turns_in_shows_at_once_the_turn_being_its_arrival() {
        start.open();
        tryVerify(() => findChild(start, "turn").running, 2000);
        file.text = fileText([{ id: "org.kde.kate" }, { id: "org.kde.konsole" }]);
        verify(!named("presence").running);
        compare(pinnedNames(), ["Kate", "Konsole"]);
    }

    function test_a_tile_that_stays_pinned_is_the_same_tile_after_a_change() {
        openNow();
        const konsole = pinnedTile("Konsole");
        rightClick(pinnedTile("Dolphin"), 30, 40);
        choose("lösen");
        tryVerify(() => !named("presence").running, 2000);
        verify(pinnedTile("Konsole") === konsole);
    }

    // Reduced motion

    function test_under_reduced_motion_the_menu_and_every_change_come_at_once() {
        Prefs.motion = "off";
        start.open();
        waitForRendering(start);
        rightClick(pinnedTile("Dolphin"), 30, 40);
        compare(menu.entry, 1, "the menu without its fade");
        choose("groß");
        verify(!named("presence").running, "the size at once");
        compare(pinnedTile("Dolphin").contentOpacity, 1);
        rightClick(pinnedTile("Dolphin"), 30, 40);
        choose("lösen");
        verify(!named("presence").running, "leaving at once");
        compare(pinnedNames(), ["Systemeinstellungen", "Konsole"]);
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        verify(!named("presence").running, "arriving at once");
        compare(pinnedNames(), ["Systemeinstellungen", "Dolphin", "Konsole"]);
    }

    // Contact sheets: the menu opened by the pointer and by the keys, each size, the empty section, the disabled items.

    Component {
        id: backdropComponent

        Rectangle {
            width: testCase.width
            height: testCase.height
            color: Tokens.color.bg
        }
    }

    // Drawn at rest: without motion, so no colour or tile is caught on its way.
    function sheet(name: string, theme: string, prepare: var) {
        Prefs.motion = "off";
        Prefs.theme = theme;
        const backdrop = createTemporaryObject(backdropComponent, testCase);
        start.parent = backdrop;
        mouseMove(backdrop, backdrop.width - 1, backdrop.height - 1);
        start.open();
        waitForRendering(backdrop);
        prepare();
        waitForRendering(backdrop);
        grabImage(backdrop).save(`startpins-${name}-${theme}.png`);
        start.parent = testCase;
        Prefs.motion = "system";
    }

    function test_contact_sheets_in_both_themes() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            sheet("menu-pointer", theme, () => rightClick(pinnedTile("Dolphin"), 60, 50));
            menu.close(false);
            sheet("menu-keys", theme, () => {
                pinnedTile("Konsole").forceActiveFocus();
                keyClick(Qt.Key_Menu);
            });
            verify(menu.items()[0].activeFocus, theme);
            menu.close(false);
            sheet("sizes", theme, () => {
                file.text = fileText([
                    { id: "org.kde.kate", columns: 4, rows: 2 },
                    { id: "org.kde.dolphin", columns: 2, rows: 2 },
                    { id: "org.kde.konsole", columns: 2, rows: 1 },
                    { id: "systemsettings", columns: 1, rows: 1 }
                ]);
            });
            sheet("empty", theme, () => file.text = fileText([]));
            verify(named("noPins").visible, theme);
            sheet("disabled", theme, () => {
                file.text = "{ broken";
                waitForRendering(start);
                rightClick(pinnedTile("Dolphin"), 60, 50);
            });
            menu.close(false);
            Prefs.motion = "off";
            file.text = usersFile;
            Prefs.motion = "system";
        }
    }
}
