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

    Component {
        id: viewComponent

        SettingsView {
            width: 900
            height: 600
        }
    }

    function init() {
        view = createTemporaryObject(viewComponent, testCase);
        closeSpy.clear();
        waitForRendering(view);
        pivot().forceActiveFocus();
    }

    function pivot(): var {
        return findChild(view, "pivot");
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
        verify(findChild(view, "turn").running);
        verify(page(0).visible);
        tryVerify(() => page(1).visible && !page(0).visible);
        compare(view.shownPlace, 1);
    }

    function test_going_back_to_an_earlier_place_turns_back() {
        pivot().select(2);
        tryVerify(() => page(2).visible);
        pivot().select(0);
        tryVerify(() => page(0).visible && !page(2).visible);
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
        view.width = Tokens.bpSidewaysScrollMin - 1;
        compare(view.columns, 1);
        tryVerify(() => groupAt("fläche").x === 0 && groupAt("fläche").y > groupAt("farben").y);
    }

    function test_the_minimum_width_leaves_room_for_two_columns_of_two_tile_units() {
        const columnWidth = (view.minimumWidth - 2 * Tokens.spaceXl - Tokens.spaceL) / 2;
        verify(columnWidth >= 2 * Tokens.tileUnit);
        verify(view.minimumWidth >= Tokens.bpSidewaysScrollMin);
    }

    function test_ctrl_w_asks_to_close_and_escape_does_not() {
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
