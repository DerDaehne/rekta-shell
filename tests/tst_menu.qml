pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "Menu"
    visible: true
    when: windowShown
    width: 1000
    height: 600

    Component {
        id: sceneComponent

        Item {
            width: 1000
            height: 600

            Button {
                id: viewButton

                objectName: "control"
                x: 40
                y: 40
                text: "view"
            }

            Button {
                objectName: "after"
                x: 200
                y: 40
                text: "after"
            }

            Menu {
                objectName: "menu"
                control: viewButton
                x: 40
                y: 80

                MenuItem { objectName: "open"; text: "open"; keyHint: "Enter" }
                MenuItem { objectName: "rename"; text: "rename"; keyHint: "F2" }
                MenuItem { objectName: "archive"; text: "archive"; visible: false }
                MenuItem { objectName: "print"; text: "print"; disabledReason: "needs a printer" }
                MenuSeparator { objectName: "separator" }
                MenuLabel { objectName: "groupLabel"; text: "sort by" }
                MenuItem { objectName: "name"; kind: "radio"; text: "name"; checked: true }
                MenuItem { objectName: "date"; kind: "radio"; text: "date" }
                MenuItem { objectName: "duration"; kind: "radio"; text: "duration" }
                MenuSeparator {}
                MenuItem { objectName: "hidden"; kind: "checkbox"; text: "show hidden" }
            }
        }
    }

    Component {
        id: longMenuComponent

        Menu {
            area: Qt.size(1000, 300)

            Repeater {
                model: 30

                delegate: MenuItem {
                    required property int index

                    objectName: `run ${index}`
                    text: `run ${index}`
                }
            }
        }
    }

    Component {
        id: spy

        SignalSpy {
            signalName: "chosen"
        }
    }

    property Item scene
    property Menu menu
    property SignalSpy chosen

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        scene = createTemporaryObject(sceneComponent, testCase);
        menu = findChild(scene, "menu");
        chosen = createTemporaryObject(spy, testCase, { target: menu });
    }

    function cleanup() {
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function row(name) {
        return findChild(scene, name);
    }

    // Opened from the keyboard: the control has the focus, as a click gives none.
    function openFromKeys(index) {
        row("control").forceActiveFocus();
        menu.openAt(index);
    }

    function test_arrows_move_through_the_items_and_wrap_around_both_ends() {
        openFromKeys(0);
        verify(row("open").activeFocus);
        keyClick(Qt.Key_Down);
        verify(row("rename").activeFocus);
        keyClick(Qt.Key_Down);
        verify(row("print").activeFocus, "a disabled item stays in the list");
        keyClick(Qt.Key_Down);
        verify(row("name").activeFocus, "separators and group labels are passed over");
        keyClick(Qt.Key_Up);
        verify(row("print").activeFocus);
        keyClick(Qt.Key_End);
        verify(row("hidden").activeFocus);
        keyClick(Qt.Key_Down);
        verify(row("open").activeFocus, "down from the last wraps to the first");
        keyClick(Qt.Key_Up);
        verify(row("hidden").activeFocus, "up from the first wraps to the last");
        keyClick(Qt.Key_Home);
        verify(row("open").activeFocus);
        verify(menu.open);
    }

    function test_a_letter_jumps_to_the_next_item_starting_with_it() {
        openFromKeys(0);
        keyClick(Qt.Key_R);
        verify(row("rename").activeFocus);
        keyClick(Qt.Key_D);
        verify(row("date").activeFocus);
        keyClick(Qt.Key_D);
        verify(row("duration").activeFocus, "the next one with that letter");
        keyClick(Qt.Key_D);
        verify(row("date").activeFocus, "and around");
        keyClick(Qt.Key_N);
        verify(row("name").activeFocus, "after the focused item and around");
        keyClick(Qt.Key_S);
        verify(row("hidden").activeFocus, "the label counts, not the kind");
        keyClick(Qt.Key_X);
        verify(row("hidden").activeFocus, "no match keeps the focus");
        keyClick(Qt.Key_R, Qt.ControlModifier);
        verify(row("hidden").activeFocus, "a letter with Ctrl is a shortcut, not a jump");
    }

    function test_escape_closes_and_gives_the_focus_back_to_the_control() {
        openFromKeys(2);
        verify(row("print").activeFocus);
        keyClick(Qt.Key_Escape);
        verify(!menu.open);
        verify(!menu.visible);
        verify(row("control").activeFocus);
        compare(chosen.count, 0);
    }

    function test_tab_closes_and_moves_on_from_the_control() {
        openFromKeys(1);
        keyClick(Qt.Key_Tab);
        verify(!menu.open);
        verify(row("after").activeFocus, "on to what follows the control");
        openFromKeys(1);
        keyClick(Qt.Key_Backtab);
        verify(!menu.open);
        verify(row("control").activeFocus, "Shift+Tab goes back to the control");
    }

    function test_enter_and_space_choose_the_focused_item_and_return_the_focus() {
        openFromKeys(1);
        keyClick(Qt.Key_Return);
        verify(!menu.open);
        compare(chosen.count, 1);
        compare(chosen.signalArguments[0][0], row("rename"));
        verify(row("control").activeFocus);
        openFromKeys(0);
        keyClick(Qt.Key_Space);
        compare(chosen.count, 2);
        compare(chosen.signalArguments[1][0], row("open"));
        verify(!menu.open);
    }

    function test_opened_from_the_keyboard_the_first_row_shows_the_focus() {
        openFromKeys(0);
        verify(row("open").activeFocus);
        verify(findChild(row("open"), "tint").visible);
    }

    function test_opened_by_a_click_no_row_shows_focus_until_a_key_moves_to_one() {
        menu.openAt(0);
        verify(menu.open);
        verify(menu.activeFocus, "the menu holds the keys");
        compare(menu.focusedIndex(), -1);
        verify(!findChild(row("open"), "tint").visible);
        keyClick(Qt.Key_Up);
        verify(row("hidden").activeFocus, "up from no row goes to the last");
        keyClick(Qt.Key_Home);
        verify(findChild(row("open"), "tint").visible);
    }

    function test_a_click_on_an_item_chooses_it_without_moving_the_focus() {
        menu.openAt(0);
        // The rows' column lays out at polish.
        waitForRendering(menu);
        mouseClick(row("rename"));
        compare(chosen.count, 1);
        compare(chosen.signalArguments[0][0], row("rename"));
        verify(!menu.open);
        verify(!row("control").activeFocus, "the control never had the focus");
        menu.openAt(0);
        mouseClick(row("groupLabel"));
        mouseClick(row("separator"));
        verify(menu.open, "a group label or a hairline is no choice");
        compare(chosen.count, 1);
    }

    function test_a_checkbox_item_toggles_and_leaves_the_menu_open() {
        openFromKeys(-1);
        const hidden = row("hidden");
        verify(hidden.activeFocus);
        verify(!hidden.checked);
        keyClick(Qt.Key_Return);
        verify(hidden.checked);
        verify(menu.open, "several can be ticked in a row");
        verify(hidden.activeFocus);
        compare(chosen.count, 1);
        mouseClick(hidden);
        verify(!hidden.checked);
        verify(menu.open);
        compare(chosen.count, 2);
    }

    function test_a_radio_item_picks_itself_alone_and_closes() {
        openFromKeys(4);
        verify(row("date").activeFocus);
        keyClick(Qt.Key_Space);
        verify(row("date").checked);
        verify(!row("name").checked, "only one radio is chosen");
        verify(!menu.open);
        compare(chosen.count, 1);
        verify(row("control").activeFocus);
    }

    function test_a_chosen_option_shows_a_filled_10px_square() {
        Prefs.theme = "dark";
        menu.openAt(0);
        for (const name of ["name", "date", "hidden"]) {
            const check = findChild(row(name), "check");
            verify(check.visible, name);
            compare(check.width, 10);
            compare(check.height, 10);
            compare(check.border.width, 1);
            compare(check.border.color, Tokens.color.textPrimary);
            compare(check.color, row(name).checked ? Tokens.color.textPrimary : Qt.color("transparent"), name);
        }
        verify(!findChild(row("open"), "check").visible, "a plain item has no square");
        const label = findChild(row("name"), "label");
        compare(label.x, Tokens.spaceM + 10 + Tokens.spaceS, "the label follows the square after space-s");
    }

    function test_a_disabled_item_is_greyed_says_why_in_its_label_and_does_nothing() {
        openFromKeys(2);
        const print = row("print");
        const label = findChild(print, "label");
        compare(label.text, "print (needs a printer)");
        compare(label.color, Tokens.color.disabled);
        compare(print.Accessible.name, "print (needs a printer)");
        keyClick(Qt.Key_Return);
        verify(menu.open, "Enter does nothing");
        mouseClick(print);
        verify(menu.open, "nor does a click");
        compare(chosen.count, 0);
    }

    function test_rows_take_the_density_s_row_height_with_the_key_hint_at_the_end() {
        for (const density of ["compact", "comfortable"]) {
            Prefs.density = density;
            menu.openAt(0);
            const open = row("open");
            compare(open.height, Tokens.rowHeight, density);
            const label = findChild(open, "label");
            compare(label.x, Tokens.spaceM);
            compare(label.font.pixelSize, Tokens.fontSizeS);
            compare(label.color, Tokens.color.textPrimary);
            const key = findChild(open, "key");
            compare(key.x + key.width, open.width - Tokens.spaceM);
            compare(key.font.pixelSize, Tokens.fontSizeXxs);
            compare(key.color, Tokens.color.textContrastHigh);
            menu.close(false);
        }
    }

    function test_groups_are_parted_by_a_hairline_and_named_by_a_label() {
        menu.openAt(0);
        const separator = row("separator");
        compare(separator.height, 1 + 2 * Tokens.spaceXs);
        const hairline = separator.children[0];
        compare(hairline.y, Tokens.spaceXs);
        compare(hairline.height, 1);
        compare(hairline.color, Tokens.color.textContrastLow);
        const groupLabel = row("groupLabel");
        compare(groupLabel.font.pixelSize, Tokens.fontSizeXs);
        compare(groupLabel.font.weight, Tokens.fontWeightSemibold);
        compare(groupLabel.color, Tokens.color.textContrastHigh);
        compare([groupLabel.topPadding, groupLabel.rightPadding, groupLabel.bottomPadding, groupLabel.leftPadding], [Tokens.spaceS + groupLabel.lineBoxTop, Tokens.spaceM, Tokens.spaceXs + groupLabel.lineBoxBottom, Tokens.spaceM], "s m xs m around its line box");
        compare(groupLabel.lineHeight, Tokens.lineHeightCompact * Tokens.fontSizeXs);
        compare(groupLabel.height, Tokens.spaceS + Tokens.lineHeightCompact * Tokens.fontSizeXs + Tokens.spaceXs);
    }

    function test_the_focused_row_shows_the_ring_inside_and_the_hover_colour() {
        openFromKeys(1);
        const rename = row("rename");
        compare(findChild(rename, "tint").color, Tokens.color.hover);
        const ring = rename.children.find(child => child instanceof FocusRing);
        verify(ring.visible);
        compare(ring.offset, -2);
        compare(ring.border.color, Tokens.color.focus);
        compare(ring.x, 0, "a 2px ring just inside the row's edge");
        compare(ring.width, rename.width);
        keyClick(Qt.Key_Down);
        verify(!ring.visible);
        verify(!findChild(rename, "tint").visible);
    }

    function test_a_long_menu_scrolls_the_focused_row_into_view() {
        const longMenu = createTemporaryObject(longMenuComponent, testCase);
        longMenu.openAt(0);
        const scroller = findChild(longMenu, "scroller");
        compare(scroller.contentY, 0);
        keyClick(Qt.Key_End);
        const last = findChild(longMenu, "run 29");
        verify(last.activeFocus);
        const top = last.mapToItem(scroller, 0, 0).y;
        verify(top >= 0 && top + last.height <= scroller.height, `the last row is in view at ${top}`);
        keyClick(Qt.Key_Home);
        compare(findChild(longMenu, "run 0").mapToItem(scroller, 0, 0).y, 0, "and back up, as focus scrolls on the web");
    }

    function test_an_enabled_row_takes_the_hover_colour_under_the_pointer() {
        menu.openAt(0);
        // The rows' column lays out at polish.
        waitForRendering(menu);
        const tint = name => findChild(row(name), "tint");
        mouseMove(row("rename"));
        verify(tint("rename").visible);
        compare(tint("rename").color, Tokens.color.hover);
        mouseMove(row("print"));
        verify(!tint("print").visible, "never on a disabled row");
        verify(!tint("rename").visible, "only the row under the pointer");
        mouseMove(row("control"));
        verify(!tint("print").visible && !tint("rename").visible);
    }

    // A test cannot send an auto-repeated key, so it hands the menu one shaped like it.
    function test_a_held_key_chooses_once() {
        openFromKeys(-1);
        const hidden = row("hidden");
        const space = repeat => ({ key: Qt.Key_Space, text: " ", modifiers: Qt.NoModifier, isAutoRepeat: repeat });
        verify(menu.handleKey(space(true)), "the menu still takes the repeat");
        verify(!hidden.checked);
        compare(chosen.count, 0);
        menu.handleKey(space(false));
        verify(hidden.checked);
        compare(chosen.count, 1);
    }

    function test_hidden_rows_are_passed_over() {
        openFromKeys(1);
        verify(row("rename").activeFocus);
        keyClick(Qt.Key_Down);
        verify(row("print").activeFocus, "the arrows skip a hidden row");
        keyClick(Qt.Key_A);
        verify(row("print").activeFocus, "and so does a letter");
        verify(!menu.items().includes(row("archive")));
    }

    function test_a_key_hint_keeps_space_s_and_space_l_from_the_label() {
        menu.openAt(0);
        const open = row("open");
        const label = findChild(open, "label");
        const key = findChild(open, "key");
        compare(open.implicitWidth, 2 * Tokens.spaceM + label.implicitWidth + Tokens.spaceS + Tokens.spaceL + key.implicitWidth);
        const name = row("name");
        compare(name.implicitWidth, 2 * Tokens.spaceM + 10 + Tokens.spaceS + findChild(name, "label").implicitWidth, "no hint, no gap");
    }

    function test_while_a_menu_is_open_escape_is_not_free() {
        verify(KeyLayers.escapeIsFree(row("control")));
        menu.openAt(0);
        verify(!KeyLayers.escapeIsFree(row("control")));
        menu.close(false);
        verify(KeyLayers.escapeIsFree(row("control")));
    }
}
