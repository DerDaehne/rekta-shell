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
    property SignalSpy activated
    // The default accent is ink, the same colour as the text; tests about the accent give it a colour of its own.
    property color inkLight
    property color inkDark

    Component {
        id: sceneComponent

        Item {
            width: 1000
            height: 600

            Column {
                x: 40
                y: 40
                width: 240
                spacing: Tokens.spaceM

                Button {
                    objectName: "before"
                    text: "before"
                }

                Select {
                    objectName: "select"
                    width: parent.width
                    label: "ausgang"
                    options: testCase.outputs
                    currentIndex: 0
                }

                Button {
                    objectName: "after"
                    text: "after"
                }
            }
        }
    }

    Component {
        id: spyComponent

        SignalSpy {
            signalName: "activated"
        }
    }

    // A select at the foot of a scroller's view, with more to scroll to below it.
    Component {
        id: scrollerComponent

        Flickable {
            x: 400
            width: 300
            height: 200
            contentHeight: content.height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content

                width: 300

                Item {
                    width: 300
                    height: 200 - Tokens.controlHeight
                }

                Select {
                    objectName: "low"
                    width: 300
                    options: testCase.outputs
                    currentIndex: 0
                }

                Item {
                    width: 300
                    height: 400
                }
            }
        }
    }

    Component {
        id: sheetComponent

        // Selects on the current theme's ground, one above the other: chosen, cut, disabled with its reason. The first
        // expands from the keys and pushes the others down.
        Rectangle {
            width: 320
            height: 400
            color: Tokens.color.bg

            Column {
                x: Tokens.spaceL
                y: Tokens.spaceL
                width: 240
                spacing: Tokens.spaceL

                Select {
                    objectName: "opens"
                    width: parent.width
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

    function initTestCase() {
        inkLight = Tokens.light.accent;
        inkDark = Tokens.dark.accent;
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "off";
        scene = createTemporaryObject(sceneComponent, testCase);
        select = findChild(scene, "select");
        activated = createTemporaryObject(spyComponent, testCase, { target: select });
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
        Tokens.light.accent = inkLight;
        Tokens.dark.accent = inkDark;
    }

    function useColourfulAccent() {
        Tokens.light.accent = "#1f5fd1";
        Tokens.dark.accent = "#7fb0ff";
    }

    function named(name: string): var {
        return findChild(scene, name);
    }

    function box(of: var): var {
        return findChild(of, "box");
    }

    // Its option rows, in order.
    function rows(of: var): var {
        return Array.from(findChild(of, "options").children).filter(row => row.objectName === "option");
    }

    function expandFromKeys(of: var) {
        of.forceActiveFocus();
        keyClick(Qt.Key_Down);
        verify(of.expanded);
    }

    // A key as Keys hands it over, held down when repeated.
    function keyEvent(code: int, repeated: bool): var {
        return { key: code, modifiers: Qt.NoModifier, isAutoRepeat: repeated };
    }

    function test_collapsed_the_box_is_a_fields_input_with_the_chosen_option_and_a_caret_at_its_end() {
        const field = box(select);
        compare(field.height, Tokens.controlHeight);
        compare(select.height, Tokens.controlHeight);
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
        verify(!findChild(select, "options").parent.visible, "no options in sight");
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

    function test_a_press_expands_it_in_place_its_box_growing_to_hold_every_option_as_a_row() {
        mouseClick(box(select));
        verify(select.expanded);
        verify(!select.activeFocus, "a press gives no focus");
        const field = box(select);
        compare(field.height, 2 * Geometry.inputBorder + 2 * Tokens.spaceXs + 3 * Tokens.rowHeight, "space-xs above and below the rows");
        compare(select.height, field.height);
        const options = rows(select);
        compare(options.map(row => findChild(row, "label").text), ["speakers", "headphones", "hdmi"]);
        options.forEach((row, k) => {
            const at = row.mapToItem(field, 0, 0);
            compare(at.y, Geometry.inputBorder + Tokens.spaceXs + k * Tokens.rowHeight, `row ${k}`);
            compare(at.x, Geometry.inputBorder);
            compare(row.width, field.width - 2 * Geometry.inputBorder);
            compare(row.height, Tokens.rowHeight);
            compare(findChild(row, "label").mapToItem(field, 0, 0).x, Geometry.inputPadding, "where the collapsed box has its text");
        });
        compare(findChild(select, "folded").opacity, 0, "no chosen line and no caret");
    }

    function test_what_stands_below_moves_down_by_exactly_what_the_box_grows() {
        const after = named("after");
        const before = after.y;
        mouseClick(box(select));
        const growth = box(select).height - Tokens.controlHeight;
        verify(growth > 0);
        tryCompare(after, "y", before + growth);
        mouseClick(rows(select)[0]);
        tryCompare(after, "y", before);
    }

    function test_the_chosen_option_takes_the_accent_with_on_accent_text() {
        useColourfulAccent();
        select.currentIndex = 1;
        mouseClick(box(select));
        const options = rows(select);
        compare(options.map(row => findChild(row, "fill").visible), [false, true, false]);
        compare(findChild(options[1], "fill").color, Tokens.color.accent);
        compare(findChild(options[1], "label").color, Tokens.color.textOnAccent);
        compare(findChild(options[0], "label").color, Tokens.color.textPrimary);
    }

    function test_the_row_the_keys_are_on_looks_focused_on_the_ground_and_on_the_accent() {
        useColourfulAccent();
        expandFromKeys(select);
        const options = rows(select);
        const onAccent = findChild(options[0], "ring");
        verify(onAccent.visible, "it starts on the chosen option");
        compare(onAccent.border.color, Tokens.color.textOnAccent, "in the text's colour on the accent");
        compare(onAccent.offset, -4);
        verify(findChild(options[0], "tint").visible);
        keyClick(Qt.Key_Down);
        verify(!onAccent.visible);
        const onGround = findChild(options[1], "ring");
        verify(onGround.visible);
        compare(onGround.border.color, Tokens.color.focus);
        compare(onGround.offset, -2);
        verify(findChild(options[1], "tint").visible, "with the hover colour");
        verify(!findChild(options[2], "tint").visible);
    }

    function test_an_option_under_the_pointer_takes_the_hover_colour() {
        mouseClick(box(select));
        const row = rows(select)[2];
        mouseMove(row, 20, row.height / 2);
        tryVerify(() => findChild(row, "tint").visible);
        verify(!findChild(rows(select)[1], "tint").visible);
        verify(!findChild(row, "ring").visible, "no ring without the keys");
    }

    function test_down_alt_down_enter_and_space_expand_it_on_the_chosen_option() {
        select.currentIndex = 1;
        for (const [code, modifiers] of [[Qt.Key_Down, Qt.NoModifier], [Qt.Key_Down, Qt.AltModifier], [Qt.Key_Return, Qt.NoModifier], [Qt.Key_Space, Qt.NoModifier]]) {
            select.forceActiveFocus();
            keyClick(code, modifiers);
            verify(select.expanded, `${code} ${modifiers}`);
            compare(select.highlighted, 1, "the keys start on the chosen option");
            keyClick(Qt.Key_Escape);
            verify(!select.expanded);
        }
    }

    function test_up_leaves_a_collapsed_select_to_what_holds_it() {
        select.forceActiveFocus();
        keyClick(Qt.Key_Up);
        verify(!select.expanded);
    }

    function test_the_arrows_move_and_stop_at_the_ends_home_and_end_jump_and_enter_chooses_and_collapses() {
        expandFromKeys(select);
        keyClick(Qt.Key_Up);
        compare(select.highlighted, 0, "no further than the first");
        keyClick(Qt.Key_Down);
        compare(select.highlighted, 1);
        keyClick(Qt.Key_End);
        compare(select.highlighted, 2);
        keyClick(Qt.Key_Down);
        compare(select.highlighted, 2, "no further than the last");
        keyClick(Qt.Key_Home);
        compare(select.highlighted, 0);
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_Return);
        verify(!select.expanded);
        verify(select.activeFocus, "the focus stays on the select");
        compare(select.currentIndex, 2);
        compare(select.currentValue, "c");
        compare(findChild(select, "chosen").text, "hdmi");
        compare(activated.count, 1);
        compare(activated.signalArguments[0][0], 2);
    }

    function test_choosing_the_chosen_option_again_collapses_and_changes_nothing() {
        expandFromKeys(select);
        keyClick(Qt.Key_Space);
        verify(!select.expanded);
        compare(activated.count, 0);
    }

    function test_escape_collapses_without_a_change() {
        expandFromKeys(select);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Escape);
        verify(!select.expanded);
        verify(select.activeFocus);
        compare(select.currentIndex, 0);
        compare(activated.count, 0);
        compare(box(select).height, Tokens.controlHeight);
    }

    function test_tab_collapses_it_and_moves_on() {
        expandFromKeys(select);
        keyClick(Qt.Key_Tab);
        verify(!select.expanded);
        verify(named("after").activeFocus);
    }

    function test_a_held_key_expands_or_chooses_only_once() {
        select.forceActiveFocus();
        verify(!select.handleKey(keyEvent(Qt.Key_Return, true)), "a repeat does not expand it");
        verify(!select.expanded);
        verify(select.handleKey(keyEvent(Qt.Key_Return, false)));
        verify(select.expanded);
        verify(select.handleKey(keyEvent(Qt.Key_Down, true)), "the arrows repeat");
        compare(select.highlighted, 1);
        verify(select.handleKey(keyEvent(Qt.Key_Return, true)));
        verify(select.expanded, "a repeat does not choose");
        compare(activated.count, 0);
    }

    function test_a_press_on_an_option_chooses_it_and_collapses() {
        mouseClick(box(select));
        waitForRendering(scene);
        mouseClick(rows(select)[1]);
        verify(!select.expanded);
        compare(select.currentIndex, 1);
        compare(activated.count, 1);
    }

    function test_out_of_sight_it_collapses_at_once_even_with_motion() {
        Prefs.motion = "on";
        mouseClick(box(select));
        tryCompare(select, "unfolded", 1, 4 * Tokens.durationShort);
        select.visible = false;
        verify(!select.expanded);
        compare(select.unfolded, 0);
        select.visible = true;
        compare(box(select).height, Tokens.controlHeight, "and comes back collapsed");
    }

    function test_a_choice_from_outside_shows_at_once() {
        select.currentIndex = 2;
        compare(findChild(select, "chosen").text, "hdmi");
        mouseClick(box(select));
        compare(rows(select).map(row => findChild(row, "fill").visible), [false, false, true]);
    }

    function test_it_unfolds_over_duration_short_with_ease_in_and_folds_in_0_7_of_that_with_ease_out() {
        Prefs.motion = "on";
        const unfolding = findChild(select, "unfolding");
        compare(unfolding.duration, Tokens.durationShort);
        compare(unfolding.easing.type, Easing.Bezier);
        compare(unfolding.easing.bezierCurve, Tokens.easeIn);
        const folding = findChild(select, "folding");
        compare(folding.duration, 0.7 * Tokens.durationShort);
        compare(folding.easing.bezierCurve, Tokens.easeOut);
        const field = box(select);
        const options = findChild(select, "options").parent;
        mouseClick(field);
        verify(field.height < select.expandedHeight, "it grows, it does not jump");
        tryVerify(() => select.unfolded > 0.2 && select.unfolded < 0.8, Tokens.durationShort);
        compare(options.opacity, select.unfolded, "the options fade in as it grows");
        compare(findChild(select, "folded").opacity, 1 - select.unfolded);
        compare(field.height, Tokens.controlHeight + select.unfolded * (select.expandedHeight - Tokens.controlHeight));
        tryCompare(field, "height", select.expandedHeight, 4 * Tokens.durationShort);
        mouseClick(rows(select)[1]);
        verify(field.height > Tokens.controlHeight);
        tryCompare(field, "height", Tokens.controlHeight, 4 * Tokens.durationShort);
    }

    function test_under_reduced_motion_it_expands_and_collapses_at_once() {
        mouseClick(box(select));
        compare(box(select).height, select.expandedHeight);
        compare(findChild(select, "options").parent.opacity, 1);
        mouseClick(rows(select)[0]);
        compare(box(select).height, Tokens.controlHeight);
    }

    function test_in_a_scroller_it_brings_its_options_into_view() {
        const view = createTemporaryObject(scrollerComponent, scene);
        const low = findChild(view, "low");
        waitForRendering(view);
        compare(view.contentY, 0);
        mouseClick(box(low));
        tryCompare(view, "contentY", low.y + low.height - view.height);
        verify(low.y >= view.contentY, "its top in view too");
        low.collapse();
        low.options = Array.from({ length: 12 }, (_, k) => ({ text: `device ${k}`, value: k }));
        low.expand();
        tryCompare(view, "contentY", low.y, 1000, "taller than the view, its top first");
    }

    function test_a_long_option_is_cut_in_the_box_and_in_its_row() {
        select.options = [{ text: "Navi 21/23 HDMI/DP Audio Controller Digital Stereo (HDMI 3) with a longer name still", value: 0 }, ...outputs];
        const chosen = findChild(select, "chosen");
        verify(chosen.truncated, "in the box");
        mouseClick(box(select));
        waitForRendering(scene);
        const row = rows(select)[0];
        const label = findChild(row, "label");
        verify(label.truncated, "in its row");
        compare(label.mapToItem(box(select), label.width, 0).x, select.width - Geometry.inputPadding, "the box's padding at its end");
    }

    function test_disabled_it_greys_stays_focusable_says_why_below_and_does_not_expand() {
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
        verify(!select.expanded);
        named("before").forceActiveFocus();
        keyClick(Qt.Key_Tab);
        verify(select.activeFocus, "still in the focus order");
        keyClick(Qt.Key_Down);
        verify(!select.expanded);
        compare(select.Accessible.description, "no other device");
    }

    function test_the_screen_reader_hears_what_it_chooses_the_choice_and_whether_it_is_expanded() {
        compare(select.Accessible.role, Accessible.ComboBox);
        compare(select.Accessible.name, "ausgang speakers");
        if ("expanded" in select.Accessible) {
            verify(select.Accessible.expandable);
            verify(!select.Accessible.expanded);
        }
        mouseClick(box(select));
        if ("expanded" in select.Accessible)
            verify(select.Accessible.expanded);
        const options = rows(select);
        compare(options[0].Accessible.role, Accessible.ListItem);
        compare(options.map(row => row.Accessible.name), ["speakers", "headphones", "hdmi"]);
        compare(options.map(row => row.Accessible.selected), [true, false, false]);
    }

    // Each pair of theme and density, collapsed and then with the first select expanded from the keys.
    function test_contact_sheet_of_selects_collapsed_and_expanded_in_both_themes_and_densities() {
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const sheet = createTemporaryObject(sheetComponent, testCase);
                const opens = findChild(sheet, "opens");
                waitForRendering(sheet);
                grabImage(sheet).save(`select-sheet-${theme}-${density}-closed.png`);
                expandFromKeys(opens);
                keyClick(Qt.Key_Down);
                waitForRendering(sheet);
                grabImage(sheet).save(`select-sheet-${theme}-${density}-open.png`);
                verify(opens.expanded, `${theme} ${density}`);
                sheet.destroy();
            }
        }
    }
}
