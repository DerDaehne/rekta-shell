pragma ComponentBehavior: Bound

import QtQuick

// Things coming and going in a list or a grid (motion.md, "Arriving, leaving" and "Reordering"; rekta.js presence(),
// enter(), leave(), :3409–3445). Those that go leave first; then the change is made, the ones that stay glide from where
// they were to where they are now, and those that come arrive. A tile leaves shrinking to 90% and arrives rising from
// 96%; anything else moves as a row, leaving towards its trailing edge and arriving from just above. A newer change
// makes the one still waiting at once; more than sixty changes, or no motion, apply at once.
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
            opacity: 1
        })

    readonly property Timer afterLeaving: Timer {
        interval: Geometry.leaveShare * Tokens.durationShort
        onTriggered: presence.settle()
    }

    // One item moving between two poses ({x, y, scale, opacity}, the shift and scale on top of where it rests) through
    // Qt's own curve. One that leaves holds its end until the change is made; the others let go as they land.
    property Component motion: Component {
        QtObject {
            id: motion

            required property Item item
            required property var from
            required property var to
            required property int duration
            required property var curve
            required property bool holds
            readonly property bool fades: from.opacity !== to.opacity
            property real progress: 0
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
            property NumberAnimation run: NumberAnimation {
                target: motion
                property: "progress"
                from: 0
                to: 1
                duration: motion.duration
                easing.type: Easing.Bezier
                easing.bezierCurve: motion.curve
                onFinished: {
                    if (!motion.holds)
                        presence.release(motion);
                }
            }

            function letGo() {
                run.stop();
                holding = false;
                if (item)
                    item.transform = Array.from(item.transform).filter(transform => transform !== shift && transform !== size);
            }

            Component.onCompleted: {
                item.transform = Array.from(item.transform).concat([shift, size]);
                run.start();
            }
        }
    }

    // `going` leave; then apply() makes the change, `staying` close the gap and the items arrived() returns arrive.
    // `arriving` is how many will come, as far as it is known beforehand.
    function change(going: var, staying: var, apply: var, arrived: var, arriving: int) {
        finish();
        if (Tokens.durationShort === 0 || going.length + arriving > Geometry.presenceAtOnceAbove) {
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

    // Makes the waiting change at once, without motion, as a newer one comes; what already arrives or glides goes on.
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
        const before = change.staying.map(item => item.mapToItem(null, 0, 0));
        change.going.forEach(releaseOn);
        change.apply();
        const arrived = change.arrived();
        // ponytail: a count known only once the change is made can no longer save the leaving; pass `arriving`.
        if (change.going.length + arrived.length > Geometry.presenceAtOnceAbove)
            return;
        change.staying.forEach((item, index) => glide(item, before[index]));
        arrived.forEach(arrive);
    }

    function isTile(item: Item): bool {
        return (item as Tile) !== null;
    }

    function start(item: Item, from: var, to: var, duration: int, curve: var, holds: bool) {
        moving = [...moving, motion.createObject(presence, {
                item: item,
                from: from,
                to: to,
                duration: duration,
                curve: curve,
                holds: holds
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
        }), Geometry.leaveShare * Tokens.durationShort, Tokens.easeOut, true);
    }

    function arrive(item: Item) {
        const tile = isTile(item);
        const from = Object.assign({}, rest, {
            y: tile ? Geometry.arriveShift : -Geometry.arriveShift,
            scale: tile ? Geometry.arriveTileScale : 1,
            opacity: 0
        });
        start(item, from, rest, tile ? Tokens.durationModerate : Tokens.durationShort, Tokens.easeIn, false);
    }

    // From where it showed before the change to where it rests now (FLIP); a glide still running gives way.
    function glide(item: Item, was: point) {
        moving.filter(running => running.item === item && !running.fades).forEach(release);
        const now = item.mapToItem(null, 0, 0);
        if (Math.abs(was.x - now.x) < 0.5 && Math.abs(was.y - now.y) < 0.5)
            return;
        start(item, Object.assign({}, rest, {
            x: was.x - now.x,
            y: was.y - now.y
        }), rest, Tokens.durationModerate, Tokens.easeBase, false);
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
