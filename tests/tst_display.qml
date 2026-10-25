pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "Display"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1200
    height: 600

    // A bar with a clock in its centre and a display that takes the clock's place, with the room it needs reserved.
    Component {
        id: sceneComponent

        Rectangle {
            id: stage

            property alias bar: appBar
            property alias clock: appClock
            property alias display: appDisplay
            property alias before: leading
            property alias middle: words
            property alias after: trailing

            width: 1200
            height: 100
            color: Tokens.color.bg

            AppBar {
                id: appBar

                y: stage.height - height
                width: stage.width
                centre: appClock
                centreReserve: appDisplay.implicitWidth

                AppBarButton { id: leading; icon: "search"; text: "go to" }
                AppBarMiddle { id: words; parts: ["konsole", "a title that runs on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on"] }

                AppBarClock {
                    id: appClock

                    objectName: "clock"
                    locale: Qt.locale("de_DE")
                    now: new Date(2026, 9, 21, 14, 32)
                }

                AppBarDisplay {
                    id: appDisplay

                    objectName: "display"
                    replaces: appClock
                    word: "lautstärke"
                    level: 0.81
                    valueText: "81%"
                }

                AppBarButton { id: trailing; icon: "bell"; text: "meldungen" }
            }
        }
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var scene
    property var clock
    property var display
    property var turning
    property var hold

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        scene = createTemporaryObject(sceneComponent, testCase);
        clock = scene.clock;
        display = scene.display;
        turning = findChild(display, "turning");
        hold = findChild(display, "hold");
    }

    function cleanup() {
        Prefs.theme = "system";
        Prefs.motion = "system";
    }

    // Shows a moment of the swap: stops the animation and sets where it stands, in turn durations.
    function stopAt(phase: real) {
        turning.pause();
        display.phase = phase;
    }

    function test_the_display_is_hidden_and_the_clock_whole_until_a_key() {
        verify(!display.shown);
        verify(!display.visible);
        compare(clock.opacity, 1);
        compare(display.replacesAngle, 0);
    }

    function test_a_key_turns_the_clock_away_and_the_display_in() {
        display.press();
        verify(display.shown);
        tryCompare(display, "phase", display.span, 2000);
        compare(clock.opacity, 0);
        compare(display.opacity, 1);
        compare(display.replacesAngle, Geometry.flipAngle);
        compare(display.displayAngle, 0);
    }

    function test_the_swap_takes_200_ms_a_turn_and_the_display_starts_when_the_clock_is_three_quarters_through() {
        compare(Geometry.flipDuration, 200);
        display.press();
        compare(turning.duration, (1 + Geometry.turnOverlap) * 200);
        stopAt(Geometry.turnOverlap - 0.01);
        compare(display.opacity, 0);
        verify(display.replacesAngle > 0 && display.replacesAngle < Geometry.flipAngle);
        stopAt(Geometry.turnOverlap + 0.05);
        verify(display.opacity > 0);
        verify(display.displayAngle < 0);
    }

    function test_the_clock_turns_about_its_bottom_edge_through_90_degrees_and_the_display_comes_in_from_minus_90() {
        display.press();
        stopAt(Geometry.turnOverlap);
        compare(display.displayAngle, -Geometry.flipAngle);
        stopAt(1);
        compare(display.replacesAngle, Geometry.flipAngle);
        const turn = clock.transform[clock.transform.length - 1];
        compare(turn.origin.y, clock.height);
        compare(turn.origin.x, clock.width / 2);
        compare(turn.axis.x, 1);
    }

    function test_the_clock_stays_whole_for_its_first_40_percent_then_fades() {
        display.press();
        stopAt(Geometry.turnOutWhole);
        compare(display.replacesFade, 1);
        stopAt(0.7);
        verify(display.replacesFade > 0 && display.replacesFade < 1);
        compare(clock.opacity, display.replacesFade);
    }

    function test_the_display_is_whole_after_its_first_35_percent() {
        display.press();
        stopAt(Geometry.turnOverlap + Geometry.turnInWhole);
        compare(display.displayFade, 1);
        stopAt(Geometry.turnOverlap + 0.1);
        verify(display.displayFade > 0 && display.displayFade < 1);
    }

    function test_the_display_stays_1700_ms_after_a_key() {
        compare(hold.interval, 1700);
        display.press();
        wait(1500);
        verify(display.shown);
        tryCompare(display, "shown", false, 1000);
    }

    function test_a_second_key_only_extends_the_stay_without_a_new_turn() {
        display.press();
        tryCompare(display, "phase", display.span, 2000);
        wait(1000);
        display.press();
        compare(display.phase, display.span);
        verify(!turning.running);
        wait(1000);
        verify(display.shown);
        compare(display.opacity, 1);
        tryCompare(display, "shown", false, 1500);
    }

    function test_the_way_back_runs_the_turns_the_other_way_round_the_display_leaving_first() {
        display.press();
        tryCompare(display, "shown", false, 3000);
        tryCompare(turning, "running", true, 500);
        stopAt(0.5);
        verify(display.displayAngle < 0 && display.displayAngle > -Geometry.flipAngle);
        compare(display.opacity, display.leaveFade);
        compare(clock.opacity, 0);
        stopAt(Geometry.turnOverlap);
        compare(display.replacesAngle, Geometry.flipAngle);
        stopAt(display.span);
        compare(clock.opacity, 1);
        compare(display.replacesAngle, 0);
        compare(display.displayAngle, -Geometry.flipAngle);
    }

    function test_the_clock_is_whole_and_the_display_gone_after_the_way_back() {
        display.press();
        tryCompare(display, "shown", false, 3000);
        tryCompare(turning, "running", false, 1000);
        compare(clock.opacity, 1);
        verify(!display.visible);
        verify(clock.enabled);
    }

    function test_a_key_during_the_way_back_brings_the_display_again_after_it() {
        display.press();
        tryCompare(display, "shown", false, 3000);
        tryCompare(turning, "running", true, 500);
        display.press();
        compare(display.toDisplay, false);
        tryCompare(display, "toDisplay", true, 1000);
        tryCompare(display, "phase", display.span, 1000);
        compare(display.opacity, 1);
    }

    function test_the_clock_takes_no_clicks_while_the_display_stands_over_it() {
        display.press();
        verify(!clock.enabled);
    }

    function test_under_reduced_motion_the_clock_and_the_display_change_at_once() {
        Prefs.motion = "off";
        display.press();
        compare(clock.opacity, 0);
        compare(display.opacity, 1);
        compare(display.displayAngle, 0);
        wait(300);
        verify(display.shown);
    }

    function test_under_reduced_motion_the_display_still_stays_1700_ms_and_goes_at_once() {
        Prefs.motion = "off";
        display.press();
        compare(hold.interval, 1700);
        wait(1500);
        verify(display.shown);
        tryCompare(display, "shown", false, 1000);
        compare(clock.opacity, 1);
        verify(!display.visible);
    }

    function test_the_bar_keeps_its_neighbours_clear_of_the_room_the_display_needs() {
        verify(scene.middle.width > 0);
        verify(scene.middle.x + scene.middle.width <= (scene.width - Tokens.tileUnit) / 2 + 0.5);
        verify(scene.after.x >= (scene.width + Tokens.tileUnit) / 2 - 0.5);
    }

    function test_the_display_stands_centred_over_the_clock() {
        compare(display.x + display.width / 2, clock.x + clock.width / 2);
        compare(display.width, Tokens.tileUnit);
    }

    function test_a_level_shows_the_meter_and_a_missing_one_shows_the_text_alone() {
        Prefs.motion = "off";
        display.press();
        const meter = findChild(display, "meter");
        const plain = findChild(display, "plain");
        verify(meter.visible);
        verify(!plain.visible);
        display.level = -1;
        display.valueText = "English (US)";
        verify(!meter.visible);
        verify(plain.visible);
    }

    function test_contact_sheet() {
        const bars = [
            { word: "lautstärke", level: 0.81, valueText: "81%" },
            { word: "mikrofon", level: 0, valueText: "stumm" },
            { word: "tastatur", level: -1, valueText: "English (US)" }
        ];
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            Prefs.motion = "off";
            const sheet = createTemporaryObject(sheetComponent, testCase, { bars });
            const displays = sheet.children.filter(child => child.objectName === "row").map(row => findChild(row, "display"));
            const holds = displays.map(display => findChild(display, "hold"));
            holds.forEach(timer => timer.interval = 60000);
            displays.forEach(display => display.press());
            waitForRendering(sheet);
            grabImage(sheet).save(`display-sheet-${theme}.png`);
        }
    }

    // The bar three times, the display standing in the centre with a volume, a muted microphone and a layout.
    Component {
        id: sheetComponent

        Rectangle {
            id: sheet

            required property var bars

            width: 1200
            height: 3 * Tokens.appbarHeight + 40
            color: Tokens.color.bg

            Repeater {
                model: sheet.bars

                delegate: AppBar {
                    id: row

                    required property var modelData
                    required property int index

                    objectName: "row"

                    y: 20 + index * Tokens.appbarHeight
                    width: sheet.width
                    centre: rowClock
                    centreReserve: Tokens.tileUnit

                    AppBarButton { icon: "search"; text: "go to" }
                    AppBarMiddle { parts: ["konsole", "~/projects: build the shell"] }

                    AppBarClock {
                        id: rowClock

                        now: new Date(2026, 9, 21, 14, 32)
                    }

                    AppBarDisplay {
                        objectName: "display"
                        replaces: rowClock
                        word: row.modelData.word
                        level: row.modelData.level
                        valueText: row.modelData.valueText
                    }

                    AppBarButton { icon: "bell"; text: "meldungen" }
                }
            }
        }
    }
}
