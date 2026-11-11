pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Start

// Which edge the Start's parts turn about: the bottom one on every way into and out of the windows, Rekta's leading
// edge between its places.
TestCase {
    id: testCase

    name: "StartTurn"
    visible: true
    when: windowShown
    width: 1600
    height: 900

    function fakeApp(name: string): var {
        return {
            id: `org.example.${name}`,
            name: name,
            icon: "",
            columns: 1,
            rows: 1,
            launch: () => {}
        };
    }

    Component {
        id: startComponent

        StartPlace {
            width: testCase.width
            height: testCase.height
            windows: []
            pinned: [testCase.fakeApp("systemsettings"), testCase.fakeApp("dolphin"), testCase.fakeApp("konsole")]
        }
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var start
    property var turner

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        start = createTemporaryObject(startComponent, testCase);
        turner = findChild(start, "turn");
    }

    function cleanup() {
        turner.finish();
        Prefs.motion = "system";
    }

    function named(name: string): var {
        return findChild(start, name);
    }

    function openNow() {
        Prefs.motion = "off";
        start.open();
        Prefs.motion = "system";
        waitForRendering(start);
    }

    function verifyAboutTheBottomEdge(turns: var) {
        verify(turns.length > 0);
        compare(turner.edge, "bottom");
        for (const turn of turns)
            compare(turn.axis, Qt.vector3d(1, 0, 0), turn.part.item.objectName);
    }

    function test_opening_the_parts_turn_in_about_the_bottom_edge_the_titles_above_the_panorama_about_the_start_s_own() {
        start.open();
        tryVerify(() => turner.running, 2000);
        turner.paused = true;
        verifyAboutTheBottomEdge(turner.arrivingTurns);
        const panoramaTop = named("panorama").mapToItem(null, 0, 0).y;
        const above = turner.arrivingTurns.filter(turn => turn.part.y + turn.part.height <= panoramaTop);
        verify(above.length > 0, "the place's titles turn too");
        for (const turn of above)
            compare(turn.originY, start.height - turn.part.y, turn.part.item.objectName);
    }

    function test_closed_back_the_parts_turn_out_about_the_bottom_edge() {
        openNow();
        keyClick(Qt.Key_Escape);
        verify(turner.back);
        verifyAboutTheBottomEdge(turner.leavingTurns);
    }

    function test_after_a_tile_press_the_parts_turn_out_forward_about_the_bottom_edge_the_pressed_tile_last() {
        openNow();
        const pressed = findChild(named("pinned"), "grid").children.find(item => (item as Tile) !== null);
        mouseClick(pressed);
        verify(!turner.back);
        verifyAboutTheBottomEdge(turner.leavingTurns);
        compare(turner.leavingTurns[turner.leavingTurns.length - 1].part.item, pressed);
    }

    // As the Start steps aside for an app started elsewhere.
    function test_left_forward_without_a_tile_the_parts_turn_out_about_the_bottom_edge() {
        openNow();
        start.leave({
            back: false,
            pressed: null
        });
        verify(!turner.back);
        verifyAboutTheBottomEdge(turner.leavingTurns);
    }

    function test_a_change_of_place_inside_the_start_keeps_rekta_s_leading_edge() {
        openNow();
        keyClick(Qt.Key_Right);
        verify(turner.running);
        compare(turner.edge, "leading");
        for (const turn of turner.leavingTurns)
            compare(turn.axis, Qt.vector3d(0, 1, 0));
    }

    function test_under_reduced_motion_the_start_stands_open_at_once_and_closes_at_once() {
        Prefs.motion = "off";
        start.open();
        verify(!turner.running);
        compare(start.phase, "open");
        keyClick(Qt.Key_Escape);
        verify(!turner.running);
        tryCompare(start, "phase", "closed", 1000);
    }
}
