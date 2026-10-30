pragma ComponentBehavior: Bound

import QtQuick

// Boxes laid out in a row that glide to their new places (motion.md, "Resize and re-flow" and "Reordering (FLIP)";
// rekta.js reflow(), :3390–3408): whatever a change moves or resizes goes from where it showed to where it rests over
// duration-moderate and ease-base. Content is never stretched: only the boxes' edges move. A box that was not laid out
// before stands at its place at once, as rekta.js presence() (:3430–3446) lets what comes enter where it rests while the
// rest glide. A newer change starts from what is showing. No motion, or `glide` false, sets everything at once.
QtObject {
    id: reflow

    // The item the targets' x are in; an item inside another one is set so that it shows there.
    required property Item frame
    // The items of the last change; the next one glides only these.
    property var known: []
    property var moves: []
    property real progress: 1
    readonly property bool running: animation.running

    // Sets the boxes to `targets`: {item, x, width, y}, x in `frame`, y in the item's parent. A parent comes before the
    // items inside it.
    function show(targets: var, glide: bool) {
        const before = new Set(known);
        const items = targets.map(target => target.item);
        // One that has left the row follows its own width again, so nothing reads a width it showed in passing.
        for (const item of known.filter(item => !items.includes(item)))
            item.width = undefined;
        known = items;
        animation.stop();
        moves = targets.map(target => ({ item: target.item, from: before.has(target.item) ? showing(target.item) : target, to: target }));
        targets.forEach(target => (target.item.y = target.y));
        progress = glide && moves.some(moved) && Tokens.durationModerate > 0 ? 0 : 1;
        follow();
        if (progress < 1)
            animation.start();
    }

    function showing(item: Item): var {
        return { x: item.mapToItem(frame, 0, 0).x, width: item.width };
    }

    function moved(move: var): bool {
        return Math.round(move.from.x) !== Math.round(move.to.x) || Math.round(move.from.width) !== Math.round(move.to.width);
    }

    function follow() {
        for (const move of moves) {
            const left = move.from.x + (move.to.x - move.from.x) * progress;
            const right = move.from.x + move.from.width + (move.to.x + move.to.width - move.from.x - move.from.width) * progress;
            move.item.x = Math.round(left - move.item.parent.mapToItem(frame, 0, 0).x);
            move.item.width = Math.round(right) - Math.round(left);
        }
    }

    onProgressChanged: follow()

    readonly property NumberAnimation run: NumberAnimation {
        id: animation

        objectName: "reflowRun"
        target: reflow
        property: "progress"
        from: 0
        to: 1
        duration: Tokens.durationModerate
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeBase
    }
}
