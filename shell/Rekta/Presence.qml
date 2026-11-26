pragma ComponentBehavior: Bound

import QtQuick

// Things coming and going in a list or a grid (motion.md, "Arriving, leaving" and "Reordering"; rekta.js presence(),
// enter(), leave(), :4220–4270). Those that go leave first; then the change is made, the ones that stay glide from where
// they were to where they are now, and those that come arrive. A tile leaves shrinking to 90% and arrives rising from
// 96% while the others glide; anything else moves as a row, leaving towards its trailing edge and arriving from just
// above. A row that comes waits unseen until nothing glides any more, the mirror of leaving, as a bar control waits for
// its neighbours to make room, so nothing lies over anything. A tile that changed size scales from its old size while
// its content shows again over the last 45% (motion.md, "Resize and re-flow"; rekta.js reflow(), :4200–4220). A newer
// change makes at once the change still waiting for its items to leave; more than sixty changes, or no motion, apply
// at once.
QtObject {
    id: presence

    // The change whose items are still leaving: {going, staying, apply, arrived}.
    property var waiting: null
    property var moving: []
    readonly property bool running: waiting !== null || moving.length > 0
    readonly property var rest: ({
            x: 0,
            y: 0,
            scale: 1,
            sx: 1,
            sy: 1,
            opacity: 1
        })

    readonly property Timer afterLeaving: Timer {
        interval: Geometry.leaveShare * Tokens.durationShort
        onTriggered: presence.settle()
    }

    // One item moving between two poses ({x, y, scale, sx, sy, opacity}: the shift, the scale about its centre and the
    // stretch from its top leading corner on top of where it rests) through Qt's own curve. One that leaves holds its end
    // until the change is made; the others let go as they land. A resized tile holds its content hidden until
    // resizeContentFrom of the time has passed, then fades it in evenly. One that waits stands at its start until go().
    property Component motion: Component {
        QtObject {
            id: motion

            required property Item item
            required property var from
            required property var to
            required property int duration
            required property var curve
            required property bool holds
            required property bool waits
            readonly property bool fades: from.opacity !== to.opacity
            readonly property bool resized: from.sx !== to.sx || from.sy !== to.sy
            property real progress: 0
            // The share of the time gone, unlike progress not eased.
            property real elapsed: 0
            property bool holding: true
            readonly property real opacity: from.opacity + (to.opacity - from.opacity) * progress

            function along(key: string): real {
                return from[key] + (to[key] - from[key]) * progress;
            }

            property Translate shift: Translate {
                x: motion.along("x")
                y: motion.along("y")
            }
            property Scale size: Scale {
                origin.x: motion.item ? motion.item.width / 2 : 0
                origin.y: motion.item ? motion.item.height / 2 : 0
                xScale: motion.along("scale")
                yScale: motion.along("scale")
            }
            property Scale stretch: Scale {
                xScale: motion.along("sx")
                yScale: motion.along("sy")
            }
            property Binding contentHeld: Binding {
                // Only a tile has content apart from its fill.
                target: motion.resized ? motion.item : null
                property: "contentOpacity"
                value: Math.max(0, motion.elapsed - Geometry.resizeContentFrom) / (1 - Geometry.resizeContentFrom)
                when: motion.holding && motion.resized
            }
            // A fading item fades as one, as CSS opacity does: drawn into a layer only while it is see-through. Qt puts
            // that layer's source beside the item, among its parent's children, until it is opaque again.
            property Binding opacityHeld: Binding {
                target: motion.item
                property: "opacity"
                value: motion.opacity
                when: motion.holding && motion.fades
            }
            property Binding layerHeld: Binding {
                target: motion.item
                property: "layer.enabled"
                value: motion.opacity > 0 && motion.opacity < 1
                when: motion.holding && motion.fades
            }
            property ParallelAnimation run: ParallelAnimation {
                onFinished: {
                    if (!motion.holds)
                        presence.land(motion);
                }

                NumberAnimation {
                    target: motion
                    property: "progress"
                    from: 0
                    to: 1
                    duration: motion.duration
                    easing.type: Easing.Bezier
                    easing.bezierCurve: motion.curve
                }
                NumberAnimation {
                    target: motion
                    property: "elapsed"
                    from: 0
                    to: 1
                    duration: motion.duration
                }
            }
            readonly property list<QtObject> transforms: [size, stretch, shift]

            function go() {
                waits = false;
                run.start();
            }

            function letGo() {
                run.stop();
                holding = false;
                if (item)
                    item.transform = Array.from(item.transform).filter(transform => !transforms.includes(transform));
            }

            // Scaled first, then shifted, as CSS reads `translate() scale()`.
            Component.onCompleted: {
                item.transform = Array.from(item.transform).concat(transforms);
                if (!waits)
                    run.start();
            }
        }
    }

    // `going` leave; then apply() makes the change, `staying` close the gap and the items arrived() returns arrive.
    // `arriving` is how many will come, as far as it is known beforehand.
    function change(going: var, staying: var, apply: var, arrived: var, arriving: int) {
        finish();
        if (Tokens.durationShort === 0 || going.length + arriving > Geometry.presenceAtOnceAbove) {
            // What still moves from before lands too, or it would go on from where the change no longer is.
            complete();
            apply();
            return;
        }
        waiting = {
            going: going,
            staying: staying,
            apply: apply,
            arrived: arrived
        };
        going.forEach(leave);
        if (going.length > 0)
            afterLeaving.restart();
        else
            settle();
    }

    // Makes the waiting change at once, without motion, as a newer one comes; what already arrives, glides or waits for
    // room goes on.
    function finish() {
        afterLeaving.stop();
        const change = waiting;
        if (!change)
            return;
        waiting = null;
        change.going.forEach(releaseOn);
        change.apply();
    }

    // Everything at rest now, the waiting change made.
    function complete() {
        finish();
        moving.slice().forEach(release);
    }

    function settle() {
        const change = waiting;
        waiting = null;
        const before = change.staying.map(item => item.mapToItem(null, 0, 0, item.width, item.height));
        change.going.forEach(releaseOn);
        change.apply();
        const arrived = change.arrived();
        // ponytail: a count known only once the change is made can no longer save the leaving; pass `arriving`.
        if (change.going.length + arrived.length > Geometry.presenceAtOnceAbove)
            return;
        change.staying.forEach((item, index) => glide(item, before[index]));
        arrived.forEach(arrive);
        arriveIfRoom();
    }

    // The rows waiting for room arrive once nothing glides any more, of this change or an earlier one.
    function arriveIfRoom() {
        if (moving.every(running => running.fades))
            moving.filter(running => running.waits).forEach(running => running.go());
    }

    function isTile(item: Item): bool {
        return (item as Tile) !== null;
    }

    function start(item: Item, from: var, to: var, duration: int, curve: var, holds: bool, waits: bool) {
        moving = [...moving, motion.createObject(presence, {
                item: item,
                from: from,
                to: to,
                duration: duration,
                curve: curve,
                holds: holds,
                waits: waits
            })];
    }

    function leave(item: Item) {
        releaseOn(item);
        const gone = isTile(item) ? {
            scale: Geometry.leaveTileScale,
            x: 0
        } : {
            scale: 1,
            x: Geometry.leaveRowDrift
        };
        start(item, rest, Object.assign({}, rest, gone, {
            opacity: 0
        }), Geometry.leaveShare * Tokens.durationShort, Tokens.easeOut, true, false);
    }

    function arrive(item: Item) {
        const tile = isTile(item);
        const from = Object.assign({}, rest, {
            y: tile ? Geometry.arriveShift : -Geometry.arriveShift,
            scale: tile ? Geometry.arriveTileScale : 1,
            opacity: 0
        });
        start(item, from, rest, tile ? Tokens.durationModerate : Tokens.durationShort, Tokens.easeIn, false, !tile);
    }

    // From where it showed before the change to where it rests now (FLIP); a glide still running gives way. A tile also
    // scales from the size it showed (rekta.js:4211–4213).
    function glide(item: Item, was: rect) {
        moving.filter(running => running.item === item && !running.fades).forEach(release);
        const now = item.mapToItem(null, 0, 0, item.width, item.height);
        const sx = isTile(item) && now.width > 0 ? was.width / now.width : 1;
        const sy = isTile(item) && now.height > 0 ? was.height / now.height : 1;
        const resized = Math.abs(sx - 1) > 0.01 || Math.abs(sy - 1) > 0.01;
        if (Math.abs(was.x - now.x) < 0.5 && Math.abs(was.y - now.y) < 0.5 && !resized)
            return;
        start(item, Object.assign({}, rest, {
            x: was.x - now.x,
            y: was.y - now.y,
            sx: resized ? sx : 1,
            sy: resized ? sy : 1
        }), rest, Tokens.durationModerate, Tokens.easeBase, false, false);
    }

    function land(running: var) {
        release(running);
        arriveIfRoom();
    }

    function release(running: var) {
        running.letGo();
        running.destroy();
        moving = moving.filter(other => other !== running);
    }

    function releaseOn(item: Item) {
        moving.filter(running => running.item === item).forEach(release);
    }
}
