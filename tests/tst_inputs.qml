pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "Inputs"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 1200

    Component {
        id: toggleComponent

        Toggle {
            label: "wifi"
        }
    }

    Component {
        id: sliderComponent

        Slider {
            width: 300
            label: "volume"
            from: 0
            to: 100
            stepSize: 1
            value: 40
        }
    }

    Component {
        id: segmentsComponent

        Segments {
            options: ["light", "dark", "system"]
        }
    }

    Component {
        id: fieldComponent

        Field {
            width: 300
            label: "name"
            placeholder: "your name"
            hint: "as it appears on screen"
        }
    }

    Component {
        id: sheetComponent

        // Every input on the current theme's ground, in each state worth seeing.
        Rectangle {
            width: 480
            height: column.height + 2 * Tokens.spaceL
            color: Tokens.color.bg

            Column {
                id: column

                x: Tokens.spaceL
                y: Tokens.spaceL
                width: parent.width - 2 * Tokens.spaceL
                spacing: Tokens.spaceL

                Toggle { label: "wifi" }
                Toggle { label: "bluetooth"; checked: true }
                Toggle { label: "airplane"; disabledReason: "set by the administrator" }
                Slider { width: parent.width; label: "volume"; from: 0; to: 100; stepSize: 1; value: 40; valueText: `${value}%` }
                Slider { width: parent.width; label: "brightness"; value: 0.7; disabledReason: "no backlight" }
                Segments { options: ["light", "dark", "system"]; currentIndex: 1 }
                Segments { options: ["left", "right"]; disabledReason: "one output only" }
                Field { objectName: "focused"; width: parent.width; label: "name"; placeholder: "your name"; hint: "as it appears on screen" }
                Field { width: parent.width; label: "nickname"; optional: true; text: "rk" }
                Field { width: parent.width; label: "port"; text: "80a"; error: "only digits" }
                Field { width: parent.width; label: "host"; text: "localhost"; disabledReason: "set by the network" }
            }
        }
    }

    // The default accent is ink, the same colour as the text; tests about the accent give it a colour of its own.
    property color inkLight
    property color inkDark

    function initTestCase() {
        inkLight = Tokens.light.accent;
        inkDark = Tokens.dark.accent;
    }

    function useColourfulAccent() {
        Tokens.light.accent = "#1f5fd1";
        Tokens.dark.accent = "#7fb0ff";
    }

    function optionsOf(segments) {
        return Array.from(findChild(segments, "options").children).filter(child => child.modelData !== undefined);
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
        Tokens.light.accent = inkLight;
        Tokens.dark.accent = inkDark;
    }

    function test_a_toggle_switches_on_click_and_space_and_says_its_state() {
        const toggle = createTemporaryObject(toggleComponent, testCase);
        const word = findChild(toggle, "word");
        compare(word.text, "off");
        mouseClick(toggle);
        verify(toggle.checked);
        compare(word.text, "on");
        compare(toggle.Accessible.checked, true);
        verify(Accessible.Switch !== undefined);
        compare(toggle.Accessible.role, Accessible.Switch);
        toggle.forceActiveFocus();
        keyClick(Qt.Key_Space);
        verify(!toggle.checked);
        compare(word.text, "off");
    }

    function test_an_on_toggle_fills_in_the_accent_inside_a_two_pixel_frame() {
        useColourfulAccent();
        const toggle = createTemporaryObject(toggleComponent, testCase);
        const track = findChild(toggle, "track");
        const fill = findChild(toggle, "fill");
        const thumb = findChild(toggle, "thumb");
        compare(track.border.width, 2);
        compare(track.border.color, Tokens.color.textPrimary);
        compare(thumb.color, Tokens.color.textPrimary);
        compare(fill.width, 0);
        toggle.checked = true;
        compare(fill.color, Qt.color("#1f5fd1"));
        tryCompare(fill, "width", 46 - 2 * 4 - 14);
        tryCompare(thumb, "x", 46 - 12);
    }

    function test_the_toggle_label_stands_two_gaps_from_the_frame() {
        const toggle = createTemporaryObject(toggleComponent, testCase);
        const label = findChild(toggle, "label");
        const track = findChild(toggle, "track");
        fuzzyCompare(track.x - (label.x + label.contentWidth), 2 * Tokens.spaceS, 1);
    }

    function test_under_reduced_motion_a_toggle_jumps() {
        Prefs.motion = "off";
        const toggle = createTemporaryObject(toggleComponent, testCase);
        toggle.checked = true;
        compare(findChild(toggle, "fill").width, 46 - 2 * 4 - 14);
        compare(findChild(toggle, "thumb").x, 46 - 12);
    }

    function test_a_disabled_toggle_stays_and_says_why() {
        const toggle = createTemporaryObject(toggleComponent, testCase, { disabledReason: "set by the administrator" });
        mouseClick(toggle);
        verify(!toggle.checked);
        compare(findChild(toggle, "track").border.color, Tokens.color.disabled);
        compare(findChild(toggle, "word").color, Tokens.color.textContrastHigh, "the word keeps its colour");
        compare(toggle.Accessible.description, "set by the administrator");
    }

    function test_a_slider_follows_the_keys_within_its_range() {
        const slider = createTemporaryObject(sliderComponent, testCase);
        slider.forceActiveFocus();
        const expected = [
            [Qt.Key_Right, 41], [Qt.Key_Up, 42], [Qt.Key_Left, 41], [Qt.Key_Down, 40],
            [Qt.Key_PageUp, 50], [Qt.Key_PageDown, 40], [Qt.Key_End, 100], [Qt.Key_Right, 100],
            [Qt.Key_Home, 0], [Qt.Key_Left, 0]
        ];
        for (const [key, value] of expected) {
            keyClick(key);
            compare(slider.value, value, `after key ${key}`);
        }
    }

    function test_a_slider_steps_without_float_noise() {
        const slider = createTemporaryObject(sliderComponent, testCase, { to: 1, stepSize: 0.1, value: 0 });
        for (let i = 0; i < 3; i++)
            slider.setValue(slider.value + slider.stepSize);
        verify(slider.value === 0.3, `exactly 0.3, not ${slider.value}`);
    }

    function test_a_slider_fills_to_its_value_and_shows_it_in_tabular_figures() {
        useColourfulAccent();
        const slider = createTemporaryObject(sliderComponent, testCase);
        const track = findChild(slider, "track");
        const fill = findChild(slider, "fill");
        const output = findChild(slider, "output");
        compare(fill.width, track.width * 0.4);
        compare(fill.color, Qt.color("#1f5fd1"));
        compare(track.height, 6);
        compare(output.text, "40");
        verify(output.width >= 3.5 * output.font.pixelSize);
        compare(output.font.features["tnum"], 1);
        compare(slider.Accessible.description, "40");
    }

    function test_a_slider_keeps_its_thumb_under_the_pointer_and_takes_no_focus() {
        const slider = createTemporaryObject(sliderComponent, testCase);
        const track = findChild(slider, "track");
        const thumb = findChild(slider, "thumb");
        mousePress(track, 5 + 0.76 * (track.width - 10), 3);
        compare(slider.value, 76);
        verify(!slider.activeFocus, "only the keyboard brings the ring");
        mouseMove(track, track.width - 5, 3);
        compare(slider.value, 100);
        mouseMove(track, 5, 3);
        compare(slider.value, 0);
        compare(thumb.x, 0);
        mouseRelease(track, 5, 3);
    }

    function test_a_disabled_slider_ignores_the_keys_and_says_why() {
        useColourfulAccent();
        const slider = createTemporaryObject(sliderComponent, testCase, { disabledReason: "no backlight" });
        slider.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(slider.value, 40);
        compare(findChild(slider, "thumb").color, Tokens.color.disabled);
        compare(findChild(slider, "fill").color, Qt.color("#1f5fd1"), "only the thumb greys");
        compare(findChild(slider, "output").color, Tokens.color.textPrimary);
        const why = findChild(slider, "why");
        verify(why.visible);
        compare(why.text, "no backlight");
        verify(slider.height > Tokens.controlHeight);
    }

    function test_segments_follow_the_keys_and_slide_the_accent_over() {
        useColourfulAccent();
        const segments = createTemporaryObject(segmentsComponent, testCase);
        const slide = findChild(segments, "slide");
        const options = optionsOf(segments);
        compare(options.length, 3);
        compare(slide.x, options[0].x);
        compare(slide.color, Qt.color("#1f5fd1"));
        compare(options[0].border.color, Qt.color("#1f5fd1"));
        segments.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(segments.currentIndex, 1);
        verify(slide.x < options[1].x, "the block slides rather than jumps");
        tryCompare(slide, "x", options[1].x);
        keyClick(Qt.Key_Down);
        compare(segments.currentIndex, 2);
        keyClick(Qt.Key_Right);
        compare(segments.currentIndex, 2, "stops at the end");
        keyClick(Qt.Key_Left);
        compare(segments.currentIndex, 1);
        keyClick(Qt.Key_Up);
        compare(segments.currentIndex, 0);
        keyClick(Qt.Key_Left);
        compare(segments.currentIndex, 0, "stops at the start");
        keyClick(Qt.Key_End);
        compare(segments.currentIndex, 2);
        keyClick(Qt.Key_Home);
        compare(segments.currentIndex, 0);
    }

    function test_a_segment_is_as_wide_as_its_word_padding_and_frame() {
        const segments = createTemporaryObject(segmentsComponent, testCase);
        const option = optionsOf(segments)[0];
        const word = Array.from(option.children).find(child => child.text === "light");
        compare(option.width, word.implicitWidth + 2 * (Tokens.controlPadding + 2));
        compare(segments.Accessible.checked, true);
    }

    function test_a_choice_from_outside_stands_still_also_after_one_made_here() {
        const segments = createTemporaryObject(segmentsComponent, testCase);
        const slide = findChild(segments, "slide");
        const options = optionsOf(segments);
        segments.choose(1);
        tryCompare(segments, "sliding", false, Tokens.durationShort * 2);
        segments.currentIndex = 2;
        compare(slide.x, options[2].x);
        compare(options[2].lit, true);
    }

    function test_the_chosen_label_turns_light_halfway() {
        const segments = createTemporaryObject(segmentsComponent, testCase);
        const options = optionsOf(segments);
        compare(options[0].lit, true);
        segments.choose(1);
        compare(options[0].lit, false, "the label left turns dark at once");
        compare(options[1].lit, false, "the chosen label waits");
        tryCompare(options[1], "lit", true, Tokens.durationShort);
    }

    function test_under_reduced_motion_segments_jump() {
        Prefs.motion = "off";
        const segments = createTemporaryObject(segmentsComponent, testCase);
        const options = optionsOf(segments);
        segments.choose(2);
        compare(findChild(segments, "slide").x, options[2].x);
        compare(options[2].lit, true);
    }

    function test_disabled_segments_keep_the_chosen_accent_and_say_why() {
        useColourfulAccent();
        const segments = createTemporaryObject(segmentsComponent, testCase, { disabledReason: "one output only" });
        const slide = findChild(segments, "slide");
        verify(slide.visible);
        compare(slide.color, Qt.color("#1f5fd1"));
        for (const option of optionsOf(segments))
            compare(option.border.color, Tokens.color.disabled);
        const why = findChild(segments, "why");
        verify(why.visible);
        compare(why.text, "one output only");
        segments.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(segments.currentIndex, 0);
    }

    function test_more_than_five_segments_warn() {
        ignoreWarning(/Segments: 6 options; more than five belong in a select/);
        createTemporaryObject(segmentsComponent, testCase, { options: ["a", "b", "c", "d", "e", "f"] });
    }

    function test_a_field_shows_its_placeholder_until_typed_into() {
        const field = createTemporaryObject(fieldComponent, testCase);
        const placeholder = findChild(field, "placeholder");
        verify(placeholder.visible);
        compare(placeholder.color, Tokens.color.textContrastMedium);
        mouseClick(findChild(field, "box"));
        keyClick(Qt.Key_R);
        compare(field.text, "r");
        verify(!placeholder.visible);
    }

    function test_an_optional_field_says_so_in_regular_and_a_required_one_carries_no_mark() {
        const field = createTemporaryObject(fieldComponent, testCase);
        const label = findChild(field, "label");
        const optional = findChild(field, "optional");
        compare(label.text, "name");
        compare(label.font.weight, Tokens.fontWeightSemibold);
        verify(!optional.visible);
        field.optional = true;
        verify(optional.visible);
        compare(optional.text, " (optional)");
        compare(optional.font.weight, Tokens.fontWeightRegular);
    }

    function test_an_error_replaces_the_hint_behind_the_error_square_and_thickens_the_border() {
        const field = createTemporaryObject(fieldComponent, testCase);
        const box = findChild(field, "box");
        const hint = findChild(field, "hint");
        const mark = findChild(field, "errorMark");
        compare(hint.text, "as it appears on screen");
        compare(box.border.width, 1);
        verify(!mark.visible);
        field.error = "only letters";
        compare(hint.text, "only letters");
        compare(hint.color, Tokens.color.textPrimary);
        compare(box.border.width, 2);
        verify(mark.visible);
        compare(mark.width, 8);
        compare(mark.y + mark.height, hint.baselineOffset, "it sits on the baseline");
        compare(mark.color, Tokens.color.statusErrorFull);
        tryCompare(box.border, "color", Tokens.color.statusErrorFull);
    }

    function test_a_disabled_field_is_read_only_and_says_why() {
        const field = createTemporaryObject(fieldComponent, testCase, { disabledReason: "set by the network", text: "host" });
        mouseClick(findChild(field, "box"));
        keyClick(Qt.Key_X);
        compare(field.text, "host");
        compare(findChild(field, "hint").text, "set by the network");
    }

    // The inputs follow the one current theme and density, so the sheet is drawn once per pair, the name field focused.
    function test_contact_sheet_of_inputs_in_both_themes_and_densities() {
        Prefs.motion = "off";
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const sheet = createTemporaryObject(sheetComponent, testCase);
                findChild(findChild(sheet, "focused"), "input").forceActiveFocus();
                waitForRendering(sheet);
                grabImage(sheet).save(`inputs-sheet-${theme}-${density}.png`);
                verify(sheet.height > 0, `${theme} ${density}`);
                sheet.destroy();
            }
        }
    }
}
