pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Readout
import Rekta
import "ContactSheets.js" as ContactSheets
import "ReadoutLine.js" as ReadoutLine

TestCase {
    id: testCase

    name: "Display"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    // As wide as the contact sheet's widest bar.
    width: 1920
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
                centreReserve: appDisplay.room

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
                    icon: "speaker"
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

    // PipeWire tells a value in an event of its own, after the key's: lets the events pending until now run.
    function nextEvent() {
        wait(0);
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
        nextEvent();
        readout.volume = 0.86;
        tryCompare(said, "count", 1);
        readout.shortcutPressed("kmix", "mic_mute");
        nextEvent();
        readout.micMuted = true;
        tryCompare(said, "count", 2);
        compare(saidWords(), ["lautstärke 86%", "mikrofon stumm"]);
    }

    function test_the_word_is_said_with_the_value_but_never_shown() {
        const readout = createTemporaryObject(readoutComponent, testCase);
        display.word = Qt.binding(() => readout.word);
        display.icon = Qt.binding(() => readout.icon);
        display.level = Qt.binding(() => readout.level);
        display.valueText = Qt.binding(() => readout.valueText);
        readout.pressed.connect(display.press);
        readout.news.connect(display.say);
        readout.shortcutPressed("kmix", "increase_volume");
        nextEvent();
        readout.volume = 0.86;
        tryCompare(said, "count", 1);
        compare(saidWords(), ["lautstärke 86%"]);
        compare(display.Accessible.name, "lautstärke 86%");
        tryCompare(display, "displayStands", true, 2000);
        compare(ReadoutLine.shownTexts(display), ["86%"]);
        compare(findChild(display, "icon").name, "speaker");
    }

    function test_the_line_holds_the_icon_the_meter_and_the_value_space_s_apart_as_wide_as_they_are() {
        Prefs.motion = "off";
        display.press();
        const parts = ReadoutLine.verify(testCase, face(), Tokens, Geometry, zeroIn(findChild(display, "value")));
        compare(display.width, face().implicitWidth);
        compare(display.height, Geometry.appBarControl);
        compare(face().height, Geometry.appBarControl);
        tryCompare(findChild(parts.meter, "fill"), "width", Tokens.tileUnit * 0.81);
    }

    function test_without_a_level_only_the_icon_and_the_value_stand_and_a_short_value_keeps_4ch() {
        Prefs.motion = "off";
        display.level = -1;
        display.icon = "edit";
        display.valueText = "de";
        display.press();
        const parts = ReadoutLine.verify(testCase, face(), Tokens, Geometry, zeroIn(findChild(display, "value")));
        const zero = zeroIn(parts.value);
        verify(parts.value.implicitWidth < 4 * zero);
        compare(parts.value.width, 4 * zero);
        display.valueText = "English (US)";
        ReadoutLine.verify(testCase, face(), Tokens, Geometry, zero);
        verify(parts.value.width > 4 * zero);
        compare(display.width, face().implicitWidth);
    }

    function test_the_display_stands_centred_over_the_clock() {
        Prefs.motion = "off";
        display.press();
        compare(display.x + display.width / 2, clock.x + clock.width / 2);
        compare(display.y + display.height / 2, clock.y + clock.height / 2);
    }

    function test_while_the_clock_stands_its_neighbours_keep_only_its_own_width_free() {
        compare(display.room, 0);
        compare(middleEnd(), Math.round(scene.bar.width / 2 - clock.implicitWidth / 2 - scene.bar.gap));
    }

    function test_the_display_takes_its_room_halfway_through_its_flip_and_only_the_edge_towards_it_glides_aside() {
        Prefs.motion = "on";
        const end = middleEnd();
        const start = scene.middle.x;
        const clockX = clock.x;
        const trailing = scene.after.x;
        verify(display.implicitWidth > clock.implicitWidth, "the display is wider than the clock");
        display.press();
        stopAt(0.49);
        compare(display.room, 0);
        verify(!scene.bar.gliding);
        display.phase = 0.5;
        compare(display.room, display.implicitWidth);
        verify(scene.bar.gliding, "the neighbours glide");
        compare(middleEnd(), end, "from where they stood");
        compare(scene.bar.reflow.run.duration, Tokens.durationModerate);
        compare(scene.bar.reflow.run.easing.bezierCurve, Tokens.easeBase);
        tryCompare(scene.bar, "gliding", false, 2000);
        compare(middleEnd(), Math.round(scene.bar.width / 2 - display.implicitWidth / 2 - scene.bar.gap));
        compare(scene.middle.x, start, "the far edge stays");
        compare(clock.x, clockX, "the clock stays");
        compare(scene.after.x, trailing, "a control packed at the far end stays");
    }

    function test_the_display_gives_its_room_back_halfway_through_the_way_back_and_the_neighbours_glide_back() {
        Prefs.motion = "on";
        const end = middleEnd();
        showDisplay();
        tryCompare(scene.bar, "gliding", false, 2000);
        const aside = middleEnd();
        verify(aside < end);
        runOutHold();
        stopAt(0.49);
        compare(display.room, display.implicitWidth);
        verify(!scene.bar.gliding);
        display.phase = 0.5;
        compare(display.room, 0);
        verify(scene.bar.gliding, "the neighbours glide back");
        compare(middleEnd(), aside, "from where they stood");
        tryCompare(scene.bar, "gliding", false, 2000);
        compare(middleEnd(), end);
    }

    function test_under_reduced_motion_the_neighbours_make_room_at_once() {
        Prefs.motion = "off";
        display.press();
        verify(!scene.bar.gliding);
        compare(middleEnd(), Math.round(scene.bar.width / 2 - display.implicitWidth / 2 - scene.bar.gap));
    }

    function face(): var {
        return findChild(display, "icon").parent;
    }

    function middleEnd(): real {
        return scene.middle.x + scene.middle.width;
    }

    function zeroIn(value: var): real {
        zeroMetrics.font = value.font;
        return zeroMetrics.advanceWidth;
    }

    TextMetrics {
        id: zeroMetrics

        text: "0"
    }

    function test_contact_sheet() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            Prefs.motion = "off";
            const sheet = createTemporaryObject(sheetComponent, testCase);
            const displays = allNamed(sheet, "display");
            displays.forEach(display => findChild(display, "hold").interval = 60000);
            displays.forEach(display => display.press());
            tryVerify(() => displays.every(display => display.displayStands && display.phase === 1));
            waitForRendering(sheet);
            grabImage(sheet).save(`display-sheet-${theme}.png`);
        }
    }

    function allNamed(item: Item, name: string): var {
        return Array.from(item.children).reduce((found, child) => found.concat(child.objectName === name ? [child] : allNamed(child, name)), []);
    }

    // The bar at 1920 px with each of the four values standing in place of the clock, then a dense bar at 1280 px:
    // two status words, "im hintergrund 3" and "meldungen 12" around the volume.
    Component {
        id: sheetComponent

        Rectangle {
            id: sheet

            readonly property var shown: [
                { word: "lautstärke", icon: "speaker", level: 0.6, valueText: "60%" },
                { word: "mikrofon", icon: "microphone-muted", level: 0, valueText: "stumm" },
                { word: "helligkeit", icon: "theme", level: 0.35, valueText: "35%" },
                { word: "tastatur", icon: "edit", level: -1, valueText: "de" }
            ]

            width: 1920
            height: 5 * (Tokens.appbarHeight + 20) + 20
            color: Tokens.color.bg

            Repeater {
                model: sheet.shown

                delegate: AppBar {
                    id: row

                    required property var modelData
                    required property int index

                    y: 20 + index * (Tokens.appbarHeight + 20)
                    width: sheet.width
                    area: Qt.size(width, 1080)
                    centre: rowClock
                    centreReserve: rowDisplay.room

                    AppBarButton { icon: "window"; text: "back" }
                    AppBarMiddle { parts: ["konsole", "~/projects: build the shell"] }

                    AppBarClock {
                        id: rowClock

                        locale: Qt.locale("de_DE")
                        now: new Date(2026, 9, 21, 14, 32)
                    }

                    AppBarDisplay {
                        id: rowDisplay

                        objectName: "display"
                        replaces: rowClock
                        word: row.modelData.word
                        icon: row.modelData.icon
                        level: row.modelData.level
                        valueText: row.modelData.valueText
                    }

                    AppBarButton { icon: "bell"; text: "meldungen" }
                }
            }

            AppBar {
                y: 20 + 4 * (Tokens.appbarHeight + 20)
                width: 1280
                area: Qt.size(width, 800)
                centre: denseClock
                centreReserve: denseDisplay.room

                AppBarStatus {
                    keys: ["muted", "doNotDisturb", "more"]
                    words: [
                        { key: "muted", word: "stumm", status: "", opens: "sound", name: "stumm" },
                        { key: "doNotDisturb", word: "nicht stören", status: "", opens: "doNotDisturb", name: "nicht stören" }
                    ]
                }

                AppBarMiddle { parts: ["konsole", "~/projects: build the shell"] }

                AppBarClock {
                    id: denseClock

                    locale: Qt.locale("de_DE")
                    now: new Date(2026, 9, 21, 14, 32)
                }

                AppBarDisplay {
                    id: denseDisplay

                    objectName: "display"
                    replaces: denseClock
                    word: "lautstärke"
                    icon: "speaker"
                    level: 0.6
                    valueText: "60%"
                }

                AppBarButton { icon: "window"; text: "im hintergrund"; count: 3; priority: 0 }
                AppBarButton { icon: "bell"; text: "meldungen"; count: 12; priority: 2 }
                AppBarButton { icon: "tune"; text: "steuerung"; priority: 1 }
            }
        }
    }
}
