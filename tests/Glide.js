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

// How far runs stray, at the most, as a share of their way, from going together along `curve` (anything with
// valueForProgress, such as an easingCurve) over `duration` ms. Each run is { steps, from, to }, started at `since`.
// When their clock began no one sees: Qt counts a new animation from its timer's last tick, which may lie up to a frame
// before the start, so up to half the duration before `since` and by the first step on the way at the latest, the best
// guess counts. A step that only sets the start tells no time (a transition may set it a frame after its clock began),
// and a run without a step on the way never ran.
function strayOf(runs, duration, curve, since) {
    const moving = runs.map(run => Object.assign({}, run, { steps: run.steps.filter(step => step.value !== run.from) }));
    if (moving.some(run => run.steps.length === 0))
        return Infinity;
    const latest = Math.min(...[].concat(...moving.map(run => run.steps.map(step => step.at))));
    let best = Infinity;
    for (let began = since - Math.round(duration / 2); began <= latest; began++)
        best = Math.min(best, Math.max(...moving.map(run => strayFrom(run, duration, curve, began))));
    return best;
}

function strayFrom(run, duration, curve, began) {
    return Math.max(...run.steps.map(step => {
        const share = Math.min(1, Math.max(0, (step.at - began) / duration));
        return Math.abs((step.value - run.from) / (run.to - run.from) - curve.valueForProgress(share));
    }));
}
