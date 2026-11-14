pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Settings
import SettingsApp

TestCase {
    id: testCase

    name: "SettingsApp"
    visible: true
    when: windowShown
    width: 1000
    height: 700

    property SettingsView view: null

    SignalSpy {
        id: closeSpy

        target: testCase.view
        signalName: "closeRequested"
    }

    // The view inside a plain item, as Quickshell's window holds its content: nothing there gives the view the focus.
    // The app's settings write into a file that the shell's settings read too, as the two processes share one.
    Component {
        id: hostComponent

        Item {
            property alias view: inner
            property alias app: appSettings
            property alias shell: shellSettings
            property alias backdrop: ground

            width: 900
            height: 600

            Layers {
                id: appSettings

                writable: true
                onWriteRequested: text => {
                    userText = text;
                    shellSettings.userText = text;
                }
            }

            // The shell follows its settings as shell.qml binds them.
            Binding {
                target: Prefs
                property: "contrast"
                value: shellSettings.value("contrast")
            }

            Layers {
                id: shellSettings
            }

            FakeStartFile {
                id: pins
            }

            Backdrop {
                id: ground

                solid: shellSettings.value("background") === "solid"
            }

            SettingsView {
                id: inner

                anchors.fill: parent
                settings: appSettings
                startFile: pins
            }
        }
    }

    Component {
        id: fieldComponent

        Field {
            label: "farbe"
            width: 200
        }
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var host: null

    function init() {
        host = createTemporaryObject(hostComponent, testCase);
        view = host.view;
        closeSpy.clear();
        waitForRendering(view);
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.systemMoreContrast = false;
    }

    function pivot(): var {
        return findChild(view, "pivot");
    }

    function turner(): var {
        return findChild(view, "turn");
    }

    function page(index: int): var {
        return findChild(view, `page-${index}`);
    }

    function groupAt(name: string): var {
        return findChild(view, `group-${name}`);
    }

    function test_the_places_are_aussehen_start_and_sitzung_in_a_nav_strip() {
        compare(Array.from(pivot().titles), ["aussehen", "start", "sitzung"]);
        compare(pivot().level, "nav");
        compare(pivot().currentIndex, 0);
    }

    function test_the_window_title_names_the_place_then_the_app() {
        compare(view.windowTitle, "aussehen · rekta einstellungen");
        pivot().select(2);
        compare(view.windowTitle, "sitzung · rekta einstellungen");
    }

    function test_choosing_a_place_turns_to_its_page_and_hides_the_one_before() {
        verify(page(0).visible);
        verify(!page(1).visible);
        pivot().select(1);
        verify(turner().running);
        verify(page(0).visible);
        tryVerify(() => page(1).visible && !page(0).visible);
        compare(view.shownPlace, 1);
    }

    function test_choosing_a_later_place_turns_forward_and_an_earlier_one_back() {
        pivot().select(2);
        verify(!turner().back);
        tryVerify(() => page(2).visible);
        pivot().select(0);
        verify(turner().back);
        tryVerify(() => page(0).visible && !page(2).visible);
    }

    function test_under_reduced_motion_a_place_change_lands_at_once() {
        Prefs.motion = "off";
        pivot().select(2);
        verify(!turner().running);
        verify(page(2).visible);
        verify(!page(0).visible);
    }

    function test_the_keys_work_without_the_focus_being_set_by_hand() {
        keyClick(Qt.Key_Right);
        compare(pivot().currentIndex, 1);
    }

    function test_escape_goes_back_one_place_with_the_back_turn_in_the_order_visited() {
        pivot().select(2);
        pivot().select(1);
        tryVerify(() => page(1).visible);
        keyClick(Qt.Key_Escape);
        compare(pivot().currentIndex, 2);
        verify(turner().back);
        tryVerify(() => page(2).visible && !page(1).visible);
        keyClick(Qt.Key_Escape);
        compare(pivot().currentIndex, 0);
        tryVerify(() => page(0).visible && !page(2).visible);
    }

    function test_escape_closes_a_list_opened_by_the_pointer_before_it_goes_back() {
        pivot().select(1);
        tryVerify(() => page(1).visible);
        const select = control("searchEscape");
        waitForRendering(select);
        mouseClick(findChild(select, "box"));
        verify(select.expanded);
        verify(!select.activeFocus, "a press gives no focus");
        keyClick(Qt.Key_Escape);
        verify(!select.expanded);
        compare(pivot().currentIndex, 1);
        keyClick(Qt.Key_Escape);
        compare(pivot().currentIndex, 0);
    }

    function test_alt_left_and_the_back_key_go_back_too() {
        pivot().select(2);
        keyClick(Qt.Key_Left, Qt.AltModifier);
        compare(pivot().currentIndex, 0);
        pivot().select(1);
        keyClick(Qt.Key_Back);
        compare(pivot().currentIndex, 0);
    }

    function test_the_mouse_back_button_goes_back() {
        pivot().select(1);
        mouseClick(view, 400, 400, Qt.BackButton);
        compare(pivot().currentIndex, 0);
    }

    function test_back_at_the_top_place_does_nothing_and_does_not_close() {
        keyClick(Qt.Key_Escape);
        keyClick(Qt.Key_Left, Qt.AltModifier);
        compare(pivot().currentIndex, 0);
        compare(closeSpy.count, 0);
    }

    function test_the_arrow_keys_and_home_and_end_move_between_places() {
        keyClick(Qt.Key_Right);
        compare(pivot().currentIndex, 1);
        keyClick(Qt.Key_End);
        compare(pivot().currentIndex, 2);
        keyClick(Qt.Key_Left);
        compare(pivot().currentIndex, 1);
        keyClick(Qt.Key_Home);
        compare(pivot().currentIndex, 0);
    }

    function test_a_group_without_fields_says_that_they_are_still_to_come() {
        const group = groupAt("problem melden");
        verify(group);
        compare(group.children[1].item.text, "kommt");
    }

    function test_groups_stand_in_two_columns_on_a_wide_window() {
        compare(view.columns, 2);
        tryVerify(() => groupAt("fläche").x > 0 && groupAt("fläche").y === groupAt("farben").y);
        compare(groupAt("farben").width, groupAt("fläche").width);
    }

    function test_groups_stand_in_one_column_on_a_narrow_window() {
        view.parent.width = Tokens.bpSidewaysScrollMin - 1;
        compare(view.columns, 1);
        tryVerify(() => groupAt("fläche").x === 0 && groupAt("fläche").y > groupAt("farben").y);
    }

    function test_the_minimum_width_leaves_room_for_two_columns_of_two_tile_units() {
        const columnWidth = (view.minimumWidth - 2 * Tokens.spaceXl - Tokens.spaceL) / 2;
        verify(columnWidth >= 2 * Tokens.tileUnit);
        verify(view.minimumWidth >= Tokens.bpSidewaysScrollMin);
        verify(view.minimumHeight > Tokens.bpShortHeight);
    }

    function test_ctrl_w_asks_to_close_and_escape_does_not() {
        pivot().select(1);
        keyClick(Qt.Key_Escape);
        compare(closeSpy.count, 0);
        keyClick(Qt.Key_W, Qt.ControlModifier);
        compare(closeSpy.count, 1);
    }

    function test_a_plain_w_does_not_close() {
        keyClick(Qt.Key_W);
        compare(closeSpy.count, 0);
    }

    function control(name: string): var {
        return findChild(view, name);
    }

    function hintOf(name: string): string {
        return findChild(control(name).parent.parent, "hint").text;
    }

    function written(): var {
        return JSON.parse(host.app.userText);
    }

    function test_the_start_place_offers_escape_as_a_select_and_no_tempo() {
        pivot().select(1);
        compare(control("startTempo"), null);
        compare(control("searchEscape").currentText, "leert die suche und schließt den start");
    }

    function test_the_aussehen_place_offers_the_tile_echo_as_a_toggle_that_is_on_by_default() {
        verify(control("echo").checked);
        compare(control("echo").label, "kachel-echo");
    }

    function test_the_aussehen_place_offers_more_contrast_in_farben_off_by_default() {
        const toggle = control("contrast");
        compare(toggle.label, "mehr kontrast");
        verify(!toggle.checked);
        verify(isInside(toggle, groupAt("farben")));
    }

    function isInside(item: var, ancestor: var): bool {
        for (let p = item; p; p = p.parent) {
            if (p === ancestor)
                return true;
        }
        return false;
    }

    function test_more_contrast_writes_more_then_normal_and_the_shell_follows_at_once() {
        control("contrast").activate();
        compare(written().contrast, "more");
        verify(Prefs.moreContrast);
        verify(Tokens.moreContrast);
        verify(control("contrast").checked);
        control("contrast").activate();
        compare(written().contrast, "normal");
        verify(!Tokens.moreContrast);
        verify(!control("contrast").checked);
    }

    function test_more_contrast_shows_on_while_the_system_asks_for_it_and_off_writes_normal() {
        Prefs.systemMoreContrast = true;
        verify(control("contrast").checked, "system is the default and follows the system");
        verify(Tokens.moreContrast);
        control("contrast").activate();
        compare(written().contrast, "normal");
        verify(!Tokens.moreContrast, "normal wins over the system");
    }

    function test_with_more_contrast_set_in_nix_the_toggle_is_on_and_the_hint_names_that_default() {
        host.app.defaultsText = '{"contrast":"more"}';
        verify(control("contrast").checked);
        verify(!hintOf("contrast").includes("vorgabe"));
        host.app.userText = '{"version":1,"contrast":"normal"}';
        verify(!control("contrast").checked);
        verify(hintOf("contrast").endsWith("vorgabe: an."));
        host.app.defaultsText = "";
        verify(hintOf("contrast").endsWith("vorgabe: wie das system."));
    }

    function test_choosing_what_escape_does_writes_it_and_the_shell_follows() {
        pivot().select(1);
        const select = control("searchEscape");
        select.forceActiveFocus();
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        verify(!select.expanded);
        compare(written().searchEscape, "back");
        compare(host.shell.value("searchEscape"), "back");
        compare(select.currentText, "leert die suche, zurück zum ort davor");
    }

    function test_the_tile_echo_toggles_the_background_and_the_shell_follows() {
        control("echo").activate();
        compare(written().background, "solid");
        verify(host.backdrop.solid);
        control("echo").activate();
        compare(written().background, "rekta");
        verify(!host.backdrop.solid);
    }

    function test_the_start_place_offers_zuletzt_as_a_toggle_that_is_on_by_default_and_the_shell_follows_it() {
        pivot().select(1);
        verify(groupAt("zuletzt"));
        compare(control("showRecent").label, "zuletzt zeigen");
        verify(control("showRecent").checked);
        control("showRecent").activate();
        compare(written().showRecent, false);
        compare(host.shell.value("showRecent"), false);
        control("showRecent").activate();
        compare(written().showRecent, true);
    }

    function test_with_zuletzt_off_in_nix_the_hint_names_that_default() {
        host.app.defaultsText = '{"showRecent":false}';
        verify(!control("showRecent").checked);
        host.app.userText = '{"version":1,"showRecent":true}';
        verify(control("showRecent").checked);
        verify(hintOf("showRecent").endsWith("vorgabe: aus."));
    }

    function test_a_value_that_differs_from_the_nix_default_names_the_default_in_the_hint() {
        host.app.defaultsText = '{"searchEscape":"back","background":"solid"}';
        compare(control("searchEscape").currentIndex, 1);
        verify(!hintOf("searchEscape").includes("vorgabe"));
        host.app.userText = '{"version":1,"searchEscape":"close","background":"rekta"}';
        verify(hintOf("searchEscape").endsWith("vorgabe: leert die suche, zurück zum ort davor."));
        verify(hintOf("echo").endsWith("vorgabe: aus."));
    }

    function test_a_broken_file_keeps_the_defaults_and_locks_the_fields_with_the_cause_and_the_remedy() {
        ignoreWarning(/settings.json holds no JSON object/);
        host.app.userText = "{ not json";
        let writes = 0;
        host.app.writeRequested.connect(() => writes++);
        for (const name of ["searchEscape", "echo", "contrast"]) {
            verify(control(name).disabled, name);
            compare(control(name).disabledReason, "datei nicht lesbar", name);
            verify(hintOf(name).includes("kein gültiges json") && hintOf(name).includes("korrigiere oder lösche"), name);
            const why = findChild(control(name), "why");
            verify(why.x + why.width <= control(name).width, `${name}: the reason stays within the column`);
        }
        control("echo").activate();
        compare(writes, 0);
        compare(host.app.userText, "{ not json");
        verify(control("echo").checked);
    }

    function test_a_newer_file_locks_the_fields_and_says_it_comes_from_a_newer_version() {
        host.app.userText = '{"version":2,"searchEscape":"back"}';
        compare(control("searchEscape").currentIndex, 1, "it is still read");
        verify(control("searchEscape").disabled);
        compare(control("searchEscape").disabledReason, "datei zu neu");
        verify(hintOf("searchEscape").includes("neueren rekta-version") && hintOf("searchEscape").includes("aktualisiere rekta"));
        control("searchEscape").activated(0);
        compare(host.app.userText, '{"version":2,"searchEscape":"back"}');
    }

    function test_a_usable_file_leaves_the_fields_enabled() {
        for (const name of ["searchEscape", "echo", "contrast"])
            verify(!control(name).disabled, name);
    }

    function test_the_tile_echo_shows_on_for_any_background_but_solid_as_the_shell_does() {
        host.app.userText = '{"version":1,"background":"something else"}';
        verify(control("echo").checked);
        host.app.userText = '{"version":1,"background":"solid"}';
        verify(!control("echo").checked);
    }

    function test_a_missing_file_keeps_the_defaults() {
        compare(host.app.userText, "");
        verify(control("echo").checked);
        compare(control("searchEscape").currentIndex, 0);
    }

    function test_a_choice_keeps_the_keys_the_app_does_not_know_also_a_start_tempo_of_old() {
        host.app.userText = '{"version":1,"accent":"ink","startTempo":"rekta"}';
        control("echo").activate();
        compare(written().accent, "ink");
        compare(written().startTempo, "rekta");
        compare(written().background, "solid");
    }

    function test_escape_in_a_text_field_does_not_go_back_but_outside_it_does() {
        pivot().select(1);
        compare(pivot().currentIndex, 1);
        const field = createTemporaryObject(fieldComponent, view);
        const input = findChild(field, "input");
        input.forceActiveFocus();
        verify(input.activeFocus);
        keyClick(Qt.Key_Escape);
        compare(pivot().currentIndex, 1);
        pivot().forceActiveFocus();
        keyClick(Qt.Key_Escape);
        compare(pivot().currentIndex, 0);
    }

    function test_escape_in_an_open_select_closes_its_list_and_does_not_go_back() {
        pivot().select(1);
        const select = control("searchEscape");
        select.forceActiveFocus();
        keyClick(Qt.Key_Space);
        verify(select.expanded);
        keyClick(Qt.Key_Escape);
        verify(!select.expanded);
        compare(pivot().currentIndex, 1);
        keyClick(Qt.Key_Escape);
        compare(pivot().currentIndex, 0);
    }
}
