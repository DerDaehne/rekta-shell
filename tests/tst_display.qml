pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Readout
import Rekta
import "ContactSheets.js" as ContactSheets

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

                AppBarButton { id: leading; icon: "window"; text: "back" }
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

    // The readout as the shell feeds it: a volume and a microphone that PipeWire reports.
    Component {
        id: readoutComponent

        KeyReadout {
            volume: 0.81
            micVolume: 0.3
        }
    }

    Component {
        id: spyComponent

        SignalSpy {
            signalName: "announced"
        }
    }

    // Rekta's curves, read from the tokens here rather than from the display.
    readonly property easingCurve tokenOut: ({ type: Easing.Bezier, bezierCurve: Tokens.easeOut })
    readonly property easingCurve tokenIn: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var scene
    property var clock
    property var display
    property var turning
    property var hold
    property var said

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        scene = createTemporaryObject(sceneComponent, testCase);
        clock = scene.clock;
        display = scene.display;
        turning = findChild(display, "turning");
        hold = findChild(display, "hold");
        said = createTemporaryObject(spyComponent, testCase, { target: display });
    }

    function cleanup() {
        Prefs.theme = "system";
        Prefs.motion = "system";
    }

    // Shows a moment of the flip: stops the animation and sets where it stands, 0 to 1.
    function stopAt(phase: real) {
        turning.pause();
        display.phase = phase;
    }

    // Ends the stay at once instead of waiting it out; the tests that need it check its interval against the token.
    function runOutHold() {
        verify(hold.running, "the display stays for the hold");
        hold.stop();
        hold.triggered();
    }

    function clockTurn(): var {
        return clock.transform[clock.transform.length - 1];
    }

    function displayTurn(): var {
        return display.transform[0];
    }

    // The display after its flip in, standing.
    function showDisplay() {
        display.press();
        tryCompare(turning, "running", false, 2000);
        compare(display.phase, 1);
    }

    // What shows on every frame of one whole flip, run by the animation itself.
    function recordFlip(): var {
        const frames = [];
        const record = () => frames.push({ phase: display.phase, clockOpacity: clock.opacity, displayShown: display.visible, displayOpacity: display.opacity });
        display.phaseChanged.connect(record);
        tryCompare(turning, "running", false, 2000);
        display.phaseChanged.disconnect(record);
        return frames;
    }

    function test_the_display_is_hidden_and_the_clock_whole_and_upright_until_a_key() {
        verify(!display.shown);
        verify(!display.visible);
        compare(clock.opacity, 1);
        compare(clockTurn().angle, 0);
    }

    function test_a_key_turns_the_clock_away_and_the_display_in() {
        showDisplay();
        verify(display.shown);
        compare(clock.opacity, 0);
        verify(display.visible);
        compare(display.opacity, 1);
        compare(displayTurn().angle, 0);
    }

    function test_the_flip_takes_duration_moderate_and_changes_halfway() {
        display.press();
        compare(turning.duration, Tokens.durationModerate);
        stopAt(0.499);
        verify(!display.visible);
        compare(clock.opacity, 1);
        stopAt(0.5);
        verify(display.visible);
        compare(clock.opacity, 0);
    }

    function test_both_turn_about_their_horizontal_middle_with_the_turnstile_perspective() {
        for (const turn of [clockTurn(), displayTurn()]) {
            compare(turn.axis.x, 1);
            compare(turn.axis.y, 0);
            compare(turn.axis.z, 0);
            compare(turn.distanceToPlane, Tokens.turnstilePerspective);
        }
        compare(clockTurn().origin.x, clock.width / 2);
        compare(clockTurn().origin.y, clock.height / 2);
        compare(displayTurn().origin.x, display.width / 2);
        compare(displayTurn().origin.y, display.height / 2);
    }

    function test_the_clock_turns_away_to_minus_90_on_ease_out_over_the_first_half_while_the_display_waits() {
        display.press();
        for (const phase of [0, 0.1, 0.25, 0.4]) {
            stopAt(phase);
            compare(clockTurn().angle, -Tokens.flipAngle * tokenOut.valueForProgress(phase * 2), `clock at ${phase}`);
            compare(clock.opacity, 1);
            verify(!display.visible, `display hidden at ${phase}`);
        }
        stopAt(0.49999);
        fuzzyCompare(clockTurn().angle, -Tokens.flipAngle, 0.01);
    }

    function test_the_display_turns_in_from_90_on_ease_in_over_the_second_half_while_the_clock_stays_away() {
        display.press();
        for (const phase of [0.5, 0.6, 0.75, 0.9, 1]) {
            stopAt(phase);
            compare(displayTurn().angle, Tokens.flipAngle * (1 - tokenIn.valueForProgress(phase * 2 - 1)), `display at ${phase}`);
            compare(display.opacity, 1);
            verify(display.visible);
            compare(clock.opacity, 0, `clock away at ${phase}`);
        }
    }

    function test_on_no_frame_of_the_flip_are_both_in_sight_and_nothing_fades() {
        display.press();
        const frames = recordFlip();
        verify(frames.length > 2, "the flip ran over several frames");
        for (const frame of frames) {
            verify(frame.displayShown !== (frame.clockOpacity === 1), `exactly one in sight at ${frame.phase}`);
            verify(frame.clockOpacity === 0 || frame.clockOpacity === 1, `clock whole or gone at ${frame.phase}`);
            compare(frame.displayOpacity, 1, `display whole at ${frame.phase}`);
        }
    }

    function test_the_display_stays_duration_level_after_a_key() {
        compare(hold.interval, Tokens.durationLevel);
        display.press();
        verify(display.shown);
        runOutHold();
        verify(!display.shown);
    }

    function test_a_second_key_only_extends_the_stay_without_a_new_flip() {
        showDisplay();
        hold.stop();
        display.press();
        compare(display.phase, 1);
        verify(!turning.running);
        verify(display.shown);
        verify(display.visible);
        runOutHold();
        verify(!display.shown);
    }

    function test_the_way_back_flips_the_display_away_first_then_the_clock_in() {
        showDisplay();
        runOutHold();
        tryCompare(turning, "running", true, 500);
        stopAt(0.25);
        compare(displayTurn().angle, -Tokens.flipAngle * tokenOut.valueForProgress(0.5));
        verify(display.visible);
        compare(clock.opacity, 0);
        stopAt(0.75);
        compare(clockTurn().angle, Tokens.flipAngle * (1 - tokenIn.valueForProgress(0.5)));
        compare(clock.opacity, 1);
        verify(!display.visible);
    }

    function test_on_no_frame_of_the_way_back_are_both_in_sight_and_nothing_fades() {
        showDisplay();
        runOutHold();
        tryCompare(turning, "running", true, 500);
        const frames = recordFlip();
        verify(frames.length > 2, "the flip ran over several frames");
        for (const frame of frames) {
            verify(frame.displayShown !== (frame.clockOpacity === 1), `exactly one in sight at ${frame.phase}`);
            verify(frame.clockOpacity === 0 || frame.clockOpacity === 1, `clock whole or gone at ${frame.phase}`);
            compare(frame.displayOpacity, 1, `display whole at ${frame.phase}`);
        }
    }

    function test_the_clock_is_whole_upright_and_the_display_gone_after_the_way_back() {
        showDisplay();
        runOutHold();
        tryCompare(turning, "running", true, 500);
        tryCompare(turning, "running", false, 1000);
        compare(clock.opacity, 1);
        compare(clockTurn().angle, 0);
        verify(!display.visible);
        verify(clock.enabled);
    }

    function test_a_key_during_the_way_back_brings_the_display_again_after_it() {
        showDisplay();
        runOutHold();
        tryCompare(turning, "running", true, 500);
        display.press();
        compare(display.toDisplay, false);
        tryCompare(display, "toDisplay", true, 1000);
        tryCompare(turning, "running", false, 1000);
        verify(display.visible);
        compare(clock.opacity, 0);
    }

    function test_the_clock_takes_no_clicks_while_the_display_stands_over_it() {
        display.press();
        verify(!clock.enabled);
    }

    function test_under_reduced_motion_the_clock_and_the_display_change_at_once() {
        Prefs.motion = "off";
        display.press();
        verify(!turning.running);
        compare(clock.opacity, 0);
        verify(display.visible);
        compare(display.opacity, 1);
        compare(displayTurn().angle, 0);
        verify(display.shown);
    }

    function test_under_reduced_motion_the_display_still_stays_duration_level_and_goes_at_once() {
        Prefs.motion = "off";
        display.press();
        compare(hold.interval, Tokens.durationLevel);
        verify(display.shown);
        runOutHold();
        verify(!turning.running);
        compare(clock.opacity, 1);
        compare(clockTurn().angle, 0);
        verify(!display.visible);
    }

    function saidWords(): var {
        return said.signalArguments.map(args => args[0]);
    }

    function test_a_key_itself_announces_nothing_as_its_value_comes_after_it() {
        display.press();
        compare(said.count, 0);
    }

    function test_news_while_the_display_shows_is_announced_politely_and_none_before_or_after() {
        display.say("lautstärke 80%");
        display.press();
        display.say("lautstärke 86%");
        compare(saidWords(), ["lautstärke 86%"]);
        compare(said.signalArguments[0][1], Accessible.Polite);
        runOutHold();
        display.say("lautstärke 45%");
        compare(said.count, 1);
    }

    function test_news_after_a_key_during_the_way_back_is_announced() {
        showDisplay();
        runOutHold();
        tryCompare(turning, "running", true, 500);
        display.press();
        display.say("lautstärke 86%");
        compare(saidWords(), ["lautstärke 86%"]);
    }

    function test_a_display_that_leaves_speaking_to_the_display_alone_announces_nothing() {
        display.speaks = false;
        display.press();
        display.say("lautstärke 86%");
        compare(said.count, 0);
    }

    function test_a_volume_key_then_a_microphone_key_announce_the_values_they_resulted_in_and_nothing_stale_or_mixed() {
        const readout = createTemporaryObject(readoutComponent, testCase);
        display.word = Qt.binding(() => readout.word);
        display.valueText = Qt.binding(() => readout.valueText);
        readout.pressed.connect(display.press);
        readout.news.connect(display.say);
        readout.shortcutPressed("kmix", "increase_volume");
        readout.volume = 0.86;
        tryCompare(said, "count", 1);
        readout.shortcutPressed("kmix", "mic_mute");
        readout.micMuted = true;
        tryCompare(said, "count", 2);
        compare(saidWords(), ["lautstärke 86%", "mikrofon stumm"]);
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
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
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

                    AppBarButton { icon: "window"; text: "back" }
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
