pragma ComponentBehavior: Bound

import QtQuick

// The place change (motion.md, "Place change"; rekta.js turn): the parts of the place you leave swing away toward the
// viewer around the leading edge of the box that clips them, light ones first and the pressed tile last. When the last
// is three quarters through, the next place shows and its parts swing in from the other side, each let go in the frame
// it lands. Back runs the other way round. A navigation while a turn runs finishes that turn first: none is refused.
//
// A part is a tile, a control, a line of text, anything that paints, or an item that says so with `turnsWhole`; a
// plain layout box or a scroller lets its children turn one by one. The turn shows and hides the places it is given.
QtObject {
    id: turner

    readonly property bool running: clock.running
    // Milliseconds since the turn began; the clock advances it each frame. While `paused`, setting it shows any moment
    // of the turn.
    property real elapsed: 0
    property bool paused: false
    // The plans (Turnstile.plan) of the place leaving and of the one arriving; each turn's `part.item` is its item.
    property var leavingTurns: []
    property var arrivingTurns: []

    // The running turn.
    property Item leavingPlace: null
    property Item arrivingPlace: null
    property bool back: false
    property Tile pressedTile: null
    property real handOverAt: 0
    property bool handedOver: false
    property var turning: []

    readonly property FrameAnimation clock: FrameAnimation {
        paused: turner.paused
        onTriggered: turner.elapsed = turner.clock.elapsedTime * 1000
    }

    // One part turning: a rotation about its clipping box's leading edge and its opacity, both following the turn's
    // clock through Qt's own curves. Before it starts it waits in its first pose.
    property Component partTurn: Component {
        QtObject {
            id: part

            required property var turn
            required property bool leaving
            readonly property Item item: turn.part.item
            readonly property bool pressed: item === turner.pressedTile
            // Forward, a leaving part swings its far side toward the viewer; back mirrors both turns.
            readonly property real direction: turner.back ? 1 : -1
            readonly property real fromAngle: leaving ? 0 : -direction * Geometry.turnInAngle
            readonly property real toAngle: leaving ? direction * Geometry.turnOutAngle : 0
            readonly property real progress: Math.min(1, Math.max(0, (turner.elapsed - turn.at) / turn.duration))
            readonly property bool started: turner.elapsed >= turn.at
            property real angle: fromAngle
            property real fade: leaving ? 1 : 0
            property bool holding: true

            property Rotation rotation: Rotation {
                axis {
                    x: 0
                    y: 1
                    z: 0
                }
                origin.x: part.turn.originX
                origin.y: part.turn.originY
                distanceToPlane: part.turn.perspective
                angle: part.angle
            }

            // A fading part fades as one, as CSS opacity does: drawn into a layer only while it is see-through.
            property Binding opacityHeld: Binding {
                target: part.item
                property: "opacity"
                value: part.fade
                when: part.holding
            }
            property Binding layerHeld: Binding {
                target: part.item
                property: "layer.enabled"
                value: part.fade > 0 && part.fade < 1
                when: part.holding
            }
            property Binding layerSmooth: Binding {
                target: part.item
                property: "layer.smooth"
                value: true
                when: part.holding
            }

            // Leaving, whole for the first share of its time, then fading; arriving, whole after its first share.
            property AnimationController motion: AnimationController {
                progress: part.progress
                animation: ParallelAnimation {
                    NumberAnimation {
                        target: part
                        property: "angle"
                        from: part.fromAngle
                        to: part.toAngle
                        duration: part.turn.duration
                        easing.type: Easing.Bezier
                        easing.bezierCurve: part.leaving ? Geometry.easeTurnOut : Geometry.easeTurnIn
                    }
                    SequentialAnimation {
                        PauseAnimation {
                            duration: part.leaving ? Geometry.turnOutWhole * part.turn.duration : 0
                        }
                        NumberAnimation {
                            target: part
                            property: "fade"
                            from: part.leaving ? 1 : 0
                            to: part.leaving ? 0 : 1
                            duration: (part.leaving ? 1 - Geometry.turnOutWhole : Geometry.turnInWhole) * part.turn.duration
                            easing.type: Easing.Bezier
                            easing.bezierCurve: part.leaving ? Geometry.easeTurnOut : Geometry.easeTurnIn
                        }
                    }
                }
            }

            // The pressed tile turns from its pressed pose: its press lets go along the turn. Driven only once it
            // starts, so the press stays where it is until then.
            property NumberAnimation pressRelease: NumberAnimation {
                target: part.pressed ? part.item : null
                property: "sink"
                from: 1
                to: 0
                duration: part.turn.duration
                easing.type: Easing.Bezier
                easing.bezierCurve: Geometry.easeTurnOut
            }
            property AnimationController pressMotion: AnimationController {
                progress: part.progress
                animation: part.pressed && part.started ? part.pressRelease : null
            }

            // A part may be gone before it is let go: its place's model made its items anew during the turn.
            function letGo() {
                holding = false;
                if (item)
                    item.transform = Array.from(item.transform).filter(transform => transform !== rotation);
            }

            Component.onCompleted: item.transform = Array.from(item.transform).concat([rotation])
        }
    }

    signal landed

    // Turns from one place to the next; either may be null (nothing to leave, nothing to arrive at). `options.back`
    // runs it the other way round; `options.pressed` is the tile that opened the next place.
    function go(from: Item, to: Item, options: var) {
        finish();
        // A place still building in leaves from its end state: the turn wins over the arrival.
        if (from)
            markArrival(from, "");
        leavingPlace = from;
        arrivingPlace = to;
        back = options?.back === true;
        if (to)
            to.visible = false;
        if (Tokens.reducedMotion) {
            handOver();
            land();
            return;
        }
        elapsed = 0;
        leave(back ? null : options?.pressed ?? null);
        clock.reset();
        clock.start();
        step();
    }

    // Ends a running turn in its end state.
    function finish() {
        if (!clock.running)
            return;
        clock.stop();
        if (!handedOver)
            handOver();
        letAllGo();
        land();
    }

    function leave(pressed: Tile) {
        const parts = leavingPlace ? partsOf(leavingPlace) : [];
        const pressedPart = parts.find(part => part.item === pressed);
        const turns = Turnstile.plan(parts.filter(part => part !== pressedPart), Tokens.durationShort, 0);
        if (pressedPart) {
            pressedTile = pressed;
            turns.push(Turnstile.pressedTurn(pressedPart, Tokens.durationShort, turns, pressed.keepPressed()));
        }
        leavingTurns = turns;
        arrivingTurns = [];
        handOverAt = Turnstile.nextPlaceAt(turns);
        turning = turns.map(turn => partTurn.createObject(turner, {
                turn: turn,
                leaving: true
            }));
    }

    function step() {
        if (!clock.running)
            return;
        if (!handedOver && elapsed >= handOverAt)
            handOver();
        if (!handedOver)
            return;
        // Each arriving part is let go in the frame it lands; a late frame may be past several landings at once.
        const landing = turning.filter(part => elapsed >= part.turn.at + part.turn.duration);
        for (const part of landing)
            release(part);
        if (turning.length === 0)
            land();
    }

    onElapsedChanged: step()

    // The place leaving goes, and the next one shows with its parts in their first pose.
    function handOver() {
        if (leavingPlace)
            leavingPlace.visible = false;
        letAllGo();
        if (pressedTile)
            pressedTile.kept = false;
        pressedTile = null;
        handedOver = true;
        if (!arrivingPlace)
            return;
        // Its parts turning in is its build-in; a place gone back to comes back as it was left.
        // ponytail: "turned" holds until the place leaves; the arrival window that ends it (rekta.js arrive()) comes
        // with a place's first arrival.
        markArrival(arrivingPlace, back ? "" : "turned");
        arrivingPlace.visible = true;
        if (!clock.running)
            return;
        arrivingTurns = Turnstile.plan(partsOf(arrivingPlace), Tokens.durationModerate, handOverAt);
        turning = arrivingTurns.map(turn => partTurn.createObject(turner, {
                turn: turn,
                leaving: false
            }));
    }

    function release(part: var) {
        part.letGo();
        part.destroy();
        turning = turning.filter(other => other !== part);
    }

    function letAllGo() {
        for (const part of turning) {
            part.letGo();
            part.destroy();
        }
        turning = [];
    }

    function land() {
        clock.stop();
        handedOver = false;
        leavingPlace = null;
        arrivingPlace = null;
        landed();
    }

    // Sets how the tiles in a place arrive (Tile.arrival), as rekta.js sets data-rk-arriving on the place.
    function markArrival(box: Item, arrival: string) {
        for (const child of box.children) {
            const tile = child as Tile;
            if (tile)
                tile.arrival = arrival;
            markArrival(child, arrival);
        }
    }

    // The parts in view: the units a place shows, its layout boxes opened up (rekta.js turnUnits()).
    function partsOf(place: Item): var {
        let root = place;
        while (root.parent)
            root = root.parent;
        const parts = [];
        collectParts(place, place, root, parts);
        return parts;
    }

    function collectParts(box: Item, place: Item, root: Item, parts: var) {
        for (const child of box.children) {
            if (!inView(child, root))
                continue;
            if (turnsWhole(child))
                parts.push(partOf(child, place));
            else
                collectParts(child, place, root, parts);
        }
    }

    function inView(item: Item, root: Item): bool {
        if (!item.visible || item.width <= 0 || item.height <= 0)
            return false;
        const box = item.mapToItem(null, 0, 0, item.width, item.height);
        return box.x + box.width > 0 && box.y + box.height > 0 && box.x < root.width && box.y < root.height;
    }

    // A part turns as one when it says so, shows text, takes the focus (a control), paints a fill or a line of its own,
    // or holds nothing (rekta.js turnsWhole()). A mouse area is input, not something shown.
    function turnsWhole(item: var): bool {
        if (item.turnsWhole !== undefined)
            return item.turnsWhole;
        if ((item as Text) || (item as TextInput) || (item as TextEdit) || item.activeFocusOnTab)
            return true;
        const box = item as Rectangle;
        if (box && (box.color.a > 0 || box.border.width > 0))
            return true;
        return item.children.length === 0 && !(item as MouseArea);
    }

    // Where a part rests on the screen, without its own transform, and the top left of the box that clips it.
    function partOf(item: Item, place: Item): var {
        const at = item.parent.mapToItem(null, item.x, item.y);
        let clip = item.parent;
        while (clip !== place && !clip.clip)
            clip = clip.parent;
        const edge = clip.mapToItem(null, 0, 0);
        return {
            item: item,
            x: at.x,
            y: at.y,
            width: item.width,
            height: item.height,
            clip: {
                x: edge.x,
                y: edge.y
            }
        };
    }
}
