pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Start

// A finger drawing down over the open Start closes it back, the whole closing following it as Escape plays it: past
// half its way it goes on and the window that had the keyboard gets it back, short of it the Start opens again. Touch
// only, and only where no scroller, place change or tile has the gesture.
TestCase {
    id: testCase

    name: "StartDrawDown"
    visible: true
    when: windowShown
    width: 1600
    height: 900

    // What the fake windows and apps were asked to do.
    property var calls: []
    // The finger's way to the whole closing: half the screen's height.
    readonly property real wholeWay: start?.screenHeight / 2

    function fakeApp(name: string): var {
        return {
            id: `org.example.${name}`,
            name: name,
            icon: "",
            columns: 1,
            rows: 1,
            launch: () => testCase.calls = [...testCase.calls, `launch ${name}`]
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

    function fakeApps(count: int): var {
        return Array.from({
            length: count
        }, (_, k) => fakeApp(`app${k}`));
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
        calls = [];
        start = makeStart({});
    }

    function cleanup() {
        turner.finish();
        Prefs.motion = "system";
    }

    // An open Start, landed, in place of the one before; `properties` set before it opens.
    function makeStart(properties: var): var {
        start?.destroy();
        Prefs.motion = "off";
        const made = createTemporaryObject(startComponent, testCase, properties);
        turner = findChild(made, "turn");
        made.open();
        Prefs.motion = "on";
        waitForRendering(made);
        for (const spy of [windowsSpy, keyboardSpy]) {
            spy.target = made;
            spy.clear();
        }
        return made;
    }

    function named(name: string): var {
        return findChild(start, name);
    }

    function lastToldWindows(): var {
        return Array.from(windowsSpy.signalArguments[windowsSpy.count - 1]);
    }

    function rotationOf(item: Item): var {
        return Array.from(item.transform).find(transform => (transform as Rotation) !== null) ?? null;
    }

    // A finger set down at (x, y) and moved by (dx, dy) in ten steps; returns its letting go.
    function draw(x: real, y: real, dx: real, dy: real): var {
        const touch = touchEvent(start);
        touch.press(0, start, x, y).commit();
        // Qt Quick holds back a touch move that comes before the frame it waits for and hands it over with that frame, so
        // each step waits for one: a scroller takes the first step past its threshold as its start.
        for (let step = 1; step <= 10; ++step) {
            touch.move(0, start, x + dx * step / 10, y + dy * step / 10).commit();
            start.Window.window.update();
            waitForRendering(start);
        }
        return {
            to: (toX, toY) => {
                touch.move(0, start, toX, toY).commit();
                start.Window.window.update();
                waitForRendering(start);
            },
            letGo: () => touch.release(0, start, x + dx, y + dy).commit()
        };
    }

    // The same by mouse.
    function drawByMouse(x: real, y: real, dy: real) {
        mousePress(start, x, y);
        for (let step = 1; step <= 10; ++step)
            mouseMove(start, x, y + dy * step / 10);
        mouseRelease(start, x, y + dy);
    }

    // The middle of the empty glass below the tiles, where nothing scrolls.
    function glassX(): real {
        return start.width / 2;
    }

    function glassY(): real {
        return start.height * 0.75;
    }

    // The time Escape's closing back has its parts gone.
    function handOver(): real {
        return turner.handOverAt;
    }

    function drawnTo(share: real): var {
        return draw(glassX(), 40, 0, share * wholeWay);
    }

    // The closing where the finger has it now: its way down over the whole way, times the closing's time.
    function closingAtFinger(): real {
        return Math.min(1, named("drawDown").activeTranslation.y / wholeWay) * start.closingTime;
    }

    function test_the_closing_a_finger_takes_along_has_the_parts_and_times_of_the_one_escape_plays() {
        start.close(null);
        turner.paused = true;
        const escape = turner.leavingTurns.map(turn => [turn.part.item.objectName, turn.at, turn.duration, turn.originY]);
        const escapeTime = turner.handOverAt + named("glassOut").interval;
        turner.finish();
        start = makeStart({});
        const finger = drawnTo(0.1);
        compare(start.phase, "followingOut");
        compare(turner.leavingTurns.map(turn => [turn.part.item.objectName, turn.at, turn.duration, turn.originY]), escape);
        compare(start.closingTime, escapeTime);
        verify(turner.back, "back, the way it came");
        compare(turner.edge, "bottom");
        finger.letGo();
    }

    function test_a_finger_drawn_down_holds_the_closing_at_its_way_over_half_the_screen_and_drawn_back_takes_it_back() {
        const finger = drawnTo(0.25);
        compare(start.phase, "followingOut");
        const quarter = closingAtFinger();
        fuzzyCompare(quarter, start.closingTime / 4, start.closingTime / wholeWay, "a quarter of the way is a quarter of the time");
        fuzzyCompare(start.closingAt, quarter, 1e-6);
        fuzzyCompare(turner.elapsed, Math.min(quarter, handOver()), 1e-6);
        compare(lastToldWindows(), [Math.max(0, start.closingAt - handOver()), 0], "KWin holds the windows, and the glass, there");
        verify(start.holdsKeyboard);
        compare(keyboardSpy.count, 0);
        wait(60);
        fuzzyCompare(start.closingAt, quarter, 1e-6, "it stays with the finger");
        finger.to(glassX(), 40 + wholeWay * 1.2);
        compare(start.closingAt, start.closingTime, "held at its end past half the screen");
        compare(named("body").opacity, 0, "the parts are gone as after Escape's hand-over");
        compare(lastToldWindows(), [start.closingTime - handOver(), 0]);
        const parts = turner.leavingTurns.length;
        finger.to(glassX(), 40);
        compare(start.closingAt, 0);
        compare(named("body").opacity, 1);
        compare(turner.turning.length, parts, "no part let go on the way");
        const first = turner.leavingTurns[0].part.item;
        compare(rotationOf(first).angle, 0);
        compare(first.opacity, 1);
        compare(lastToldWindows(), [0, 0]);
        finger.letGo();
    }

    function test_let_go_past_half_its_way_the_closing_goes_on_in_its_own_times_and_the_window_gets_the_keyboard_back() {
        const finger = drawnTo(0.75);
        const from = start.closingAt;
        const letGo = Date.now();
        finger.letGo();
        compare(start.phase, "closing");
        if (from >= handOver()) {
            compare(lastToldWindows(), [from - handOver(), 1], "KWin's windows go on from there");
            verify(!start.holdsKeyboard, "the glass goes from there");
        }
        tryCompare(start, "phase", "closed", 2000);
        const took = Date.now() - letGo;
        verify(took < start.closingTime - from + 200, `the rest of its way, not all of it: ${took} ms for ${start.closingTime - from}`);
        compare(calls, ["activate konsole"]);
        verify(!named("body").visible);
        compare(named("body").opacity, 1, "whole again for the next opening");
    }

    function test_let_go_past_half_before_the_hand_over_the_parts_turn_out_on_and_from_there_windows_and_glass_come() {
        const finger = drawnTo(0.505);
        if (start.closingAt >= handOver())
            skip("the hand-over comes before half the way");
        const told = windowsSpy.count;
        finger.letGo();
        compare(start.phase, "closing");
        verify(start.holdsKeyboard, "the parts still turn out, the windows wait");
        compare(windowsSpy.count, told);
        tryVerify(() => !start.holdsKeyboard, 1000);
        const [time, pace] = lastToldWindows();
        compare(pace, 1);
        verify(time < 50, `the windows set off at the hand-over: ${time}`);
        fuzzyCompare(named("glassOut").interval, FadeBack.duration - time, 1, "the glass goes with them");
        tryCompare(start, "phase", "closed", 2000);
        compare(calls, ["activate konsole"]);
    }

    function test_let_go_short_of_half_the_same_way_runs_back_and_the_start_stands_open_with_its_keyboard_and_focus() {
        const tile = start.pinTiles()[1];
        tile.forceActiveFocus();
        const finger = drawnTo(0.45);
        const from = start.closingAt;
        const seen = [];
        start.closingAtChanged.connect(() => seen.push(start.closingAt));
        const letGo = Date.now();
        finger.letGo();
        compare(start.phase, "returningIn");
        compare(lastToldWindows(), [Math.max(0, from - handOver()), -1], "KWin's windows run back the same way");
        tryCompare(start, "phase", "open", 2000);
        const took = Date.now() - letGo;
        verify(took < from + 200, `in the time it had come: ${took} ms for ${from}`);
        for (let i = 1; i < seen.length; i++)
            verify(seen[i] <= seen[i - 1], "only ever back");
        compare(keyboardSpy.count, 0, "the Start never let the keyboard go");
        compare(calls, []);
        verify(tile.activeFocus, "the focus is where it was");
        verify(named("body").visible);
        compare(named("body").opacity, 1);
        verify(!turner.running);
        compare(rotationOf(tile), null, "the parts are at rest");
        compare(lastToldWindows()[0], 0);
    }

    function test_the_finger_decides_at_half_its_way() {
        drawnTo(0.49).letGo();
        compare(start.phase, "returningIn");
        tryCompare(start, "phase", "open", 2000);
        drawnTo(0.5).letGo();
        compare(start.phase, "closing");
    }

    function test_meta_while_the_finger_holds_the_closing_closes_it_from_there() {
        const finger = drawnTo(0.3);
        start.toggle();
        compare(start.phase, "closing");
        tryCompare(start, "phase", "closed", 2000);
        compare(calls, ["activate konsole"]);
        finger.letGo();
        compare(start.phase, "closed", "the finger letting go afterwards changes nothing");
    }

    function test_a_finger_drawn_up_or_sideways_does_not_close() {
        draw(glassX(), glassY(), 0, -0.4 * wholeWay).letGo();
        compare(start.phase, "open", "up");
        compare(windowsSpy.count, 0);
        draw(glassX(), glassY(), -400, 120).letGo();
        compare(start.phase, "open", "mostly sideways");
        compare(named("pivot").currentIndex, 1, "goes to alle apps");
        compare(windowsSpy.count, 0);
    }

    function test_a_finger_that_sets_out_up_and_turns_down_does_not_close() {
        const finger = draw(glassX(), glassY(), 0, -60);
        finger.to(glassX(), glassY() + 0.6 * wholeWay);
        finger.letGo();
        compare(start.phase, "open");
    }

    function test_a_finger_drawn_down_from_a_tile_closes_and_never_starts_the_tile() {
        const tile = start.pinTiles()[0];
        const at = tile.mapToItem(start, tile.width / 2, tile.height / 2);
        draw(at.x, at.y, 0, 0.7 * wholeWay).letGo();
        compare(start.phase, "closing");
        tryCompare(start, "phase", "closed", 2000);
        compare(calls, ["activate konsole"]);
    }

    function test_a_mouse_drawn_down_never_closes() {
        drawByMouse(glassX(), 40, 0.8 * wholeWay);
        compare(start.phase, "open");
        compare(windowsSpy.count, 0);
        const tile = start.pinTiles()[0];
        const at = tile.mapToItem(start, tile.width / 2, tile.height / 2);
        drawByMouse(at.x, at.y, 0.8 * wholeWay);
        compare(start.phase, "open");
        compare(calls, [], "and a drag by mouse never starts the tile either");
    }

    function test_nothing_closes_while_the_start_turns_in_or_to_another_place() {
        start.close(null);
        tryCompare(start, "phase", "closed", 2000);
        start.open();
        verify(start.turning);
        drawnTo(0.7).letGo();
        tryCompare(start, "phase", "open", 3000);
        verify(!turner.paused);
        named("pivot").select(1);
        verify(start.turning);
        drawnTo(0.7).letGo();
        compare(start.phase, "open");
        compare(windowsSpy.count, 0);
    }

    function test_in_a_search_a_finger_drawn_mostly_sideways_does_not_close() {
        keyClick(Qt.Key_K);
        tryCompare(start, "searching", true);
        start.forceActiveFocus();
        draw(glassX(), glassY(), -300, 200).letGo();
        compare(start.phase, "open");
        compare(windowsSpy.count, 0);
    }

    function test_nothing_closes_while_the_keys_are_in_the_search_line() {
        keyClick(Qt.Key_K);
        tryCompare(start, "searching", true);
        named("typed").forceActiveFocus();
        drawnTo(0.7).letGo();
        compare(start.phase, "open");
    }

    function test_nothing_closes_while_text_in_the_search_line_is_selected() {
        keyClick(Qt.Key_K);
        tryCompare(start, "searching", true);
        named("typed").selectAll();
        start.forceActiveFocus();
        verify(!named("typed").activeFocus);
        compare(named("typed").selectedText, "k");
        drawnTo(0.7).letGo();
        compare(start.phase, "open");
    }

    // Compact at 720 × 1280 with thirty pins, the panorama scrolls top to bottom.
    function scrollingPanorama(): var {
        start = makeStart({
            width: 720,
            height: 1280,
            pinned: fakeApps(30)
        });
        const scroller = findChild(named("panorama"), "scroller");
        verify(!named("panorama").sideways);
        verify(scroller.contentHeight > scroller.height + 200, `it scrolls: ${scroller.contentHeight}`);
        return scroller;
    }

    function test_over_a_scroller_off_its_top_a_finger_drawn_down_scrolls_and_does_not_close() {
        const scroller = scrollingPanorama();
        scroller.contentY = 400;
        draw(360, 600, 0, 0.3 * wholeWay).letGo();
        compare(start.phase, "open");
        compare(windowsSpy.count, 0);
        verify(scroller.contentY < 400, `it scrolled: ${scroller.contentY}`);
    }

    function test_a_scroll_that_reaches_the_top_on_the_way_does_not_close() {
        const scroller = scrollingPanorama();
        scroller.contentY = 60;
        draw(360, 600, 0, 0.7 * wholeWay).letGo();
        compare(start.phase, "open");
        compare(windowsSpy.count, 0);
        tryCompare(scroller, "contentY", 0, 2000);
    }

    function test_over_a_scroller_at_its_top_a_finger_drawn_down_closes() {
        const scroller = scrollingPanorama();
        compare(scroller.contentY, 0);
        draw(360, 600, 0, 0.7 * wholeWay).letGo();
        compare(start.phase, "closing");
    }

    function test_under_reduced_motion_nothing_follows_and_let_go_past_half_the_start_is_closed_at_once_with_the_keyboard_back() {
        Prefs.motion = "off";
        const finger = drawnTo(0.8);
        compare(start.phase, "open");
        compare(named("body").opacity, 1);
        compare(windowsSpy.count, 0);
        finger.letGo();
        tryCompare(start, "phase", "closed", 100);
        compare(calls, ["activate konsole"]);
    }

    function test_under_reduced_motion_let_go_short_of_half_everything_stays() {
        Prefs.motion = "off";
        drawnTo(0.45).letGo();
        compare(start.phase, "open");
        compare(windowsSpy.count, 0);
        compare(keyboardSpy.count, 0);
        compare(calls, []);
    }
}
