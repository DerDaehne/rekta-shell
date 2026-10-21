pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "Tile"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 800

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
        const tile = createTemporaryObject(tileComponent, testCase, { opens: true });
        mousePress(tile, tile.width / 2, tile.height / 2);
        wait(Tokens.durationPress * 1.5);
        verify(tile.sink > 0.98, "in within duration-press");
        mouseRelease(tile, tile.width / 2, tile.height / 2);
        wait(Tokens.durationPress);
        verify(tile.sink > 0.3, "still well sunk after duration-press");
        wait(Tokens.durationShort * 1.3 - Tokens.durationPress);
        verify(tile.sink < 0.01, "back after duration-short");
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

    // The tiles follow the one current theme and density, so the sheet is drawn once per pair.
    function test_contact_sheet_of_tiles_in_both_themes_and_densities() {
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const sheet = createTemporaryObject(sheetComponent, testCase);
                for (const status of ["neutral", "info", "success", "warning", "error"]) {
                    findChild(findChild(sheet, `middle-${status}`), "press").start(0, 0);
                    findChild(findChild(sheet, `corner-${status}`), "press").start(0.9, 0.9);
                }
                findChild(sheet, "opens-info").forceActiveFocus();
                wait(Tokens.durationPress + Tokens.durationShort);
                waitForRendering(sheet);
                grabImage(sheet).save(`tile-sheet-${theme}-${density}.png`);
                verify(sheet.height > 0, `${theme} ${density}`);
                sheet.destroy();
            }
        }
    }
}
