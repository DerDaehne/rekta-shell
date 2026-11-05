import QtQuick

// Live tile news (motion.md, "Live tile news"; rekta.js tileUpdate(), :4181–4215), over duration-moderate. A peek, for a
// new number: the part that peeks as it was leaves upwards over 0.6 × that while the new one rises from below over 0.8 ×,
// after 0.2 ×. A flip, for a new status: the tile turns away around its horizontal axis over the first half, changes, and
// turns back. A continuous reading is no news and changes in place. While held, news waits, and comes in one step when
// the tile is let go (live.md, "Holding still").
Item {
    id: news

    // The tile's content; its first visible stat is what a peek moves, unless the tile marks a part.
    required property Item content
    // The part the tile marks to peek (rekta.js:4200), a count.
    property TextRole marked: null
    property bool held: false
    readonly property bool peeking: peek.target !== null
    // How far the flip has turned the tile around its horizontal axis, in degrees (as CSS rotateX).
    readonly property real flipAngle: flip.phase < 0.5 ? -Tokens.flipAngle * easeOut.valueForProgress(flip.phase * 2) : Tokens.flipAngle * (1 - easeIn.valueForProgress(flip.phase * 2 - 1))
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

    // The first visible stat in the content, also one that a row or box inside it holds.
    function firstStat(): Stat {
        return statIn(content);
    }

    function statIn(parent: Item): Stat {
        for (const item of parent.children) {
            if (!item.visible)
                continue;
            const stat = (item as Stat) ?? statIn(item);
            if (stat)
                return stat;
        }
        return null;
    }

    // What a part says, to tell whether the news changed it.
    function said(part: Item): string {
        const stat = part as Stat;
        return stat ? `${stat.value}\n${stat.label}` : (part as TextRole).text;
    }

    // The part as it was, to leave in its place.
    function copy(part: Item) {
        const stat = part as Stat;
        if (stat) {
            ghost.value = stat.value;
            ghost.label = stat.label;
            ghost.placeWidth = stat.placeWidth;
            ghost.width = stat.width;
            return;
        }
        markedGhost.text = marked.text;
        markedGhost.font = marked.font;
        markedGhost.color = marked.color;
        markedGhost.lineHeightFactor = marked.lineHeightFactor;
        markedGhost.width = marked.width;
    }

    function startPeek(change: var) {
        const part = marked ?? firstStat();
        if (!part) {
            change();
            return;
        }
        const was = said(part);
        copy(part);
        peek.at = part.mapToItem(news, 0, 0);
        change();
        // A part that is gone after the change has no new number to bring in.
        if (!part.visible || said(part) === was)
            return;
        peek.target = part;
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
    // tile does (core/src/declare.c:667).
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
        property Item target: null
        readonly property bool ofStat: (target as Stat) !== null
        // Where the part stands in the tile.
        property point at
        // 0 to 1 over duration-moderate, linear; each part eases its own share of it.
        property real phase: 1
        readonly property real leaving: news.easeOut.valueForProgress(Math.min(1, phase / Geometry.peekOutShare))
        readonly property real rising: news.easeIn.valueForProgress(Math.max(0, (phase - Geometry.peekInDelay) / Geometry.peekInShare))
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

    // The stat or the marked part as it was, where it was, leaving through the tile's edge.
    Stat {
        id: ghost

        objectName: "ghost"
        visible: news.peeking && peek.ofStat
        x: peek.at.x
        y: peek.at.y
        opacity: 1 - peek.leaving
        Accessible.ignored: true
        transform: Translate {
            y: -Tokens.peekTravel * ghost.height * peek.leaving
        }
    }

    TextRole {
        id: markedGhost

        objectName: "markedGhost"
        visible: news.peeking && !peek.ofStat
        x: peek.at.x
        y: peek.at.y
        opacity: 1 - peek.leaving
        Accessible.ignored: true
        transform: Translate {
            y: -Tokens.peekTravel * markedGhost.height * peek.leaving
        }
    }

    // The new one, drawn in its place while it rises; the part itself stays where its tile puts it.
    ShaderEffectSource {
        objectName: "incoming"
        visible: news.peeking
        sourceItem: peek.target
        hideSource: news.peeking
        x: peek.at.x
        y: peek.at.y + Tokens.peekTravel * height * (1 - peek.rising)
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
