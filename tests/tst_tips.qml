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

            Text {
                objectName: "unhosted"
                x: 600
                y: 200
                width: 120
                text: "a network name far too long for its box"
                elide: Text.ElideRight

                OverflowTip {}
            }

            // A host that shows a cut text whole in its tip, as the side panel does; a press anywhere in it hides a tip.
            Item {
                readonly property bool overflowTips: true

                y: 300
                width: 1000
                height: 300

                Text {
                    objectName: "cut"
                    x: 100
                    width: 120
                    text: "a network name far too long for its box"
                    elide: Text.ElideRight

                    OverflowTip {}
                }

                Text {
                    objectName: "fits"
                    x: 400
                    width: 200
                    text: "home"
                    elide: Text.ElideRight

                    OverflowTip {}
                }

                Text {
                    objectName: "lines"
                    x: 700
                    width: 250
                    text: "the first line\nand the second\n"
                    maximumLineCount: 1
                    elide: Text.ElideRight

                    OverflowTip {}
                }

                PressHidesTips {}
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

    Component {
        id: otherWindowComponent

        // A second window with its own control and its own tooltip, as each monitor's bar has.
        Window {
            property alias button: far
            property alias tooltip: farTip

            width: 300
            height: 200
            visible: true

            IconButton {
                id: far

                x: 100
                y: 100
                icon: "search"
                label: "search"
            }

            Tooltip {
                id: farTip
            }
        }
    }

    property Item scene
    property Tooltip tooltip

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
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

    function test_a_tip_that_changes_while_it_shows_says_its_new_words() {
        const close = findChild(scene, "close");
        close.forceActiveFocus();
        close.label = "close for good";
        compare(Tips.target, box("close"));
        compare(Tips.text, "close for good");
        compare(findChild(tooltip, "words").text, "close for good");
        findChild(scene, "more").label = "more for this";
        compare(Tips.text, "close for good", "another control's tip leaves it");
        close.tip = "";
        compare(Tips.target, null, "a tip that goes empty hides");
    }

    function test_a_tip_that_changes_while_its_pointer_waits_shows_its_new_words() {
        const close = findChild(scene, "close");
        mouseMove(box("close"));
        compare(Tips.waiting, box("close"));
        close.label = "close for good";
        tryCompare(Tips, "target", box("close"), Tokens.durationTipDelay * 2);
        compare(findChild(tooltip, "words").text, "close for good");
        mouseMove(scene, 5, 5);
        Tips.hiddenAt = -Infinity;
        mouseMove(box("close"));
        close.tip = "";
        compare(Tips.waiting, null, "a tip that goes empty while it waits never shows");
        wait(Tokens.durationTipDelay * 2);
        compare(Tips.target, null);
    }

    function test_each_window_s_tooltip_draws_only_a_tip_from_its_own_window() {
        const other = createTemporaryObject(otherWindowComponent, testCase);
        const far = findChild(other.button, "box");
        Tips.show(far, "search");
        verify(other.tooltip.visible);
        compare(other.tooltip.target, far);
        verify(!tooltip.visible, "the other window's tooltip stays out of it");
        compare(tooltip.target, null);
        Tips.show(box("close"), "close");
        verify(tooltip.visible);
        verify(!other.tooltip.visible);
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
        compare(tooltip.y, Math.round(scene.mapFromItem(close, 0, 0).y - Tokens.tipGap - tooltip.height));
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

    function test_a_tip_shows_its_words_as_written_never_as_markup() {
        Tips.show(box("close"), "one<br>two");
        compare(findChild(tooltip, "words").lineCount, 1);
    }

    function test_a_pointer_resting_on_a_cut_text_shows_its_whole_text_after_tip_delay() {
        const cut = findChild(scene, "cut");
        verify(cut.truncated);
        mouseMove(cut);
        wait(Tokens.durationTipDelay - 200);
        compare(Tips.target, null, "not before tip-delay");
        tryCompare(Tips, "target", cut, Tokens.durationTipDelay);
        compare(Tips.text, "a network name far too long for its box");
        verify(tooltip.visible);
        compare(findChild(tooltip, "words").text, "a network name far too long for its box");
    }

    function test_a_text_that_fits_has_no_tip() {
        mouseMove(findChild(scene, "fits"));
        compare(Tips.waiting, null);
        wait(Tokens.durationTipDelay * 2);
        compare(Tips.target, null);
    }

    function test_a_text_cut_at_its_line_count_shows_all_its_lines_in_its_tip() {
        const lines = findChild(scene, "lines");
        verify(lines.truncated);
        mouseMove(lines);
        tryCompare(Tips, "target", lines, Tokens.durationTipDelay * 2);
        compare(Tips.text, "the first line\nand the second", "without the space around them");
        compare(findChild(tooltip, "words").lineCount, 2, "line for line");
    }

    function test_moving_on_from_another_tip_a_cut_text_shows_its_tip_at_once() {
        mouseMove(box("close"));
        tryCompare(Tips, "target", box("close"), Tokens.durationTipDelay * 2);
        mouseMove(findChild(scene, "cut"));
        compare(Tips.target, findChild(scene, "cut"));
    }

    function test_touch_never_shows_the_tip_of_a_cut_text() {
        const cut = findChild(scene, "cut");
        touchEvent(cut).press(0, cut, cut.width / 2, cut.height / 2).commit();
        touchEvent(cut).release(0, cut, cut.width / 2, cut.height / 2).commit();
        wait(Tokens.durationTipDelay * 2);
        compare(Tips.target, null);
    }

    function test_escape_a_press_and_leaving_hide_the_tip_of_a_cut_text() {
        const cut = findChild(scene, "cut");
        let lower = 0;
        const off = KeyLayers.on(10, event => {
            lower++;
            return event.key === Qt.Key_Escape;
        });
        scene.forceActiveFocus();
        mouseMove(cut);
        tryCompare(Tips, "target", cut, Tokens.durationTipDelay * 2);
        keyClick(Qt.Key_Escape);
        compare(Tips.target, null, "Escape");
        compare(lower, 0, "the tip used it");
        off();
        mouseMove(scene, 5, 5);
        mouseMove(cut);
        compare(Tips.target, cut);
        mousePress(cut);
        compare(Tips.target, null, "a press");
        mouseRelease(cut);
        mouseMove(scene, 5, 5);
        mouseMove(cut);
        compare(Tips.target, cut);
        mouseMove(scene, 5, 5);
        compare(Tips.target, null, "leaving");
    }

    function test_a_text_that_comes_to_be_cut_brings_its_tip_and_one_that_fits_again_takes_it_away() {
        const fits = findChild(scene, "fits");
        mouseMove(fits);
        wait(Tokens.durationTipDelay * 2);
        fits.text = "a name that has grown too long for its box";
        tryCompare(Tips, "target", fits, Tokens.durationTipDelay * 2);
        compare(Tips.text, "a name that has grown too long for its box");
        fits.text = "a new name, again too long for its box";
        compare(Tips.text, "a new name, again too long for its box", "a tip that shows says the new words");
        compare(findChild(tooltip, "words").text, "a new name, again too long for its box");
        fits.width = 900;
        compare(Tips.target, null, "once the words fit, the tip goes");
    }

    function test_a_cut_text_s_waiting_tip_follows_its_words_and_never_shows_once_they_fit() {
        const cut = findChild(scene, "cut");
        mouseMove(cut);
        compare(Tips.waiting, cut);
        cut.text = "another name far too long for its box";
        tryCompare(Tips, "target", cut, Tokens.durationTipDelay * 2);
        compare(Tips.text, "another name far too long for its box");
        mouseMove(scene, 5, 5);
        Tips.hiddenAt = -Infinity;
        mouseMove(cut);
        compare(Tips.waiting, cut);
        cut.width = 900;
        compare(Tips.waiting, null);
        wait(Tokens.durationTipDelay * 2);
        compare(Tips.target, null, "words that fit by the end of tip-delay bring no tip");
    }

    function test_new_words_while_a_cut_text_s_tip_waits_do_not_start_tip_delay_again() {
        const cut = findChild(scene, "cut");
        mouseMove(cut);
        wait(Tokens.durationTipDelay - 150);
        cut.text = "another name far too long for its box";
        wait(300);
        compare(Tips.target, cut, "it shows once the pointer has rested for tip-delay");
        compare(Tips.text, "another name far too long for its box");
    }

    function test_outside_a_host_that_offers_them_a_cut_text_leaves_the_tips_alone() {
        const unhosted = findChild(scene, "unhosted");
        verify(unhosted.truncated);
        mouseMove(unhosted);
        compare(Tips.waiting, null);
        wait(Tokens.durationTipDelay * 2);
        compare(Tips.target, null);
    }

    function test_under_reduced_motion_a_tip_is_there_at_once() {
        Prefs.motion = "off";
        findChild(scene, "close").forceActiveFocus();
        compare(tooltip.opacity, 1);
        compare(tooltip.shift, 0);
    }
}
