pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "PressOutside"
    visible: true
    when: windowShown
    width: 400
    height: 300

    // Another window of the program, such as the bar under an open popup.
    Item {
        id: bar

        anchors.fill: parent
    }

    Component {
        id: popupComponent

        // An open popup in the test window's top leading corner, as a floating surface's own window.
        Window {
            property alias outside: outside
            property alias content: content

            flags: Qt.Popup
            x: testCase.mapToGlobal(0, 0).x
            y: testCase.mapToGlobal(0, 0).y
            width: 40
            height: 40
            visible: true

            PressOutside {
                id: outside
            }

            Item {
                id: content

                anchors.fill: parent
            }
        }
    }

    Component {
        id: spyComponent

        SignalSpy {
            signalName: "pressedOutside"
        }
    }

    function openPopup() {
        const popup = createTemporaryObject(popupComponent, testCase);
        tryVerify(() => popup.visible);
        const spy = createTemporaryObject(spyComponent, testCase, { target: popup.outside });
        return { popup, spy };
    }

    function test_a_finger_on_another_window_counts_as_a_press_outside_the_open_popup() {
        const { spy } = openPopup();
        const touch = touchEvent(bar);
        touch.press(0, bar, 100, 100).commit();
        compare(spy.count, 1);
        touch.release(0, bar, 100, 100).commit();
        compare(spy.count, 1);
    }

    function test_a_press_outside_says_where_it_landed_in_the_popups_window() {
        const { popup, spy } = openPopup();
        mousePress(popup.content, -60, -50);
        compare(spy.count, 1);
        compare(spy.signalArguments[0][0], Qt.point(-60, -50));
        mouseRelease(popup.content, -60, -50);
    }

    function test_a_finger_far_from_the_popup_counts_too() {
        const { spy } = openPopup();
        touchEvent(bar).press(0, bar, 395, 295).commit().release(0, bar, 395, 295).commit();
        compare(spy.count, 1);
    }

    // Qt hands a mouse press on another window to the popup first, as a press outside it, and passes it on to that
    // window only when the popup leaves it.
    function test_a_mouse_press_outside_counts_and_is_left_to_the_window_under_it() {
        const { popup, spy } = openPopup();
        mousePress(popup.content, -60, -60);
        compare(spy.count, 1);
        verify(!popup.outside.pressed);
        mouseRelease(popup.content, -60, -60);
    }

    function test_the_first_point_past_each_edge_of_the_popup_counts_and_the_last_inside_does_not() {
        const { popup, spy } = openPopup();
        const tap = (x, y) => touchEvent(bar).press(0, bar, x, y).commit().release(0, bar, x, y).commit();
        const click = (x, y) => {
            mousePress(popup.content, x, y);
            mouseRelease(popup.content, x, y);
        };
        tap(0, 0);
        tap(39, 39);
        compare(spy.count, 0);
        tap(40, 39);
        compare(spy.count, 1);
        tap(39, 40);
        compare(spy.count, 2);
        click(-1, 0);
        compare(spy.count, 3);
        click(0, -1);
        compare(spy.count, 4);
    }

    function test_a_press_inside_the_popup_is_no_press_outside() {
        const { popup, spy } = openPopup();
        touchEvent(popup.content).press(0, popup.content, 20, 20).commit().release(0, popup.content, 20, 20).commit();
        mouseClick(popup.content, 20, 20);
        compare(spy.count, 0);
    }
}
