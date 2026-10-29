.pragma library

// Rekta's wheel latch (layout.md "Sideways scrolling by mouse wheel", rules 1–6; rekta.js panorama() wheel(), :872–900,
// and stripWheel(), :968–975), as plain functions over web-signed deltas: positive dy scrolls down, positive dx right.
// route() takes the gesture so far and one wheel event and says what to do with it.
//
// ponytail: Qt hands a wheel event to the item under the pointer and has no "native" scroll to leave to, so the
// callers scroll the latched scroller themselves; a pass means the event goes on to the items below and the page.

// One wheel event in web terms. Qt's deltas point the other way (angleDelta.y > 0 is up) and count 120 per notch.
function webEvent(wheel, linesPerNotch, linePixels, ctrlMask, shiftMask) {
    const along = (angle, pixel) => pixel !== 0 ? -pixel : -angle / 120 * linesPerNotch * linePixels;
    return {
        ctrl: (wheel.modifiers & ctrlMask) !== 0,
        shift: (wheel.modifiers & shiftMask) !== 0,
        dx: along(wheel.angleDelta.x, wheel.pixelDelta.x),
        dy: along(wheel.angleDelta.y, wheel.pixelDelta.y)
    };
}

// The scroller a gesture starts in (rule 1), or the panorama (rule 2); a horizontal start is native (rule 3).
function begin(horizontal, down, host) {
    if (horizontal)
        return { target: "native", inner: null };
    const inner = host.innerAt(down);
    return inner ? { target: "inner", inner } : { target: "pan", inner: null };
}

// host: innerAt(down) the nearest scroller under the pointer with room in that direction (rekta.js:882–885),
// room(scroller, down) whether it still has room, panRoom(down) whether the panorama has.
// Returns { gesture, fresh, action }, action being "pass", "swallow", "inner" or "pan".
function route(gesture, e, now, latch, host) {
    if (e.ctrl)
        return { gesture, fresh: false, action: "pass" };              // rule 5 (rekta.js:873)
    const horizontal = e.shift || Math.abs(e.dx) >= Math.abs(e.dy);    // rule 3 (:875)
    const down = e.dy > 0;
    const fresh = !gesture || now - gesture.last > latch;              // one gesture: events less than the latch apart (:877)
    const started = fresh ? begin(horizontal, down, host) : gesture;
    const next = { target: started.target, inner: started.inner, last: now };    // :888
    if (next.target === "native" || horizontal)
        return { gesture: next, fresh, action: "pass" };               // :889
    if (next.target === "inner")                                       // rule 1: swallowed at its end, never sideways (:890–894)
        return { gesture: next, fresh, action: host.room(next.inner, down) ? "inner" : "swallow" };
    if (!host.panRoom(down))
        return { gesture: next, fresh, action: "pass" };               // rule 4: the ends fall through (:896–897)
    return { gesture: next, fresh, action: "pan" };
}

// A strip of titles moves sideways under a plain vertical wheel, inside its own box (rekta.js:968–975): the new
// position, or null where the event is not the strip's (modifier, horizontal input, no room, an end).
function stripMove(e, position, most) {
    if (e.ctrl || e.shift || Math.abs(e.dx) >= Math.abs(e.dy))
        return null;
    const down = e.dy > 0;
    if (most <= 0 || (down ? position >= most - 1 : position <= 0))
        return null;
    return Math.max(0, Math.min(most, position + e.dy));
}
