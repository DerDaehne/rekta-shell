pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Settings
import SettingsApp
import Start
import "ContactSheets.js" as ContactSheets

// The group "angeheftet" of the settings app's place "start": the pinned apps as rows, pinned, unpinned, sized and
// ordered there, with undo in a toast that hangs from the top, and live with the Start through start.json.
TestCase {
    id: testCase

    name: "SettingsPins"
    visible: true
    when: windowShown
    width: 1000
    height: 800

    readonly property string pinkIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAGklEQVR4nGN4aTWLbMQwqnlU86jmUc0DqxkAreu3b+7dCC4AAAAASUVORK5CYII="

    function installedApp(id: string, name: string): var {
        return {
            id: id,
            name: name,
            genericName: "",
            keywords: [],
            exec: "",
            icon: testCase.pinkIcon,
            launch: () => {}
        };
    }

    // A–Z, as the app model lists them.
    readonly property var installed: [installedApp("org.kde.dolphin", "Dolphin"), installedApp("org.kde.kate", "Kate"), installedApp("org.kde.konsole", "Konsole"), installedApp("systemsettings", "Systemeinstellungen")]

    // start.json with a key of the user's own on the file and on an entry, an app that is not installed and a size
    // written by hand.
    function fileText(pinned: var): string {
        return JSON.stringify({
            theme: "kept",
            pinned: pinned
        }, null, 2) + "\n";
    }

    readonly property string usersFile: fileText([
        { id: "systemsettings" },
        { id: "org.kde.dolphin", columns: 2, rows: 1, group: "files" },
        { id: "org.gone.app", columns: 1, rows: 1 },
        { id: "org.kde.konsole", columns: 3, rows: 1 }
    ])

    // The app's view, as settings/shell.qml holds it.
    Component {
        id: hostComponent

        Item {
            id: host

            property string startText
            property alias view: inner
            property alias file: pins

            width: 900
            height: 700

            Layers {
                id: layers

                writable: true
            }

            FakeStartFile {
                id: pins

                text: host.startText
            }

            SettingsView {
                id: inner

                anchors.fill: parent
                settings: layers
                startFile: pins
                apps: testCase.installed
            }
        }
    }

    // The Start and the app side by side, each with its own reader of one start.json, as two processes share it.
    Component {
        id: bothComponent

        Item {
            id: both

            property alias view: inner
            property alias start: place
            property alias appFile: appPins
            property alias startFile: startPins

            width: testCase.width
            height: testCase.height

            FakeStartFile {
                id: appPins

                text: testCase.usersFile
                onWrote: next => startPins.text = next
            }

            FakeStartFile {
                id: startPins

                text: testCase.usersFile
                onWrote: next => appPins.text = next
            }

            Layers {
                id: layers

                writable: true
            }

            SettingsView {
                id: inner

                width: 900
                height: 700
                settings: layers
                startFile: appPins
                apps: testCase.installed
            }

            StartPlace {
                id: place

                visible: false
                width: 1600
                height: 900
                windows: []
                apps: testCase.installed
                pinFile: startPins
                pinned: Rules.pinnedTiles(startPins.list, id => testCase.installed.some(app => app.id === id)).map(tile => Object.assign({}, testCase.installed.find(app => app.id === tile.id), tile))
            }
        }
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var host: null
    property var view: null
    property var file: null

    function make(text: string) {
        host = createTemporaryObject(hostComponent, testCase, { startText: text });
        view = host.view;
        file = host.file;
        Prefs.motion = "off";
        findChild(view, "pivot").select(1);
        waitForRendering(view);
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop|Unable to assign/);
        make(usersFile);
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function group(): var {
        return findChild(view, "group-angeheftet").children[1].item;
    }

    function rowsOf(pinned: var): var {
        return pinned.rows.all().sort((a, b) => a.index - b.index);
    }

    function rows(): var {
        return rowsOf(group());
    }

    function titles(): var {
        return rows().map(row => row.title);
    }

    function row(title: string): var {
        return rows().find(each => each.title === title);
    }

    function listedIds(): var {
        return JSON.parse(file.text).pinned.map(entry => entry.id);
    }

    function combo(): var {
        return group().choice;
    }

    function pinButton(): var {
        return findChild(group(), "pin");
    }

    function toast(): var {
        return view.toaster.open;
    }

    function choose(id: string) {
        combo().open();
        combo().choose(combo().shown.findIndex(option => option.value === id));
    }

    // Pulls a row's name towards the trailing edge by a share of the row's width and lets it go.
    function pull(target: var, share: real) {
        const scene = view.Window.window.contentItem;
        const from = findChild(target, "pullArea").mapToItem(scene, 40, target.height / 2);
        const to = from.x + share * target.width;
        mousePress(scene, from.x, from.y);
        mouseMove(scene, from.x + 20, from.y);
        mouseMove(scene, (from.x + to) / 2, from.y);
        mouseMove(scene, to, from.y);
        mouseRelease(scene, to, from.y);
    }

    function test_each_entry_of_the_file_is_a_row_in_the_files_order_with_grip_icon_name_size_and_loesen() {
        compare(titles(), ["Systemeinstellungen", "Dolphin", "org.gone.app", "Konsole"]);
        const dolphin = row("Dolphin");
        verify(dolphin.grip.visible);
        compare(dolphin.grip.Accessible.name, "Dolphin verschieben");
        compare(findChild(dolphin, "icon").source.toString(), pinkIcon);
        compare(findChild(dolphin, "icon").width, Geometry.iconSize);
        compare(findChild(dolphin, "name").text, "Dolphin");
        compare(findChild(dolphin, "size").currentText, "breit");
        const remove = findChild(dolphin, "remove");
        compare(remove.icon, "close");
        compare(remove.variant, "quiet");
        compare(remove.tip, "lösen");
        verify(findChild(dolphin, "size").x < remove.x, "the size stands before lösen");
        compare(dolphin.height, Tokens.rowHeight);
        compare(findChild(dolphin, "hairline").y, 0, "on a hairline");
    }

    function test_without_a_list_the_rows_show_the_defaults() {
        make(JSON.stringify({ theme: "kept" }));
        compare(titles(), ["Systemeinstellungen", "Dolphin", "Konsole"]);
        make("");
        compare(titles(), ["Systemeinstellungen", "Dolphin", "Konsole"]);
    }

    function test_the_first_change_without_a_list_writes_the_defaults_with_it() {
        make("");
        findChild(row("Konsole"), "remove").clicked();
        tryCompare(file, "text", fileText([{ id: "systemsettings" }, { id: "org.kde.dolphin" }]).replace('"theme": "kept",\n  ', ""));
    }

    function test_an_app_that_is_not_installed_shows_its_id_and_nicht_installiert() {
        const gone = row("org.gone.app");
        verify(findChild(gone, "missing").visible);
        compare(findChild(gone, "missing").text, "nicht installiert");
        verify(!findChild(row("Dolphin"), "missing").visible);
    }

    function test_an_app_that_is_not_installed_can_be_moved_and_unpinned() {
        const gone = row("org.gone.app");
        gone.grip.forceActiveFocus();
        keyClick(Qt.Key_Up, Qt.AltModifier);
        compare(listedIds(), ["systemsettings", "org.gone.app", "org.kde.dolphin", "org.kde.konsole"]);
        keyClick(Qt.Key_Delete);
        tryCompare(testCase, "listedIdsNow", ["systemsettings", "org.kde.dolphin", "org.kde.konsole"]);
    }

    readonly property var listedIdsNow: file ? Pins.read(file.text).list?.map(entry => entry.id) ?? null : null

    function test_an_empty_list_shows_rektas_empty_state() {
        make(fileText([]));
        compare(rows().length, 0);
        const empty = findChild(group(), "empty");
        verify(empty.visible);
        compare(empty.text, "nichts angeheftet.");
        verify(combo().visible, "the way on, pinning, stays below");
    }

    function test_unpinning_the_last_row_shows_the_empty_state_and_hands_the_focus_to_the_combobox() {
        make(fileText([{ id: "org.kde.kate" }]));
        row("Kate").grip.forceActiveFocus();
        keyClick(Qt.Key_Delete);
        tryCompare(rows(), "length", 0);
        verify(findChild(group(), "empty").visible);
        verify(findChild(combo(), "input").activeFocus);
    }

    function test_a_broken_file_shows_the_defaults_with_every_control_disabled_and_saying_why() {
        make("{ not json");
        compare(titles(), ["Systemeinstellungen", "Dolphin", "Konsole"]);
        for (const each of rows()) {
            compare(each.grip.disabledReason, "datei nicht lesbar");
            compare(findChild(each, "size").disabledReason, "datei nicht lesbar");
            compare(findChild(each, "remove").disabledReason, "datei nicht lesbar");
        }
        compare(combo().disabledReason, "datei nicht lesbar");
        compare(pinButton().disabledReason, "datei nicht lesbar");
        compare(findChild(findChild(group(), "add"), "hint").text, "start.json ist kein gültiges json. korrigiere oder lösche die datei, dann lässt sich hier wieder etwas ändern.");
    }

    function test_a_broken_file_stays_byte_identical_whatever_is_tried() {
        const broken = "{ not json";
        make(broken);
        const first = rows()[0];
        first.grip.forceActiveFocus();
        keyClick(Qt.Key_Down, Qt.AltModifier);
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Delete);
        findChild(first, "remove").clicked();
        group().remove(first);
        findChild(first, "size").activated(2);
        group().pin("org.kde.kate");
        pull(first, 0.8);
        wait(Tokens.durationModerate);
        compare(file.text, broken);
        verify(!first.going);
        compare(first.grip.Accessible.checked, false, "nothing was picked up");
    }

    function test_the_combobox_lists_every_app_and_greys_the_pinned_ones_with_the_reason() {
        compare(combo().options.map(option => option.label), ["Dolphin", "Kate", "Konsole", "Systemeinstellungen"]);
        compare(combo().options.map(option => option.disabledReason), ["angeheftet", "", "angeheftet", "angeheftet"]);
        compare(combo().label, "app");
    }

    function test_anheften_is_disabled_until_an_app_is_chosen() {
        compare(pinButton().disabledReason, "wähle eine app");
        pinButton().click();
        compare(file.text, usersFile);
        choose("org.kde.kate");
        compare(pinButton().disabledReason, "");
    }

    function test_choosing_an_app_does_not_pin_it_yet() {
        choose("org.kde.kate");
        compare(file.text, usersFile);
    }

    function test_anheften_puts_the_app_at_the_end_as_one_by_one_and_clears_the_field() {
        choose("org.kde.kate");
        pinButton().click();
        const listed = JSON.parse(file.text);
        compare(listed.pinned[4], { id: "org.kde.kate", columns: 1, rows: 1 });
        compare(listed.theme, "kept");
        compare(titles(), ["Systemeinstellungen", "Dolphin", "org.gone.app", "Konsole", "Kate"]);
        compare(combo().value, undefined);
        compare(findChild(combo(), "input").text, "");
        compare(pinButton().disabledReason, "wähle eine app");
        compare(toast().text, "Kate angeheftet");
        compare(combo().options[1].disabledReason, "angeheftet", "now greyed");
    }

    function test_a_pinned_row_arrives_six_pixels_from_above_fading_in_over_duration_short() {
        Prefs.motion = "on";
        choose("org.kde.kate");
        pinButton().click();
        const kate = row("Kate");
        compare(kate.arriving, 1);
        compare(kate.transform[0].y, -Geometry.rowEnterShift);
        compare(kate.opacity, 0);
        tryCompare(kate, "arriving", 0, Tokens.durationShort + 500);
        compare(kate.opacity, 1);
    }

    function test_the_first_rows_do_not_arrive() {
        for (const each of rows())
            compare(each.arriving, 0);
    }

    function test_loesen_unpins_the_row_and_says_so_in_a_toast() {
        findChild(row("Dolphin"), "remove").clicked();
        tryCompare(testCase, "listedIdsNow", ["systemsettings", "org.gone.app", "org.kde.konsole"]);
        compare(titles(), ["Systemeinstellungen", "org.gone.app", "Konsole"]);
        compare(toast().text, "Dolphin gelöst");
        compare(toast().actionLabel, "rückgängig");
    }

    function test_a_leaving_row_drifts_twelve_pixels_and_fades_over_point_six_of_duration_short() {
        Prefs.motion = "on";
        const dolphin = row("Dolphin");
        findChild(dolphin, "remove").clicked();
        verify(dolphin.going);
        compare(file.text, usersFile, "the entry goes once the row has left");
        const goingOut = findChild(dolphin, "goingOut");
        compare(goingOut.duration, Geometry.rowLeaveShare * Tokens.durationShort);
        compare(goingOut.easing.bezierCurve, Tokens.easeOut);
        tryVerify(() => dolphin.leaving > 0.3 && dolphin.leaving < 1);
        fuzzyCompare(dolphin.transform[0].x, dolphin.leaving * Geometry.rowLeaveDrift, 0.01);
        fuzzyCompare(dolphin.opacity, 1 - dolphin.leaving, 0.01);
        tryCompare(testCase, "listedIdsNow", ["systemsettings", "org.gone.app", "org.kde.konsole"], Geometry.rowLeaveShare * Tokens.durationShort + 500);
    }

    function test_after_a_row_has_left_the_others_close_the_gap_over_duration_moderate() {
        Prefs.motion = "on";
        const gone = row("org.gone.app");
        findChild(row("Dolphin"), "remove").clicked();
        tryCompare(testCase, "listedIdsNow", ["systemsettings", "org.gone.app", "org.kde.konsole"]);
        verify(gone.offset > 0, "it starts where it showed");
        wait(Tokens.durationShort + 50);
        verify(gone.offset > 0, "still closing after duration-short");
        tryCompare(gone, "offset", 0, Tokens.durationModerate);
    }

    function test_delete_unpins_the_row_with_the_focus_on_any_of_its_controls() {
        findChild(row("Dolphin"), "size").forceActiveFocus();
        keyClick(Qt.Key_Delete);
        tryCompare(testCase, "listedIdsNow", ["systemsettings", "org.gone.app", "org.kde.konsole"]);
        findChild(row("Konsole"), "remove").forceActiveFocus();
        keyClick(Qt.Key_Delete);
        tryCompare(testCase, "listedIdsNow", ["systemsettings", "org.gone.app"]);
    }

    function test_backspace_does_not_unpin() {
        row("Dolphin").grip.forceActiveFocus();
        keyClick(Qt.Key_Backspace);
        wait(50);
        compare(file.text, usersFile);
    }

    function test_unpinning_hands_the_focus_to_the_same_control_of_the_next_row_at_the_end_to_the_one_before() {
        findChild(row("Dolphin"), "remove").forceActiveFocus();
        keyClick(Qt.Key_Delete);
        verify(findChild(row("org.gone.app"), "remove").activeFocus);
        row("Konsole").grip.forceActiveFocus();
        keyClick(Qt.Key_Delete);
        verify(row("org.gone.app").grip.activeFocus);
    }

    function test_a_row_pulled_past_half_its_width_is_unpinned() {
        pull(row("Dolphin"), 0.5 + 0.02);
        tryCompare(testCase, "listedIdsNow", ["systemsettings", "org.gone.app", "org.kde.konsole"]);
        compare(toast().text, "Dolphin gelöst");
    }

    function test_a_row_pulled_short_of_half_its_width_glides_back() {
        const dolphin = row("Dolphin");
        pull(dolphin, 0.5 - 0.02);
        tryCompare(dolphin, "pulled", 0);
        compare(file.text, usersFile);
        verify(!dolphin.going);
    }

    function test_a_pull_never_starts_on_a_control_of_the_row() {
        const dolphin = row("Dolphin");
        for (const name of ["size", "remove"]) {
            const control = findChild(dolphin, name);
            mousePress(control, 4, control.height / 2);
            mouseMove(control, 30, control.height / 2);
            mouseMove(control, dolphin.width, control.height / 2);
            compare(dolphin.pulled, 0, name);
            mouseRelease(control, dolphin.width, control.height / 2);
        }
        dolphin.grip.forceActiveFocus();
        compare(file.text, usersFile);
    }
    // The view moved so that the row's name starts at the window's leading edge: a finger there is the edge's.
    // The view moved so that the row.s name starts at the window.s leading edge: a finger there is the edge.s.
    function test_a_finger_pull_from_within_space_l_of_the_windows_edge_does_nothing_and_a_mouse_pull_does() {
        const dolphin = row("Dolphin");
        const area = findChild(dolphin, "pullArea");
        host.x = -area.mapToItem(host, 0, 0).x;
        const scene = view.Window.window.contentItem;
        const from = area.mapToItem(scene, Tokens.spaceL - 2, area.height / 2);
        verify(from.x < Tokens.spaceL);
        const by = 0.8 * dolphin.width;
        const touch = touchEvent(scene);
        touch.press(0, scene, from.x, from.y).commit();
        for (let step = 1; step <= 10; ++step)
            touch.move(0, scene, from.x + by * step / 10, from.y).commit();
        compare(dolphin.pulled, 0, "the finger at the edge moves nothing");
        touch.release(0, scene, from.x + by, from.y).commit();
        wait(Tokens.durationShort);
        compare(file.text, usersFile);
        mousePress(scene, from.x, from.y);
        mouseMove(scene, from.x + 20, from.y);
        mouseMove(scene, from.x + by / 2, from.y);
        mouseMove(scene, from.x + by, from.y);
        verify(dolphin.pulled > 0, "a mouse pulls from anywhere");
        mouseRelease(scene, from.x + by, from.y);
        tryCompare(testCase, "listedIdsNow", ["systemsettings", "org.gone.app", "org.kde.konsole"]);
    }

    function test_a_finger_pull_away_from_the_edge_unpins() {
        const dolphin = row("Dolphin");
        const scene = view.Window.window.contentItem;
        const from = findChild(dolphin, "pullArea").mapToItem(scene, 60, dolphin.height / 2);
        verify(from.x > Tokens.spaceL);
        const by = 0.8 * dolphin.width;
        const touch = touchEvent(scene);
        touch.press(0, scene, from.x, from.y).commit();
        for (let step = 1; step <= 10; ++step)
            touch.move(0, scene, from.x + by * step / 10, from.y).commit();
        touch.release(0, scene, from.x + by, from.y).commit();
        tryCompare(testCase, "listedIdsNow", ["systemsettings", "org.gone.app", "org.kde.konsole"]);
    }

    function test_the_size_offers_klein_breit_gross_and_sehr_gross_with_the_current_one_chosen() {
        const size = findChild(row("Systemeinstellungen"), "size");
        compare(size.options.map(option => option.text), ["klein", "breit", "groß", "sehr groß"]);
        compare(size.currentText, "klein");
        compare(size.label, "größe von Systemeinstellungen");
    }

    function test_a_size_written_by_hand_is_one_more_option_only_in_its_row() {
        const konsole = findChild(row("Konsole"), "size");
        compare(konsole.options.map(option => option.text), ["klein", "breit", "groß", "sehr groß", "3×1"]);
        compare(konsole.currentText, "3×1");
        compare(findChild(row("Dolphin"), "size").options.length, 4);
    }

    function test_another_choice_replaces_a_size_written_by_hand() {
        findChild(row("Konsole"), "size").activated(2);
        const konsole = JSON.parse(file.text).pinned[3];
        compare([konsole.columns, konsole.rows], [2, 2]);
        compare(findChild(row("Konsole"), "size").options.length, 4);
        compare(findChild(row("Konsole"), "size").currentText, "groß");
    }

    function test_choosing_a_size_resizes_the_entry_says_so_and_the_row_stays() {
        const dolphin = row("Dolphin");
        findChild(dolphin, "size").activated(3);
        const entry = JSON.parse(file.text).pinned[1];
        compare(entry, { id: "org.kde.dolphin", columns: 4, rows: 2, group: "files" });
        compare(toast().text, "Dolphin: sehr groß");
        compare(row("Dolphin"), dolphin);
        compare(dolphin.index, 1);
        compare(findChild(dolphin, "size").currentText, "sehr groß");
    }

    function test_choosing_the_current_size_writes_nothing() {
        findChild(row("Dolphin"), "size").activated(1);
        compare(file.text, usersFile);
        compare(toast(), null);
    }

    function test_alt_down_on_a_grip_moves_the_entry_by_its_index_in_the_whole_list_without_a_toast() {
        const settings = row("Systemeinstellungen");
        settings.grip.forceActiveFocus();
        keyClick(Qt.Key_Down, Qt.AltModifier);
        keyClick(Qt.Key_Down, Qt.AltModifier);
        compare(listedIds(), ["org.kde.dolphin", "org.gone.app", "systemsettings", "org.kde.konsole"]);
        compare(JSON.parse(file.text).pinned[0].group, "files", "the other keys stay");
        compare(titles(), ["Dolphin", "org.gone.app", "Systemeinstellungen", "Konsole"]);
        verify(settings.grip.activeFocus, "the moved row keeps its grip's focus");
        compare(toast(), null);
    }

    function test_picking_up_moving_and_putting_down_writes_each_step() {
        row("Konsole").grip.forceActiveFocus();
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Up);
        compare(listedIds(), ["systemsettings", "org.kde.dolphin", "org.kde.konsole", "org.gone.app"]);
        keyClick(Qt.Key_Space);
        compare(group().rows.grabbedRow, null);
        compare(toast(), null);
    }

    function test_dragging_a_grip_moves_the_entry() {
        const settings = row("Systemeinstellungen");
        const list = group().rows;
        const x = Geometry.gripWidth / 2;
        const y = settings.height / 2;
        mousePress(list, x, y);
        mouseMove(list, x, y + settings.height, -1, Qt.LeftButton);
        mouseMove(list, x, y + 2 * settings.height + 1, -1, Qt.LeftButton);
        mouseRelease(list, x, y + 2 * settings.height + 1);
        compare(listedIds(), ["org.kde.dolphin", "org.gone.app", "systemsettings", "org.kde.konsole"]);
        compare(toast(), null);
    }

    function test_after_a_move_the_rows_settle_over_duration_moderate() {
        Prefs.motion = "on";
        const settings = row("Systemeinstellungen");
        settings.grip.forceActiveFocus();
        keyClick(Qt.Key_Down, Qt.AltModifier);
        verify(settings.offset < 0, "it glides from where it showed");
        wait(Tokens.durationShort + 50);
        verify(settings.offset < 0, "still settling after duration-short");
        tryCompare(settings, "offset", 0, Tokens.durationModerate);
    }

    function test_undoing_an_unpin_puts_the_entry_back_byte_identically_and_it_arrives() {
        findChild(row("Dolphin"), "remove").clicked();
        tryCompare(testCase, "listedIdsNow", ["systemsettings", "org.gone.app", "org.kde.konsole"]);
        Prefs.motion = "on";
        toast().undo();
        compare(file.text, usersFile);
        verify(row("Dolphin").arriving > 0);
    }

    function test_undoing_a_resize_puts_the_size_back_byte_identically() {
        findChild(row("Dolphin"), "size").activated(0);
        verify(file.text !== usersFile);
        toast().undo();
        compare(file.text, usersFile);
        compare(findChild(row("Dolphin"), "size").currentText, "breit");
    }

    function test_undoing_a_pin_puts_the_file_back_byte_identically() {
        choose("org.kde.kate");
        pinButton().click();
        toast().undo();
        compare(file.text, usersFile);
    }

    function test_undo_finds_the_entry_by_its_app_after_a_move() {
        findChild(row("Konsole"), "size").activated(0);
        row("Konsole").grip.forceActiveFocus();
        keyClick(Qt.Key_Up, Qt.AltModifier);
        toast().undo();
        compare(listedIds(), ["systemsettings", "org.kde.dolphin", "org.kde.konsole", "org.gone.app"]);
        const konsole = JSON.parse(file.text).pinned[2];
        compare([konsole.columns, konsole.rows], [3, 1]);
    }

    function test_ctrl_z_while_the_toast_stands_undoes() {
        const dolphin = row("Dolphin");
        dolphin.grip.forceActiveFocus();
        keyClick(Qt.Key_Delete);
        tryCompare(testCase, "listedIdsNow", ["systemsettings", "org.gone.app", "org.kde.konsole"]);
        verify(row("org.gone.app").grip.activeFocus);
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(file.text, usersFile);
    }

    function test_ctrl_z_in_the_combobox_does_not_undo() {
        findChild(row("Dolphin"), "size").activated(0);
        const changed = file.text;
        findChild(combo(), "input").forceActiveFocus();
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(file.text, changed);
        verify(toast() !== null);
    }

    function test_a_new_toast_replaces_the_open_one() {
        findChild(row("Dolphin"), "size").activated(0);
        findChild(row("Konsole"), "size").activated(0);
        compare(toast().text, "Konsole: klein");
        toast().undo();
        const listed = JSON.parse(file.text).pinned;
        compare([listed[1].columns, listed[3].columns], [1, 3], "only the newest change comes back");
    }

    function test_the_apps_toast_hangs_from_the_top_centre() {
        findChild(row("Dolphin"), "size").activated(0);
        const shown = toast();
        verify(view.toaster.hangsFromTop);
        compare(view.toaster.y, 0);
        compare(shown.x, (view.width - shown.width) / 2);
        compare(shown.y, Tokens.spaceM);
        verify(shown.width <= Geometry.toastMaxWidth);
    }

    function test_tab_reaches_grip_size_and_loesen_of_each_row_then_the_combobox_and_anheften() {
        const first = rows()[0];
        first.grip.forceActiveFocus();
        const reached = [];
        for (let step = 0; step < 3 * 4 + 2; ++step) {
            const item = view.Window.activeFocusItem;
            const owner = rows().find(each => each.holds(item));
            reached.push(owner ? `${owner.index} ${owner.partWithFocus()}` : item.objectName || item.parent.objectName);
            keyClick(Qt.Key_Tab);
        }
        compare(reached, ["0 grip", "0 size", "0 remove", "1 grip", "1 size", "1 remove", "2 grip", "2 size", "2 remove", "3 grip", "3 size", "3 remove", "input", "pin"]);
    }

    function test_escape_puts_a_picked_up_row_back_before_it_goes_back_a_place() {
        findChild(view, "pivot").select(0);
        findChild(view, "pivot").select(1);
        const konsole = row("Konsole");
        konsole.grip.forceActiveFocus();
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Escape);
        compare(listedIds(), ["systemsettings", "org.kde.dolphin", "org.gone.app", "org.kde.konsole"]);
        compare(findChild(view, "pivot").currentIndex, 1);
        keyClick(Qt.Key_Escape);
        compare(findChild(view, "pivot").currentIndex, 0);
    }

    function test_escape_folds_an_open_size_before_it_goes_back_a_place() {
        findChild(view, "pivot").select(0);
        findChild(view, "pivot").select(1);
        const size = findChild(row("Dolphin"), "size");
        size.forceActiveFocus();
        keyClick(Qt.Key_Down, Qt.AltModifier);
        verify(size.expanded);
        keyClick(Qt.Key_Escape);
        verify(!size.expanded);
        compare(findChild(view, "pivot").currentIndex, 1);
    }

    function test_under_reduced_motion_everything_happens_at_once() {
        Prefs.motion = "off";
        const dolphin = row("Dolphin");
        const gone = row("org.gone.app");
        findChild(dolphin, "remove").clicked();
        compare(listedIds(), ["systemsettings", "org.gone.app", "org.kde.konsole"], "the row has left at once");
        compare(gone.offset, 0, "the gap closed at once");
        compare(toast().y, Tokens.spaceM, "the toast stands at once");
        toast().undo();
        compare(row("Dolphin").arriving, 0, "it is back at once");
        row("Konsole").grip.forceActiveFocus();
        keyClick(Qt.Key_Up, Qt.AltModifier);
        compare(row("Konsole").offset, 0, "settled at once");
    }

    // The Start and the app, each with a reader of the same start.json.
    function makeBoth(): var {
        const pair = createTemporaryObject(bothComponent, testCase);
        Prefs.motion = "off";
        findChild(pair.view, "pivot").select(1);
        view = pair.view;
        file = pair.appFile;
        return pair;
    }

    function startNames(start: var): var {
        return start.pinned.map(app => app.name);
    }

    function test_a_change_in_the_start_shows_in_the_list_at_once() {
        const pair = makeBoth();
        pair.start.pinApp(installedApp("org.kde.kate", "Kate"));
        compare(titles(), ["Systemeinstellungen", "Dolphin", "org.gone.app", "Konsole", "Kate"]);
        pair.startFile.unpin(1);
        compare(titles(), ["Systemeinstellungen", "org.gone.app", "Konsole", "Kate"]);
        pair.startFile.resize(0, 2, 2);
        compare(findChild(row("Systemeinstellungen"), "size").currentText, "groß");
    }

    function test_a_change_here_shows_in_the_start_at_once() {
        const pair = makeBoth();
        compare(startNames(pair.start), ["Systemeinstellungen", "Dolphin", "Konsole"]);
        findChild(row("Dolphin"), "remove").clicked();
        compare(startNames(pair.start), ["Systemeinstellungen", "Konsole"]);
        choose("org.kde.kate");
        pinButton().click();
        compare(startNames(pair.start), ["Systemeinstellungen", "Konsole", "Kate"]);
        row("Kate").grip.forceActiveFocus();
        keyClick(Qt.Key_Up, Qt.AltModifier);
        keyClick(Qt.Key_Up, Qt.AltModifier);
        compare(startNames(pair.start), ["Systemeinstellungen", "Kate", "Konsole"]);
        findChild(row("Kate"), "size").activated(1);
        compare(pair.start.pinned.find(app => app.name === "Kate").columns, 2);
    }

    function test_a_row_with_the_focus_gone_from_elsewhere_hands_the_focus_on() {
        const pair = makeBoth();
        findChild(row("Dolphin"), "size").forceActiveFocus();
        pair.startFile.unpin(1);
        verify(findChild(row("org.gone.app"), "size").activeFocus);
        row("Konsole").grip.forceActiveFocus();
        pair.startFile.unpin(2);
        verify(row("org.gone.app").grip.activeFocus);
    }

    function test_a_change_from_elsewhere_ends_a_pick_up_and_the_file_holds() {
        const pair = makeBoth();
        const konsole = row("Konsole");
        konsole.grip.forceActiveFocus();
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Up);
        verify(group().rows.grabbedRow === konsole);
        pair.startFile.unpin(0);
        compare(group().rows.grabbedRow, null);
        const before = pair.startFile.text;
        keyClick(Qt.Key_Up);
        compare(pair.startFile.text, before, "the arrows no longer move it");
        compare(titles(), ["Dolphin", "Konsole", "org.gone.app"]);
    }

    function test_a_change_from_elsewhere_ends_a_drag() {
        const pair = makeBoth();
        const settings = row("Systemeinstellungen");
        const list = group().rows;
        const x = Geometry.gripWidth / 2;
        const y = settings.height / 2;
        mousePress(list, x, y);
        mouseMove(list, x, y + settings.height, -1, Qt.LeftButton);
        verify(list.draggedRow === settings);
        pair.startFile.resize(3, 1, 1);
        compare(list.draggedRow, null);
        mouseMove(list, x, y + 2 * settings.height + 1, -1, Qt.LeftButton);
        mouseRelease(list, x, y + 2 * settings.height + 1);
        compare(listedIds(), ["systemsettings", "org.kde.dolphin", "org.gone.app", "org.kde.konsole"]);
        compare(settings.offset, 0);
    }

    // The group at rest, empty, broken, with the combobox open and with a row picked up, in both themes.
    function test_contact_sheet() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const states = [["list", usersFile, () => {}], ["empty", fileText([]), () => {}], ["broken", "{ not json", () => {}], ["combobox", usersFile, () => {
                        findChild(combo(), "input").forceActiveFocus();
                        keyClick(Qt.Key_K);
                        keyClick(Qt.Key_Down);
                    }], ["picked-up", usersFile, () => {
                        row("Dolphin").grip.forceActiveFocus();
                        keyClick(Qt.Key_Space);
                    }], ["toast", usersFile, () => findChild(row("Dolphin"), "size").activated(0)]];
            for (const [name, text, act] of states) {
                make(text);
                act();
                waitForRendering(view);
                grabImage(view).save(`settingspins-sheet-${theme}-${name}.png`);
            }
        }
    }
}
