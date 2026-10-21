import QtQuick
import QtQuick.Shapes

// A sparkline (tiles.md, "Tile content patterns"; data.md, "Sparklines"; rekta.css:136–145): a trend at a glance, one
// series, no axis. It is drawn in a 200 × 28 box scaled to its width, stroke and all, in the tile's text colour; a
// finished (success) tile drops it, since stillness means done. It draws in when its place arrives; new values on as
// many points move the line to them (motion.md, "Data morph"); while its live region is stale or offline it fades.
Item {
    id: spark

    property list<real> values
    // What it traces and how, read by screen readers ("frames a second: 60, rising").
    property string label
    property color ink: Tokens.color.textPrimary
    // True while its live region is stale or offline (live.md, "Stale says so").
    property bool stale: false
    // False for a line that stands from the start, as a finished item's does (`.rk-spark--static`).
    property bool drawsIn: true
    readonly property Tile tile: (parent?.parent ?? null) as Tile
    // How its place arrives, as Tile.arrival; in a tile, the tile's.
    property string arrival: tile ? tile.arrival : ""
    readonly property var drawnPoints: prefix(between(morph.from, morph.to, morph.progress), drawIn.progress).map(p => Qt.point(p.x, p.y))

    // The points in box units, inset by half the stroke so a flat line is never cut off: no values draw nothing, a
    // constant series (one value among them) lies flat along the bottom (data.md, "Sparklines").
    function layout(series: list<real>): var {
        const readings = Array.from(series);
        const inset = Geometry.sparkStroke / 2;
        const across = Geometry.sparkBoxWidth - 2 * inset;
        const bottom = Geometry.sparkBoxHeight - inset;
        if (readings.length === 1)
            return [{ x: inset, y: bottom }, { x: inset + across, y: bottom }];
        const lo = Math.min(...readings);
        const span = Math.max(...readings) - lo;
        const rise = v => span > 0 ? (v - lo) / span * (Geometry.sparkBoxHeight - 2 * inset) : 0;
        return readings.map((v, i) => ({ x: inset + i * across / (readings.length - 1), y: bottom - rise(v) }));
    }

    function between(from: var, to: var, progress: real): var {
        if (progress >= 1 || from.length !== to.length)
            return to;
        return to.map((p, i) => ({ x: from[i].x + (p.x - from[i].x) * progress, y: from[i].y + (p.y - from[i].y) * progress }));
    }

    // The first share of the line by its length: how far it has drawn in (`stroke-dashoffset` along pathLength 1).
    function prefix(points: var, share: real): var {
        if (share >= 1 || points.length < 2)
            return share > 0 ? points : [];
        const lengths = points.slice(1).map((p, i) => Math.hypot(p.x - points[i].x, p.y - points[i].y));
        let left = share * lengths.reduce((sum, length) => sum + length, 0);
        const drawn = [points[0]];
        for (let i = 0; i < lengths.length && left > 0; i++) {
            const k = Math.min(1, left / lengths[i]);
            drawn.push({ x: points[i].x + (points[i + 1].x - points[i].x) * k, y: points[i].y + (points[i + 1].y - points[i].y) * k });
            left -= lengths[i];
        }
        return drawn;
    }

    // As many points as before travel to their new places, eased from wherever the line is now; any other count is
    // drawn again at once (rekta.js sparkTo(), :3477–3492).
    function moveTo(next: var) {
        const now = between(morph.from, morph.to, morph.progress);
        morphRun.stop();
        if (now.length === 0 || now.length !== next.length) {
            morph.from = next;
            morph.to = next;
            morph.progress = 1;
            return;
        }
        morph.from = now;
        morph.to = next;
        morphRun.restart();
    }

    // It draws in once while its place arrives, after a turn as well; a place that has arrived shows it whole.
    function followArrival() {
        if (arrival === "") {
            drawInRun.complete();
            drawIn.armed = false;
            return;
        }
        if (drawIn.armed)
            return;
        drawIn.armed = true;
        if (drawsIn)
            drawInRun.restart();
    }

    onValuesChanged: moveTo(layout(values))
    onArrivalChanged: followArrival()
    Component.onCompleted: {
        const points = layout(values);
        morph.from = points;
        morph.to = points;
        followArrival();
    }

    width: parent ? parent.width : 0
    height: width * Geometry.sparkBoxHeight / Geometry.sparkBoxWidth
    visible: !tile || tile.status !== "success"
    opacity: stale ? Geometry.sparkStaleOpacity : 1
    Accessible.role: Accessible.Graphic
    Accessible.name: label

    Behavior on opacity {
        NumberAnimation {
            duration: Tokens.durationShort
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeBase
        }
    }

    QtObject {
        id: morph

        objectName: "morph"
        property var from: []
        property var to: []
        property real progress: 1
    }

    NumberAnimation {
        id: morphRun

        objectName: "morphRun"
        target: morph
        property: "progress"
        from: 0
        to: 1
        duration: Tokens.durationLong
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeBase
    }

    QtObject {
        id: drawIn

        objectName: "drawIn"
        property real progress: 1
        property bool armed: false
    }

    NumberAnimation {
        id: drawInRun

        objectName: "drawInRun"
        target: drawIn
        property: "progress"
        from: 0
        to: 1
        duration: Tokens.durationLong
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
    }

    Shape {
        width: Geometry.sparkBoxWidth
        height: Geometry.sparkBoxHeight
        scale: spark.width / Geometry.sparkBoxWidth
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            objectName: "line"
            strokeColor: spark.ink
            strokeWidth: Geometry.sparkStroke
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.FlatCap

            PathPolyline {
                path: spark.drawnPoints
            }
        }
    }
}
