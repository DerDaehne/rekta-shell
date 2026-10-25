pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "LongList"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1200
    height: 640

    // A coloured 20 × 20 square as PNG (the check has no SVG image plugin), as an app's own icon is coloured.
    readonly property string pinkIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAGklEQVR4nGN4aTWLbMQwqnlU86jmUc0DqxkAreu3b+7dCC4AAAAASUVORK5CYII="

    function rowsOf(count: int): var {
        return Array.from({ length: count }, (_, i) => ({ text: `app ${i}`, icon: testCase.pinkIcon }));
    }

    Component {
        id: listComponent

        LongList {
            x: 20
            y: 20
            width: 400
            height: 10 * Tokens.rowHeight + Geometry.hairline
            rows: testCase.rowsOf(40)
            empty: "keine apps installiert."
        }
    }

    SignalSpy {
        id: shownSpy

        signalName: "shown"
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var list
    property var view

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        list = createTemporaryObject(listComponent, testCase);
        view = findChild(list, "view");
        shownSpy.target = list;
        shownSpy.clear();
        waitForRendering(list);
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function row(index: int): var {
        return view.itemAtIndex(index);
    }

    function test_rows_stand_at_the_density_s_row_height_on_hairlines_below_a_top_one() {
        for (const density of ["compact", "comfortable"]) {
            Prefs.density = density;
            waitForRendering(list);
            compare(row(0).height, Tokens.rowHeight, density);
            compare(row(1).mapToItem(list, 0, 0).y, Geometry.hairline + Tokens.rowHeight, density);
            const hairline = findChild(row(0), "hairline");
            compare(hairline.y + hairline.height, row(0).height, `${density}: the hairline under the row`);
            compare(hairline.color, Tokens.color.textContrastLow);
        }
        compare(list.children[0].height, Geometry.hairline, "the list's top border");
        compare(list.children[0].y, 0);
    }

    function test_a_row_holds_its_icon_in_the_lead_padding_and_its_text_space_m_beyond() {
        const icon = findChild(row(0), "icon");
        const words = findChild(row(0), "text");
        compare(icon.x, Geometry.listRowLead + Tokens.spaceS);
        compare(icon.width, Geometry.iconSize);
        compare(icon.y + icon.height / 2, row(0).height / 2);
        compare(words.x, icon.x + Geometry.iconSize + Tokens.spaceM);
        compare(words.x + words.width, row(0).width - Tokens.spaceS);
        compare(words.font.pixelSize, Tokens.fontSizeS);
        compare(words.text, "app 0");
        compare(words.elide, Text.ElideRight);
        compare(words.color, Tokens.color.textPrimary);
    }

    function test_only_the_rows_in_view_and_six_either_side_exist() {
        list.rows = rowsOf(10000);
        // Rows beyond the view come a moment later, as Qt makes them while idle.
        tryVerify(() => row(15) !== null, 1000, "six rows past the view");
        const made = view.contentItem.children.filter(item => item.turnsWhole === true);
        verify(made.length <= 10 + 6 + 1, `${made.length} rows made`);
        compare(row(30), null);
    }

    function test_a_click_chooses_the_row_and_shows_it() {
        mouseClick(row(2));
        compare(list.chosen, 2);
        compare(shownSpy.count, 1);
        compare(shownSpy.signalArguments[0][0], 2);
        tryCompare(findChild(row(2), "fill"), "color", Tokens.color.accent);
        tryCompare(findChild(row(2), "text"), "color", Tokens.color.textOnAccent);
        verify(findChild(row(2), "check").visible, "a checkmark at its leading edge");
        verify(!findChild(row(2), "hairline").visible, "text-contrast-low turns clear");
        verify(!findChild(row(1), "check").visible);
        compare(findChild(row(1), "fill").color.a, 0);
    }

    function test_the_checkmark_sits_space_xs_in_turned_against_the_clock() {
        mouseClick(row(0));
        const check = findChild(row(0), "check");
        compare(check.x, Tokens.spaceXs);
        compare(check.y, row(0).height / 2 - Geometry.listCheckRaise);
        compare(check.width, Geometry.listCheckWidth);
        compare(check.height, Geometry.listCheckHeight);
        compare(check.rotation, -45);
        compare(check.children[0].color, Tokens.color.textOnAccent);
    }

    function test_a_choice_holds_until_it_is_cleared() {
        mouseClick(row(3));
        mouseClick(row(5));
        compare(list.chosen, 5, "one row at a time");
        list.clear();
        compare(list.chosen, -1);
        tryCompare(findChild(row(5), "fill").color, "a", 0);
    }

    function test_a_pressed_row_tilts_toward_the_point_and_shrinks_then_comes_back() {
        const pressed = row(1);
        mousePress(pressed, pressed.width - 2, pressed.height / 2);
        verify(pressed.held);
        verify(pressed.pressX > 0.9);
        tryCompare(pressed, "sink", 1, Tokens.durationPress + 100);
        compare(pressed.tilt, Tokens.rowTilt);
        mouseRelease(pressed, pressed.width - 2, pressed.height / 2);
        tryCompare(pressed, "sink", 0, Tokens.durationShort + 200);
    }

    function test_a_press_eases_in_over_press_and_back_over_short() {
        const pressed = row(1);
        mousePress(pressed);
        wait(Tokens.durationPress / 2);
        verify(pressed.sink > 0 && pressed.sink < 1, `halfway in: ${pressed.sink}`);
        tryCompare(pressed, "sink", 1, 200);
        mouseRelease(pressed);
        wait(Tokens.durationPress + Tokens.durationShort / 2);
        verify(pressed.sink > 0 && pressed.sink < 1, `on its way back: ${pressed.sink}`);
    }

    function test_under_reduced_motion_a_press_only_shrinks() {
        Prefs.motion = "off";
        const pressed = row(1);
        mousePress(pressed, 2, 2);
        compare(pressed.sink, 1);
        compare(pressed.tilt, 0);
        mouseRelease(pressed, 2, 2);
    }

    function test_dragging_off_a_row_lets_it_go_and_chooses_nothing() {
        const pressed = row(1);
        mousePress(pressed, 50, 10);
        mouseMove(pressed, 50 + Geometry.pressSlopMouse + 2, 10);
        verify(!pressed.held);
        mouseRelease(pressed, 50 + Geometry.pressSlopMouse + 2, 10);
        compare(shownSpy.count, 0);
    }

    function test_hover_tints_a_row() {
        mouseMove(row(4), 50, 10);
        tryVerify(() => findChild(row(4), "tint").visible);
        compare(findChild(row(4), "tint").color, Tokens.color.hover);
        verify(!findChild(row(3), "tint").visible);
    }

    function test_the_list_is_one_tab_stop_whose_active_row_shows_the_ring_inside() {
        verify(list.activeFocusOnTab);
        list.forceActiveFocus();
        compare(list.active, 0, "the keys start at the first row in view");
        verify(findChild(list, "view").activeFocus);
        const rings = item => item.children.filter(child => child.border !== undefined && child.border.width === Geometry.focusRingWidth && child.visible);
        compare(rings(row(0)).length, 1);
        compare(rings(row(0))[0].width, row(0).width, "a 2px ring 2px inside, flush with the row's edges");
        compare(rings(row(0))[0].border.color, Tokens.color.focus);
        compare(rings(row(1)).length, 0);
        compare(rings(list).length, 1, "and the list its own, outside");
        list.focus = false;
        testCase.forceActiveFocus();
        compare(rings(row(0)).length, 0, "only while the list has the focus");
    }

    function test_scrolled_down_the_keys_start_from_the_first_row_in_view() {
        view.contentY = 12 * Tokens.rowHeight;
        list.forceActiveFocus();
        compare(list.active, 12);
    }

    function test_arrows_page_keys_home_and_end_move_the_active_row_and_scroll_it_into_view() {
        list.forceActiveFocus();
        keyClick(Qt.Key_Down);
        compare(list.active, 1);
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Up);
        compare(list.active, 0, "it stops at the first row");
        keyClick(Qt.Key_PageDown);
        compare(list.active, 9, "a page is the rows in view less one");
        keyClick(Qt.Key_End);
        compare(list.active, 39);
        const last = row(39);
        const top = last.mapToItem(view, 0, 0).y;
        verify(top >= 0 && top + last.height <= view.height, `whole in view at ${top}`);
        keyClick(Qt.Key_PageUp);
        compare(list.active, 30);
        keyClick(Qt.Key_Home);
        compare(list.active, 0);
        compare(view.contentY, 0);
        compare(list.chosen, -1, "moving chooses nothing");
    }

    function test_enter_and_space_press_and_choose_the_active_row() {
        list.forceActiveFocus();
        keyClick(Qt.Key_Down);
        keyPress(Qt.Key_Return);
        verify(row(1).held, "it sinks");
        compare(list.chosen, 1);
        compare(shownSpy.count, 1);
        keyRelease(Qt.Key_Return);
        tryVerify(() => !row(1).held, Tokens.durationPress + 100, "and lets go once the sink has played");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Space);
        compare(list.chosen, 2);
        compare(shownSpy.count, 2);
    }

    function test_while_loading_the_line_runs_after_busy_delay_over_still_placeholders() {
        list.rows = [];
        list.loading = true;
        const ghosts = findChild(list, "ghosts");
        const busy = findChild(list, "busy");
        verify(ghosts.visible);
        verify(!busy.shown, "not before busy-delay");
        tryVerify(() => busy.shown, Tokens.durationBusyDelay + 200);
        compare(busy.y, 0, "on the first hairline");
        compare(busy.height, Geometry.busyLineHeight);
        const ghost = ghosts.children[0];
        compare(ghost.height, Tokens.rowHeight);
        const bar = ghost.children[0];
        compare(bar.width, Geometry.ghostWidth * Tokens.fontSizeS);
        compare(bar.height, Geometry.ghostHeight * Tokens.fontSizeS);
        compare(bar.color, Tokens.color.surface);
        compare(bar.radius, Tokens.radiusS);
        verify(ghosts.children.filter(item => item.turnsWhole === true).length >= 10, "as many as fill the list");
        verify(!findChild(list, "empty").visible);
        list.rows = rowsOf(3);
        list.loading = false;
        verify(!ghosts.visible);
        verify(row(2) !== null);
    }

    function test_without_rows_the_list_says_what_is_empty_on_its_first_hairline() {
        list.rows = [];
        const empty = findChild(list, "empty");
        verify(empty.visible);
        compare(empty.text, "keine apps installiert.");
        compare(empty.color, Tokens.color.textContrastHigh);
        compare(empty.y, Geometry.hairline + Tokens.spaceM);
        keyClick(Qt.Key_Down);
        compare(list.active, -1);
    }

    function test_a_place_change_turns_each_row_as_one_part_and_the_list_as_a_scroller() {
        verify(row(0).turnsWhole);
        verify(!list.turnsWhole);
    }

    Component {
        id: sheetComponent

        Rectangle {
            width: testCase.width
            height: 4 * Tokens.rowHeight + 2 * Tokens.spaceL + Geometry.hairline
            color: Tokens.color.bg

            Row {
                x: Tokens.spaceL
                y: Tokens.spaceL
                spacing: Tokens.spaceL

                LongList {
                    objectName: "rows"
                    width: 360
                    height: 4 * Tokens.rowHeight + Geometry.hairline
                    rows: testCase.rowsOf(6).map((row, i) => ({ text: i === 3 ? "a name far too long for its row, cut at its end" : row.text, icon: row.icon }))
                }

                LongList {
                    objectName: "loading"
                    width: 360
                    height: 4 * Tokens.rowHeight + Geometry.hairline
                    loading: true
                }

                LongList {
                    objectName: "empty"
                    width: 360
                    height: 4 * Tokens.rowHeight + Geometry.hairline
                    rows: []
                    empty: "keine apps installiert."
                }
            }
        }
    }

    // A list with a chosen row, the active row in the ring, a hovered and a pressed row; one loading, one empty.
    function test_contact_sheet() {
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const sheet = createTemporaryObject(sheetComponent, testCase);
                const rows = findChild(sheet, "rows");
                const sheetView = findChild(rows, "view");
                findChild(sheet, "loading").forceActiveFocus();
                rows.forceActiveFocus();
                rows.chosen = 0;
                keyClick(Qt.Key_Down);
                mouseMove(sheetView.itemAtIndex(2), 40, 10);
                sheetView.itemAtIndex(3).press(1, -1);
                wait(Tokens.durationShort + Tokens.durationBusyDelay);
                waitForRendering(sheet);
                grabImage(sheet).save(`longlist-sheet-${theme}-${density}.png`);
                verify(rows.active === 1, `${theme} ${density}`);
            }
        }
    }
}
