pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Tray
import "ContactSheets.js" as ContactSheets
import "Ink.js" as Ink

TestCase {
    id: testCase

    name: "Tray"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 800
    height: 500

    // What the fake apps and entries were asked to do, oldest first.
    property var calls: []
    // The icon names the stand-in for the icon theme was asked about, oldest first.
    property var asked: []

    // A DBusMenu's entries, as the opener lists them.
    component FakeMenu: QtObject {
        property var entries: []
    }

    component FakeEntry: QtObject {
        id: entry

        property string text
        // An image URL, empty when the entry has none.
        property string icon
        property bool enabled: true
        property bool isSeparator: false
        // 0 none, 1 checkbox, 2 radio
        property int buttonType: 0
        property int checkState: Qt.Unchecked
        property bool hasChildren: entries.length > 0
        property var entries: []

        signal triggered

        onTriggered: testCase.calls = [...testCase.calls, `triggered ${text}`]
    }

    component FakeApp: QtObject {
        id: app

        property string word
        property string icon
        property string state
        property bool hasMenu: menu !== null
        property FakeMenu menu: null

        function activate() {
            testCase.calls = [...testCase.calls, `activate ${word}`];
        }
    }

    // What QsMenuOpener gives: the entries of the menu it was pointed at.
    Component {
        id: fakeOpener

        QtObject {
            id: opener

            property var menu: null
            readonly property QtObject children: QtObject {
                property var values: opener.menu?.entries ?? []
            }
        }
    }

    Component {
        id: entryComponent

        FakeEntry {}
    }

    Component {
        id: menuComponent

        FakeMenu {}
    }

    Component {
        id: appComponent

        FakeApp {}
    }

    // The bar with the control among others, and its menu above it.
    Component {
        id: sceneComponent

        Item {
            id: scene

            property var apps: []
            property alias bar: appBar
            property alias control: background

            width: 800
            height: 500

            Rectangle {
                anchors.fill: parent
                color: Tokens.color.bg
            }

            AppBar {
                id: appBar

                objectName: "bar"
                y: scene.height - height
                width: scene.width
                area: Qt.size(scene.width, scene.height)

                AppBarButton {
                    objectName: "goto"
                    icon: "search"
                    text: "back"
                    priority: 3
                }

                BackgroundControl {
                    id: background

                    objectName: "background"
                    apps: scene.apps
                    area: appBar.area
                    opener: fakeOpener
                    priority: 0
                }

                AppBarButton {
                    objectName: "messages"
                    icon: "bell"
                    text: "meldungen"
                    priority: 2
                    disabledReason: "kommt mit dem panel"
                }
            }

            // Like the shell's popup, the menu stands apart from the bar, above it.
            Component.onCompleted: {
                background.menu.parent = scene;
                background.menu.x = Tokens.spaceXl;
            }

            Binding {
                target: background.menu
                property: "y"
                value: appBar.y - background.menu.height - Tokens.spaceXs
            }
        }
    }

    // A coloured 20 × 20 square as PNG, as an app's own icon is coloured.
    readonly property string blueIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAGklEQVR4nGOQnfmZbMQwqnlU86jmUc0DqxkAaSeYL8S+KvQAAAAASUVORK5CYII="

    // A 16 × 16 one, as a DBusMenu hands over the PNG of an entry at its own size.
    readonly property string smallIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAFklEQVR42mOwKvtAEmIY1TCqYfhqAAByVKAQbSDPuAAAAABJRU5ErkJggg=="
    // Icon names as Quickshell hands them over; the stand-in for the icon theme knows only mail-client.
    readonly property string knownIcon: "image://icon/mail-client"
    readonly property string unknownIcon: "image://icon/no-such-icon"
    // The same name with the app's own icon directory, where Quickshell's provider looks too.
    readonly property string unknownIconInAppDirectory: "image://icon/no-such-icon?path=/opt/mail/icons"

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var scene

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        calls = [];
        asked = [];
    }

    function cleanup() {
        Prefs.theme = "system";
        Prefs.density = "auto";
        Prefs.motion = "system";
    }

    function entry(text: string, props: var): QtObject {
        return createTemporaryObject(entryComponent, testCase, Object.assign({ text }, props ?? {}));
    }

    function menuOf(entries: var): var {
        return createTemporaryObject(menuComponent, testCase, { entries });
    }

    function app(word: string, props: var): QtObject {
        return createTemporaryObject(appComponent, testCase, Object.assign({ word, icon: blueIcon }, props ?? {}));
    }

    // Three apps: one with a state, a menu and a submenu, one with a menu, one that has none.
    function threeApps(): var {
        const device = entry("Pair", { entries: [entry("Ping"), entry("Send file")] });
        return [
            app("Nextcloud", { state: "Synchronisiert", menu: menuOf([entry("Open folder"), entry("Pause", { buttonType: 1 }), entry("Devices", { entries: [device, entry("Refresh")] })]) }),
            app("KDE Connect", { menu: menuOf([entry("Browse"), entry("Quit", { enabled: false })]) }),
            app("Steam", {})
        ];
    }

    // One app whose menu has the given entries.
    function mail(entries: var): var {
        return [app("Mail", { menu: menuOf(entries) })];
    }

    // The stand-in for the icon theme. The rows ask it in their bindings, so it adds to the list in place.
    function themeKnows(name: string): bool {
        asked.push(name);
        return name === "mail-client";
    }

    function open(apps: var): var {
        scene = createTemporaryObject(sceneComponent, testCase, { apps });
        const control = scene.control;
        control.iconKnown = themeKnows;
        control.forceActiveFocus();
        control.menu.openAt(0);
        return control.menu;
    }

    function rowNames(menu: var): var {
        return menu.items().map(item => item.text);
    }

    function rowAt(menu: var, text: string): var {
        return menu.items().find(item => item.text === text);
    }

    function test_the_list_has_a_row_per_app_with_its_icon_word_and_state() {
        const menu = open(threeApps());
        compare(rowNames(menu), ["Nextcloud", "KDE Connect", "Steam"]);
        const nextcloud = rowAt(menu, "Nextcloud");
        compare(nextcloud.icon, blueIcon);
        compare(findChild(nextcloud, "key").text, "Synchronisiert");
        compare(nextcloud.Accessible.name, "Nextcloud, Synchronisiert", "word and state are read");
        compare(rowAt(menu, "Steam").Accessible.name, "Steam");
    }

    // Presses an app's row as the pointer, the keys or → do.
    function pressRow(menu: var, word: string, how: string) {
        const row = rowAt(menu, word);
        if (how === "click" || how === "right click") {
            mouseClick(row, undefined, undefined, how === "click" ? Qt.LeftButton : Qt.RightButton);
            return;
        }
        menu.focusAt(menu.items().indexOf(row));
        keyClick({ "enter": Qt.Key_Return, "space": Qt.Key_Space, "right": Qt.Key_Right }[how]);
    }

    function test_any_press_on_an_app_with_a_menu_opens_it_in_place_even_when_the_app_has_a_window() {
        for (const how of ["click", "right click", "enter", "space", "right"]) {
            calls = [];
            const menu = open(threeApps());
            pressRow(menu, "Nextcloud", how);
            compare(calls, [], `${how}: the app is not brought forward`);
            verify(menu.open, `${how}: the menu stays`);
            compare(rowNames(menu), ["zurück · Nextcloud", "Open folder", "Pause", "Devices"], how);
            menu.close(false);
        }
    }

    function test_a_press_enter_or_space_on_an_app_without_a_menu_brings_it_forward_and_closes_the_menu() {
        for (const how of ["click", "enter", "space"]) {
            calls = [];
            const menu = open(threeApps());
            pressRow(menu, "Steam", how);
            compare(calls, ["activate Steam"], how);
            verify(!menu.open, how);
        }
    }

    function test_right_or_a_right_click_on_an_app_without_a_menu_does_nothing() {
        for (const how of ["right click", "right"]) {
            calls = [];
            const menu = open(threeApps());
            pressRow(menu, "Steam", how);
            compare(calls, [], how);
            verify(menu.open, how);
            compare(rowNames(menu), ["Nextcloud", "KDE Connect", "Steam"], how);
            menu.close(false);
        }
    }

    function test_an_app_with_a_menu_ends_in_the_chevron_on_and_one_without_has_none() {
        const menu = open(threeApps());
        const onward = row => findChild(row, "onward");
        verify(onward(rowAt(menu, "Nextcloud")).visible);
        verify(onward(rowAt(menu, "KDE Connect")).visible);
        verify(!onward(rowAt(menu, "Steam")).visible);
        waitForRendering(scene);
        wait(Tokens.durationFloat);
        const image = grabImage(testCase);
        for (const word of ["KDE Connect", "Steam"]) {
            const row = rowAt(menu, word);
            const end = row.mapToItem(testCase, row.width - Tokens.spaceM - 3 * Geometry.chevronSize, 0);
            const area = { x: Math.round(end.x), y: Math.round(end.y), width: 3 * Geometry.chevronSize, height: Math.round(row.height) };
            compare(Ink.bounds(image, area, Tokens.color.textPrimary, Tokens.color.bg) !== null, word === "KDE Connect", `${word}: drawn at its end or not`);
        }
    }

    function test_an_app_s_state_stands_before_the_chevron_and_is_cut_first_while_the_chevron_stays() {
        const menu = open([app("Nextcloud", { state: "Synchronisiere 12 Dateien", menu: menuOf([entry("Open folder")]) })]);
        const row = rowAt(menu, "Nextcloud");
        const key = findChild(row, "key");
        const onward = findChild(row, "onward");
        compare(key.x + key.width, onward.x + Geometry.chevronOnNudge - Tokens.spaceS, "space-s before the chevron");
        verify(!key.truncated);
        row.width = row.implicitWidth - key.implicitWidth / 2;
        verify(key.truncated, "the state is cut");
        verify(!findChild(row, "label").truncated, "the word stays whole");
        verify(onward.visible);
        compare(onward.x + onward.width, row.width - Tokens.spaceM - Geometry.chevronOnNudge, "the chevron keeps the end");
        compare(key.x + key.width, onward.x + Geometry.chevronOnNudge - Tokens.spaceS);
    }

    function test_the_menu_of_an_app_shows_checks_separators_and_greyed_entries() {
        const menu = open(threeApps());
        mouseClick(rowAt(menu, "KDE Connect"));
        compare(rowAt(menu, "Quit").disabled, true);
        compare(findChild(rowAt(menu, "Quit"), "label").text, "Quit", "an app's words stay as they are");
        tryVerify(() => rowAt(menu, "Browse").activeFocus);
        keyClick(Qt.Key_Escape);
        tryVerify(() => rowAt(menu, "KDE Connect")?.activeFocus === true, 5000, "the focus is on the row that was pressed");
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Right);
        const pause = rowAt(menu, "Pause");
        compare(pause.kind, "checkbox");
        compare(pause.checked, false);
    }

    function test_below_the_first_level_the_back_row_names_the_entry_that_was_left_and_on_it_the_app() {
        const menu = open(threeApps());
        keyClick(Qt.Key_Right);
        compare(rowNames(menu)[0], "zurück · Nextcloud");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(rowNames(menu)[0], "zurück · Devices");
    }

    function test_a_checkbox_entry_stands_before_its_text_in_a_menu_without_icons() {
        const menu = open(threeApps());
        keyClick(Qt.Key_Right);
        const pause = rowAt(menu, "Pause");
        compare(pause.kind, "checkbox");
        compare(findChild(pause, "check").x, Tokens.spaceM, "the box where a row starts");
        compare(findChild(pause, "label").x, Tokens.spaceM + Geometry.menuCheck + Tokens.spaceS, "the text after the box");
        compare(findChild(rowAt(menu, "Open folder"), "label").x, Tokens.spaceM, "an entry without a box starts at the edge");
    }

    function test_an_entry_with_an_icon_shows_it_first_and_every_entry_starts_its_words_at_one_edge() {
        const menu = open(mail([entry("Compose", { icon: blueIcon }), entry("Settings"), entry("Notify", { buttonType: 1 })]));
        keyClick(Qt.Key_Right);
        const icon = findChild(rowAt(menu, "Compose"), "icon");
        verify(icon.visible);
        compare(icon.source, blueIcon);
        compare(icon.x, Tokens.spaceM);
        compare(icon.width, 20);
        compare(icon.height, 20);
        const edge = icon.x + icon.width + Tokens.spaceS;
        for (const text of ["Compose", "Settings", "Notify"])
            compare(findChild(rowAt(menu, text), "label").x, edge, `${text} starts its words at the edge`);
        compare(findChild(rowAt(menu, "zurück · Mail"), "label").x, Tokens.spaceM + Geometry.chevronSize + Tokens.spaceS, "the back row has its chevron, not the icon's room");
        verify(!findChild(rowAt(menu, "Settings"), "icon").visible, "an entry without an icon gets none");
    }

    function test_an_apps_menu_without_icons_shows_none_and_starts_its_words_at_the_edge_with_a_box_before_its_word() {
        const menu = open(threeApps());
        keyClick(Qt.Key_Right);
        for (const text of ["Open folder", "Devices"]) {
            verify(!findChild(rowAt(menu, text), "icon").visible, text);
            compare(findChild(rowAt(menu, text), "label").x, Tokens.spaceM, text);
        }
        compare(findChild(rowAt(menu, "Pause"), "check").x, Tokens.spaceM);
    }

    function test_an_app_whose_icon_name_the_theme_does_not_know_shows_no_picture_and_its_word_stands_at_the_common_edge() {
        const menu = open([app("Nextcloud", { icon: unknownIcon }), app("Mail", {}), app("Steam", { icon: "" })]);
        const nextcloud = rowAt(menu, "Nextcloud");
        verify(asked.includes("no-such-icon"), "the host's icon theme is asked");
        compare(nextcloud.icon.toString(), "", "no picture, not the checkerboard of a missing icon");
        verify(!findChild(nextcloud, "icon").visible);
        for (const word of ["Nextcloud", "Steam"])
            compare(findChild(rowAt(menu, word), "label").x, findChild(rowAt(menu, "Mail"), "label").x, word);
    }

    function test_an_app_whose_icon_name_is_unknown_indents_nothing_when_no_other_row_has_an_icon() {
        const menu = open([app("Nextcloud", { icon: unknownIcon }), app("Steam", { icon: "" })]);
        for (const word of ["Nextcloud", "Steam"])
            compare(findChild(rowAt(menu, word), "label").x, Tokens.spaceM, word);
    }

    function test_an_entry_whose_icon_name_the_theme_does_not_know_shows_no_picture_and_its_words_stand_at_the_common_edge() {
        const menu = open(mail([entry("Compose", { icon: blueIcon }), entry("Calendar", { icon: unknownIcon }), entry("Settings")]));
        keyClick(Qt.Key_Right);
        const calendar = rowAt(menu, "Calendar");
        verify(asked.includes("no-such-icon"), "the host's icon theme is asked");
        compare(calendar.icon.toString(), "");
        verify(!findChild(calendar, "icon").visible);
        compare(findChild(calendar, "label").x, findChild(rowAt(menu, "Compose"), "label").x);
    }

    function test_an_entry_s_small_picture_stands_at_its_own_size_in_the_middle_of_the_icon_field() {
        const menu = open(mail([entry("Compose", { icon: blueIcon }), entry("Contacts", { icon: smallIcon })]));
        keyClick(Qt.Key_Right);
        const field = findChild(rowAt(menu, "Contacts"), "icon");
        tryCompare(field, "status", Image.Ready);
        const picture = findChild(field, "picture");
        compare(field.width, 20);
        compare(picture.width, 16);
        compare(picture.x, 2);
        compare(picture.y, 2);
        compare(findChild(rowAt(menu, "Contacts"), "label").x, findChild(rowAt(menu, "Compose"), "label").x);
    }

    function test_a_separator_entry_is_a_hairline_not_a_row() {
        const open_ = open([app("Mail", { menu: menuOf([entry("Open"), entry("", { isSeparator: true }), entry("Quit")]) })]);
        keyClick(Qt.Key_Right);
        compare(rowNames(open_), ["zurück · Mail", "Open", "Quit"]);
        compare(open_.rows.length, 5, "the back row, two entries, the separator and the repeater");
        verify(Array.from(open_.rows).some(row => row instanceof MenuSeparator));
    }

    function test_an_entry_with_children_opens_the_next_level_and_escape_goes_back_one_level_at_a_time() {
        const menu = open(threeApps());
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(rowNames(menu), ["zurück · Devices", "Pair", "Refresh"]);
        keyClick(Qt.Key_Return);
        compare(rowNames(menu), ["zurück · Pair", "Ping", "Send file"], "a third level");
        keyClick(Qt.Key_Escape);
        compare(rowNames(menu), ["zurück · Devices", "Pair", "Refresh"]);
        tryVerify(() => rowAt(menu, "Pair").activeFocus);
        keyClick(Qt.Key_Escape);
        compare(rowNames(menu), ["zurück · Nextcloud", "Open folder", "Pause", "Devices"]);
        tryVerify(() => rowAt(menu, "Devices").activeFocus);
        keyClick(Qt.Key_Escape);
        compare(rowNames(menu), ["Nextcloud", "KDE Connect", "Steam"]);
        tryVerify(() => rowAt(menu, "Nextcloud").activeFocus);
        verify(menu.open, "the list stays");
        keyClick(Qt.Key_Escape);
        verify(!menu.open, "Escape on the list closes");
    }

    // No tooltip is drawn outside the side panel, so a tip held here would only take the menu's Escape.
    function test_a_cut_row_brings_no_tip_and_the_first_escape_does_what_the_menu_does_with_it() {
        const longWord = "Synchronisation of every folder of the account with the server, the shared ones too";
        const longEntry = "Open the folder of the account in the file manager, with the shared folders beside it";
        const menu = open([app(longWord, { menu: menuOf([entry(longEntry)]) })]);
        const word = findChild(rowAt(menu, longWord), "label");
        verify(word.truncated);
        verify(rowAt(menu, longWord).activeFocus, "the keyboard is on it");
        mouseMove(word);
        wait(Tokens.durationTipDelay * 2);
        compare(Tips.target, null);
        keyClick(Qt.Key_Right);
        tryVerify(() => rowAt(menu, longEntry).activeFocus);
        verify(findChild(rowAt(menu, longEntry), "label").truncated);
        compare(Tips.target, null);
        keyClick(Qt.Key_Escape);
        compare(rowNames(menu), [longWord], "the first Escape goes back a level");
        tryVerify(() => rowAt(menu, longWord).activeFocus);
        keyClick(Qt.Key_Escape);
        verify(!menu.open, "and on the list closes it");
    }

    function test_left_goes_back_one_level_like_escape() {
        const menu = open(threeApps());
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Left);
        compare(rowNames(menu), ["Nextcloud", "KDE Connect", "Steam"]);
        tryVerify(() => rowAt(menu, "Nextcloud").activeFocus);
        keyClick(Qt.Key_Left);
        verify(menu.open, "Left on the list does nothing");
    }

    function test_the_back_row_goes_back_when_pressed() {
        const menu = open(threeApps());
        keyClick(Qt.Key_Right);
        mouseClick(rowAt(menu, "zurück · Nextcloud"));
        compare(rowNames(menu), ["Nextcloud", "KDE Connect", "Steam"]);
    }

    function test_tab_closes_everything_and_the_next_opening_starts_at_the_list() {
        const menu = open(threeApps());
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Tab);
        verify(!menu.open);
        scene.control.forceActiveFocus();
        menu.openAt(0);
        compare(rowNames(menu), ["Nextcloud", "KDE Connect", "Steam"]);
    }

    function test_choosing_a_leaf_triggers_it_and_closes() {
        const menu = open(threeApps());
        keyClick(Qt.Key_Right);
        mouseClick(rowAt(menu, "Open folder"));
        compare(calls, ["triggered Open folder"]);
        verify(!menu.open);
    }

    function test_choosing_a_check_triggers_it_and_leaves_the_menu_open() {
        const menu = open(threeApps());
        keyClick(Qt.Key_Right);
        mouseClick(rowAt(menu, "Pause"));
        compare(calls, ["triggered Pause"]);
        verify(menu.open);
    }

    function test_the_app_answering_sets_a_check_right() {
        const apps = threeApps();
        const menu = open(apps);
        keyClick(Qt.Key_Right);
        const pause = apps[0].menu.entries[1];
        pause.checkState = Qt.Checked;
        verify(rowAt(menu, "Pause").checked);
    }

    function test_choosing_a_greyed_entry_does_nothing() {
        const menu = open(threeApps());
        mouseClick(rowAt(menu, "KDE Connect"));
        mouseClick(rowAt(menu, "Quit"));
        compare(calls, []);
        verify(menu.open);
    }

    function test_the_entries_of_a_menu_arriving_late_still_take_the_focus_at_the_first_row() {
        const late = menuOf([]);
        const menu = open([app("Slow", { menu: late })]);
        keyClick(Qt.Key_Right);
        verify(rowAt(menu, "Slow"), "while the entries load the rows stay as they were");
        late.entries = [entry("Open"), entry("Quit")];
        tryVerify(() => rowAt(menu, "Open").activeFocus);
        keyClick(Qt.Key_Escape);
        tryVerify(() => rowAt(menu, "Slow").activeFocus);
    }

    function test_an_apps_menu_changing_while_it_is_open_changes_its_rows() {
        const apps = threeApps();
        const menu = open(apps);
        keyClick(Qt.Key_Right);
        apps[0].menu.entries = [entry("Open folder"), entry("Log out")];
        compare(rowNames(menu), ["zurück · Nextcloud", "Open folder", "Log out"]);
    }

    function test_an_app_leaving_while_its_menu_is_open_leaves_the_list_changed() {
        const apps = threeApps();
        const menu = open(apps);
        scene.apps = [apps[1], apps[2]];
        compare(rowNames(menu), ["KDE Connect", "Steam"]);
    }

    // The bar with `before` apps once it has laid itself out, then with `after`.
    function countFrom(before: int, after: int): var {
        const apps = Array.from({ length: Math.max(before, after) }, (_, at) => app(`App ${at}`, {}));
        scene = createTemporaryObject(sceneComponent, testCase, { apps: apps.slice(0, before) });
        tryVerify(() => !scene.bar.settling && !scene.bar.gliding);
        scene.apps = apps.slice(0, after);
        return scene.control;
    }

    function test_a_new_number_peeks_in_and_the_bar_glides_as_the_control_widens() {
        Prefs.motion = "on";
        const control = countFrom(9, 10);
        compare(control.count, 10);
        compare(findChild(control, "label").text, "im hintergrund", "the number is no part of the word");
        verify(findChild(control, "peekRun").running, "it peeks");
        compare(findChild(control, "ghost").text, " 9");
        compare(findChild(control, "count").text, " 10");
        verify(scene.bar.gliding, "the others glide to their new places");
        compare(control.Accessible.name, "im hintergrund 10");
    }

    function test_under_reduced_motion_a_new_number_stands_at_once() {
        Prefs.motion = "off";
        const control = countFrom(9, 10);
        tryVerify(() => !findChild(control, "peekRun").running);
        verify(!scene.bar.gliding);
        compare(findChild(control, "count").opacity, 1);
        compare(findChild(control, "count").text, " 10");
        verify(!findChild(control, "ghost").visible);
    }

    function test_with_no_app_the_control_is_gone_from_the_bar_and_leaves_no_gap() {
        scene = createTemporaryObject(sceneComponent, testCase, { apps: threeApps() });
        const messages = findChild(scene, "messages");
        const control = scene.control;
        verify(control.visible);
        const withControl = messages.x;
        scene.apps = [];
        tryVerify(() => !control.visible, 1000, "gone, not disabled");
        verify(!control.disabled);
        tryVerify(() => messages.x < withControl, 1000, "the controls after it close up");
        scene.apps = [app("Steam", {})];
        tryVerify(() => control.visible, Tokens.durationModerate + 1000, "it comes back with the first app, once the others have made room");
        compare(control.count, 1);
    }

    function test_the_bar_does_not_count_the_gone_control_when_it_fits_the_others_without_more() {
        scene = createTemporaryObject(sceneComponent, testCase, { apps: [] });
        const others = findChild(scene, "goto").width + findChild(scene, "messages").width;
        scene.bar.width = others + scene.bar.gap + 2 * scene.bar.padding + 1;
        compare(scene.bar.plan.more, false, "two controls fit");
        scene.apps = [app("Steam", {})];
        compare(scene.bar.plan.more, true, "with the third the least important moves into more");
        verify(scene.bar.plan.moved.includes(scene.control));
    }

    function test_right_click_on_an_entry_with_children_opens_the_next_level() {
        const menu = open(threeApps());
        keyClick(Qt.Key_Right);
        mouseClick(rowAt(menu, "Devices"), undefined, undefined, Qt.RightButton);
        compare(rowNames(menu), ["zurück · Devices", "Pair", "Refresh"]);
    }

    function test_right_click_on_the_back_row_does_nothing() {
        const menu = open(threeApps());
        keyClick(Qt.Key_Right);
        mouseClick(rowAt(menu, "zurück · Nextcloud"), undefined, undefined, Qt.RightButton);
        compare(rowNames(menu)[0], "zurück · Nextcloud");
    }

    Component {
        id: remapComponent

        PopupRemap {
            surface: Item {
                width: 100
                height: 100
            }
        }
    }

    Component {
        id: mapSpyComponent

        SignalSpy {
            signalName: "mappedChanged"
        }
    }

    function test_a_popup_that_changes_size_while_mapped_is_unmapped_for_a_turn_and_mapped_again() {
        const remap = createTemporaryObject(remapComponent, testCase, { wanted: true });
        const spy = createTemporaryObject(mapSpyComponent, testCase, { target: remap });
        verify(remap.mapped);
        remap.surface.height = 160;
        tryCompare(spy, "count", 2, 5000, "unmapped, then mapped again");
        verify(remap.mapped);
        verify(!remap.remapping);
    }

    function test_a_popup_that_changes_width_is_remapped_too() {
        const remap = createTemporaryObject(remapComponent, testCase, { wanted: true });
        const spy = createTemporaryObject(mapSpyComponent, testCase, { target: remap });
        remap.surface.width = 180;
        tryCompare(spy, "count", 2);
    }

    function test_a_popup_that_is_not_wanted_stays_unmapped_when_its_surface_changes() {
        const remap = createTemporaryObject(remapComponent, testCase, { wanted: false });
        const spy = createTemporaryObject(mapSpyComponent, testCase, { target: remap });
        remap.surface.height = 160;
        wait(100);
        compare(spy.count, 0);
        verify(!remap.mapped);
    }

    function test_passive_apps_are_not_listed() {
        verify(!TrayRules.listed(0));
        verify(TrayRules.listed(1));
        verify(TrayRules.listed(2));
    }

    function test_the_word_is_the_title_else_the_id() {
        compare(TrayRules.word("Steam", "steam-tray"), "Steam");
        compare(TrayRules.word("", "steam-tray"), "steam-tray");
    }

    function test_the_state_is_the_tooltip_title_else_its_description() {
        compare(TrayRules.state(1, "Synchronisiert", "alles aktuell"), "Synchronisiert");
        compare(TrayRules.state(1, "", "alles aktuell"), "alles aktuell");
        compare(TrayRules.state(1, "", ""), "");
    }

    function test_an_app_that_needs_attention_says_wartet_first() {
        compare(TrayRules.state(2, "2 neue", ""), "wartet · 2 neue");
        compare(TrayRules.state(2, "", ""), "wartet");
    }

    function test_a_long_state_is_cut_with_an_ellipsis_and_short_ones_stay() {
        const long = "Synchronisiere 1234 Dateien in den Ordner";
        const state = TrayRules.state(1, long, "");
        verify(state.length < long.length);
        verify(state.endsWith("…"));
        compare(TrayRules.state(1, "kurz", ""), "kurz");
    }

    function test_only_an_icon_name_is_checked_against_the_theme_and_by_its_name_alone() {
        compare(TrayRules.shownIcon(knownIcon, themeKnows), knownIcon);
        compare(TrayRules.shownIcon(unknownIcon, themeKnows), "");
        compare(asked, ["mail-client", "no-such-icon"]);
        for (const picture of ["image://qsimage/3", "image://qspixmap/4/0", smallIcon, ""])
            compare(TrayRules.shownIcon(picture, themeKnows), picture, "an app's own picture stays as it comes");
        compare(asked.length, 2, "without asking the theme");
    }

    function test_an_unknown_icon_name_with_the_app_s_own_icon_directory_keeps_its_picture_as_the_provider_looks_there_too() {
        compare(TrayRules.shownIcon(unknownIconInAppDirectory, themeKnows), unknownIconInAppDirectory);
        compare(asked, [], "the theme alone cannot tell");
    }

    function test_contact_sheet() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        const sheets = {
            "list": threeApps,
            "menu": threeApps,
            "menu-icons": () => mail([entry("Compose", { icon: blueIcon }), entry("Settings", { icon: blueIcon }), entry("Notify", { buttonType: 1, checkState: Qt.Checked, icon: blueIcon })]),
            "menu-mixed": () => mail([entry("Compose", { icon: blueIcon }), entry("Settings"), entry("Notify", { buttonType: 1, checkState: Qt.Checked }), entry("Sync", { buttonType: 1, icon: blueIcon })]),
            "menu-pictures": () => mail([entry("Compose", { icon: blueIcon }), entry("Calendar", { icon: unknownIcon }), entry("Contacts", { icon: smallIcon }), entry("Settings", { icon: blueIcon })])
        };
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            for (const [level, apps] of Object.entries(sheets)) {
                const menu = open(apps());
                if (level !== "list") {
                    keyClick(Qt.Key_Right);
                    keyClick(Qt.Key_Down);
                }
                waitForRendering(scene);
                wait(Tokens.durationFloat);
                grabImage(scene).save(`tray-sheet-${theme}-${level}.png`);
                menu.close(false);
                scene.destroy();
            }
        }
    }
}
