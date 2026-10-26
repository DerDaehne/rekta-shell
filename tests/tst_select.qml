pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "Select"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 600

    readonly property var outputs: [
        { text: "speakers", value: "a" },
        { text: "headphones", value: "b" },
        { text: "hdmi", value: "c" }
    ]
    property Item scene
    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var select
    property var list
    property SignalSpy activated

    Component {
        id: sceneComponent

        Item {
            width: 1000
            height: 600

            Button {
                objectName: "before"
                x: 40
                y: 40
                text: "before"
            }

            Select {
                objectName: "select"
                x: 40
                y: 100
                width: 240
                label: "ausgang"
                options: testCase.outputs
                currentIndex: 0
            }

            Button {
                objectName: "after"
                x: 400
                y: 100
                text: "after"
            }

            // So low that its list has no room below.
            Select {
                objectName: "low"
                x: 40
                y: 600 - Tokens.controlHeight - Tokens.spaceS
                width: 240
                options: testCase.outputs
                currentIndex: 1
            }
        }
    }

    Component {
        id: spyComponent

        SignalSpy {
            signalName: "activated"
        }
    }

    Component {
        id: sheetComponent

        // Selects on the current theme's ground: chosen, cut, disabled with its reason, and one that opens its list here.
        Rectangle {
            id: sheet

            width: 560
            height: 360
            color: Tokens.color.bg

            Column {
                x: Tokens.spaceL
                y: Tokens.spaceL
                width: 240
                spacing: Tokens.spaceL

                Select {
                    objectName: "opens"
                    width: parent.width
                    overlay: sheet
                    options: testCase.outputs
                    currentIndex: 1
                }

                Select {
                    width: parent.width
                    options: [{ text: "Navi 21/23 HDMI/DP Audio Controller Digital Stereo (HDMI 3)", value: 0 }]
                    currentIndex: 0
                }

                Select {
                    width: parent.width
                    options: testCase.outputs
                    currentIndex: 0
                    disabledReason: "no other device"
                }
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "off";
        scene = createTemporaryObject(sceneComponent, testCase);
        select = findChild(scene, "select");
        list = select.list;
        activated = createTemporaryObject(spyComponent, testCase, { target: select });
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function named(name: string): var {
        return findChild(scene, name);
    }

    function box(of: var): var {
        return findChild(of, "box");
    }

    // The list's options, in order.
    function rows(of: var): var {
        return Array.from(of.list.rows).filter(row => row instanceof MenuItem && row.kind === "option");
    }

    function openFromKeys(of: var) {
        of.forceActiveFocus();
        keyClick(Qt.Key_Down);
        verify(of.list.open);
    }

    function test_the_box_is_a_fields_input_with_the_chosen_option_and_a_caret_at_its_end() {
        const field = box(select);
        compare(field.height, Tokens.controlHeight);
        compare(field.radius, Tokens.radiusS);
        compare(field.color, Tokens.color.bg);
        compare(field.border.width, Geometry.inputBorder);
        compare(field.border.color, Tokens.color.textContrastMedium);
        const chosen = findChild(select, "chosen");
        compare(chosen.text, "speakers");
        compare(chosen.x, Geometry.inputPadding);
        compare(chosen.font.pixelSize, Tokens.fontSizeS);
        const caret = findChild(select, "caret");
        compare(caret.width, 10);
        compare(caret.height, 5);
        compare(caret.x + caret.width, select.width - 1 - 13, "13px before the end of the padding box");
        compare(caret.y, Math.round(1 + 0.55 * (Tokens.controlHeight - 2 - 5)), "55% down");
        compare(caret.data[0].fillColor, Tokens.color.textPrimary);
        compare(chosen.width, select.width - Geometry.inputPadding - 36, "the text stops where the caret's padding starts");
    }

    function test_its_edge_darkens_under_the_pointer_and_with_the_focus_which_shows_the_ring() {
        const field = box(select);
        mouseMove(field, 20, 10);
        tryCompare(field.border, "color", Tokens.color.textPrimary);
        mouseMove(testCase, 900, 500);
        tryCompare(field.border, "color", Tokens.color.textContrastMedium);
        select.forceActiveFocus();
        compare(field.border.color, Tokens.color.textPrimary);
        verify(findChild(field, "ring").visible);
    }

    function test_a_press_opens_the_list_below_the_box_at_its_leading_edge_at_least_as_wide_as_the_box() {
        mouseClick(box(select));
        verify(list.open);
        compare(list.parent.parent, select.Window.contentItem, "over the window");
        const at = box(select).mapToItem(list.parent, 0, 0);
        tryCompare(list, "y", at.y + Tokens.controlHeight + Geometry.floatGap);
        compare(list.x, at.x);
        compare(list.side, "below");
        compare(list.width, select.width);
        select.width = 300;
        compare(list.width, 300, "a box wider than the list widens it");
        verify(!select.activeFocus, "a press gives no focus");
    }

    function test_its_options_offer_their_texts_and_the_chosen_one_carries_a_check() {
        mouseClick(box(select));
        const options = rows(select);
        compare(options.map(row => row.text), ["speakers", "headphones", "hdmi"]);
        compare(options.map(row => findChild(row, "mark").visible), [true, false, false]);
        compare(options.map(row => findChild(row, "check").visible), [false, false, false], "no box");
        const mark = findChild(options[0], "mark");
        compare(mark.width, 10);
        compare(mark.height, 6);
        compare(mark.rotation, -45);
        compare(mark.x, Tokens.spaceM);
        compare(findChild(options[0], "label").x, Tokens.spaceM + 10 + 2 + Tokens.spaceS, "every text after the check's slot");
        compare(findChild(options[1], "label").x, findChild(options[0], "label").x);
    }

    function test_down_alt_down_enter_and_space_open_the_list_on_the_chosen_option() {
        select.currentIndex = 1;
        for (const [key, modifiers] of [[Qt.Key_Down, Qt.NoModifier], [Qt.Key_Down, Qt.AltModifier], [Qt.Key_Return, Qt.NoModifier], [Qt.Key_Space, Qt.NoModifier]]) {
            select.forceActiveFocus();
            keyClick(key, modifiers);
            verify(list.open, `${key} ${modifiers}`);
            verify(rows(select)[1].activeFocus, "the focus starts on the chosen option");
            keyClick(Qt.Key_Escape);
            verify(!list.open);
        }
    }

    function test_up_leaves_a_closed_select_to_what_holds_it() {
        select.forceActiveFocus();
        keyClick(Qt.Key_Up);
        verify(!list.open);
    }

    function test_the_arrows_move_and_enter_chooses_closes_and_gives_the_focus_back() {
        openFromKeys(select);
        const options = rows(select);
        keyClick(Qt.Key_Down);
        verify(options[1].activeFocus);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        verify(options[0].activeFocus, "around the end");
        keyClick(Qt.Key_Up);
        verify(options[2].activeFocus);
        keyClick(Qt.Key_Return);
        verify(!list.open);
        verify(select.activeFocus);
        compare(select.currentIndex, 2);
        compare(select.currentValue, "c");
        compare(findChild(select, "chosen").text, "hdmi");
        compare(activated.count, 1);
        compare(activated.signalArguments[0][0], 2);
    }

    function test_choosing_the_chosen_option_again_changes_nothing() {
        openFromKeys(select);
        keyClick(Qt.Key_Return);
        verify(!list.open);
        compare(activated.count, 0);
    }

    function test_escape_closes_without_choosing_and_gives_the_focus_back() {
        openFromKeys(select);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Escape);
        verify(!list.open);
        verify(select.activeFocus);
        compare(select.currentIndex, 0);
        compare(activated.count, 0);
    }

    function test_tab_closes_it_and_moves_on() {
        openFromKeys(select);
        keyClick(Qt.Key_Tab);
        verify(!list.open);
        verify(named("after").activeFocus);
    }

    function test_a_click_on_an_option_chooses_it() {
        mouseClick(box(select));
        waitForRendering(scene);
        mouseClick(rows(select)[1]);
        verify(!list.open);
        compare(select.currentIndex, 1);
        compare(activated.count, 1);
    }

    function test_a_press_elsewhere_closes_the_list_and_reaches_what_lies_there() {
        const clicked = createTemporaryObject(spyComponent, testCase, { target: named("after"), signalName: "clicked" });
        mouseClick(box(select));
        mouseClick(named("after"));
        verify(!list.open);
        compare(clicked.count, 1);
        compare(activated.count, 0);
    }

    function test_a_press_on_the_box_while_the_list_is_open_closes_it() {
        mouseClick(box(select));
        mouseClick(box(select));
        verify(!list.open, "after a press");
        openFromKeys(select);
        mouseClick(box(select));
        verify(!list.open, "after the keys");
        verify(select.activeFocus, "and the focus is back on the box");
    }

    function test_the_wheel_elsewhere_closes_it() {
        mouseClick(box(select));
        mouseWheel(scene, 700, 400, 0, -120);
        verify(!list.open);
    }

    function test_with_no_room_below_the_list_floats_above_the_box() {
        const low = named("low");
        mouseClick(box(low));
        verify(low.list.open);
        const at = box(low).mapToItem(low.list.parent, 0, 0);
        tryVerify(() => low.list.height > 3 * Tokens.rowHeight, 1000, "laid out with all its options");
        compare(low.list.side, "above");
        compare(low.list.y, at.y - Geometry.floatGap - low.list.height);
        compare(low.list.x, at.x);
    }

    function test_the_list_closes_when_its_select_goes_out_of_sight() {
        mouseClick(box(select));
        select.visible = false;
        verify(!list.open);
    }

    function test_a_choice_from_outside_shows_at_once() {
        select.currentIndex = 2;
        compare(findChild(select, "chosen").text, "hdmi");
        mouseClick(box(select));
        compare(rows(select).map(row => row.checked), [false, false, true]);
    }

    function test_a_long_option_is_cut_in_the_box_and_in_the_list() {
        select.options = [{ text: "Navi 21/23 HDMI/DP Audio Controller Digital Stereo (HDMI 3) with a longer name still", value: 0 }, ...outputs];
        const chosen = findChild(select, "chosen");
        verify(chosen.truncated, "in the box");
        mouseClick(box(select));
        waitForRendering(scene);
        compare(list.width, Geometry.floatMaxSize, "the list no wider than a floating surface may be");
        const row = rows(select)[0];
        const label = findChild(row, "label");
        verify(label.truncated, "in the list");
        verify(label.x + label.width <= row.width - Tokens.spaceM);
    }

    function test_disabled_it_greys_stays_focusable_says_why_below_and_does_not_open() {
        select.disabledReason = "no other device";
        const field = box(select);
        compare(field.border.color, Tokens.color.disabled);
        compare(findChild(select, "chosen").color, Tokens.color.disabled);
        compare(findChild(select, "caret").data[0].fillColor, Tokens.color.disabled);
        const why = findChild(select, "why");
        verify(why.visible);
        compare(why.text, "no other device");
        compare(why.y, Tokens.controlHeight + Tokens.spaceXs);
        compare(select.implicitHeight, why.y + why.height);
        mouseClick(field);
        verify(!list.open);
        named("before").forceActiveFocus();
        keyClick(Qt.Key_Tab);
        verify(select.activeFocus, "still in the focus order");
        keyClick(Qt.Key_Down);
        verify(!list.open);
        compare(select.Accessible.description, "no other device");
    }

    function test_the_screen_reader_hears_what_it_chooses_and_the_choice() {
        compare(select.Accessible.role, Accessible.ComboBox);
        compare(select.Accessible.name, "ausgang speakers");
    }

    // Each pair of theme and density, closed and then with the first select's list open from the keyboard.
    function test_contact_sheet_of_selects_closed_and_open_in_both_themes_and_densities() {
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const sheet = createTemporaryObject(sheetComponent, testCase);
                const opens = findChild(sheet, "opens");
                waitForRendering(sheet);
                grabImage(sheet).save(`select-sheet-${theme}-${density}-closed.png`);
                openFromKeys(opens);
                waitForRendering(sheet);
                grabImage(sheet).save(`select-sheet-${theme}-${density}-open.png`);
                verify(opens.list.open, `${theme} ${density}`);
                sheet.destroy();
            }
        }
    }
}
