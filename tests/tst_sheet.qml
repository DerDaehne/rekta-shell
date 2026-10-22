pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "Sheet"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1640
    height: 1040

    // What lies behind a sheet: a place with a title, a line and a control, on the theme's ground.
    component Behind: Rectangle {
        color: Tokens.color.bg

        Column {
            x: Tokens.spaceL
            y: Tokens.spaceL
            width: parent.width - 2 * Tokens.spaceL
            spacing: Tokens.spaceM

            Title {
                width: parent.width
                text: "nightly builds"
            }

            Body {
                width: parent.width
                text: "The builds of every branch, run at two each night and kept for thirty days."
            }

            Button {
                text: "run now"
            }
        }
    }

    // A form in a sheet (forms.md, "A form in a sheet").
    component RenameSheet: Sheet {
        id: rename

        // What the form was loaded with: it is dirty while it differs.
        property string loaded: "nightly builds"

        kicker: "group"
        title: "Rename the group"
        dirty: nameField.text !== loaded

        Field {
            id: nameField

            objectName: "name"
            width: parent.width
            label: "name"
            text: rename.loaded
        }

        Actions {
            width: parent.width

            Button {
                objectName: "cancel"
                text: "cancel"
                onClicked: rename.request("cancel")
            }

            Button {
                objectName: "save"
                variant: "primary"
                text: "rename"
                onClicked: rename.close("save")
            }
        }
    }

    component DeleteConfirm: Confirm {
        kicker: "project"
        title: "Delete the project?"
        text: "Its 12 runs and their logs go with it."
        ok: "delete the project"
        cancel: "keep the project"
        safe: "cancel"
    }

    Component {
        id: sceneComponent

        // The host: it routes every key nobody took to the key layers, as a shell's root does.
        Item {
            width: 1000
            height: 600
            Keys.onPressed: event => KeyLayers.dispatch(event, Window.activeFocusItem)

            Behind {
                anchors.fill: parent
            }

            Button {
                objectName: "opener"
                x: 600
                y: 300
                text: "rename"
            }

            RenameSheet {
                objectName: "sheet"
                anchors.fill: parent
            }

            Confirm {
                objectName: "confirm"
                anchors.fill: parent
                title: "Archive the group?"
            }
        }
    }

    Component {
        id: closedSpyComponent

        SignalSpy {
            signalName: "closed"
        }
    }

    Component {
        id: scrollerBehindComponent

        // Something behind the sheet that scrolls.
        Flickable {
            anchors.fill: parent
            z: -1
            contentHeight: 5000
        }
    }

    Component {
        id: answeredSpyComponent

        SignalSpy {
            signalName: "answered"
        }
    }

    // A sideways place with its content, for a sheet to cover.
    component Host: Item {
        width: 800
        height: 500

        Behind {
            anchors.fill: parent
        }
    }

    Component {
        id: contactComponent

        // A form, a confirmation for an action that cannot be undone and the question before unsaved input goes, in
        // a sideways viewport; the form again in a narrow one.
        Rectangle {
            width: grid.width
            height: grid.height
            color: Tokens.color.bg

            Grid {
                id: grid

                columns: 2
                spacing: Tokens.spaceM

                Host {
                    RenameSheet {
                        objectName: "form"
                        anchors.fill: parent
                    }
                }

                Host {
                    DeleteConfirm {
                        objectName: "confirm"
                        anchors.fill: parent
                    }
                }

                Host {
                    RenameSheet {
                        objectName: "asking"
                        anchors.fill: parent
                        dirty: true
                    }
                }

                Host {
                    width: 400

                    RenameSheet {
                        objectName: "narrow"
                        anchors.fill: parent
                    }
                }
            }
        }
    }

    property Item scene
    property Sheet sheet
    property Confirm confirm
    property SignalSpy closedSpy

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        scene = createTemporaryObject(sceneComponent, testCase);
        sheet = findChild(scene, "sheet");
        confirm = findChild(scene, "confirm");
        closedSpy = createTemporaryObject(closedSpyComponent, testCase, { target: sheet });
        named("opener").forceActiveFocus();
    }

    function cleanup() {
        Tips.hide();
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function named(name: string): var {
        return findChild(scene, name);
    }

    function input(): var {
        return findChild(named("name"), "input");
    }

    function panel(of: var): var {
        return findChild(of, "panel");
    }

    // Opens a sheet and waits for it to be in.
    function openFully(of: var) {
        of.show();
        tryCompare(of, "entry", 1, Tokens.durationShort * 4);
    }

    function closedWith(answer: string) {
        tryCompare(closedSpy, "count", 1, Tokens.durationShort * 4);
        compare(closedSpy.signalArguments[0][0], answer);
        verify(!sheet.visible);
    }

    function test_a_sheet_hangs_from_the_top_edge_32rem_wide_on_the_ground_with_a_hairline_below() {
        Prefs.motion = "off";
        sheet.show();
        const box = panel(sheet);
        compare(box.width, 512);
        compare(box.x, (1000 - 512) / 2, "centred");
        compare(box.mapToItem(sheet, 0, 0).y, 0, "at the top edge");
        compare(box.color, Tokens.color.textContrastLow, "the hairline shows under the ground");
        compare(box.topLeftRadius, 0);
        compare(box.bottomLeftRadius, Tokens.radiusM);
        const scroller = findChild(sheet, "scroller");
        compare(box.height, scroller.height + Geometry.hairline);
        compare(scroller.parent.color, Tokens.color.bg);
        compare(findChild(sheet, "shading").color, Tokens.color.shading);
        scene.width = 400;
        compare(box.width, 400, "never wider than the window");
    }

    function test_a_sheet_takes_space_l_above_and_below_and_space_xl_at_the_sides_when_sideways() {
        Prefs.motion = "off";
        sheet.show();
        const form = findChild(sheet, "form");
        compare(form.x, Tokens.spaceXl, "a sideways viewport");
        compare(form.y, Tokens.spaceL);
        tryCompare(findChild(sheet, "scroller"), "contentHeight", form.height + 2 * Tokens.spaceL);
        scene.width = 700;
        compare(form.x, Tokens.spaceM, "narrower than 760px");
        scene.width = 1000;
        scene.height = 480;
        compare(form.x, Tokens.spaceM, "no higher than 480px");
    }

    function test_a_kicker_comes_space_xs_above_the_title_and_the_rest_space_m_apart() {
        Prefs.motion = "off";
        sheet.show();
        const form = findChild(sheet, "form");
        const heading = form.children[0];
        waitForRendering(sheet);
        compare(heading.spacing, Tokens.spaceXs);
        compare(form.spacing, Tokens.spaceM);
        compare(named("name").y, heading.height + Tokens.spaceM);
    }

    function test_a_long_sheet_stays_space_xl_short_of_the_bottom_and_scrolls() {
        Prefs.motion = "off";
        sheet.show();
        scene.height = 200;
        const scroller = findChild(sheet, "scroller");
        compare(panel(sheet).height, 200 - Tokens.spaceXl);
        verify(scroller.interactive, "the rest scrolls");
    }

    function test_a_sheet_comes_16px_down_from_the_top_edge_with_a_fade_in_duration_short_and_ease_in() {
        Prefs.motion = "on";
        const comingIn = findChild(sheet, "comingIn");
        compare(comingIn.duration, Tokens.durationShort);
        compare(comingIn.easing.type, Easing.Bezier);
        compare(comingIn.easing.bezierCurve, Tokens.easeIn);
        sheet.show();
        compare(sheet.shift, -16, "it starts 16px above its place");
        compare(panel(sheet).opacity, 0, "and fades in");
        verify(panel(sheet).layer.enabled, "as one, as CSS opacity does");
        compare(sheet.shade, 1, "the shading is there at once");
        tryCompare(sheet, "entry", 1, Tokens.durationShort * 4);
        compare(sheet.shift, 0);
        compare(panel(sheet).opacity, 1);
        verify(!panel(sheet).layer.enabled, "a layer only while it fades");
        sheet.entry = 0.5;
        compare(sheet.shift, -8, "it moves, never scales");
    }

    function test_a_sheet_leaves_back_up_in_0_8_duration_short_with_ease_out_and_closes_once_gone() {
        Prefs.motion = "on";
        const goingUp = findChild(sheet, "goingUp");
        compare(goingUp.duration, 0.8 * Tokens.durationShort);
        compare(goingUp.easing.type, Easing.Bezier);
        compare(goingUp.easing.bezierCurve, Tokens.easeOut);
        openFully(sheet);
        sheet.request("cancel");
        verify(sheet.visible, "it is still there as it leaves");
        compare(closedSpy.count, 0, "its answer counts once it has gone");
        tryVerify(() => sheet.shift < -8 && findChild(sheet, "shading").opacity < 0.5, Tokens.durationShort * 4, "it moves up and the shading fades");
        closedWith("cancel");
        sheet.show();
        compare(sheet.shade, 1, "opened again, the shading is back at once");
    }

    function test_a_close_while_it_leaves_ends_it_at_once() {
        Prefs.motion = "on";
        openFully(sheet);
        sheet.request("cancel");
        sheet.close("save");
        compare(closedSpy.count, 1);
        compare(closedSpy.signalArguments[0][0], "save");
        verify(!sheet.visible);
    }

    function test_under_reduced_motion_a_sheet_opens_and_closes_at_once() {
        Prefs.motion = "off";
        sheet.show();
        verify(sheet.visible);
        compare(sheet.entry, 1);
        compare(sheet.shift, 0);
        compare(panel(sheet).opacity, 1);
        sheet.request("cancel");
        compare(closedSpy.count, 1, "gone at once");
        verify(!sheet.visible);
    }

    function test_a_sheet_takes_the_focus_and_gives_it_back_to_what_had_it() {
        Prefs.motion = "off";
        sheet.show();
        verify(input().activeFocus, "the first control takes the focus");
        verify(!named("opener").activeFocus);
        sheet.close("save");
        verify(named("opener").activeFocus, "the focus goes back to the control that had it");
    }

    function test_tab_and_shift_tab_stay_inside_the_sheet() {
        Prefs.motion = "off";
        sheet.show();
        keyClick(Qt.Key_Tab);
        verify(named("cancel").activeFocus);
        keyClick(Qt.Key_Tab);
        verify(named("save").activeFocus);
        keyClick(Qt.Key_Tab);
        verify(findChild(sheet, "close").activeFocus);
        keyClick(Qt.Key_Tab);
        verify(input().activeFocus, "from the last control round to the first");
        keyClick(Qt.Key_Backtab);
        verify(findChild(sheet, "close").activeFocus, "from the first back to the last");
        verify(!named("opener").activeFocus);
    }

    function test_a_host_can_name_where_the_focus_goes_back() {
        Prefs.motion = "off";
        sheet.opener = named("opener");
        testCase.forceActiveFocus();
        sheet.show();
        sheet.close("save");
        verify(named("opener").activeFocus);
    }

    function test_the_focus_goes_back_only_to_a_control_that_still_shows() {
        Prefs.motion = "off";
        sheet.show();
        named("opener").visible = false;
        sheet.close("save");
        verify(!named("opener").activeFocus);
    }

    function test_escape_through_the_key_layers_is_a_close_request() {
        Prefs.motion = "off";
        sheet.show();
        verify(!KeyLayers.escapeIsFree(named("cancel")), "a modal holds Escape");
        keyClick(Qt.Key_Escape);
        closedWith("cancel");
        verify(KeyLayers.escapeIsFree(named("opener")));
    }

    function test_escape_from_outside_the_sheet_is_not_its_own() {
        Prefs.motion = "off";
        sheet.show();
        named("opener").forceActiveFocus();
        keyClick(Qt.Key_Escape);
        verify(sheet.open);
    }

    function test_nothing_behind_the_shading_hovers_or_scrolls() {
        Prefs.motion = "off";
        const behind = createTemporaryObject(scrollerBehindComponent, scene);
        mouseWheel(scene, 100, 500, 0, -120);
        tryVerify(() => behind.contentY > 0, 1000, "without a sheet the wheel scrolls what lies behind");
        behind.cancelFlick();
        behind.contentY = 0;
        sheet.show();
        waitForRendering(sheet);
        mouseWheel(scene, 100, 500, 0, -120);
        wait(100);
        compare(behind.contentY, 0);
        mouseMove(named("opener"));
        verify(!named("opener").hovered);
    }

    function test_a_tip_takes_escape_before_the_sheet() {
        Prefs.motion = "off";
        sheet.show();
        keyClick(Qt.Key_Backtab);
        verify(Tips.target !== null, "the close button shows its tip on keyboard focus");
        keyClick(Qt.Key_Escape);
        compare(Tips.target, null);
        verify(sheet.open, "the tip went first");
        keyClick(Qt.Key_Escape);
        closedWith("cancel");
    }

    function test_a_tap_on_the_shading_closes_it_and_one_on_the_sheet_does_not() {
        Prefs.motion = "off";
        sheet.show();
        waitForRendering(sheet);
        const box = panel(sheet);
        mouseClick(sheet, box.x + 4, box.height - 8);
        verify(sheet.open, "a tap on the sheet's own padding");
        mouseClick(sheet, 100, 500);
        closedWith("cancel");
    }

    function test_its_visible_way_out_is_a_quiet_close_button_at_the_top_corner() {
        Prefs.motion = "off";
        sheet.show();
        waitForRendering(sheet);
        const close = findChild(sheet, "close");
        verify(close.visible);
        compare(close.variant, "quiet");
        compare(close.icon, "close");
        compare(close.label, "close");
        const at = close.mapToItem(panel(sheet), 0, 0);
        compare(at.y, Tokens.spaceXs);
        compare(at.x + close.width, panel(sheet).width - Tokens.spaceXs);
        const kicker = findChild(sheet, "form").children[0].children[0];
        compare(kicker.rightPadding, Tokens.touchTarget, "the kicker keeps clear of it");
        mouseClick(close);
        closedWith("cancel");
    }

    function test_a_sheet_whose_safe_answer_is_its_way_out_can_go_without_the_close_button() {
        Prefs.motion = "off";
        sheet.closeButton = false;
        sheet.show();
        verify(!findChild(sheet, "close").visible);
        compare(findChild(sheet, "form").children[0].children[0].rightPadding, 0);
    }

    function test_with_unsaved_input_a_close_request_asks_first_in_the_sheet_s_place() {
        Prefs.motion = "off";
        sheet.show();
        input().text = "builds";
        verify(sheet.dirty);
        keyClick(Qt.Key_Escape);
        verify(sheet.open, "it did not close");
        verify(sheet.asking);
        verify(!findChild(sheet, "form").visible, "the question takes the sheet's place");
        verify(!findChild(sheet, "close").visible);
        const ask = findChild(sheet, "ask");
        verify(ask.visible);
        compare(ask.children[0].kicker, "unsaved");
        compare(ask.children[0].title, "Discard what you entered?");
        const keep = findChild(sheet, "keep");
        compare(keep.text, "keep editing");
        compare(keep.variant, "primary");
        verify(keep.activeFocus, "keep editing is focused");
        compare(findChild(sheet, "discard").text, "discard changes");
    }

    function test_while_it_asks_escape_and_the_shading_keep_editing_and_the_focus_goes_back() {
        Prefs.motion = "off";
        sheet.dirty = true;
        sheet.show();
        for (let round = 0; round < 3; round++) {
            keyClick(Qt.Key_Escape);
            verify(sheet.asking, `Escape ${2 * round + 1} asks`);
            keyClick(Qt.Key_Escape);
            verify(!sheet.asking, `Escape ${2 * round + 2} keeps editing`);
            verify(input().activeFocus, "the focus goes back where it was");
        }
        sheet.request("cancel");
        waitForRendering(sheet);
        mouseClick(sheet, 100, 500);
        verify(!sheet.asking);
        verify(sheet.open);
        mouseClick(findChild(sheet, "close"));
        verify(sheet.asking, "the close button asks too");
        mouseClick(findChild(sheet, "keep"));
        verify(!sheet.asking);
        compare(closedSpy.count, 0, "nothing was lost");
    }

    function test_discarding_closes_the_sheet_with_the_request_s_answer() {
        Prefs.motion = "off";
        sheet.dirty = true;
        sheet.show();
        mouseClick(named("cancel"));
        verify(sheet.asking, "a cancel answer asks");
        mouseClick(findChild(sheet, "discard"));
        closedWith("cancel");
        verify(named("opener").activeFocus);
        sheet.show();
        verify(!sheet.asking, "opened again, it shows the form");
    }

    function test_the_app_s_own_close_leaves_without_asking() {
        Prefs.motion = "off";
        sheet.dirty = true;
        sheet.show();
        mouseClick(named("save"));
        verify(!sheet.asking);
        closedWith("save");
    }

    function test_an_unchanged_form_never_asks() {
        Prefs.motion = "off";
        sheet.show();
        keyClick(Qt.Key_Escape);
        verify(!sheet.asking);
        closedWith("cancel");
    }

    function test_a_confirmation_puts_its_question_its_line_and_cancel_before_ok() {
        Prefs.motion = "off";
        confirm.text = "Its runs stay.";
        confirm.show();
        compare(confirm.title, "Archive the group?");
        compare(findChild(confirm, "text").text, "Its runs stay.");
        verify(findChild(confirm, "text").visible);
        compare(findChild(confirm, "cancel").text, "cancel");
        compare(findChild(confirm, "ok").text, "ok");
        waitForRendering(confirm);
        verify(findChild(confirm, "cancel").x < findChild(confirm, "ok").x, "cancel, then ok");
        verify(!findChild(confirm, "close").visible, "its safe answer is its way out");
        confirm.close("ok");
        confirm.text = "";
        confirm.show();
        verify(!findChild(confirm, "text").visible, "no line when none is given");
    }

    function test_a_confirmation_s_safe_answer_is_primary_and_takes_the_focus() {
        Prefs.motion = "off";
        confirm.show();
        compare(findChild(confirm, "ok").variant, "primary");
        compare(findChild(confirm, "cancel").variant, "");
        verify(findChild(confirm, "ok").activeFocus);
    }

    function test_for_an_action_that_cannot_be_undone_cancel_is_safe_and_ok_is_destructive() {
        Prefs.motion = "off";
        confirm.safe = "cancel";
        confirm.show();
        compare(findChild(confirm, "cancel").variant, "primary");
        compare(findChild(confirm, "ok").variant, "destructive");
        verify(findChild(confirm, "cancel").activeFocus);
    }

    function test_a_confirmation_answers_true_for_ok_and_false_for_cancel_escape_and_the_shading() {
        Prefs.motion = "off";
        const answered = createTemporaryObject(answeredSpyComponent, testCase, { target: confirm });
        const ways = [
            [() => mouseClick(findChild(confirm, "ok")), true],
            [() => mouseClick(findChild(confirm, "cancel")), false],
            [() => keyClick(Qt.Key_Escape), false],
            [() => mouseClick(confirm, 100, 500), false]
        ];
        for (const [answer, expected] of ways) {
            confirm.show();
            waitForRendering(confirm);
            answer();
            compare(answered.signalArguments[answered.count - 1][0], expected);
            verify(!confirm.open);
        }
        compare(answered.count, 4, "each question is answered once");
        verify(named("opener").activeFocus, "and the focus is back");
    }

    // The sheets follow the one current theme and density, so the contact sheet is drawn once per pair.
    function test_contact_sheet_of_a_form_a_confirmation_and_the_question_in_both_themes_and_densities() {
        Prefs.motion = "off";
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const contact = createTemporaryObject(contactComponent, testCase);
                findChild(contact, "narrow").show();
                findChild(contact, "form").show();
                const asking = findChild(contact, "asking");
                asking.show();
                asking.request("cancel");
                // The confirmation opens last, so its safe answer holds the focus.
                findChild(contact, "confirm").show();
                waitForRendering(contact);
                grabImage(contact).save(`sheet-sheet-${theme}-${density}.png`);
                verify(asking.asking, `${theme} ${density}`);
                contact.destroy();
            }
        }
    }
}
