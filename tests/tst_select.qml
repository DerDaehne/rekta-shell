pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import "ContactSheets.js" as ContactSheets

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

            // At the foot of the window, with no room for its list below.
            Select {
                objectName: "low"
                x: 600
                y: parent.height - Tokens.controlHeight - Tokens.spaceS
                width: 240
                options: testCase.outputs
                currentIndex: 0
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
        id: scrollerComponent

        Flickable {
            x: 400
            width: 300
            height: 200
            contentHeight: 600
            boundsBehavior: Flickable.StopAtBounds

            Select {
                objectName: "scrolled"
                y: 60
                width: 300
                options: testCase.outputs
                currentIndex: 0
            }
        }
    }

    Component {
        id: sheetComponent

        // Selects on the current theme's ground, one above the other: chosen, cut, disabled with its reason. The first
        // opens from the keys; its list floats over the others.
        Rectangle {
            width: 320
            height: 300
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
    }

    function named(name: string): var {
        return findChild(scene, name);
    }

    function box(of: var): var {
        return findChild(of, "box");
    }

    function list(of: var): var {
        return findChild(of, "list");
    }

    function rows(of: var): var {
        return Array.from(list(of).rows).filter(row => row.objectName === "option");
    }

    // The option the keys are on in the open list, -1 for none.
    function focused(of: var): int {
        return rows(of).findIndex(row => row.activeFocus);
    }

    function openFromKeys(of: var) {
        of.forceActiveFocus();
        keyClick(Qt.Key_Return);
        verify(of.expanded);
    }

    // A key as Keys hands it over, held down when repeated.
    function keyEvent(code: int, repeated: bool): var {
        return { key: code, text: "", modifiers: Qt.NoModifier, isAutoRepeat: repeated };
    }

    // A frame drawn after this point. waitForRendering alone waits for the next frame, which never comes once a scene
    // has nothing left to draw, and then runs out its whole timeout.
    function waitForFrame(item: Item) {
        item.Window.window.update();
        waitForRendering(item);
    }

    function window(): Item {
        return testCase.Window.window.contentItem;
    }

    function inScene(item: var): point {
        return item.mapToItem(null, 0, 0);
    }

    // True where the pixel lies nearer the text colour than the ground.
    function inkAt(image: var, x: real, y: real): bool {
        const pixel = image.pixel(Math.round(x), Math.round(y));
        const distance = (a, b) => Math.abs(a.r - b.r) + Math.abs(a.g - b.g) + Math.abs(a.b - b.b);
        return distance(pixel, Tokens.color.textPrimary) < distance(pixel, Tokens.color.bg);
    }

    function test_closed_the_box_is_a_fields_input_with_the_chosen_option_and_the_combobox_chevron_pointing_down_18px_before_its_end() {
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
        compare(chosen.width, select.width - Geometry.inputPadding - 36, "the text stops where the chevron's padding starts");
        compare(findChild(select, "chevron").color, Tokens.color.textPrimary);
        waitForFrame(scene);
        const image = grabImage(window());
        const at = inScene(field);
        const centreX = at.x + field.width - 1 - 18;
        const centreY = at.y + field.height / 2;
        verify(inkAt(image, centreX, centreY), "its point in the middle");
        verify(!inkAt(image, centreX, centreY - 3), "open above it");
        verify(inkAt(image, centreX - 3, centreY - 2), "an arm up to the left");
        verify(inkAt(image, centreX + 2, centreY - 2), "an arm up to the right");
        verify(!inkAt(image, centreX - 6, centreY - 2), "8px wide in all");
        verify(!inkAt(image, centreX + 5, centreY - 2));
        verify(!list(select).visible, "no list in sight");
    }

    function test_the_chevron_points_up_while_the_list_is_open() {
        openFromKeys(select);
        waitForFrame(scene);
        const field = box(select);
        const image = grabImage(window());
        const at = inScene(field);
        const centreX = at.x + field.width - 1 - 18;
        const centreY = at.y + field.height / 2;
        verify(inkAt(image, centreX, centreY - 1), "its point in the middle");
        verify(!inkAt(image, centreX, centreY + 2), "open below it");
        verify(inkAt(image, centreX - 3, centreY + 1), "an arm down to the left");
        verify(inkAt(image, centreX + 2, centreY + 1), "an arm down to the right");
    }

    function test_its_edge_darkens_under_the_pointer_with_the_focus_which_shows_the_ring_and_while_its_list_is_open() {
        const field = box(select);
        mouseMove(field, 20, 10);
        tryCompare(field.border, "color", Tokens.color.textPrimary);
        mouseMove(testCase, 900, 300);
        tryCompare(field.border, "color", Tokens.color.textContrastMedium);
        select.forceActiveFocus();
        compare(field.border.color, Tokens.color.textPrimary);
        verify(findChild(field, "ring").visible);
        keyClick(Qt.Key_Return);
        verify(!select.activeFocus, "the focus is in the list");
        compare(field.border.color, Tokens.color.textPrimary, "still dark while the list is open");
    }

    function test_a_press_opens_a_list_that_floats_below_the_field_at_least_as_wide_as_it_and_moves_nothing() {
        const after = named("after");
        const before = after.y;
        mouseClick(box(select));
        verify(select.expanded);
        verify(!select.activeFocus, "a press gives no focus");
        const surface = list(select);
        verify(surface.visible);
        compare(surface.parent, window(), "it floats above the window's content");
        compare(surface.side, "below");
        compare(inScene(surface).y, inScene(box(select)).y + Tokens.controlHeight + Tokens.spaceXs);
        compare(inScene(surface).x, inScene(box(select)).x);
        verify(surface.width >= select.width);
        compare(surface.border.color, Tokens.color.textContrastMedium, "a floating surface's edge");
        compare(rows(select).map(row => row.text), ["speakers", "headphones", "hdmi"]);
        compare(select.height, Tokens.controlHeight, "the select keeps its height");
        compare(after.y, before, "nothing below moves");
        compare(focused(select), -1, "no option takes the ring from a press");
    }

    function test_with_no_room_below_the_list_floats_above_the_field() {
        const low = named("low");
        mouseClick(box(low));
        const surface = list(low);
        compare(surface.side, "above");
        compare(inScene(surface).y + surface.height, inScene(box(low)).y - Tokens.spaceXs);
    }

    function test_enter_space_and_alt_down_open_the_list_with_the_focus_on_the_chosen_option() {
        select.currentIndex = 1;
        for (const [code, modifiers] of [[Qt.Key_Return, Qt.NoModifier], [Qt.Key_Space, Qt.NoModifier], [Qt.Key_Down, Qt.AltModifier]]) {
            select.forceActiveFocus();
            keyClick(code, modifiers);
            verify(select.expanded, `${code} ${modifiers}`);
            compare(focused(select), 1, "the keys start on the chosen option");
            verify(findChild(rows(select)[1], "ring").visible);
            keyClick(Qt.Key_Escape);
            verify(!select.expanded);
        }
    }

    function test_in_the_list_up_and_down_wrap_around_and_home_and_end_jump() {
        openFromKeys(select);
        keyClick(Qt.Key_Up);
        compare(focused(select), 2, "↑ from the first goes to the last");
        keyClick(Qt.Key_Down);
        compare(focused(select), 0, "↓ from the last goes to the first");
        keyClick(Qt.Key_Down);
        compare(focused(select), 1);
        keyClick(Qt.Key_End);
        compare(focused(select), 2);
        keyClick(Qt.Key_Home);
        compare(focused(select), 0);
        verify(select.expanded);
        compare(activated.count, 0, "moving chooses nothing");
    }

    function test_in_the_list_a_letter_moves_to_the_next_option_starting_with_it_and_one_that_starts_none_stays() {
        openFromKeys(select);
        keyClick("h");
        compare(focused(select), 1);
        keyClick("h");
        compare(focused(select), 2);
        keyClick("h");
        compare(focused(select), 1, "around the list");
        keyClick("x");
        compare(focused(select), 1);
        verify(select.expanded);
    }

    function test_enter_or_space_chooses_closes_and_keeps_the_focus_on_the_field() {
        for (const code of [Qt.Key_Return, Qt.Key_Space]) {
            openFromKeys(select);
            keyClick(Qt.Key_Down);
            keyClick(code);
            verify(!select.expanded);
            verify(select.activeFocus, "the focus is back on the select");
        }
        compare(select.currentIndex, 2);
        compare(select.currentValue, "c");
        compare(findChild(select, "chosen").text, "hdmi");
        compare(activated.count, 2);
        compare(activated.signalArguments[1][0], 2);
    }

    function test_choosing_the_chosen_option_again_closes_and_changes_nothing() {
        openFromKeys(select);
        keyClick(Qt.Key_Space);
        verify(!select.expanded);
        compare(activated.count, 0);
    }

    function test_escape_closes_without_a_change_and_the_focus_stays_on_the_field_and_opening_again_starts_on_the_choice() {
        select.currentIndex = 1;
        openFromKeys(select);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Escape);
        verify(!select.expanded);
        verify(select.activeFocus);
        compare(select.currentIndex, 1);
        compare(activated.count, 0);
        keyClick(Qt.Key_Return);
        verify(select.expanded);
        compare(focused(select), 1, "on the choice, not where the keys were");
    }

    function test_tab_closes_and_moves_on() {
        openFromKeys(select);
        keyClick(Qt.Key_Tab);
        verify(!select.expanded);
        verify(named("after").activeFocus);
    }

    function test_a_press_on_an_option_chooses_it_closes_and_opened_again_it_carries_the_tick() {
        mouseClick(box(select));
        waitForFrame(scene);
        mouseClick(rows(select)[1]);
        verify(!select.expanded);
        compare(select.currentIndex, 1);
        compare(activated.count, 1);
        mouseClick(box(select));
        compare(rows(select).map(row => row.checked), [false, true, false]);
    }

    function test_a_list_closed_by_a_pointer_leaves_the_focus_where_it_was() {
        const before = named("before");
        before.forceActiveFocus();
        mouseClick(box(select));
        waitForFrame(scene);
        mouseClick(rows(select)[2]);
        verify(before.activeFocus);
        mouseClick(box(select));
        mouseClick(scene, 900, 300);
        verify(!select.expanded);
        verify(before.activeFocus);
    }

    function test_a_press_outside_closes_the_list_without_a_change() {
        mouseClick(box(select));
        verify(select.expanded);
        mouseClick(scene, 900, 300);
        verify(!select.expanded);
        compare(select.currentIndex, 0);
        compare(activated.count, 0);
    }

    function test_a_press_on_the_field_while_the_list_is_open_closes_it() {
        mouseClick(box(select));
        verify(select.expanded);
        mouseClick(box(select));
        verify(!select.expanded);
    }

    function test_the_focus_leaving_for_something_else_closes_the_list() {
        openFromKeys(select);
        named("before").forceActiveFocus();
        verify(!select.expanded);
    }

    function test_the_chosen_option_carries_a_tick_without_a_box_and_a_choice_from_outside_shows_at_once() {
        select.currentIndex = 2;
        compare(findChild(select, "chosen").text, "hdmi");
        mouseClick(box(select));
        const options = rows(select);
        compare(options.map(row => row.kind), ["option", "option", "option"]);
        compare(options.map(row => findChild(row, "tick").visible), [false, false, true]);
        compare(options.map(row => findChild(row, "check").visible), [false, false, false], "no box");
    }

    function test_closed_up_down_home_and_end_change_the_choice_without_opening_and_stop_at_the_ends() {
        select.forceActiveFocus();
        keyClick(Qt.Key_Up);
        compare(select.currentIndex, 0, "no further than the first");
        compare(activated.count, 0);
        keyClick(Qt.Key_Down);
        compare(select.currentIndex, 1);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        compare(select.currentIndex, 2, "no further than the last");
        keyClick(Qt.Key_Home);
        compare(select.currentIndex, 0);
        keyClick(Qt.Key_End);
        compare(select.currentIndex, 2);
        verify(!select.expanded);
        verify(select.activeFocus);
        compare(activated.count, 4);
        compare(activated.signalArguments.map(args => args[0]), [1, 2, 0, 2]);
    }

    function test_closed_a_letter_chooses_the_next_option_starting_with_it_around_the_list_and_one_that_starts_none_changes_nothing() {
        select.forceActiveFocus();
        keyClick("h");
        compare(select.currentIndex, 1);
        keyClick("H");
        compare(select.currentIndex, 2);
        keyClick("s");
        compare(select.currentIndex, 0, "around the list");
        verify(select.handleKey({ key: Qt.Key_X, text: "x", modifiers: Qt.NoModifier, isAutoRepeat: false }), "used up, as rekta-core does");
        compare(select.currentIndex, 0);
        verify(!select.expanded);
        compare(activated.count, 3);
        verify(!select.handleKey({ key: Qt.Key_H, text: "h", modifiers: Qt.ControlModifier, isAutoRepeat: false }), "Ctrl+H is no letter");
    }

    function test_closed_escape_and_keys_that_are_no_letters_go_on_to_what_holds_it() {
        select.forceActiveFocus();
        for (const [code, text] of [[Qt.Key_Escape, "\u001b"], [Qt.Key_1, "1"], [Qt.Key_Left, ""], [Qt.Key_Tab, "\t"]])
            verify(!select.handleKey({ key: code, text: text, modifiers: Qt.NoModifier, isAutoRepeat: false }), `${code}`);
        compare(select.currentIndex, 0);
    }

    function test_a_held_key_opens_only_once() {
        select.forceActiveFocus();
        verify(select.handleKey(keyEvent(Qt.Key_Return, true)));
        verify(!select.expanded, "a repeat does not open it");
        verify(select.handleKey(keyEvent(Qt.Key_Return, false)));
        verify(select.expanded);
    }

    function test_out_of_sight_it_closes() {
        mouseClick(box(select));
        select.visible = false;
        verify(!select.expanded);
        select.visible = true;
        verify(!list(select).visible, "and comes back closed");
    }

    function test_the_list_comes_in_as_every_floating_surface_does_and_at_once_under_reduced_motion() {
        openFromKeys(select);
        compare(list(select).entry, 1, "at once");
        keyClick(Qt.Key_Escape);
        Prefs.motion = "on";
        keyClick(Qt.Key_Return);
        verify(list(select).entry < 1, "it fades in");
        compare(findChild(list(select), "comingIn").duration, Tokens.durationFloat);
        tryCompare(list(select), "entry", 1, 4 * Tokens.durationFloat);
    }

    function test_the_list_follows_the_field_when_its_scroller_moves() {
        const view = createTemporaryObject(scrollerComponent, scene);
        const scrolled = findChild(view, "scrolled");
        openFromKeys(scrolled);
        const before = list(scrolled).y;
        view.contentY = 40;
        compare(list(scrolled).y, before - 40);
    }

    function test_a_long_option_is_cut_in_the_box_and_in_its_row() {
        select.options = [{ text: "Navi 21/23 HDMI/DP Audio Controller Digital Stereo (HDMI 3) with a longer name still", value: 0 }, ...outputs];
        verify(findChild(select, "chosen").truncated, "in the box");
        mouseClick(box(select));
        waitForFrame(scene);
        verify(findChild(rows(select)[0], "label").truncated, "in its row");
    }

    function test_disabled_it_greys_stays_focusable_says_why_below_and_neither_opens_nor_changes() {
        select.disabledReason = "no other device";
        const field = box(select);
        compare(field.border.color, Tokens.color.disabled);
        compare(findChild(select, "chosen").color, Tokens.color.disabled);
        compare(findChild(select, "chevron").color, Tokens.color.disabled);
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
        for (const code of [Qt.Key_Return, Qt.Key_Down, Qt.Key_End])
            keyClick(code);
        keyClick("h");
        verify(!select.expanded);
        compare(select.currentIndex, 0);
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
        compare(list(select).Accessible.role, Accessible.List);
        compare(list(select).Accessible.name, "ausgang");
        const options = rows(select);
        compare(options[0].Accessible.role, Accessible.ListItem);
        compare(options.map(row => row.Accessible.name), ["speakers", "headphones", "hdmi"]);
        compare(options.map(row => row.Accessible.checked), [true, false, false]);
    }

    // Each pair of theme and density, closed and then with the first select's list open from the keys, the focus on its
    // second option.
    function test_contact_sheet_of_selects_closed_and_open_in_both_themes_and_densities() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        scene.visible = false;
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const sheet = createTemporaryObject(sheetComponent, testCase);
                const opens = findChild(sheet, "opens");
                waitForRendering(sheet);
                grabImage(sheet).save(`select-sheet-${theme}-${density}-closed.png`);
                openFromKeys(opens);
                keyClick(Qt.Key_Up);
                waitForRendering(sheet);
                grabImage(window()).save(`select-sheet-${theme}-${density}-open.png`);
                verify(opens.expanded, `${theme} ${density}`);
                sheet.destroy();
            }
        }
    }
}
