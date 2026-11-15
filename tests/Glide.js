.pragma library

// The steps an animated property takes, each with the time it was taken. Under load frames come late or few, but each
// step still stands where the animation clock puts it, so steps checked against a curve hold however busy the machine
// is, where a look after a fixed wait finds an old frame or one past the end.

// How many steps and ticks were taken so far: their order, which a stamp in whole milliseconds cannot always tell.
let taken = 0;

// Records every change of `property` of `object` from now on, as { at, order, value } with `at` from Date.now().
function record(object, property) {
    const steps = [];
    object[`${property}Changed`].connect(() => steps.push({ at: Date.now(), order: ++taken, value: object[property] }));
    return steps;
}

// The animation timer's ticks while the test runs, beginning with one already taken, each as { at, order, time } with
// `at` from Date.now() and `time` the timer's own clock in ms. Every animation of the thread advances on them by the
// same time. The ticker starts before the animations a test then checks, so in each tick it moves first.
function ticks(testCase) {
    const clock = testCase.createTemporaryQmlObject(`import QtQuick
        NumberAnimation {
            id: clock
            property real time
            target: clock; property: "time"; from: 0; to: 1e9; duration: 1e9; running: true
        }`, testCase);
    const stamped = [];
    clock.timeChanged.connect(() => stamped.push({ at: Date.now(), order: ++taken, time: Math.round(clock.time) }));
    // A tick stamped in the very millisecond of a `since` taken right after could not tell whether it came before it.
    testCase.tryVerify(() => stamped.length > 0 && stamped[0].at < Date.now(), 1000, "the animation timer ticks");
    return stamped;
}

// How far runs stray, at the most, as a share of their way, from going together along `curve` (anything with
// valueForProgress, such as an easingCurve) over `duration` ms, started by what happened at `since` (from Date.now()).
// Each run is { steps, from, to } and must have ended on `to`; wait for that end exactly, as a tryCompare on a number
// also passes a step a hair before it. All is measured on the timer's clock: a step counts at the tick it was taken in,
// as a busy machine may stamp it long after the tick began. Qt counts a new animation from the timer's last tick, and a
// transition may start a frame after its trigger, so the run's clock began no earlier than the last tick before `since`
// and no later than the second after, nor than the tick before the first step on the way; within that window the best
// guess counts. Measured from the earliest, no run may end before `duration` has passed, and measured from the latest,
// none may still be on its way after it. A step that only sets the start tells no time, and a run without a step on the
// way never ran.
function strayOf(runs, duration, curve, since, ticks) {
    const before = ticks.filter(tick => tick.at < since);
    const after = ticks.filter(tick => tick.at > since);
    const moving = runs.map(run => {
        const steps = run.steps.filter(step => step.value !== run.from);
        return { from: run.from, to: run.to, steps: steps.map(step => onTheClock(step, ticks)) };
    });
    if (before.length === 0 || after.length < 2 || moving.some(run => run.steps.length === 0))
        return Infinity;
    const earliest = before[before.length - 1].time;
    const latest = Math.min(after[1].time, tickBefore(Math.min(...moving.map(run => run.steps[0].at)), ticks));
    if (!moving.every(run => endsWithin(run, earliest + duration, latest + duration)))
        return Infinity;
    let best = Infinity;
    for (let began = earliest; began <= latest; began++)
        best = Math.min(best, Math.max(...moving.map(run => strayFrom(run, duration, curve, began))));
    return best;
}

// How far runs that wait for a glide stray, as strayOf measures them, `landed` being the glide's last step. Waiting on
// the same clock, they began between the glide's last two ticks; a step taken in its last would make strayOf count them
// from a tick earlier, so those are left out.
function strayAfter(landed, runs, duration, curve, ticks) {
    const landedIn = tickOf(landed, ticks);
    const later = runs.map(run => ({ steps: run.steps.filter(step => tickOf(step, ticks) > landedIn), from: run.from, to: run.to }));
    return strayOf(later, duration, curve, ticks[landedIn - 1].at, ticks);
}

// The tick a step was taken in, as its index in `ticks`: what one frame shows, whatever moved first within it.
function tickOf(step, ticks) {
    return ticks.filter(tick => tick.order < step.order).length - 1;
}

// The step at the timer's time of the tick it was taken in, or of the last tick before a step taken between ticks.
function onTheClock(step, ticks) {
    const sooner = ticks.filter(tick => tick.order < step.order);
    return { at: (sooner.length > 0 ? sooner[sooner.length - 1] : ticks[0]).time, value: step.value };
}

// The time of the last tick before `time`: an animation moves first in the tick after the one it began at.
function tickBefore(time, ticks) {
    const sooner = ticks.filter(tick => tick.time < time);
    return sooner.length > 0 ? sooner[sooner.length - 1].time : -Infinity;
}

function endsWithin(run, notBefore, notAfter) {
    const last = run.steps[run.steps.length - 1];
    const onTheWay = run.steps.filter(step => step.value !== run.to);
    return last.value === run.to && last.at >= notBefore && onTheWay.every(step => step.at < notAfter);
}

function strayFrom(run, duration, curve, began) {
    return Math.max(...run.steps.map(step => {
        const share = Math.min(1, Math.max(0, (step.at - began) / duration));
        return Math.abs((step.value - run.from) / (run.to - run.from) - curve.valueForProgress(share));
    }));
}

// How far two runs driven by one value lie apart, as shares of their ways, at the end of each tick both stepped in:
// paired by the steps' order, never by a clock, so a busy machine cannot part them.
function apartPerTick(one, other, ticks) {
    const shareAtTick = run => {
        const shares = new Map();
        for (const step of run.steps)
            shares.set(ticks.filter(tick => tick.order < step.order).length, (step.value - run.from) / (run.to - run.from));
        return shares;
    };
    const others = shareAtTick(other);
    return [...shareAtTick(one)].filter(([tick]) => others.has(tick)).map(([tick, share]) => Math.abs(share - others.get(tick)));
}
