pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Start

// A finger swiping up from the bottom edge of the primary screen opens the Start, the whole opening following it: KWin's
// fade-back tells how far up the finger is (StartSurface hands it on), and the Start tells KWin where its windows stand.
TestCase {
    id: testCase

    name: "StartSwipe"
    visible: true
    when: windowShown
    width: 1600
    height: 900

    // What the fake windows were asked to do.
    property var calls: []
    // The finger's way to the whole opening: half the screen's height.
    readonly property real wholeWay: height / 2

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
            windows: [testCase.fakeWindow("konsole", true)]
            pinned: [testCase.fakeApp("systemsettings"), testCase.fakeApp("dolphin"), testCase.fakeApp("konsole")]
        }
    }

    SignalSpy {
        id: windowsSpy

        signalName: "windowsAt"
    }

    SignalSpy {
        id: keyboardSpy

        signalName: "holdsKeyboardChanged"
    }

    SignalSpy {
        id: closedSpy

        signalName: "closed"
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
        for (const spy of [windowsSpy, keyboardSpy, closedSpy]) {
            spy.target = made;
            spy.clear();
        }
        return made;
    }

    function named(name: string): var {
        return findChild(start, name);
    }

    // The windows three quarters back, when the parts start to turn in.
    function partsWait(): real {
        return named("waitForWindows").interval;
    }

    function lastLanding(turns: var): real {
        return Math.max(...turns.map(turn => turn.at + turn.duration));
    }

    function lastToldWindows(): var {
        return Array.from(windowsSpy.signalArguments[windowsSpy.count - 1]);
    }

    function rotationOf(item: Item): var {
        return Array.from(item.transform).find(transform => (transform as Rotation) !== null) ?? null;
    }

    // The finger as far up as puts the opening at `time`.
    function fingerAt(time: real) {
        start.followFinger(time / start.openingTime * wholeWay);
    }

    // Every place the opening stands at from now on.
    function watchTimes(): var {
        const seen = [];
        start.openingAtChanged.connect(() => seen.push({
                at: start.openingAt,
                held: turner.turning.length
            }));
        return seen;
    }

    function test_half_the_screen_s_height_up_is_the_whole_opening_and_a_quarter_up_is_halfway() {
        start.followFinger(wholeWay / 2);
        compare(start.phase, "following");
        verify(start.openingTime > partsWait());
        fuzzyCompare(start.openingAt, start.openingTime / 2, 1e-6);
        fuzzyCompare(turner.elapsed, Math.max(0, start.openingTime / 2 - partsWait()), 1e-6);
        compare(lastToldWindows(), [start.openingAt, 0], "KWin holds the windows, and with them the glass, there");
        wait(60);
        fuzzyCompare(turner.elapsed, Math.max(0, start.openingTime / 2 - partsWait()), 1e-6, "it stays with the finger");
        start.followFinger(wholeWay);
        compare(start.openingAt, start.openingTime);
        compare(turner.elapsed, start.openingTime - partsWait());
        verify(!start.holdsKeyboard, "the window under the finger keeps the keyboard");
    }

    function test_the_opening_a_finger_takes_along_has_the_times_and_parts_of_the_one_meta_plays() {
        start.open();
        tryVerify(() => turner.running, 2000);
        turner.paused = true;
        const meta = turner.arrivingTurns.map(turn => [turn.part.item.objectName, turn.at, turn.duration, turn.originY]);
        const metaTime = partsWait() + lastLanding(turner.arrivingTurns);
        turner.finish();
        start = makeStart();
        start.followFinger(1);
        compare(turner.arrivingTurns.map(turn => [turn.part.item.objectName, turn.at, turn.duration, turn.originY]), meta);
        compare(start.openingTime, metaTime);
        compare(turner.edge, "bottom");
    }

    function test_drawn_back_the_finger_takes_the_opening_back_and_no_part_is_let_go_on_the_way() {
        start.followFinger(wholeWay);
        const parts = turner.arrivingTurns.length;
        compare(turner.turning.length, parts, "landed, every part is still held");
        const first = turner.arrivingTurns[0];
        fingerAt(partsWait() + first.at + first.duration / 2);
        const angle = rotationOf(first.part.item).angle;
        verify(angle > 0 && angle < Tokens.turnstileInAngle, `halfway in again: ${angle}`);
        fingerAt(0);
        compare(turner.turning.length, parts);
        compare(rotationOf(first.part.item).angle, Tokens.turnstileInAngle);
        compare(first.part.item.opacity, 0);
    }

    function test_past_half_the_screen_and_below_where_it_set_down_the_finger_holds_the_opening_at_its_ends() {
        start.followFinger(3 * wholeWay);
        compare(start.openingAt, start.openingTime);
        start.followFinger(-40);
        compare(start.openingAt, 0);
        compare(lastToldWindows(), [0, 0]);
        compare(start.phase, "following");
    }

    function test_let_go_past_half_its_way_the_opening_goes_on_from_there_in_its_own_times_then_the_start_has_the_keyboard() {
        start.followFinger(wholeWay * 0.75);
        const from = start.openingAt;
        const seen = watchTimes();
        const letGo = Date.now();
        start.letFingerGo();
        compare(lastToldWindows(), [from, 1], "KWin's windows go on from there");
        verify(start.holdsKeyboard, "it takes the keyboard as Meta's opening does");
        tryCompare(start, "phase", "open", 2000);
        const took = Date.now() - letGo;
        verify(seen.length > 0);
        verify(seen.every(moment => moment.at >= from), "no new run-up");
        verify(took < 0.75 * start.openingTime, `the last quarter, not all of it: ${took} ms of ${start.openingTime}`);
        verify(!turner.running);
        compare(rotationOf(turner.arrivingTurns[0].part.item), null, "the parts are let go once landed");
        verify(start.holdsKeyboard);
    }

    function test_let_go_short_of_half_its_way_the_opening_runs_back_to_nothing_and_the_window_keeps_the_keyboard() {
        start.followFinger(wholeWay * 0.4);
        const from = start.openingAt;
        const parts = turner.arrivingTurns.length;
        const seen = watchTimes();
        const letGo = Date.now();
        start.letFingerGo();
        compare(start.phase, "returning");
        compare(lastToldWindows(), [from, -1], "KWin's windows run back the same way");
        tryCompare(start, "phase", "closed", 2000);
        const took = Date.now() - letGo;
        verify(seen.length > 1);
        for (let i = 1; i < seen.length; i++)
            verify(seen[i].at <= seen[i - 1].at, "only ever back");
        verify(seen.slice(0, -1).every(moment => moment.held === parts), "not one part let go before the end");
        verify(took < from + 200, `in the time it had come: ${took} ms for ${from}`);
        compare(keyboardSpy.count, 0, "the Start never asked for the keyboard");
        compare(calls, [], "and gave no window the keyboard");
        verify(!named("body").visible);
        verify(!named("glass").visible);
        compare(closedSpy.count, 1);
    }

    function test_the_finger_decides_at_half_its_way() {
        start.followFinger(wholeWay * 0.49);
        start.letFingerGo();
        compare(start.phase, "returning");
        tryCompare(start, "phase", "closed", 2000);
        start.followFinger(wholeWay * 0.5);
        start.letFingerGo();
        compare(start.phase, "opening");
    }

    function test_meta_while_the_finger_holds_the_opening_opens_it_all_from_there() {
        start.followFinger(wholeWay * 0.3);
        const from = start.openingAt;
        start.toggle();
        compare(start.phase, "opening");
        compare(lastToldWindows(), [from, 1]);
        tryCompare(start, "phase", "open", 2000);
        const told = windowsSpy.count;
        start.letFingerGo();
        compare(start.phase, "open", "the finger letting go afterwards changes nothing");
        compare(windowsSpy.count, told);
    }

    function test_meta_while_the_opening_runs_back_opens_it_all_from_where_it_is() {
        start.followFinger(wholeWay * 0.45);
        start.letFingerGo();
        wait(30);
        const at = start.openingAt;
        start.toggle();
        compare(start.phase, "opening");
        compare(lastToldWindows(), [at, 1]);
        tryCompare(start, "phase", "open", 2000);
    }

    function test_meta_while_the_let_go_opening_goes_on_closes_the_start_back_as_ever() {
        start.followFinger(wholeWay * 0.6);
        start.letFingerGo();
        wait(30);
        start.toggle();
        compare(start.phase, "closing");
        verify(turner.back);
        verify(!turner.paused);
        tryCompare(start, "phase", "closed", 3000);
    }

    function test_after_running_back_meta_opens_the_start_as_ever() {
        start.followFinger(wholeWay * 0.2);
        start.letFingerGo();
        tryCompare(start, "phase", "closed", 2000);
        start.open();
        tryCompare(start, "phase", "open", 3000);
        verify(!turner.paused);
    }

    function test_a_finger_on_the_bottom_edge_of_the_open_start_does_not_move_it() {
        Prefs.motion = "off";
        start.open();
        Prefs.motion = "on";
        start.followFinger(wholeWay * 0.8);
        start.letFingerGo();
        compare(start.phase, "open");
        compare(windowsSpy.count, 0);
    }

    function test_under_reduced_motion_nothing_follows_the_finger_and_let_go_past_half_the_start_stands_open_with_the_keyboard() {
        Prefs.motion = "off";
        start.followFinger(wholeWay * 0.8);
        compare(start.phase, "closed");
        verify(!named("body").visible);
        compare(windowsSpy.count, 0);
        start.letFingerGo();
        compare(start.phase, "open");
        verify(named("body").visible);
        verify(start.holdsKeyboard);
    }

    // Under a full-screen window the Start's surface maps only as the finger comes, and has no size before its first
    // configure.
    function test_the_parts_are_planned_once_the_start_has_its_size_and_then_stand_where_the_finger_is() {
        start.width = 0;
        start.followFinger(wholeWay / 2);
        compare(start.phase, "following", "the surface shows");
        verify(!turner.running);
        compare(windowsSpy.count, 0);
        start.width = testCase.width;
        verify(turner.running);
        verify(turner.arrivingTurns.length > 0);
        fuzzyCompare(start.openingAt, start.openingTime / 2, 1e-6);
        compare(lastToldWindows(), [start.openingAt, 0]);
    }

    function test_let_go_past_half_before_the_start_had_its_size_it_opens_as_meta_opens_it() {
        start.width = 0;
        start.followFinger(wholeWay * 0.8);
        start.letFingerGo();
        compare(start.phase, "opening");
        verify(named("waitForWindows").running, "the parts wait for the windows, as after Meta");
        verify(start.holdsKeyboard);
        start.width = testCase.width;
        tryCompare(start, "phase", "open", 3000);
    }

    function test_let_go_short_of_half_before_the_start_had_its_size_it_goes_again() {
        start.width = 0;
        start.followFinger(wholeWay * 0.3);
        start.letFingerGo();
        compare(start.phase, "closed");
        compare(keyboardSpy.count, 0);
        compare(windowsSpy.count, 0);
    }

    function test_under_reduced_motion_let_go_short_of_half_nothing_happens() {
        Prefs.motion = "off";
        start.followFinger(wholeWay * 0.45);
        start.letFingerGo();
        compare(start.phase, "closed");
        compare(keyboardSpy.count, 0);
        compare(windowsSpy.count, 0);
    }
}
