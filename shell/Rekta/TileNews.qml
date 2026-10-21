import QtQuick

// Live tile news (motion.md, "Live tile news"; rekta.js tileUpdate(), :3447–3476), over duration-moderate. A peek, for a
// new number: the stat as it was leaves upwards over 0.6 × that while the new one rises from below over 0.8 ×, after
// 0.2 ×. A flip, for a new status: the tile turns away around its horizontal axis over the first half, changes, and
// turns back. A continuous reading is no news and changes in place. While held, news waits, and comes in one step when
// the tile is let go (live.md, "Holding still").
Item {
    id: news

    // The tile's content; its first visible stat is what a peek moves.
    required property Item content
    property bool held: false
    readonly property bool peeking: peek.target !== null
    // How far the flip has turned the tile around its horizontal axis, in degrees (as CSS rotateX).
    readonly property real flipAngle: flip.phase < 0.5 ? -Geometry.flipAngle * easeOut.valueForProgress(flip.phase * 2) : Geometry.flipAngle * (1 - easeIn.valueForProgress(flip.phase * 2 - 1))
    readonly property easingCurve easeOut: ({ type: Easing.Bezier, bezierCurve: Tokens.easeOut })
    readonly property easingCurve easeIn: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })
    property var waiting: []

    // kind: "peek" (a new number), "flip" (a new status) or "" (a continuous reading). A newer piece of news ends the
    // one still running at once. Under reduced motion duration-moderate is 0, so the change comes at once.
    function tell(kind: string, change: var) {
        if (held) {
            waiting.push({ kind, change });
            return;
        }
        finish();
        if (kind !== "peek" && kind !== "flip") {
            change();
            return;
        }
        if (kind === "flip")
            startFlip(change);
        else
            startPeek(change);
    }

    function finish() {
        peekRun.stop();
        peek.target = null;
        flipRun.stop();
        flip.phase = 1;
    }

    function firstStat(): Stat {
        for (const item of content.children) {
            const stat = item as Stat;
            if (stat && stat.visible)
                return stat;
        }
        return null;
    }

    function startPeek(change: var) {
        const stat = firstStat();
        if (!stat) {
            change();
            return;
        }
        ghost.value = stat.value;
        ghost.label = stat.label;
        ghost.placeWidth = stat.placeWidth;
        ghost.width = stat.width;
        ghost.x = content.x + stat.x;
        ghost.y = content.y + stat.y;
        change();
        if (stat.value === ghost.value && stat.label === ghost.label)
            return;
        peek.target = stat;
        peekRun.restart();
    }

    function startFlip(change: var) {
        flip.change = change;
        flip.phase = 0;
        flipRun.restart();
    }

    function turnOver() {
        const change = flip.change;
        flip.change = null;
        if (change)
            change();
    }

    // Let go, a held tile catches up in one step; a new status among the waiting news turns it over, as rekta-core's
    // tile does (core/src/declare.c:663).
    onHeldChanged: {
        if (held || waiting.length === 0)
            return;
        const list = waiting;
        waiting = [];
        const kind = list.some(w => w.kind === "flip") ? "flip" : list.some(w => w.kind === "peek") ? "peek" : "";
        tell(kind, () => list.forEach(w => w.change()));
    }

    QtObject {
        id: peek

        objectName: "peek"
        property Stat target: null
        // 0 to 1 over duration-moderate, linear; each part eases its own share of it.
        property real phase: 1
        readonly property real leaving: news.easeOut.valueForProgress(Math.min(1, phase / 0.6))
        readonly property real rising: news.easeIn.valueForProgress(Math.max(0, (phase - 0.2) / 0.8))
    }

    NumberAnimation {
        id: peekRun

        objectName: "peekRun"
        target: peek
        property: "phase"
        from: 0
        to: 1
        duration: Tokens.durationModerate
        onFinished: peek.target = null
    }

    // The stat as it was, where it was, leaving through the tile's edge.
    Stat {
        id: ghost

        objectName: "ghost"
        visible: news.peeking
        opacity: 1 - peek.leaving
        Accessible.ignored: true
        transform: Translate {
            y: -Geometry.peekShift * ghost.height * peek.leaving
        }
    }

    // The new stat, drawn in its place while it rises; the stat itself stays where its column puts it.
    ShaderEffectSource {
        objectName: "incoming"
        visible: news.peeking
        sourceItem: peek.target
        hideSource: news.peeking
        x: news.content.x + (peek.target?.x ?? 0)
        y: news.content.y + (peek.target?.y ?? 0) + Geometry.peekShift * height * (1 - peek.rising)
        width: peek.target?.width ?? 0
        height: peek.target?.height ?? 0
        opacity: peek.rising
    }

    QtObject {
        id: flip

        objectName: "flip"
        property var change: null
        // 0 to 1 over duration-moderate, linear; the change comes halfway, with the tile edge on.
        property real phase: 1

        onPhaseChanged: {
            if (phase >= 0.5)
                news.turnOver();
        }
    }

    NumberAnimation {
        id: flipRun

        objectName: "flipRun"
        target: flip
        property: "phase"
        from: 0
        to: 1
        duration: Tokens.durationModerate
    }
}
