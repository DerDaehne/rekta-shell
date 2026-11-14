.pragma library

// The steps an animated property takes, each with the time it was taken. Under load frames come late or few, but each
// step still stands where the animation clock puts it, so steps checked against a curve hold however busy the machine
// is, where a look after a fixed wait finds an old frame or one past the end.

// Records every change of `property` of `object` from now on, as { at, value } with `at` from Date.now().
function record(object, property) {
    const steps = [];
    object[`${property}Changed`].connect(() => steps.push({ at: Date.now(), value: object[property] }));
    return steps;
}

// The times of the animation timer's ticks while the test runs, beginning with one already taken. Every animation of
// the thread advances on them, and under load they come late together with the steps they bound.
function ticks(testCase) {
    const clock = testCase.createTemporaryQmlObject(`import QtQuick
        NumberAnimation {
            id: clock
            property real t
            target: clock; property: "t"; from: 0; to: 1; duration: 1000; loops: Animation.Infinite; running: true
        }`, testCase);
    const at = [];
    clock.tChanged.connect(() => at.push(Date.now()));
    testCase.tryVerify(() => at.length > 0, 1000, "the animation timer ticks");
    return at;
}

// Date.now() and the timer each round to the millisecond.
const clockRounding = 2;

// How far runs stray, at the most, as a share of their way, from going together along `curve` (anything with
// valueForProgress, such as an easingCurve) over `duration` ms, started by what happened at `since`. Each run is
// { steps, from, to } and must have ended on `to`. Qt counts a new animation from the timer's last tick, and a
// transition may start a frame after its trigger, so the run's clock began no earlier than the last tick before `since`
// and no later than the second after; within that window the best guess counts. Measured from the earliest, no run may
// end before `duration` has passed. A step that only sets the start tells no time, and a run without a step on the way
// never ran.
function strayOf(runs, duration, curve, since, ticks) {
    const before = ticks.filter(at => at < since);
    const after = ticks.filter(at => at > since);
    if (before.length === 0 || after.length < 2)
        return Infinity;
    const earliest = before[before.length - 1];
    const moving = runs.map(run => Object.assign({}, run, { steps: run.steps.filter(step => step.value !== run.from) }));
    if (moving.some(run => run.steps.length === 0 || !endsOn(run, earliest + duration - clockRounding)))
        return Infinity;
    let best = Infinity;
    for (let began = earliest; began <= after[1]; began++)
        best = Math.min(best, Math.max(...moving.map(run => strayFrom(run, duration, curve, began))));
    return best;
}

function endsOn(run, notBefore) {
    const last = run.steps[run.steps.length - 1];
    return last.value === run.to && last.at >= notBefore;
}

function strayFrom(run, duration, curve, began) {
    return Math.max(...run.steps.map(step => {
        const share = Math.min(1, Math.max(0, (step.at - began) / duration));
        return Math.abs((step.value - run.from) / (run.to - run.from) - curve.valueForProgress(share));
    }));
}
