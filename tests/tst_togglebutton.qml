pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import "ContactSheets.js" as ContactSheets

TestCase {
    id: testCase

    name: "ToggleButton"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 600

    Component {
        id: buttonComponent

        ToggleButton {
            width: 2 * Tokens.tileUnit
            icon: "bell"
            text: "alerts"
        }
    }

    Component {
        id: spyComponent

        SignalSpy {}
    }

    Component {
        id: sheetComponent

        // Off and on, with a value, with details, focused, and disabled off and on, on the current theme's ground.
        Rectangle {
            width: grid.width + 2 * Tokens.spaceL
            height: grid.height + 2 * Tokens.spaceL
            color: Tokens.color.bg

            Grid {
                id: grid

                x: Tokens.spaceL
                y: Tokens.spaceL
                columns: 2
                spacing: Tokens.spaceS

                Repeater {
                    model: [
                        { name: "off", text: "bluetooth", icon: "bluetooth" },
                        { name: "on", text: "dunkel", icon: "theme", checked: true },
                        { name: "value", text: "wlan", icon: "wireless", checked: true, value: "Home", details: true },
                        { name: "details", text: "bluetooth", icon: "bluetooth", details: true },
                        { name: "focused", text: "nicht stören", icon: "bell", checked: true },
                        { name: "long", text: "wlan", icon: "wireless", checked: true, value: "The network of the guest room upstairs", details: true },
                        { name: "disabledOff", text: "bluetooth", icon: "bluetooth", disabledReason: "funk gesperrt" },
                        { name: "disabledOn", text: "wlan", icon: "wireless", checked: true, disabledReason: "funk gesperrt" }
                    ]

                    delegate: ToggleButton {
                        required property var modelData

                        objectName: modelData.name
                        width: Tokens.tileUnit + Tokens.tileUnit / 4
                        text: modelData.text
                        icon: modelData.icon
                        onWord: "an"
                        offWord: "aus"
                        checked: modelData.checked ?? false
                        value: modelData.value ?? ""
                        details: modelData.details ?? false
                        disabledReason: modelData.disabledReason ?? ""
                    }
                }
            }
        }
    }

    // The default accent is ink, the text colour, and on-accent is the ground; colour tests give both their own colour.
    property color inkLight
    property color onInkLight

    function initTestCase() {
        inkLight = Tokens.light.accent;
        onInkLight = Tokens.light.textOnAccent;
    }

    function init() {
        Prefs.theme = "light";
        Prefs.motion = "off";
        Tokens.light.accent = "#1f5fd1";
        Tokens.light.textOnAccent = "#fffbe0";
    }

    function cleanup() {
        Tokens.light.accent = inkLight;
        Tokens.light.textOnAccent = onInkLight;
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function make(properties: var): var {
        return createTemporaryObject(buttonComponent, testCase, properties ?? {});
    }

    function spy(target: var, signalName: string): var {
        return createTemporaryObject(spyComponent, testCase, { target, signalName });
    }

    function test_pressed_it_takes_the_accent_fill_with_on_accent_words_like_a_chosen_segment() {
        const button = make({ checked: true });
        const fill = findChild(button, "fill");
        compare(fill.color, Tokens.color.accent);
        compare(fill.opacity, 1);
        compare(findChild(button, "frame").border.color, Tokens.color.accent);
        compare(findChild(button, "frame").border.width, Geometry.buttonBorder);
        compare(fill.radius, Tokens.radiusS);
        for (const part of ["word", "state", "glyph"])
            compare(findChild(button, part).color, Tokens.color.textOnAccent, part);
    }

    function test_not_pressed_it_is_a_quiet_button_whose_words_darken_under_the_pointer() {
        const button = make();
        compare(findChild(button, "fill").opacity, 0, "no fill");
        compare(findChild(button, "frame").border.color, Qt.color("transparent"), "no frame");
        compare(findChild(button, "word").color, Tokens.color.textContrastHigh);
        compare(findChild(button, "glyph").color, Tokens.color.textContrastHigh);
        mouseMove(findChild(button, "box"));
        tryCompare(button, "hovered", true);
        compare(findChild(button, "word").color, Tokens.color.textPrimary);
        compare(findChild(button, "press").opacity, 1, "and the hover colour lies over it");
        compare(findChild(button, "press").color, Tokens.color.hover);
    }

    function test_a_press_switches_it_at_once_without_giving_focus() {
        const button = make();
        const toggled = spy(button, "toggled");
        mouseClick(findChild(button, "box"));
        verify(button.checked);
        compare(toggled.count, 1);
        verify(!button.activeFocus, "only the keyboard brings the ring");
        mouseClick(findChild(button, "box"));
        verify(!button.checked);
        compare(toggled.count, 2);
    }

    function test_space_and_enter_switch_it_and_a_held_key_switches_once() {
        const button = make();
        button.forceActiveFocus();
        keyClick(Qt.Key_Space);
        verify(button.checked);
        keyClick(Qt.Key_Return);
        verify(!button.checked);
        keyClick(Qt.Key_Enter);
        verify(button.checked);
        const held = { key: Qt.Key_Space, isAutoRepeat: true, accepted: false };
        button.handleKey(held);
        verify(held.accepted);
        verify(button.checked, "the repeats of a held key do nothing more");
        verify(findChild(button, "ring").visible, "the keyboard shows the ring");
    }

    function test_the_fill_eases_in_and_out_over_duration_short_and_at_once_under_reduced_motion() {
        Prefs.motion = "on";
        const button = make();
        const fill = findChild(button, "fill");
        button.toggle();
        verify(fill.opacity < 1, "it eases in");
        tryCompare(fill, "opacity", 1, 4 * Tokens.durationShort);
        button.toggle();
        verify(fill.opacity > 0, "and out");
        tryCompare(fill, "opacity", 0, 4 * Tokens.durationShort);
        Prefs.motion = "off";
        button.toggle();
        compare(fill.opacity, 1, "reduced, it is there at once");
    }

    function test_it_is_read_as_a_button_pressed_or_not_and_by_its_word() {
        const button = make();
        compare(button.Accessible.role, Accessible.Button);
        verify(button.Accessible.checkable);
        verify(!button.Accessible.checked);
        compare(button.Accessible.name, "alerts", "on and off are said by the pressed state, not by the name");
        button.toggle();
        verify(button.Accessible.checked);
        button.value = "Home";
        compare(button.Accessible.name, "alerts Home", "a value is read with it");
    }

    function test_its_state_word_says_on_or_off_or_the_value_that_stands_for_it() {
        const button = make({ onWord: "an", offWord: "aus" });
        const state = findChild(button, "state");
        compare(state.text, "aus");
        button.checked = true;
        compare(state.text, "an");
        button.value = "Home";
        compare(state.text, "Home");
        compare(state.font.pixelSize, Tokens.fontSizeXs);
        compare(state.font.weight, Tokens.fontWeightRegular);
        compare(state.lineHeight, Tokens.lineHeightCompact * Tokens.fontSizeXs);
    }

    function test_its_icon_stands_beside_its_word_with_the_state_word_below_from_the_start() {
        for (const density of ["compact", "comfortable"]) {
            Prefs.density = density;
            const button = make();
            const box = findChild(button, "box");
            const glyph = findChild(button, "glyph");
            const word = findChild(button, "word");
            const state = findChild(button, "state");
            const inner = Geometry.buttonBorder + Tokens.controlPadding;
            compare(glyph.x, inner, `${density}: from the start, inside the frame and the padding`);
            compare(glyph.size, Geometry.iconSize);
            compare(word.mapToItem(box, 0, 0).x, inner + Geometry.iconSize + Tokens.spaceS, "the word beside the icon");
            compare(word.font.weight, Tokens.fontWeightSemibold);
            compare(word.font.pixelSize, Tokens.fontSizeS);
            compare(state.mapToItem(box, 0, 0).x, word.mapToItem(box, 0, 0).x);
            compare(state.y, word.y + word.height, "the state word below it");
            compare(box.height, Math.max(Tokens.controlHeight, 2 * Geometry.buttonBorder + word.height + state.height), "no padding above or below the two lines");
            compare(word.mapToItem(box, 0, 0).y - (box.height - word.height - state.height) / 2, 0, "the lines centred");
            compare(button.height, box.height);
        }
    }

    function test_words_too_long_for_its_place_are_cut() {
        const button = make({ value: "The network of the guest room upstairs, next to the stairs", details: true });
        const state = findChild(button, "state");
        verify(state.truncated);
        compare(state.mapToItem(button, 0, 0).x + state.width, findChild(button, "chevron").x - Tokens.spaceS, "they end before the chevron");
        button.details = false;
        compare(state.mapToItem(button, 0, 0).x + state.width, button.width - Geometry.buttonBorder - Tokens.controlPadding, "else at the padding");
    }

    function test_disabled_it_keeps_its_state_greys_and_says_why_below() {
        const button = make({ disabledReason: "funk gesperrt" });
        const why = findChild(button, "why");
        verify(why.visible);
        compare(why.text, "funk gesperrt");
        compare(why.y, findChild(button, "box").height + Tokens.spaceXs, "space-xs below it");
        compare(button.height, why.y + why.height);
        compare(button.Accessible.description, "funk gesperrt");
        compare(findChild(button, "frame").border.color, Tokens.color.disabled);
        compare(findChild(button, "word").color, Tokens.color.disabled);
        button.checked = true;
        compare(findChild(button, "fill").color, Tokens.color.disabled, "pressed, a disabled fill");
        compare(findChild(button, "fill").opacity, 1);
        compare(findChild(button, "word").color, Tokens.color.bg, "with words in the ground colour");
        mousePress(findChild(button, "box"));
        compare(findChild(button, "press").opacity, 0, "no press colour");
        mouseRelease(findChild(button, "box"));
        verify(button.checked, "a press does not switch it");
        button.forceActiveFocus();
        verify(button.activeFocus, "it stays focusable");
        keyClick(Qt.Key_Space);
        verify(button.checked, "nor does a key");
        button.disabledReason = "";
        verify(!why.visible);
    }

    function test_with_details_a_chevron_ends_it_and_a_press_there_asks_for_them_without_switching() {
        const button = make({ details: true });
        const asked = spy(button, "detailsAsked");
        const chevron = findChild(button, "chevron");
        verify(chevron.visible);
        compare(chevron.x, button.width - Geometry.buttonBorder - Tokens.controlPadding - Geometry.iconSize, "at the end, inside the padding");
        compare(chevron.color, findChild(button, "word").color);
        mouseClick(button, chevron.x + chevron.width / 2, button.height / 2);
        compare(asked.count, 1);
        verify(!button.checked, "the details part does not switch");
        mouseClick(button, button.detailsStart - 2, button.height / 2);
        verify(button.checked, "before it, a press switches");
        compare(asked.count, 1);
    }

    function test_a_right_click_and_the_menu_key_ask_for_the_details() {
        const button = make({ details: true });
        const asked = spy(button, "detailsAsked");
        mouseClick(findChild(button, "box"), 10, 10, Qt.RightButton);
        compare(asked.count, 1);
        verify(!button.checked);
        button.forceActiveFocus();
        keyClick(Qt.Key_Menu);
        compare(asked.count, 2);
        verify(!button.checked);
    }

    function test_without_details_there_is_no_chevron_and_a_right_click_does_nothing() {
        const button = make();
        const asked = spy(button, "detailsAsked");
        verify(!findChild(button, "chevron").visible);
        mouseClick(findChild(button, "box"), button.width - 10, 10);
        verify(button.checked, "the end switches like the rest");
        mouseClick(findChild(button, "box"), 10, 10, Qt.RightButton);
        button.forceActiveFocus();
        keyClick(Qt.Key_Menu);
        compare(asked.count, 0);
        verify(button.checked, "nor does it switch");
    }

    function test_disabled_it_opens_no_details() {
        const button = make({ details: true, disabledReason: "funk gesperrt" });
        const asked = spy(button, "detailsAsked");
        mouseClick(findChild(button, "box"), 10, 10, Qt.RightButton);
        button.forceActiveFocus();
        keyClick(Qt.Key_Menu);
        compare(asked.count, 0);
    }

    // The buttons follow the one current theme and density, so the sheet is drawn once per pair.
    function test_contact_sheet_of_toggle_buttons_in_both_themes_and_densities() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        Tokens.light.accent = inkLight;
        Tokens.light.textOnAccent = onInkLight;
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const sheet = createTemporaryObject(sheetComponent, testCase);
                findChild(sheet, "focused").forceActiveFocus();
                waitForRendering(sheet);
                grabImage(sheet).save(`togglebutton-sheet-${theme}-${density}.png`);
                verify(findChild(sheet, "long").height > 0, `${theme} ${density}`);
                sheet.destroy();
            }
        }
    }
}
