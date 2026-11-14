pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import "ContactSheets.js" as ContactSheets
import "ReadoutLine.js" as ReadoutLine
import "Glide.js" as Glide

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
            icon: "speaker"
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

    function test_under_a_full_screen_window_the_glass_shows_the_bar_s_line_with_the_bar_s_padding_as_wide_as_it() {
        alone.away = true;
        alone.press();
        verify(alone.mapped);
        tryCompare(alone, "settled", true, 2000);
        const face = findChild(alone, "icon").parent;
        ReadoutLine.verify(testCase, face, Tokens, Geometry, zeroIn(findChild(alone, "value")));
        compare(face.x, Tokens.spaceM);
        compare(face.y, 0);
        compare(face.width, face.implicitWidth);
        compare(face.height, Tokens.appbarHeight, "the line is centred on the bar's height");
        compare(alone.implicitWidth, face.implicitWidth + 2 * Tokens.spaceM);
        compare(alone.glass.width, alone.width);
        compare(findChild(face, "icon").name, "speaker");
    }

    function test_without_a_level_the_glass_shows_the_icon_and_the_value_alone() {
        alone.away = true;
        alone.level = -1;
        alone.word = "tastatur";
        alone.icon = "edit";
        alone.valueText = "English (US)";
        alone.press();
        const face = findChild(alone, "icon").parent;
        ReadoutLine.verify(testCase, face, Tokens, Geometry, zeroIn(findChild(alone, "value")));
        compare(alone.glass.width, face.implicitWidth + 2 * Tokens.spaceM);
    }

    function test_the_word_is_said_but_not_shown() {
        alone.away = true;
        alone.press();
        compare(alone.Accessible.name, "lautstärke 81%");
        compare(ReadoutLine.shownTexts(alone), ["81%"]);
    }

    function test_the_glass_is_the_bar_s_height_and_glass() {
        compare(alone.glass.height, Tokens.appbarHeight);
        compare(alone.glass.color, Tokens.color.glass);
        compare(findChild(alone, "hairline").height, Geometry.hairline);
        compare(alone.height, Tokens.appbarHeight);
        compare(Geometry.toastRise, 12);
    }

    function zeroIn(value: var): real {
        zeroMetrics.font = value.font;
        return zeroMetrics.advanceWidth;
    }

    TextMetrics {
        id: zeroMetrics

        text: "0"
    }

    function test_it_stays_the_hold_and_then_goes_and_is_unmapped_after_the_way_out() {
        showAlone();
        compare(hold.interval, Tokens.durationLevel);
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
        compare(alone.glass.y, restingY + Geometry.toastRise);
        stopAt(0.4);
        const eased = alone.ease.valueForProgress(0.4);
        verify(eased > 0 && eased < 1);
        fuzzyCompare(alone.glass.opacity, eased, 1e-9);
        fuzzyCompare(alone.glass.y, restingY + (1 - eased) * Geometry.toastRise, 1e-9);
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
        fuzzyCompare(alone.glass.y, restingY + (1 - eased) * Geometry.toastRise, 1e-9);
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

    function test_a_newly_mapped_surface_starts_its_way_in_with_its_first_frame() {
        alone.away = true;
        alone.press();
        verify(alone.awaitsFrame);
        verify(moving.paused);
        compare(alone.phase, 0);
        tryCompare(alone, "awaitsFrame", false, 2000);
        verify(!moving.paused);
        tryCompare(alone, "settled", true, 2000);
    }

    function test_a_further_key_restarts_the_hold() {
        hold.interval = 800;
        alone.away = true;
        alone.press();
        wait(500);
        const shown = Glide.record(alone, "shown");
        const further = Date.now();
        alone.press();
        tryCompare(alone, "shown", false, 3000);
        verify(shown[0].at - further >= 500, "the further key starts the hold again");
        tryCompare(alone, "mapped", false, 3000);
    }

    SignalSpy {
        id: mappedSpy

        signalName: "mappedChanged"
    }

    SignalSpy {
        id: saidSpy

        signalName: "announced"
    }

    function saidWords(): var {
        return saidSpy.signalArguments.map(args => args[0]);
    }

    function test_under_a_full_screen_window_a_key_itself_says_nothing_and_news_after_it_is_announced_politely() {
        saidSpy.target = alone;
        saidSpy.clear();
        alone.away = true;
        alone.press();
        compare(saidSpy.count, 0);
        alone.say("lautstärke 86%");
        alone.say("mikrofon stumm");
        compare(saidWords(), ["lautstärke 86%", "mikrofon stumm"]);
        compare(saidSpy.signalArguments[0][1], Accessible.Polite);
    }

    function test_nothing_is_announced_without_a_full_screen_window_or_after_the_display_has_gone() {
        saidSpy.target = alone;
        saidSpy.clear();
        alone.press();
        alone.say("lautstärke 50%");
        compare(saidSpy.count, 0);
        showAlone();
        expire();
        alone.say("lautstärke 40%");
        compare(saidSpy.count, 0);
    }

    function test_news_after_a_key_on_the_way_out_is_announced() {
        saidSpy.target = alone;
        showAlone();
        saidSpy.clear();
        expire();
        alone.press();
        alone.say("lautstärke 86%");
        compare(saidWords(), ["lautstärke 86%"]);
    }

    function test_under_reduced_motion_the_display_comes_and_goes_at_once_but_stays_its_time() {
        Prefs.motion = "off";
        failOnWarning(/setPaused|TypeError|ReferenceError|Binding loop/);
        compare(moving.duration, 0);
        compare(hold.interval, Tokens.durationLevel);
        alone.away = true;
        alone.press();
        tryCompare(alone, "settled", true, 500);
        compare(alone.glass.y, restingY);
        expire();
        tryCompare(alone, "mapped", false, 500);
    }

    function test_contact_sheet() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        const shown = [
            { word: "lautstärke", icon: "speaker", level: 0.6, valueText: "60%" },
            { word: "mikrofon", icon: "microphone-muted", level: 0, valueText: "stumm" },
            { word: "helligkeit", icon: "theme", level: 0.35, valueText: "35%" },
            { word: "tastatur", icon: "edit", level: -1, valueText: "de" }
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

    // The display with each of the four values on the ground, as it stands over a full-screen window.
    Component {
        id: sheetComponent

        Rectangle {
            id: sheet

            required property var shown

            width: 2 * Tokens.tileUnit + 160
            height: 4 * (Tokens.appbarHeight + 20) + 20
            color: Tokens.color.bg

            Repeater {
                model: sheet.shown

                delegate: ReadoutAlone {
                    id: one

                    required property var modelData
                    required property int index

                    objectName: "one"
                    x: 20
                    y: 20 + index * (Tokens.appbarHeight + 20)
                    width: implicitWidth
                    height: implicitHeight
                    word: modelData.word
                    icon: modelData.icon
                    level: modelData.level
                    valueText: modelData.valueText
                }
            }
        }
    }
}
