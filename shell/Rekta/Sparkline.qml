import QtQuick
import QtQuick.Shapes

// A sparkline (tiles.md, "Tile content patterns"; data.md, "Sparklines"; rekta.css:225–237): a trend at a glance, one
// series, no axis. It is drawn in a box 200 : 28 as wide as it is given, but its line stays 2px on the screen at any
// width, in the tile's text colour; a finished (success) tile drops it, since stillness means done. It draws in when
// its place arrives, uncovered from the leading edge; new values on as many points move the line to them (motion.md,
// "Data morph"); while its live region is stale or offline it fades.
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
    readonly property var drawnPoints: onScreen(between(morph.from, morph.to, morph.progress)).map(p => Qt.point(p.x, p.y))

    // The points as shares of the area inside the box inset by half the stroke (x from the leading edge, y from the top):
    // no values draw nothing, a constant series (one value among them) lies flat along the bottom (data.md, "Sparklines").
    function layout(series: list<real>): var {
        const readings = Array.from(series);
        if (readings.length === 1)
            return [{ x: 0, y: 1 }, { x: 1, y: 1 }];
        const lo = Math.min(...readings);
        const span = Math.max(...readings) - lo;
        const rise = v => span > 0 ? (v - lo) / span : 0;
        return readings.map((v, i) => ({ x: i / (readings.length - 1), y: 1 - rise(v) }));
    }

    // The shares laid on the screen: 1px clear of the box on every side, whatever the width (data.md, "Clear of the
    // hairline").
    function onScreen(points: var): var {
        const inset = Geometry.sparkStroke / 2;
        return points.map(p => ({ x: inset + p.x * (width - 2 * inset), y: inset + p.y * (height - 2 * inset) }));
    }

    function between(from: var, to: var, progress: real): var {
        if (progress >= 1 || from.length !== to.length)
            return to;
        return to.map((p, i) => ({ x: from[i].x + (p.x - from[i].x) * progress, y: from[i].y + (p.y - from[i].y) * progress }));
    }

    // As many points as before travel to their new places, eased from wherever the line is now; any other count is
    // drawn again at once (rekta.js sparkTo(), :4261–4276).
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

    // `clip-path: inset(-2px)` grows from the leading edge, 2px over all around (rekta.css:233, :237).
    Item {
        objectName: "wipe"
        x: -Geometry.sparkWipeOverhang
        y: -Geometry.sparkWipeOverhang
        width: Geometry.sparkWipeOverhang + (spark.width + Geometry.sparkWipeOverhang) * drawIn.progress
        height: spark.height + 2 * Geometry.sparkWipeOverhang
        clip: true

        Shape {
            objectName: "shape"
            x: Geometry.sparkWipeOverhang
            y: Geometry.sparkWipeOverhang
            width: spark.width
            height: spark.height
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
}
