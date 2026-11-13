pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Start

// Three fingers on the touchpad open and close the Start as a finger on the screen does: KWin's fade-back tells how far
// of its whole swipe they have come, up or down, and when they let go (StartSurface hands it on). Up opens the closed
// Start, down closes the open one, the whole motion following them; past half their way it goes on, short of it it
// runs back.
TestCase {
    id: testCase

    name: "StartTouchpad"
    visible: true
    when: windowShown
    width: 1600
    height: 900

    // What the fake windows were asked to do.
    property var calls: []

    function fakeApp(name: string): var {
        return {
            id: `org.example.${name}`,
            name: name,
            icon: "",
            columns: 1,
            rows: 1,
            launch: () => {}
        };
    }

    function fakeWindow(title: string, active: bool): var {
        return {
            title: title,
            icon: "",
            lastActivated: 1,
            stackingOrder: 0,
            active: active,
            minimized: false,
            activate: () => testCase.calls = [...testCase.calls, `activate ${title}`]
        };
    }

    Component {
        id: startComponent

        StartPlace {
            width: testCase.width
            height: testCase.height
            windows: [testCase.fakeWindow("konsole", true), testCase.fakeWindow("dolphin", false)]
            pinned: [testCase.fakeApp("systemsettings"), testCase.fakeApp("dolphin"), testCase.fakeApp("konsole")]
            showRecent: false
        }
    }

    SignalSpy {
        id: windowsInSpy

        signalName: "windowsAt"
    }

    SignalSpy {
        id: windowsOutSpy

        signalName: "windowsOutAt"
    }

    SignalSpy {
        id: keyboardSpy

        signalName: "holdsKeyboardChanged"
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var start
    property var turner

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "on";
        calls = [];
        start = makeStart();
    }

    function cleanup() {
        turner.finish();
        Prefs.motion = "system";
    }

    function makeStart(): var {
        const made = createTemporaryObject(startComponent, testCase);
        turner = findChild(made, "turn");
        watch(made);
        return made;
    }

    function watch(made: var) {
        for (const spy of [windowsInSpy, windowsOutSpy, keyboardSpy]) {
            spy.target = made;
            spy.clear();
        }
    }

    // The Start open and landed, as Meta leaves it.
    function openAtOnce() {
        Prefs.motion = "off";
        start.open();
        Prefs.motion = "on";
        compare(start.phase, "open");
        waitForRendering(start);
        watch(start);
    }

    function named(name: string): var {
        return findChild(start, name);
    }

    function lastTold(spy: SignalSpy): var {
        return Array.from(spy.signalArguments[spy.count - 1]);
    }

    function test_three_fingers_up_hold_the_opening_where_a_finger_on_the_screen_as_far_of_its_way_holds_it() {
        start.followFinger(0.3 * start.screenHeight / 2);
        const byFinger = start.openingAt;
        turner.finish();
        start = makeStart();
        start.followSwipe(0.3);
        compare(start.phase, "following");
        fuzzyCompare(start.openingAt, byFinger, 1e-6);
        fuzzyCompare(start.openingAt, 0.3 * start.openingTime, 1e-6);
        compare(lastTold(windowsInSpy), [start.openingAt, 0], "KWin holds the windows, and with them the glass, there");
        start.followSwipe(1);
        compare(start.openingAt, start.openingTime, "KWin's whole swipe is the whole opening");
        start.followSwipe(0.1);
        fuzzyCompare(start.openingAt, 0.1 * start.openingTime, 1e-6, "drawn back, it takes the opening back");
        verify(!start.holdsKeyboard, "the window keeps the keyboard while the fingers hold the opening");
    }

    function test_let_go_at_half_their_way_the_opening_goes_on_from_there_and_the_start_takes_the_keyboard() {
        start.followSwipe(0.5);
        const from = start.openingAt;
        start.letFingerGo();
        compare(start.phase, "opening");
        compare(lastTold(windowsInSpy), [from, 1], "KWin's windows go on from there");
        verify(start.holdsKeyboard);
        tryCompare(start, "phase", "open", 2000);
        verify(!turner.running);
    }

    function test_let_go_short_of_half_their_way_the_opening_runs_back_to_nothing_and_the_window_keeps_the_keyboard() {
        start.followSwipe(0.49);
        const from = start.openingAt;
        start.letFingerGo();
        compare(start.phase, "returning");
        compare(lastTold(windowsInSpy), [from, -1], "KWin's windows run back the same way");
        tryCompare(start, "phase", "closed", 2000);
        compare(keyboardSpy.count, 0, "the Start never asked for the keyboard");
        compare(calls, []);
        verify(!named("body").visible);
    }

    function test_three_fingers_up_over_the_open_start_do_nothing() {
        openAtOnce();
        start.followSwipe(0.8);
        start.letFingerGo();
        compare(start.phase, "open");
        compare(windowsInSpy.count, 0);
        compare(windowsOutSpy.count, 0);
        compare(keyboardSpy.count, 0);
    }

    function test_three_fingers_down_hold_the_closing_back_at_their_progress_with_the_keyboard_kept() {
        openAtOnce();
        start.followSwipeOut(0.25);
        compare(start.phase, "followingOut");
        fuzzyCompare(start.closingAt, 0.25 * start.closingTime, 1e-6);
        fuzzyCompare(turner.elapsed, Math.min(start.closingAt, turner.handOverAt), 1e-6);
        compare(lastTold(windowsOutSpy), [Math.max(0, start.closingAt - turner.handOverAt), 0]);
        start.followSwipeOut(1);
        compare(start.closingAt, start.closingTime, "KWin's whole swipe is the whole closing");
        verify(start.holdsKeyboard);
        compare(keyboardSpy.count, 0);
    }

    function test_let_go_at_half_their_way_down_the_closing_goes_on_and_the_window_gets_the_keyboard_back() {
        openAtOnce();
        start.followSwipeOut(0.5);
        start.letFingerGoOut();
        compare(start.phase, "closing");
        tryCompare(start, "phase", "closed", 2000);
        compare(calls, ["activate konsole"]);
        verify(!named("body").visible);
    }

    function test_let_go_short_of_half_their_way_down_the_closing_runs_back_and_the_start_stays_open() {
        openAtOnce();
        start.followSwipeOut(0.49);
        start.letFingerGoOut();
        compare(start.phase, "returningIn");
        compare(lastTold(windowsOutSpy)[1], -1, "KWin's windows run back the same way");
        tryCompare(start, "phase", "open", 2000);
        verify(start.holdsKeyboard);
        compare(keyboardSpy.count, 0);
        compare(calls, []);
    }

    function test_three_fingers_down_over_the_closed_start_do_nothing() {
        start.followSwipeOut(0.8);
        start.letFingerGoOut();
        compare(start.phase, "closed");
        compare(windowsInSpy.count, 0);
        compare(windowsOutSpy.count, 0);
        compare(keyboardSpy.count, 0);
    }

    function test_under_reduced_motion_nothing_follows_three_fingers_up_and_let_go_at_half_the_start_stands_open() {
        Prefs.motion = "off";
        start.followSwipe(0.8);
        compare(start.phase, "closed");
        compare(windowsInSpy.count, 0);
        start.letFingerGo();
        compare(start.phase, "open");
        verify(named("body").visible);
        verify(start.holdsKeyboard);
    }

    function test_under_reduced_motion_three_fingers_up_let_go_short_of_half_do_nothing() {
        Prefs.motion = "off";
        start.followSwipe(0.45);
        start.letFingerGo();
        compare(start.phase, "closed");
        compare(keyboardSpy.count, 0);
    }

    function test_under_reduced_motion_nothing_follows_three_fingers_down_and_let_go_at_half_the_start_is_closed() {
        openAtOnce();
        Prefs.motion = "off";
        start.followSwipeOut(0.8);
        compare(start.phase, "open");
        compare(named("body").opacity, 1);
        compare(windowsOutSpy.count, 0);
        start.letFingerGoOut();
        compare(start.phase, "closed");
        compare(calls, ["activate konsole"]);
    }

    function test_under_reduced_motion_three_fingers_down_let_go_short_of_half_leave_the_start_open() {
        openAtOnce();
        Prefs.motion = "off";
        start.followSwipeOut(0.45);
        start.letFingerGoOut();
        compare(start.phase, "open");
        compare(keyboardSpy.count, 0);
        compare(calls, []);
    }
}
