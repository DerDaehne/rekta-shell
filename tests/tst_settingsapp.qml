pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
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
    Component {
        id: hostComponent

        Item {
            property alias view: inner

            width: 900
            height: 600

            SettingsView {
                id: inner

                anchors.fill: parent
            }
        }
    }

    function init() {
        view = createTemporaryObject(hostComponent, testCase).view;
        closeSpy.clear();
        waitForRendering(view);
    }

    function cleanup() {
        Prefs.motion = "system";
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

    function test_each_group_says_that_its_fields_are_still_to_come() {
        const group = groupAt("farben");
        verify(group);
        compare(group.children[1].text, "kommt");
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
}
