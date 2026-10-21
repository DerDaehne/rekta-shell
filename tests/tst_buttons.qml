pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "Buttons"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 600

    Component {
        id: buttonComponent

        Button {
            text: "save schedule"
            pendingText: "saving schedule…"
        }
    }

    Component {
        id: iconComponent

        IconButton {
            icon: "close"
            label: "close"
        }
    }

    Component {
        id: spy

        SignalSpy {
            signalName: "clicked"
        }
    }

    Component {
        id: sheetComponent

        // Each kind in each state on the current theme's ground: resting, pressed, focused, pending, disabled.
        Rectangle {
            width: 980
            height: grid.height + 2 * Tokens.spaceL
            color: Tokens.color.bg

            Grid {
                id: grid

                x: Tokens.spaceL
                y: Tokens.spaceL
                columns: 5
                columnSpacing: Tokens.spaceL
                rowSpacing: Tokens.spaceXl
                verticalItemAlignment: Grid.AlignVCenter

                Repeater {
                    model: ["", "primary", "quiet", "destructive"]

                    delegate: Repeater {
                        id: kind

                        required property string modelData

                        model: ["resting", "pressed", "focused", "pending", "disabled"]

                        delegate: Button {
                            required property string modelData

                            objectName: `${kind.modelData || "framed"}-${modelData}`
                            variant: kind.modelData
                            text: kind.modelData === "destructive" ? "delete" : "save"
                            pendingText: kind.modelData === "destructive" ? "deleting…" : "saving…"
                            pending: modelData === "pending"
                            disabledReason: modelData === "disabled" ? "no changes" : ""
                        }
                    }
                }

                IconButton { icon: "close"; label: "close" }
                IconButton { icon: "more"; label: "more"; variant: "quiet" }
                IconButton { icon: "search"; label: "search"; variant: "primary" }
                Button { icon: "plus"; text: "add" }
                IconButton { icon: "close"; label: "close"; disabledReason: "busy" }
            }
        }
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
        Prefs.systemHasTouch = false;
    }

    function test_each_kind_takes_its_colours_from_the_tokens() {
        const expected = [
            ["", "transparent", Tokens.color.textPrimary, Tokens.color.textPrimary],
            ["primary", Tokens.color.accent, Tokens.color.accent, Tokens.color.textOnAccent],
            ["quiet", "transparent", "transparent", Tokens.color.textContrastHigh],
            ["destructive", "transparent", Tokens.color.statusErrorFull, Tokens.color.statusErrorFull]
        ];
        for (const [variant, fill, frame, ink] of expected) {
            const button = createTemporaryObject(buttonComponent, testCase, { variant: variant });
            compare(findChild(button, "fill").color, Qt.color(fill), `${variant} fill`);
            compare(findChild(button, "frame").border.color, Qt.color(frame), `${variant} frame`);
            compare(findChild(button, "frame").border.width, 2, `${variant} frame width`);
            compare(findChild(button, "label").color, ink, `${variant} words`);
            compare(findChild(button, "label").font.weight, Tokens.fontWeightSemibold);
            compare(findChild(button, "fill").radius, Tokens.radiusS);
        }
    }

    function test_the_height_follows_the_density() {
        for (const density of ["compact", "comfortable"]) {
            Prefs.density = density;
            const button = createTemporaryObject(buttonComponent, testCase);
            compare(findChild(button, "box").height, Tokens.controlHeight, density);
        }
        verify(Tokens.controlHeight === 44, "comfortable is the larger one");
    }

    function test_hover_and_press_lay_the_hover_colour_over_it() {
        const button = createTemporaryObject(buttonComponent, testCase, { variant: "primary" });
        const press = findChild(button, "press");
        compare(press.color, Tokens.color.hover);
        compare(press.opacity, 0);
        mousePress(findChild(button, "box"));
        compare(press.opacity, 1, "the primary's overlay changes at once");
        mouseRelease(findChild(button, "box"));
    }

    function test_a_click_acts_without_giving_focus() {
        const button = createTemporaryObject(buttonComponent, testCase);
        const clicks = createTemporaryObject(spy, testCase, { target: button });
        mouseClick(findChild(button, "box"));
        compare(clicks.count, 1);
        verify(!button.activeFocus, "only the keyboard brings the ring");
    }

    function test_space_and_enter_act() {
        const button = createTemporaryObject(buttonComponent, testCase);
        const clicks = createTemporaryObject(spy, testCase, { target: button });
        button.forceActiveFocus();
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Enter);
        compare(clicks.count, 3);
    }

    function test_a_pending_button_keeps_its_width_and_refuses() {
        const button = createTemporaryObject(buttonComponent, testCase, { pendingText: "saving…" });
        const clicks = createTemporaryObject(spy, testCase, { target: button });
        const box = findChild(button, "box");
        const width = box.width;
        button.pending = true;
        compare(findChild(button, "label").text, "saving…");
        compare(box.width, width, "a shorter label keeps the width");
        compare(findChild(button, "label").color, Tokens.color.textPrimary, "it keeps its colours");
        button.forceActiveFocus();
        verify(button.activeFocus, "it stays focusable");
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Return);
        mouseClick(box);
        compare(clicks.count, 0);
        button.pendingText = "saving the whole schedule…";
        verify(box.width > width, "a longer one may grow, as min-width does");
    }

    function test_the_pending_line_waits_for_busy_delay_and_stays_for_busy_min() {
        const button = createTemporaryObject(buttonComponent, testCase);
        const line = findChild(button, "pendingLine");
        const box = findChild(button, "box");
        compare(line.y, box.height + 2, "it runs 2px under the frame");
        compare(line.width, box.width - 4);
        button.pending = true;
        wait(Tokens.durationBusyDelay / 2);
        verify(!line.shown, "not before busy-delay");
        tryCompare(line, "shown", true, Tokens.durationBusyDelay * 2);
        button.pending = false;
        compare(findChild(button, "label").text, "save schedule");
        wait(Tokens.durationBusyMin / 2);
        verify(line.shown, "stays for busy-min");
        tryCompare(line, "shown", false, Tokens.durationBusyMin * 2);
    }

    function test_under_reduced_motion_the_pending_line_stands_still() {
        Prefs.motion = "off";
        const button = createTemporaryObject(buttonComponent, testCase, { pending: true });
        const line = findChild(button, "pendingLine");
        tryCompare(line, "shown", true, Tokens.durationBusyDelay * 2);
        const segment = findChild(line, "segment");
        compare(segment.x, 0);
        compare(segment.width, line.width);
        compare(findChild(line, "busySegment").ink, Tokens.color.textContrastMedium);
    }

    function test_a_disabled_button_stays_focusable_says_why_and_refuses() {
        const button = createTemporaryObject(buttonComponent, testCase, { variant: "primary", disabledReason: "no changes" });
        const clicks = createTemporaryObject(spy, testCase, { target: button });
        const why = findChild(button, "why");
        verify(why.visible);
        compare(why.text, "no changes");
        compare(button.Accessible.description, "no changes");
        compare(findChild(button, "fill").color, Qt.color("transparent"), "never filled");
        compare(findChild(button, "frame").border.color, Tokens.color.disabled);
        compare(findChild(button, "label").color, Tokens.color.disabled);
        mousePress(findChild(button, "box"));
        compare(findChild(button, "press").opacity, 0, "no press colour");
        mouseRelease(findChild(button, "box"));
        button.forceActiveFocus();
        verify(button.activeFocus);
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Enter);
        compare(clicks.count, 0);
        button.disabledReason = "";
        verify(!why.visible);
    }

    function test_an_icon_button_is_square_at_the_control_height() {
        const button = createTemporaryObject(iconComponent, testCase);
        const box = findChild(button, "box");
        compare(box.width, Tokens.controlHeight);
        compare(box.height, Tokens.controlHeight);
        compare(button.Accessible.name, "close");
        button.inRow = true;
        compare(box.height, Tokens.rowHeight);
        Prefs.density = "compact";
        Prefs.systemHasTouch = true;
        compare(box.width, Tokens.touchTarget, "never below the touch target under a coarse pointer");
        compare(box.height, Tokens.touchTarget);
    }

    function test_an_icon_button_without_a_label_warns() {
        ignoreWarning(/IconButton "close": no label/);
        createTemporaryObject(iconComponent, testCase, { label: "" });
    }

    // The buttons follow the one current theme and density, so the sheet is drawn once per pair.
    function test_contact_sheet_of_buttons_in_both_themes_and_densities() {
        Prefs.motion = "off";
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const sheet = createTemporaryObject(sheetComponent, testCase);
                for (const kind of ["framed", "primary", "quiet", "destructive"]) {
                    // Pressed and focused stand in for their states; only one can hold the focus at a time.
                    findChild(findChild(sheet, `${kind}-pressed`), "press").opacity = 1;
                }
                findChild(sheet, "primary-focused").forceActiveFocus();
                wait(Tokens.durationBusyDelay + 50);
                waitForRendering(sheet);
                grabImage(sheet).save(`buttons-sheet-${theme}-${density}.png`);
                verify(sheet.height > 0, `${theme} ${density}`);
                sheet.destroy();
            }
        }
    }
}
