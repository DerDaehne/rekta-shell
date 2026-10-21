pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "Tips"
    visible: true
    when: windowShown
    width: 1000
    height: 600

    Component {
        id: sceneComponent

        // A window's root as a host sets it up: keys nobody took go to the layers, and one tooltip floats above all.
        Item {
            width: 1000
            height: 600
            Keys.onPressed: event => KeyLayers.dispatch(event, Window.activeFocusItem)

            IconButton {
                objectName: "close"
                x: 100
                y: 200
                icon: "close"
                label: "close"
            }

            IconButton {
                objectName: "more"
                x: 200
                y: 200
                icon: "more"
                label: "more"
            }

            Button {
                objectName: "save"
                x: 300
                y: 200
                text: "save"
            }

            Tooltip {
                objectName: "tooltip"
                readonly property var at: target ? Placement.tip(parent.mapFromItem(target, 0, 0, target.width, target.height), Qt.size(width, height), area) : null

                area: Qt.size(parent.width, parent.height)
                x: at ? at.x : 0
                y: at ? at.y : 0
                side: at ? at.side : "above"
            }
        }
    }

    property Item scene
    property Tooltip tooltip

    function init() {
        scene = createTemporaryObject(sceneComponent, testCase);
        tooltip = findChild(scene, "tooltip");
        mouseMove(scene, 5, 5);
        Tips.hide();
        Tips.hiddenAt = -Infinity;
    }

    function cleanup() {
        Tips.hide();
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    function box(name) {
        return findChild(findChild(scene, name), "box");
    }

    function test_a_resting_pointer_shows_the_tip_after_tip_delay() {
        mouseMove(box("close"));
        compare(Tips.target, null);
        wait(Tokens.durationTipDelay - 200);
        compare(Tips.target, null, "not before tip-delay");
        tryCompare(Tips, "target", box("close"), Tokens.durationTipDelay);
        verify(tooltip.visible);
        compare(findChild(tooltip, "words").text, "close", "an icon button shows its label");
    }

    function test_keyboard_focus_shows_the_tip_at_once() {
        findChild(scene, "more").forceActiveFocus();
        compare(Tips.target, box("more"));
        compare(Tips.text, "more");
        verify(tooltip.visible);
    }

    function test_moving_on_from_a_tip_shows_the_next_at_once() {
        mouseMove(box("close"));
        tryCompare(Tips, "target", box("close"), Tokens.durationTipDelay * 2);
        mouseMove(box("more"));
        compare(Tips.target, box("more"), "straight from one tip to the next");
        mouseMove(scene, 5, 5);
        compare(Tips.target, null);
        mouseMove(box("close"));
        compare(Tips.target, box("close"), "within tip-delay of the last one");
    }

    function test_touch_never_shows_a_tip() {
        const close = box("close");
        touchEvent(close).press(0, close, close.width / 2, close.height / 2).commit();
        touchEvent(close).release(0, close, close.width / 2, close.height / 2).commit();
        wait(Tokens.durationTipDelay * 2);
        compare(Tips.target, null);
    }

    function test_escape_hides_the_tip_before_any_lower_layer() {
        let lower = 0;
        const off = KeyLayers.on(10, event => {
            lower++;
            return event.key === Qt.Key_Escape;
        });
        findChild(scene, "close").forceActiveFocus();
        verify(tooltip.visible);
        keyClick(Qt.Key_Escape);
        compare(Tips.target, null);
        compare(lower, 0, "the tip used it");
        verify(findChild(scene, "close").activeFocus, "the focus stays");
        keyClick(Qt.Key_Escape);
        compare(lower, 1, "with no tip, Escape goes on down");
        off();
    }

    function test_a_press_hides_the_tip() {
        mouseMove(box("close"));
        tryCompare(Tips, "target", box("close"), Tokens.durationTipDelay * 2);
        mousePress(box("close"));
        compare(Tips.target, null);
        mouseRelease(box("close"));
        findChild(scene, "more").forceActiveFocus();
        mouseClick(box("save"));
        compare(Tips.target, null, "a press on another control too");
    }

    function test_leaving_hides_the_tip_or_stops_its_wait() {
        mouseMove(box("close"));
        tryCompare(Tips, "target", box("close"), Tokens.durationTipDelay * 2);
        mouseMove(scene, 5, 5);
        compare(Tips.target, null);
        Tips.hiddenAt = -Infinity;
        mouseMove(box("close"));
        wait(100);
        mouseMove(scene, 5, 5);
        wait(Tokens.durationTipDelay * 2);
        compare(Tips.target, null, "a pointer that left before tip-delay brings no tip");
    }

    function test_the_focus_leaving_hides_the_tip() {
        findChild(scene, "close").forceActiveFocus();
        compare(Tips.target, box("close"));
        findChild(scene, "save").forceActiveFocus();
        compare(Tips.target, null);
    }

    function test_a_tip_is_an_ink_strip_in_the_ground_colour() {
        Prefs.theme = "dark";
        findChild(scene, "close").forceActiveFocus();
        compare(tooltip.color, Tokens.color.textPrimary);
        compare(tooltip.radius, Tokens.radiusS);
        const words = findChild(tooltip, "words");
        compare(words.color, Tokens.color.bg);
        compare(words.font.pixelSize, Tokens.fontSizeXs);
        compare(words.font.weight, Tokens.fontWeightSemibold);
        compare(words.lineHeight, Tokens.lineHeightCompact * Tokens.fontSizeXs, "a line box of line-height-compact");
        compare(words.x, Tokens.spaceS);
        compare(words.y, 4);
        compare(tooltip.height, words.height + 8);
        compare(tooltip.z, Tokens.layerFloat);
    }

    function test_a_long_tip_wraps_at_20rem_or_space_m_from_the_window_s_sides() {
        Tips.show(box("close"), "close this schedule and every run that is still waiting for its turn in the queue");
        compare(tooltip.width, 320);
        verify(findChild(tooltip, "words").lineCount > 1);
        tooltip.area = Qt.size(300, 600);
        compare(tooltip.width, 300 - 2 * Tokens.spaceM);
    }

    function test_a_tip_sits_above_its_control_and_comes_in_like_a_floating_surface() {
        Prefs.motion = "on";
        const close = box("close");
        findChild(scene, "close").forceActiveFocus();
        compare(tooltip.side, "above");
        compare(tooltip.y, Math.round(scene.mapFromItem(close, 0, 0).y - Geometry.tipGap - tooltip.height));
        compare(tooltip.opacity, 0);
        compare(tooltip.shift, 4, "it rises from its control");
        compare(findChild(tooltip, "comingIn").duration, Tokens.durationFloat);
        compare(findChild(tooltip, "comingIn").easing.bezierCurve, Tokens.easeIn);
        tryCompare(tooltip, "entry", 1, Tokens.durationFloat * 4);
        compare(tooltip.shift, 0);
        Tips.show(box("more"), "more");
        compare(tooltip.opacity, 0, "and again for the next control");
        Tips.hide();
        verify(!tooltip.visible, "it leaves at once");
        wait(Tokens.durationFloat / 3);
        verify(!tooltip.visible);
    }

    function test_under_reduced_motion_a_tip_is_there_at_once() {
        Prefs.motion = "off";
        findChild(scene, "close").forceActiveFocus();
        compare(tooltip.opacity, 1);
        compare(tooltip.shift, 0);
    }
}
