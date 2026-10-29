pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "ReadoutAlone"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 700
    height: 300

    Component {
        id: aloneComponent

        ReadoutAlone {
            width: implicitWidth
            height: implicitHeight
            word: "lautstärke"
            level: 0.81
            valueText: "81%"
        }
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var alone
    property var hold
    property var moving
    property real restingY

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        alone = createTemporaryObject(aloneComponent, testCase);
        hold = findChild(alone, "hold");
        moving = findChild(alone, "moving");
        restingY = 0;
    }

    function cleanup() {
        Prefs.theme = "system";
        Prefs.motion = "system";
    }

    // The display on screen at rest.
    function showAlone() {
        alone.away = true;
        alone.press();
        tryCompare(alone, "settled", true, 2000);
    }

    // The hold runs out.
    function expire() {
        hold.stop();
        hold.triggered();
    }

    // Shows a moment of the way in or out: stops the animation and sets where it stands, 0 to 1.
    function stopAt(phase: real) {
        moving.pause();
        alone.phase = phase;
    }

    function test_a_key_without_a_full_screen_window_shows_nothing() {
        alone.press();
        verify(!alone.mapped);
        verify(!alone.glass.visible);
        verify(!hold.running);
    }

    function test_a_key_under_a_full_screen_window_shows_the_word_the_level_and_the_value() {
        alone.away = true;
        alone.press();
        verify(alone.mapped);
        tryCompare(alone, "settled", true, 2000);
        const meter = findChild(alone, "meter");
        verify(meter.visible);
        compare(meter.label, "lautstärke");
        compare(meter.value, 0.81);
        compare(meter.valueText, "81%");
    }

    function test_a_text_without_a_level_shows_over_its_word() {
        alone.away = true;
        alone.level = -1;
        alone.word = "tastatur";
        alone.valueText = "English (US)";
        alone.press();
        verify(!findChild(alone, "meter").visible);
        verify(findChild(alone, "plain").visible);
    }

    function test_the_glass_is_the_bar_s_height_and_the_tile_unit_wide_with_the_bar_s_padding() {
        compare(alone.glass.height, Tokens.appbarHeight);
        compare(alone.glass.width, Tokens.tileUnit + 2 * Tokens.spaceM);
        compare(alone.glass.color, Tokens.color.glass);
        compare(findChild(alone, "hairline").height, Geometry.hairline);
        compare(alone.height, Tokens.appbarHeight);
        compare(Geometry.readoutRise, 12);
    }

    function test_it_stays_the_hold_and_then_goes_and_is_unmapped_after_the_way_out() {
        showAlone();
        compare(hold.interval, Geometry.displayHold);
        verify(hold.running);
        expire();
        verify(alone.mapped);
        verify(alone.leaving);
        tryCompare(alone, "mapped", false, 2000);
        compare(alone.progress, 0);
        verify(!alone.glass.visible);
    }

    function test_a_further_key_keeps_the_display_without_a_new_arrival() {
        showAlone();
        alone.press();
        verify(!moving.running);
        verify(hold.running);
        compare(alone.progress, 1);
        verify(alone.settled);
    }

    function test_a_key_on_the_way_out_waits_for_it_and_the_display_comes_again() {
        showAlone();
        expire();
        stopAt(0.5);
        alone.press();
        verify(alone.leaving);
        verify(!hold.running);
        moving.resume();
        tryCompare(alone, "settled", true, 2000);
        verify(hold.running);
    }

    function test_the_display_is_gone_at_once_when_the_full_screen_window_ends() {
        showAlone();
        alone.away = false;
        verify(!alone.mapped);
        compare(alone.progress, 0);
        verify(!hold.running);
        verify(!moving.running);
    }

    function test_the_way_in_rises_twelve_pixels_with_a_fade_in_the_short_duration_and_ease_in() {
        compare(moving.duration, Tokens.durationShort);
        alone.away = true;
        alone.press();
        stopAt(0);
        compare(alone.progress, 0);
        compare(alone.glass.opacity, 0);
        compare(alone.glass.y, restingY + Geometry.readoutRise);
        stopAt(0.4);
        const eased = alone.ease.valueForProgress(0.4);
        verify(eased > 0 && eased < 1);
        fuzzyCompare(alone.glass.opacity, eased, 1e-9);
        fuzzyCompare(alone.glass.y, restingY + (1 - eased) * Geometry.readoutRise, 1e-9);
        compare(alone.ease.bezierCurve.toString(), Tokens.easeIn.toString());
        verify(!alone.settled);
        stopAt(1);
        compare(alone.glass.y, restingY);
        compare(alone.glass.opacity, 1);
    }

    function test_the_way_out_runs_the_curve_backwards_not_its_complement() {
        showAlone();
        expire();
        compare(moving.from, 1);
        compare(moving.to, 0);
        // A fifth of the way out in time: the eased value of the way in at four fifths, as a reversed animation shows it.
        stopAt(0.8);
        const eased = alone.ease.valueForProgress(0.8);
        verify(eased > 0.9);
        fuzzyCompare(alone.glass.opacity, eased, 1e-9);
        fuzzyCompare(alone.glass.y, restingY + (1 - eased) * Geometry.readoutRise, 1e-9);
        verify(!alone.settled);
    }

    function test_the_surface_stays_mapped_from_the_first_key_through_the_way_out_and_a_key_during_it() {
        mappedSpy.target = alone;
        mappedSpy.clear();
        showAlone();
        compare(mappedSpy.count, 1);
        expire();
        stopAt(0.5);
        alone.press();
        moving.resume();
        tryCompare(alone, "settled", true, 2000);
        compare(mappedSpy.count, 1);
        expire();
        tryCompare(alone, "mapped", false, 2000);
        compare(mappedSpy.count, 2);
    }

    function test_a_further_key_restarts_the_hold() {
        hold.interval = 800;
        alone.away = true;
        alone.press();
        wait(500);
        alone.press();
        wait(500);
        verify(alone.shown);
        tryCompare(alone, "mapped", false, 3000);
    }

    SignalSpy {
        id: mappedSpy

        signalName: "mappedChanged"
    }


    function test_under_reduced_motion_the_display_comes_and_goes_at_once_but_stays_its_time() {
        Prefs.motion = "off";
        compare(moving.duration, 0);
        compare(hold.interval, Geometry.displayHold);
        alone.away = true;
        alone.press();
        tryCompare(alone, "settled", true, 500);
        compare(alone.glass.y, restingY);
        expire();
        tryCompare(alone, "mapped", false, 500);
    }

    function test_contact_sheet() {
        const shown = [
            { word: "lautstärke", level: 0.81, valueText: "81%" },
            { word: "mikrofon", level: 0, valueText: "stumm" },
            { word: "tastatur", level: -1, valueText: "English (US)" }
        ];
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            Prefs.motion = "off";
            const sheet = createTemporaryObject(sheetComponent, testCase, { shown });
            for (const one of sheet.children.filter(child => child.objectName === "one")) {
                findChild(one, "hold").interval = 60000;
                one.away = true;
                one.press();
            }
            waitForRendering(sheet);
            grabImage(sheet).save(`readout-alone-sheet-${theme}.png`);
        }
    }

    // The display three times on the ground, as it stands over a full-screen window.
    Component {
        id: sheetComponent

        Rectangle {
            id: sheet

            required property var shown

            width: 3 * (Tokens.tileUnit + 2 * Tokens.spaceM) + 80
            height: Tokens.appbarHeight + 40
            color: Tokens.color.bg

            Repeater {
                model: sheet.shown

                delegate: ReadoutAlone {
                    id: one

                    required property var modelData
                    required property int index

                    objectName: "one"
                    x: 20 + index * (width + 20)
                    y: 20
                    width: implicitWidth
                    height: implicitHeight
                    word: modelData.word
                    level: modelData.level
                    valueText: modelData.valueText
                }
            }
        }
    }
}
