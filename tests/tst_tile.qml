pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import "ContactSheets.js" as ContactSheets
import "Glide.js" as Glide

TestCase {
    id: testCase

    name: "Tile"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 800

    readonly property easingCurve easeBase: ({ type: Easing.Bezier, bezierCurve: Tokens.easeBase })

    Component {
        id: tileComponent

        Tile {
            x: 100
            y: 100

            Facts {
                objectName: "facts"
                text: "30 of 30 runs"
            }
        }
    }

    Component {
        id: spy

        SignalSpy {
            signalName: "activated"
        }
    }

    Component {
        id: sheetComponent

        // Each status, informing and opening, at rest and pressed (in the middle, near a corner), on the current
        // theme's ground.
        Rectangle {
            width: 980
            height: grid.height + 2 * Tokens.spaceL
            color: Tokens.color.bg

            Grid {
                id: grid

                x: Tokens.spaceL
                y: Tokens.spaceL
                columns: 5
                spacing: Tokens.spaceL

                Repeater {
                    model: ["rest", "opens", "middle", "corner"]

                    delegate: Repeater {
                        id: phase

                        required property string modelData

                        model: ["", "info", "success", "warning", "error"]

                        delegate: Tile {
                            required property string modelData

                            objectName: `${phase.modelData}-${modelData || "neutral"}`
                            status: modelData
                            opens: phase.modelData !== "rest"

                            Kicker {
                                width: parent.width
                                text: "nightly import"
                            }
                            Body {
                                width: parent.width
                                text: phase.modelData
                            }
                            Facts {
                                width: parent.width
                                text: "30 of 30 runs"
                            }
                        }
                    }
                }
            }
        }
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
        Prefs.contrast = "system";
    }

    function corner(tile) {
        return tile.mapToItem(testCase, tile.width, tile.height);
    }

    function test_the_fill_is_the_status() {
        const expected = [
            ["", Tokens.color.surface], ["info", Tokens.color.statusInfoTile], ["success", Tokens.color.statusSuccessTile],
            ["warning", Tokens.color.statusWarningTile], ["error", Tokens.color.statusErrorTile]
        ];
        for (const [status, fill] of expected) {
            const tile = createTemporaryObject(tileComponent, testCase, { status: status });
            tryCompare(findChild(tile, "fill"), "color", fill, 1000, status);
            compare(findChild(tile, "fill").radius, Tokens.radiusTile);
        }
    }

    function test_on_a_status_fill_secondary_text_takes_the_primary_colour() {
        const tile = createTemporaryObject(tileComponent, testCase);
        const facts = findChild(tile, "facts");
        compare(facts.color, Tokens.color.textContrastHigh, "on the neutral surface");
        tile.status = "warning";
        compare(facts.color, Tokens.color.textPrimary, "on a status fill");
        tile.status = "";
        compare(facts.color, Tokens.color.textContrastHigh);
    }

    function test_the_status_word_stands_top_right() {
        const tile = createTemporaryObject(tileComponent, testCase, { status: "error" });
        const word = findChild(tile, "word");
        verify(word.visible);
        compare(word.text, "failed");
        compare(word.y, 10);
        compare(tile.width - (word.x + word.width), 12);
        compare(word.font.weight, Tokens.fontWeightSemibold);
        compare(word.color, Tokens.color.textPrimary);
        compare(tile.Accessible.description, "failed");
        tile.status = "";
        verify(!word.visible, "a neutral tile has no status to spell out");
    }

    function test_under_more_contrast_a_status_tile_is_framed_inside_in_its_full_colour_and_keeps_its_word() {
        Prefs.contrast = "more";
        const expected = [
            ["info", "statusInfoFull"], ["success", "statusSuccessFull"], ["warning", "statusWarningFull"], ["error", "statusErrorFull"]
        ];
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            for (const [status, full] of expected) {
                const tile = createTemporaryObject(tileComponent, testCase, { status: status });
                const frame = findChild(tile, "statusFrame");
                verify(frame.visible, `${theme} ${status}`);
                compare(frame.border.color, Tokens.color[full], `${theme} ${status}`);
                compare(frame.border.width, 2);
                compare(frame.color, Qt.color("transparent"), "the fill shows through");
                compare(Qt.rect(frame.x, frame.y, frame.width, frame.height), Qt.rect(0, 0, tile.width, tile.height), "inside the tile");
                compare(frame.radius, Tokens.radiusTile);
                verify(findChild(tile, "word").visible, "the word stays");
            }
        }
    }

    function test_a_neutral_tile_or_normal_contrast_has_no_frame() {
        Prefs.contrast = "more";
        const tile = createTemporaryObject(tileComponent, testCase, { status: "" });
        verify(!findChild(tile, "statusFrame").visible, "no status, no frame");
        tile.status = "warning";
        verify(findChild(tile, "statusFrame").visible);
        Prefs.contrast = "normal";
        verify(!findChild(tile, "statusFrame").visible, "normal contrast has none");
    }

    function test_its_size_counts_tile_units_and_gaps() {
        const tile = createTemporaryObject(tileComponent, testCase, { columns: 2, rows: 1 });
        compare(tile.width, 2 * Tokens.tileUnit + Tokens.spaceS);
        compare(tile.height, Tokens.tileUnit);
    }

    function test_a_tile_that_only_informs_neither_presses_nor_takes_focus() {
        const tile = createTemporaryObject(tileComponent, testCase);
        const activations = createTemporaryObject(spy, testCase, { target: tile });
        verify(!tile.activeFocusOnTab);
        mousePress(tile);
        verify(!tile.pressed);
        mouseRelease(tile);
        mouseMove(tile);
        verify(!findChild(tile, "tint").visible);
        compare(activations.count, 0);
    }

    function test_a_tile_that_opens_takes_focus_with_the_ring_inside_and_activates() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true, status: "info" });
        const activations = createTemporaryObject(spy, testCase, { target: tile });
        verify(tile.activeFocusOnTab);
        compare(tile.Accessible.role, Accessible.Button);
        mouseClick(tile);
        compare(activations.count, 1);
        verify(!tile.activeFocus, "a click gives no focus");
        tile.forceActiveFocus();
        const ring = Array.from(tile.children).find(child => child.onFill !== undefined);
        verify(ring.visible);
        verify(ring.onFill);
        compare(ring.border.color, Tokens.color.textPrimary);
        mouseMove(tile, 10, 10);
        verify(findChild(tile, "tint").visible, "hover tints it");
    }

    function test_pressed_near_a_corner_it_tilts_that_corner_back() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true });
        const resting = corner(tile);
        mousePress(tile, tile.width - 1, tile.height - 1);
        verify(tile.pressed);
        fuzzyCompare(tile.pressX, 1, 0.02);
        fuzzyCompare(tile.pressY, 1, 0.02);
        tryCompare(tile, "sink", 1, Tokens.durationPress * 3);
        fuzzyCompare(tile.tiltX, -Tokens.tileTilt, 0.2);
        fuzzyCompare(tile.tiltY, Tokens.tileTilt, 0.2);
        fuzzyCompare(tile.pressScale, Tokens.tilePressScale, 0.001);
        const sunk = corner(tile);
        const centre = tile.mapToItem(testCase, tile.width / 2, tile.height / 2);
        const topLeft = tile.mapToItem(testCase, 0, 0);
        verify(sunk.x < resting.x && sunk.y < resting.y, "the pressed corner goes in");
        verify(sunk.x - centre.x < centre.x - topLeft.x, "and further than the far corner");
        mouseRelease(tile, tile.width - 1, tile.height - 1);
        tryCompare(tile, "sink", 0, Tokens.durationShort * 3);
    }

    function test_it_sinks_in_over_duration_press_and_comes_back_over_duration_short() {
        const ticks = Glide.ticks(testCase);
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true });
        const steps = Glide.record(tile, "sink");
        const pressed = Date.now();
        mousePress(tile, tile.width / 2, tile.height / 2);
        tryCompare(tile, "sink", 1, Tokens.durationPress * 3);
        const sinking = steps.splice(0);
        const released = Date.now();
        mouseRelease(tile, tile.width / 2, tile.height / 2);
        tryCompare(tile, "sink", 0, Tokens.durationShort * 3);
        const inStray = Glide.strayOf([{ steps: sinking, from: 0, to: 1 }], Tokens.durationPress, easeBase, pressed, ticks);
        verify(inStray < 0.06, `in over duration-press, off by ${inStray}`);
        const backStray = Glide.strayOf([{ steps, from: 1, to: 0 }], Tokens.durationShort, easeBase, released, ticks);
        verify(backStray < 0.06, `back over duration-short, off by ${backStray}`);
    }

    function test_pressed_on_the_right_edge_the_right_side_goes_back() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true });
        const rightBefore = tile.mapToItem(testCase, tile.width, tile.height / 2);
        const leftBefore = tile.mapToItem(testCase, 0, tile.height / 2);
        mousePress(tile, tile.width - 1, tile.height / 2);
        tryCompare(tile, "sink", 1, Tokens.durationPress * 3);
        const right = tile.mapToItem(testCase, tile.width, tile.height / 2);
        const left = tile.mapToItem(testCase, 0, tile.height / 2);
        verify(rightBefore.x - right.x > left.x - leftBefore.x, "the right edge moves in further than the left");
    }

    function test_it_lets_go_when_focus_moves_away_with_space_held() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true });
        const other = createTemporaryObject(tileComponent, testCase, { opens: true, x: 500 });
        tile.forceActiveFocus();
        keyPress(Qt.Key_Space);
        verify(tile.pressed);
        other.forceActiveFocus();
        tryVerify(() => !tile.pressed);
    }

    function test_enter_that_opens_a_place_taking_the_focus_still_shows_the_whole_sink() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true });
        const place = createTemporaryObject(tileComponent, testCase, { opens: true, x: 500 });
        tile.activated.connect(() => place.forceActiveFocus());
        let deepest = 0;
        tile.sinkChanged.connect(() => deepest = Math.max(deepest, tile.sink));
        tile.forceActiveFocus();
        keyClick(Qt.Key_Return);
        verify(place.activeFocus, "the place took the focus");
        tryVerify(() => !tile.pressed, Tokens.durationPress * 3);
        verify(deepest > 0.5, `it sank (to ${deepest})`);
    }

    function test_pressed_in_the_middle_it_sinks_straight_back() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true });
        mousePress(tile, tile.width / 2, tile.height / 2);
        tryCompare(tile, "sink", 1, Tokens.durationPress * 3);
        fuzzyCompare(tile.tiltX, 0, 0.01);
        fuzzyCompare(tile.tiltY, 0, 0.01);
        const sunk = corner(tile);
        const centre = tile.mapToItem(testCase, tile.width / 2, tile.height / 2);
        fuzzyCompare(sunk.x - centre.x, tile.width / 2 * Tokens.tilePressScale, 0.5);
        mouseRelease(tile, tile.width / 2, tile.height / 2);
    }

    function test_a_quick_tap_still_shows_the_whole_sink() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true });
        mouseClick(tile);
        verify(tile.pressed, "held for duration-press after the release");
        tryCompare(tile, "pressed", false, Tokens.durationPress * 3);
    }

    function test_while_pressed_the_hit_area_reaches_space_m_further() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true });
        const activations = createTemporaryObject(spy, testCase, { target: tile });
        mousePress(tile, tile.width - 2, tile.height / 2);
        mouseRelease(tile, tile.width + Tokens.spaceM - 2, tile.height / 2);
        compare(activations.count, 1, "a release within space-m still lands");
        mousePress(tile, tile.width - 2, tile.height / 2);
        mouseRelease(tile, tile.width + Tokens.spaceM + 4, tile.height / 2);
        compare(activations.count, 1, "beyond it the press is let go");
        mouseClick(tile, -Tokens.spaceM / 2, tile.height / 2);
        compare(activations.count, 1, "a press beside the resting tile is not its own");
    }

    function test_dragging_never_activates() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true });
        const activations = createTemporaryObject(spy, testCase, { target: tile });
        mousePress(tile, 40, 40);
        mouseMove(tile, 46, 40);
        verify(!tile.pressed, "4px of movement gives up the press");
        mouseRelease(tile, 46, 40);
        compare(activations.count, 0);
    }

    Component {
        id: scrollerComponent

        Flickable {
            width: 400
            height: 400
            contentHeight: 1200

            Tile {
                objectName: "tile"
                y: 200
                opens: true
            }
        }
    }

    function test_a_scroller_around_it_takes_a_drag_that_starts_on_it_and_the_press_gives_up() {
        const scroller = createTemporaryObject(scrollerComponent, testCase);
        const tile = findChild(scroller, "tile");
        const activations = createTemporaryObject(spy, testCase, { target: tile });
        mouseDrag(scroller, 60, 260, 0, -200);
        tryVerify(() => !scroller.moving, 3000);
        verify(scroller.contentY > 0, `scrolled to ${scroller.contentY}`);
        compare(activations.count, 0);
        verify(!tile.pressed);
    }

    function test_under_reduced_motion_a_press_only_shrinks() {
        Prefs.motion = "off";
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true });
        mousePress(tile, tile.width - 1, tile.height - 1);
        compare(tile.sink, 1, "at once");
        compare(tile.tiltX, 0);
        compare(tile.tiltY, 0);
        fuzzyCompare(tile.pressScale, Tokens.tilePressScale, 0.001);
        mouseRelease(tile, tile.width - 1, tile.height - 1);
    }

    function test_a_finger_presses_after_tap_delay_and_gives_up_on_eight_pixels() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true });
        const activations = createTemporaryObject(spy, testCase, { target: tile });
        const touch = touchEvent(tile);
        touch.press(0, tile, 40, 40).commit();
        verify(!tile.pressed, "not before tap-delay");
        tryCompare(tile, "pressed", true, Tokens.durationTapDelay * 3);
        touch.move(0, tile, 46, 40).commit();
        verify(tile.pressed, "6px is still a tap");
        touch.move(0, tile, 49, 40).commit();
        tryCompare(tile, "pressed", false, 500, "9px is the start of a scroll");
        touch.release(0, tile, 49, 40).commit();
        compare(activations.count, 0);
        touch.press(0, tile, 40, 40).commit();
        touch.release(0, tile, 40, 40).commit();
        verify(tile.pressed, "a quick tap still sinks");
        compare(activations.count, 1);
    }

    Component {
        id: menuSpy

        SignalSpy {
            signalName: "menuAsked"
        }
    }

    function test_a_right_click_asks_for_the_menu_at_the_pointer_and_neither_presses_nor_activates() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true, hasMenu: true });
        const asked = createTemporaryObject(menuSpy, testCase, { target: tile });
        const activations = createTemporaryObject(spy, testCase, { target: tile });
        mousePress(tile, 30, 50, Qt.RightButton);
        verify(!tile.pressed, "no sink");
        mouseRelease(tile, 30, 50, Qt.RightButton);
        compare(asked.count, 1);
        compare(asked.signalArguments[0][0], Qt.point(30, 50));
        compare(activations.count, 0);
    }

    function test_a_tile_without_a_menu_leaves_the_right_click_to_what_lies_beneath() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true });
        const asked = createTemporaryObject(menuSpy, testCase, { target: tile });
        mouseClick(tile, 30, 50, Qt.RightButton);
        compare(asked.count, 0);
    }

    function test_shift_f10_and_the_menu_key_ask_for_the_menu_below_the_leading_edge() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true, hasMenu: true, columns: 2 });
        const asked = createTemporaryObject(menuSpy, testCase, { target: tile });
        tile.forceActiveFocus();
        keyClick(Qt.Key_F10, Qt.ShiftModifier);
        keyClick(Qt.Key_Menu);
        compare(asked.count, 2);
        const below = Qt.point(Geometry.contextMenuAtX, Geometry.contextMenuAtY);
        compare(asked.signalArguments[0][0], below);
        compare(asked.signalArguments[1][0], below);
        verify(!tile.pressed);
        keyClick(Qt.Key_F10);
        compare(asked.count, 2, "F10 alone is no menu key");
    }

    function test_a_long_press_asks_for_the_menu_at_the_finger_and_its_release_activates_nothing() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true, hasMenu: true });
        const asked = createTemporaryObject(menuSpy, testCase, { target: tile });
        const activations = createTemporaryObject(spy, testCase, { target: tile });
        const touch = touchEvent(tile);
        const asks = Glide.record(asked, "count");
        const pressed = Date.now();
        touch.press(0, tile, 40, 60).commit();
        compare(asked.count, 0, "not at once");
        tryCompare(asked, "count", 1, Tokens.durationLongPress * 2);
        verify(asks[0].at - pressed >= Tokens.durationLongPress * 0.8, "not before long-press");
        compare(asked.signalArguments[0][0], Qt.point(40, 60));
        touch.release(0, tile, 40, 60).commit();
        compare(activations.count, 0);
    }

    function test_a_finger_that_moves_exactly_eight_pixels_still_asks_for_the_menu() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true, hasMenu: true });
        const asked = createTemporaryObject(menuSpy, testCase, { target: tile });
        const touch = touchEvent(tile);
        touch.press(0, tile, 40, 40).commit();
        touch.move(0, tile, 48, 40).commit();
        tryCompare(asked, "count", 1, Tokens.durationLongPress * 2);
        touch.release(0, tile, 48, 40).commit();
    }

    function test_a_finger_that_moves_diagonally_past_eight_pixels_asks_for_no_menu() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true, hasMenu: true });
        const asked = createTemporaryObject(menuSpy, testCase, { target: tile });
        const touch = touchEvent(tile);
        touch.press(0, tile, 40, 40).commit();
        touch.move(0, tile, 46, 46).commit();
        wait(Tokens.durationLongPress * 1.5);
        touch.release(0, tile, 46, 46).commit();
        compare(asked.count, 0);
    }

    function test_a_finger_that_moves_more_than_eight_pixels_asks_for_no_menu() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true, hasMenu: true });
        const asked = createTemporaryObject(menuSpy, testCase, { target: tile });
        const touch = touchEvent(tile);
        touch.press(0, tile, 40, 40).commit();
        touch.move(0, tile, 49, 40).commit();
        wait(Tokens.durationLongPress * 1.5);
        touch.release(0, tile, 49, 40).commit();
        compare(asked.count, 0);
    }

    function test_a_long_press_on_a_tile_without_a_menu_is_a_press() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true });
        const activations = createTemporaryObject(spy, testCase, { target: tile });
        const touch = touchEvent(tile);
        touch.press(0, tile, 40, 40).commit();
        wait(Tokens.durationLongPress * 1.5);
        touch.release(0, tile, 40, 40).commit();
        compare(activations.count, 1);
    }

    function test_enter_activates_as_it_goes_down_and_space_as_it_comes_up() {
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true });
        const activations = createTemporaryObject(spy, testCase, { target: tile });
        tile.forceActiveFocus();
        keyPress(Qt.Key_Return);
        compare(activations.count, 1);
        verify(tile.pressed);
        compare(tile.pressX, 0);
        compare(tile.pressY, 0);
        keyRelease(Qt.Key_Return);
        tryCompare(tile, "pressed", false, Tokens.durationPress * 3);
        keyPress(Qt.Key_Space);
        compare(activations.count, 1);
        verify(tile.pressed);
        keyRelease(Qt.Key_Space);
        compare(activations.count, 2);
    }

    // The tiles follow the one current theme, density and contrast, so the sheet is drawn once for each.
    function test_contact_sheet_of_tiles_in_both_themes_densities_and_contrasts() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const [theme, contrast] of [["light", "normal"], ["dark", "normal"], ["light", "more"], ["dark", "more"]]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                Prefs.contrast = contrast;
                const sheet = createTemporaryObject(sheetComponent, testCase);
                for (const status of ["neutral", "info", "success", "warning", "error"]) {
                    findChild(findChild(sheet, `middle-${status}`), "press").start(0, 0);
                    findChild(findChild(sheet, `corner-${status}`), "press").start(0.9, 0.9);
                }
                findChild(sheet, "opens-info").forceActiveFocus();
                wait(Tokens.durationPress + Tokens.durationShort);
                grabImage(sheet).save(`tile-sheet-${theme}-${density}${contrast === "more" ? "-more-contrast" : ""}.png`);
                verify(sheet.height > 0, `${theme} ${density} ${contrast}`);
                sheet.destroy();
            }
        }
    }
}
