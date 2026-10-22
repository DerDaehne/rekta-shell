pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Tray

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

    // A DBusMenu's entries, as the opener lists them.
    component FakeMenu: QtObject {
        property var entries: []
    }

    component FakeEntry: QtObject {
        id: entry

        property string text
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
        property bool onlyMenu: false
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
                    text: "go to"
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

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var scene

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        calls = [];
    }

    function cleanup() {
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function entry(text: string, props: var): QtObject {
        return createTemporaryObject(entryComponent, testCase, Object.assign({ text }, props ?? {}));
    }

    function menuOf(entries: var): QtObject {
        return createTemporaryObject(menuComponent, testCase, { entries });
    }

    function app(word: string, props: var): QtObject {
        return createTemporaryObject(appComponent, testCase, Object.assign({ word, icon: blueIcon }, props ?? {}));
    }

    // Three apps: one with a menu and a submenu, one that is only a menu, one that has none.
    function threeApps(): var {
        const device = entry("Pair", { entries: [entry("Ping"), entry("Send file")] });
        return [
            app("Nextcloud", { state: "Synchronisiert", menu: menuOf([entry("Open folder"), entry("Pause", { buttonType: 1 }), entry("Devices", { entries: [device, entry("Refresh")] })]) }),
            app("KDE Connect", { onlyMenu: true, menu: menuOf([entry("Browse"), entry("Quit", { enabled: false })]) }),
            app("Steam", {})
        ];
    }

    function open(apps: var): var {
        scene = createTemporaryObject(sceneComponent, testCase, { apps });
        const control = scene.control;
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

    function test_pressing_an_app_brings_it_forward_and_closes_the_menu() {
        const menu = open(threeApps());
        mouseClick(rowAt(menu, "Nextcloud"));
        compare(calls, ["activate Nextcloud"]);
        verify(!menu.open);
    }

    function test_pressing_an_app_that_is_only_a_menu_opens_its_menu_in_place() {
        const menu = open(threeApps());
        mouseClick(rowAt(menu, "KDE Connect"));
        compare(calls, []);
        verify(menu.open, "the menu stays");
        compare(rowNames(menu), ["zurück · KDE Connect", "Browse", "Quit"]);
    }

    function test_pressing_an_app_that_is_only_a_menu_without_one_does_nothing() {
        const menu = open([app("Odd", { onlyMenu: true })]);
        mouseClick(rowAt(menu, "Odd"));
        compare(calls, []);
        verify(menu.open);
        compare(rowNames(menu), ["Odd"]);
    }

    function test_right_opens_the_menu_of_an_app_that_is_pressed_to_activate() {
        const menu = open(threeApps());
        keyClick(Qt.Key_Right);
        compare(rowNames(menu)[0], "zurück · Nextcloud");
        compare(calls, []);
    }

    function test_right_on_an_app_without_a_menu_does_nothing() {
        const menu = open(threeApps());
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_Right);
        compare(rowNames(menu), ["Nextcloud", "KDE Connect", "Steam"]);
    }

    function test_the_menu_of_an_app_shows_checks_separators_and_greyed_entries() {
        const menu = open(threeApps());
        mouseClick(rowAt(menu, "KDE Connect"));
        compare(rowAt(menu, "Quit").disabled, true);
        compare(findChild(rowAt(menu, "Quit"), "label").text, "Quit", "an app's words stay as they are");
        keyClick(Qt.Key_Escape);
        keyClick(Qt.Key_Right);
        const pause = rowAt(menu, "Pause");
        compare(pause.kind, "checkbox");
        compare(pause.checked, false);
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
        compare(rowNames(menu), ["zurück · Nextcloud", "Pair", "Refresh"]);
        keyClick(Qt.Key_Return);
        compare(rowNames(menu), ["zurück · Nextcloud", "Ping", "Send file"], "a third level");
        keyClick(Qt.Key_Escape);
        compare(rowNames(menu), ["zurück · Nextcloud", "Pair", "Refresh"]);
        verify(rowAt(menu, "Pair").activeFocus, "the focus is on the row that opened the level");
        keyClick(Qt.Key_Escape);
        compare(rowNames(menu), ["zurück · Nextcloud", "Open folder", "Pause", "Devices"]);
        verify(rowAt(menu, "Devices").activeFocus);
        keyClick(Qt.Key_Escape);
        compare(rowNames(menu), ["Nextcloud", "KDE Connect", "Steam"]);
        verify(rowAt(menu, "Nextcloud").activeFocus);
        verify(menu.open, "the list stays");
        keyClick(Qt.Key_Escape);
        verify(!menu.open, "Escape on the list closes");
    }

    function test_left_goes_back_one_level_like_escape() {
        const menu = open(threeApps());
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Left);
        compare(rowNames(menu), ["Nextcloud", "KDE Connect", "Steam"]);
        verify(rowAt(menu, "Nextcloud").activeFocus);
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

    function test_the_number_follows_the_apps_in_place() {
        const apps = threeApps();
        open(apps);
        const control = scene.control;
        compare(control.text, "im hintergrund 3");
        const messages = findChild(scene, "messages");
        scene.apps = apps.slice(0, 2);
        compare(control.text, "im hintergrund 2");
        compare(findChild(control, "label").text, "im hintergrund 2");
        verify(!findChild(control, "press").opacity, "nothing blinks or peeks");
        verify(messages.x > 0);
    }

    function test_with_no_app_the_control_is_gone_from_the_bar_and_leaves_no_gap() {
        scene = createTemporaryObject(sceneComponent, testCase, { apps: threeApps() });
        const messages = findChild(scene, "messages");
        const control = scene.control;
        verify(control.visible);
        const withControl = messages.x;
        scene.apps = [];
        verify(!control.visible, "gone, not disabled");
        verify(!control.disabled);
        verify(messages.x < withControl, "the controls after it close up");
        scene.apps = [app("Steam", {})];
        verify(control.visible, "it comes back with the first app");
        compare(control.text, "im hintergrund 1");
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

    function test_an_app_that_needs_attention_says_so_first() {
        compare(TrayRules.state(2, "2 neue", ""), "aufmerksamkeit · 2 neue");
        compare(TrayRules.state(2, "", ""), "aufmerksamkeit");
    }

    function test_a_long_state_is_cut_with_an_ellipsis_and_short_ones_stay() {
        const long = "Synchronisiere 1234 Dateien in den Ordner";
        const state = TrayRules.state(1, long, "");
        verify(state.length < long.length);
        verify(state.endsWith("…"));
        compare(TrayRules.state(1, "kurz", ""), "kurz");
    }

    function test_contact_sheet() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            for (const level of ["list", "menu"]) {
                const menu = open(threeApps());
                if (level === "menu") {
                    keyClick(Qt.Key_Down);
                    keyClick(Qt.Key_Right);
                    keyClick(Qt.Key_Down);
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
