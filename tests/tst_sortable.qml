pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import "ContactSheets.js" as ContactSheets

TestCase {
    id: testCase

    name: "Sortable"
    // Objects created inside an invisible test case are never rendered, so pictures would stay empty.
    visible: true
    when: windowShown
    width: 800
    height: 600

    Component {
        id: fixtureComponent

        Rectangle {
            id: fixture

            property alias list: list
            property alias flick: flick
            property alias outside: outside
            property string selected
            property int escapes: 0

            width: 400
            height: 300
            color: Tokens.color.bg
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape)
                    escapes++;
            }

            Flickable {
                id: flick

                anchors.fill: parent
                contentHeight: list.height + parent.height

                SortableRows {
                    id: list

                    width: flick.width
                    onMoved: (from, to) => model.move(from, to, 1)
                    model: ListModel {
                        ListElement {
                            title: "mail"
                        }
                        ListElement {
                            title: "kalender"
                        }
                        ListElement {
                            title: "dateien"
                        }
                        ListElement {
                            title: "konsole"
                        }
                    }
                    delegate: SortableRow {
                        id: row

                        required property string title

                        objectName: title
                        name: title

                        Text {
                            objectName: "words"
                            width: parent.width
                            height: row.height
                            verticalAlignment: Text.AlignVCenter
                            text: row.title
                            color: Tokens.color.textPrimary
                            font.family: Tokens.fontSans
                            font.pixelSize: Tokens.fontSizeM

                            TapHandler {
                                onTapped: fixture.selected = row.title
                            }

                            Item {
                                objectName: "control"
                                x: parent.width - width
                                width: Tokens.rowHeight
                                height: row.height
                                activeFocusOnTab: true
                            }
                        }
                    }
                }
            }

            Item {
                id: outside

                activeFocusOnTab: true
            }
        }
    }

    Component {
        id: spyComponent

        SignalSpy {}
    }

    property var fixture
    property var list
    property var moves

    function init() {
        Prefs.theme = "light";
        Prefs.motion = "off";
        fixture = createTemporaryObject(fixtureComponent, testCase);
        list = fixture.list;
        moves = createTemporaryObject(spyComponent, testCase, { target: list, signalName: "moved" });
        waitForRendering(fixture);
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function titles(): var {
        return list.all().sort((a, b) => a.index - b.index).map(row => row.title);
    }

    function row(title: string): var {
        return findChild(list, title);
    }

    function rowHeight(): real {
        return row("mail").height;
    }

    // The middle of a row's grip as it rests, in the list's coordinates, which stand still while rows move.
    function gripY(index: int): real {
        return list.tops[index] + rowHeight() / 2;
    }

    function press(index: int) {
        mousePress(list, Geometry.gripWidth / 2, gripY(index));
    }

    function pull(index: int, dy: real) {
        mouseMove(list, Geometry.gripWidth / 2, gripY(index) + dy, -1, Qt.LeftButton);
    }

    function release(index: int, dy: real) {
        mouseRelease(list, Geometry.gripWidth / 2, gripY(index) + dy);
    }

    function dragBy(index: int, dy: real) {
        press(index);
        pull(index, dy / 2);
        pull(index, dy);
        release(index, dy);
    }

    function test_a_drag_by_the_grip_moves_the_row_and_reports_from_and_to() {
        dragBy(0, 2 * rowHeight() + 1);
        compare(moves.count, 1);
        compare(moves.signalArguments[0][0], 0);
        compare(moves.signalArguments[0][1], 2);
        compare(titles(), ["kalender", "dateien", "mail", "konsole"]);
    }

    function test_a_drag_up_takes_the_first_place_whose_middle_it_passed() {
        dragBy(3, -2 * rowHeight() - 1);
        compare(moves.signalArguments[0][0], 3);
        compare(moves.signalArguments[0][1], 1);
    }

    function test_the_row_takes_the_next_place_only_once_its_middle_has_passed_that_rows_middle() {
        press(0);
        pull(0, rowHeight());
        compare(list.drag.to, 0, "middle on middle");
        pull(0, rowHeight() + 1);
        compare(list.drag.to, 1, "one past the middle");
        pull(0, -1);
        compare(list.drag.to, 0, "upwards from the first place");
        release(0, -1);
        compare(moves.count, 0, "back where it started");

        press(2);
        pull(2, -rowHeight());
        compare(list.drag.to, 2, "middle on middle, upwards");
        pull(2, -rowHeight() - 1);
        compare(list.drag.to, 1, "one past the middle, upwards");
        release(2, -rowHeight() - 1);
    }

    function test_the_drag_starts_only_after_four_pixels_up_or_down() {
        press(1);
        pull(1, Geometry.gripDragStart - 1);
        compare(list.draggedRow, null);
        compare(row("kalender").offset, 0);
        pull(1, Geometry.gripDragStart);
        compare(list.draggedRow, row("kalender"));
        verify(row("kalender").lifted);
        compare(row("kalender").offset, Geometry.gripDragStart);
        release(1, Geometry.gripDragStart);
    }

    function test_a_press_on_the_grip_without_moving_does_nothing_and_gives_no_focus() {
        press(1);
        release(1, 0);
        compare(moves.count, 0);
        compare(list.spoken, "");
        verify(!row("kalender").grip.activeFocus);
        compare(fixture.selected, "");
    }

    function test_a_drag_anywhere_but_the_grip_never_moves_the_row_and_a_click_there_still_selects() {
        const x = Geometry.gripWidth + 40;
        mouseClick(list, x, gripY(2));
        compare(fixture.selected, "dateien");
        mouseDrag(list, x, gripY(0), 0, 2 * rowHeight());
        compare(moves.count, 0);
        compare(list.draggedRow, null);
        compare(titles(), ["mail", "kalender", "dateien", "konsole"]);
    }

    function test_a_finger_on_the_grip_drags_the_row_and_never_scrolls_while_elsewhere_it_scrolls() {
        const touch = touchEvent(list);
        const x = Geometry.gripWidth / 2;
        touch.press(0, list, x, gripY(0)).commit();
        for (let step = 1; step <= 8; step++)
            touch.move(0, list, x, gripY(0) + step * rowHeight() / 4).commit();
        touch.move(0, list, x, gripY(0) + 2 * rowHeight() + 1).commit();
        touch.release(0, list, x, gripY(0) + 2 * rowHeight() + 1).commit();
        compare(fixture.flick.contentY, 0, "the grip kept the finger");
        compare(moves.count, 1);
        compare(moves.signalArguments[0][1], 2);

        const elsewhere = Geometry.gripWidth + 40;
        touch.press(0, fixture, elsewhere, gripY(3)).commit();
        for (let step = 1; step <= 8; step++) {
            touch.move(0, fixture, elsewhere, gripY(3) - step * rowHeight() / 2).commit();
            wait(16);
        }
        touch.release(0, fixture, elsewhere, gripY(3) - 4 * rowHeight()).commit();
        verify(fixture.flick.contentY > 0, "a finger beside the grip scrolls");
        compare(moves.count, 1);
    }

    function test_a_drag_taken_away_puts_the_row_back_without_a_move() {
        press(0);
        pull(0, 2 * rowHeight());
        verify(list.draggedRow !== null);
        row("mail").grip.enabled = false;
        compare(list.draggedRow, null);
        compare(moves.count, 0);
        compare(titles(), ["mail", "kalender", "dateien", "konsole"]);
        compare(row("mail").y, 0);
        compare(row("kalender").y, rowHeight());
    }

    function test_the_dragged_row_follows_the_pointer_and_the_others_make_room_in_duration_short() {
        Prefs.motion = "on";
        press(0);
        pull(0, Geometry.gripDragStart);
        pull(0, rowHeight() + 1);
        compare(row("mail").offset, rowHeight() + 1, "the pointer, at once");
        const kalender = row("kalender");
        verify(kalender.offset > -rowHeight(), "making room takes its time");
        wait(Tokens.durationShort / 2);
        verify(kalender.offset < 0 && kalender.offset > -rowHeight(), `under way: ${kalender.offset}`);
        tryCompare(kalender, "offset", -rowHeight(), Tokens.durationShort);
        compare(row("dateien").offset, 0, "rows beyond the place stay");
        release(0, rowHeight() + 1);
    }

    function test_on_release_everything_settles_with_flip_in_duration_moderate() {
        Prefs.motion = "on";
        press(0);
        pull(0, Geometry.gripDragStart);
        pull(0, rowHeight() + 1);
        tryCompare(row("kalender"), "offset", -rowHeight());
        release(0, rowHeight() + 1);
        const mail = row("mail");
        compare(mail.index, 1);
        compare(mail.y, rowHeight() + 1, "from where it showed");
        compare(row("kalender").y, 0, "the one that made room is already there");
        wait(Tokens.durationShort + 50);
        verify(mail.offset > 0, `still settling after duration-short: ${mail.offset}`);
        tryCompare(mail, "y", rowHeight(), Tokens.durationModerate);
    }

    function test_under_reduced_motion_making_room_and_settling_happen_at_once_while_the_row_still_follows_the_pointer() {
        press(0);
        pull(0, Geometry.gripDragStart);
        pull(0, rowHeight() + 1);
        compare(row("mail").offset, rowHeight() + 1);
        compare(row("kalender").offset, -rowHeight());
        release(0, rowHeight() + 1);
        compare(row("mail").y, rowHeight());
        compare(row("mail").offset, 0);
        compare(row("kalender").y, 0);
    }

    function test_a_drop_says_the_new_place() {
        dragBy(0, 2 * rowHeight() + 1);
        compare(list.spoken, "mail: platz 3 von 4.");
    }

    function test_a_drag_let_go_where_it_started_reports_no_move_and_says_nothing() {
        dragBy(1, rowHeight() / 3);
        compare(moves.count, 0);
        compare(list.spoken, "");
    }

    function test_space_picks_up_and_lifts_the_row_and_presses_the_grip() {
        const kalender = row("kalender");
        kalender.grip.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(list.grabbedRow, kalender);
        verify(kalender.lifted);
        verify(kalender.grip.Accessible.checked);
        compare(list.spoken, "kalender aufgenommen, platz 2 von 4. ↑ ↓ zum bewegen, leertaste zum ablegen, escape zum zurücklegen.");
    }

    function test_arrows_move_the_picked_up_row_one_place_and_the_focus_stays_on_its_grip() {
        const kalender = row("kalender");
        kalender.grip.forceActiveFocus();
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Down);
        compare(Array.from(moves.signalArguments[0]), [1, 2]);
        compare(titles(), ["mail", "dateien", "kalender", "konsole"]);
        verify(kalender.grip.activeFocus);
        compare(list.spoken, "platz 3 von 4");
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Up);
        compare(titles(), ["kalender", "mail", "dateien", "konsole"]);
        keyClick(Qt.Key_Up);
        compare(moves.count, 3, "no place above the first");
        compare(list.spoken, "platz 1 von 4");
    }

    function test_space_puts_the_row_down_where_it_is() {
        const kalender = row("kalender");
        kalender.grip.forceActiveFocus();
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Space);
        compare(list.grabbedRow, null);
        verify(!kalender.lifted);
        verify(!kalender.grip.Accessible.checked);
        compare(titles(), ["mail", "dateien", "kalender", "konsole"]);
        compare(list.spoken, "kalender abgelegt auf platz 3 von 4.");
    }

    function test_picked_up_and_put_down_without_a_move_reports_no_move() {
        row("kalender").grip.forceActiveFocus();
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Enter);
        compare(moves.count, 0);
        compare(list.grabbedRow, null);
    }

    function test_escape_puts_the_row_back_and_is_taken_before_the_place_gets_it() {
        const kalender = row("kalender");
        kalender.grip.forceActiveFocus();
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Escape);
        compare(titles(), ["mail", "kalender", "dateien", "konsole"]);
        compare(Array.from(moves.signalArguments[2]), [3, 1]);
        compare(list.grabbedRow, null);
        compare(list.spoken, "kalender zurückgelegt.");
        compare(fixture.escapes, 0);
        verify(kalender.grip.activeFocus);
        keyClick(Qt.Key_Escape);
        compare(fixture.escapes, 1, "nothing picked up, Escape is the place's");
    }

    function test_alt_and_an_arrow_move_the_row_at_once_without_picking_it_up() {
        const dateien = row("dateien");
        dateien.grip.forceActiveFocus();
        keyClick(Qt.Key_Up, Qt.AltModifier);
        compare(Array.from(moves.signalArguments[0]), [2, 1]);
        compare(list.grabbedRow, null);
        verify(dateien.grip.activeFocus);
        compare(list.spoken, "dateien: platz 2 von 4.");
        keyClick(Qt.Key_Up);
        compare(moves.count, 1, "an arrow alone does not move it");
    }

    function test_focus_leaving_the_row_puts_it_down_where_it_is() {
        const kalender = row("kalender");
        kalender.grip.forceActiveFocus();
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Down);
        fixture.outside.forceActiveFocus();
        compare(list.grabbedRow, null);
        verify(!kalender.lifted);
        compare(titles(), ["mail", "dateien", "kalender", "konsole"]);
    }

    function test_focus_moving_to_a_control_in_the_row_keeps_it_picked_up_and_leaving_from_there_puts_it_down() {
        const kalender = row("kalender");
        kalender.grip.forceActiveFocus();
        keyClick(Qt.Key_Space);
        findChild(kalender, "control").forceActiveFocus();
        compare(list.grabbedRow, kalender, "inside the row");
        fixture.outside.forceActiveFocus();
        compare(list.grabbedRow, null);
        verify(!kalender.lifted);
    }

    function test_tabbing_on_through_the_row_into_the_next_puts_the_picked_up_row_down() {
        const kalender = row("kalender");
        kalender.grip.forceActiveFocus();
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Tab);
        verify(findChild(kalender, "control").activeFocus);
        compare(list.grabbedRow, kalender);
        keyClick(Qt.Key_Tab);
        verify(row("dateien").grip.activeFocus);
        compare(list.grabbedRow, null);
        verify(!kalender.lifted);
        compare(moves.count, 0);
    }

    function test_a_keyboard_move_glides_with_flip_in_duration_moderate() {
        Prefs.motion = "on";
        const mail = row("mail");
        mail.grip.forceActiveFocus();
        keyClick(Qt.Key_Down, Qt.AltModifier);
        compare(mail.y, 0, "from where it showed");
        wait(Tokens.durationShort + 50);
        verify(mail.y < rowHeight(), `still gliding after duration-short: ${mail.y}`);
        tryCompare(mail, "y", rowHeight(), Tokens.durationModerate);
        compare(row("kalender").y, 0);
    }

    function test_while_picked_up_from_the_keyboard_a_pointer_drag_does_nothing() {
        row("mail").grip.forceActiveFocus();
        keyClick(Qt.Key_Space);
        dragBy(2, rowHeight() * 2);
        compare(moves.count, 0);
        compare(list.draggedRow, null);
    }

    function test_the_grip_is_24_pixels_wide_as_tall_as_its_row_and_read_as_moving_the_item() {
        const grip = row("mail").grip;
        compare(grip.width, Geometry.gripWidth);
        compare(grip.height, row("mail").height);
        compare(grip.Accessible.role, Accessible.Button);
        compare(grip.Accessible.name, "mail verschieben");
        verify(grip.Accessible.checkable);
        compare(findChild(grip, "squares").size, Geometry.gripGlyph);
        compare(findChild(row("mail"), "words").x, 0, "the content starts after the grip");
        compare(findChild(row("mail"), "words").mapToItem(row("mail"), 0, 0).x, Geometry.gripWidth);
    }

    function test_the_grip_is_contrast_medium_and_primary_under_the_pointer_or_picked_up() {
        const grip = row("mail").grip;
        const squares = findChild(grip, "squares");
        compare(squares.color, Tokens.color.textContrastMedium);
        mouseMove(grip, grip.width / 2, grip.height / 2);
        compare(squares.color, Tokens.color.textPrimary);
        mouseMove(list, list.width - 1, gripY(3));
        compare(squares.color, Tokens.color.textContrastMedium);
        grip.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(squares.color, Tokens.color.textPrimary);
    }

    // A pixel of a grabbed picture, in the fixture's coordinates.
    function pixelAt(image: var, item: var, x: real, y: real): color {
        const at = item.mapToItem(fixture, x, y);
        return image.pixel(Math.round(at.x), Math.round(at.y));
    }

    function test_the_grips_focus_ring_sits_inside_it_in_the_focus_colour() {
        const grip = row("kalender").grip;
        grip.forceActiveFocus();
        waitForRendering(fixture);
        const image = grabImage(fixture);
        // outline-offset -2px with a 2px outline: the ring covers the grip's outer two pixels.
        const inside = Geometry.focusRingInsetInRow;
        compare(pixelAt(image, grip, 0, grip.height / 2), Tokens.color.focus);
        compare(pixelAt(image, grip, inside - 1, grip.height / 2), Tokens.color.focus);
        compare(pixelAt(image, grip, inside, grip.height / 2), Tokens.color.bg);
        compare(pixelAt(image, grip, grip.width / 2, 0), Tokens.color.focus);
        compare(pixelAt(image, grip, grip.width / 2, -1), Tokens.color.bg, "nothing outside the grip");
    }

    function test_lifted_the_row_is_a_bg_surface_with_a_one_pixel_contrast_medium_edge_inside_and_no_shadow() {
        Prefs.theme = "dark";
        const kalender = row("kalender");
        kalender.grip.forceActiveFocus();
        keyClick(Qt.Key_Space);
        waitForRendering(fixture);
        const image = grabImage(fixture);
        const middle = kalender.height / 2;
        const across = kalender.width / 2;
        compare(pixelAt(image, kalender, across, 0), Tokens.color.textContrastMedium, "top edge");
        compare(pixelAt(image, kalender, across, kalender.height - 1), Tokens.color.textContrastMedium, "bottom edge");
        compare(pixelAt(image, kalender, kalender.width - 1, middle), Tokens.color.textContrastMedium, "trailing edge");
        compare(pixelAt(image, kalender, across, Geometry.liftedEdge), Tokens.color.bg, "one pixel, then the ground");
        compare(pixelAt(image, kalender, across, kalender.height), Tokens.color.bg, "no shadow below");
        compare(pixelAt(image, kalender, across, -1), Tokens.color.bg, "no shadow above");
        compare(findChild(kalender, "lift").color, Tokens.color.bg);
        verify(kalender.z > row("mail").z, "above the others");
    }

    function test_a_row_at_rest_has_neither_edge_nor_surface() {
        const image = grabImage(fixture);
        const kalender = row("kalender");
        compare(pixelAt(image, kalender, kalender.width / 2, 0), Tokens.color.bg);
        verify(!findChild(kalender, "edge").visible);
    }

    // At rest, one picked up with its grip focused, one under the pointer, on the current theme's ground.
    function test_contact_sheet() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            fixture.height = list.height;
            row("kalender").grip.forceActiveFocus();
            keyClick(Qt.Key_Space);
            mouseMove(list, Geometry.gripWidth / 2, gripY(3));
            waitForRendering(fixture);
            grabImage(fixture).save(`sortable-sheet-${theme}.png`);
            verify(row("kalender").lifted, theme);
            keyClick(Qt.Key_Escape);
        }
    }
}
