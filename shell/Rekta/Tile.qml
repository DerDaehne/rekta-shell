import QtQuick
import "Status.js" as Status

// A tile (tiles.md; rekta.css:81–94, :115–125): its whole area is one fill, and the fill is its status. It opens
// something or it only informs; it never changes data. A tile that opens nudges back where it is pressed, by up to
// tile-tilt, and shrinks to tile-press-scale (motion.md, "Press"; rekta.js press()). Its content sits at the bottom.
// It builds in when its place arrives (motion.md, "Tiles building in"), and news() shows what is new (TileNews).
Item {
    id: tile

    // info | success | warning | error, or "" for none (the neutral surface)
    property string status: ""
    // The word that spells the status out, top right (tiles.md, "Status word").
    property string word: status !== "" ? Status.word(status) : ""
    // True for a tile that opens a place or a sheet; false for one that only informs.
    property bool opens: false
    property int columns: 1
    property int rows: 1
    // How its place arrives (behaviour.md, `data-rk-arriving`), set by the place: "arriving" builds the tile in,
    // "turned" does not (the turn was the arrival; sparklines still draw in), "" once the arrival is over.
    property string arrival: ""
    // Its place in the build-in order; past ten tiles they rise together.
    property int buildIndex: 0
    // True while its live region holds still: news waits (live.md, "Holding still").
    property bool held: false
    // On a status fill only the primary text colour clears AA; Status.secondaryInk() reads this (rekta.css:63–65).
    readonly property bool statusFill: status !== ""
    // A place turn keeps the tile that opened the next place pressed until it turns away (rekta.js turn.leave()).
    property bool kept: false
    readonly property bool pressed: press.held || kept
    // Where it was pressed, -1 to 1 from the centre; 0 0 for the keyboard.
    readonly property real pressX: press.x
    readonly property real pressY: press.y
    // How far it has sunk, 0 to 1, eased like a CSS transition: in over duration-press, back over duration-short.
    // Not bound to `pressed`, or sink moves before the Behavior's duration does and lets go in duration-press.
    property real sink: (press.held || kept) ? 1 : 0
    // The tilt the sink has reached, in degrees; none under reduced motion, where a press only shrinks (rekta.css:1211).
    readonly property real tiltX: Tokens.reducedMotion ? 0 : -pressY * sink * Tokens.tileTilt
    readonly property real tiltY: Tokens.reducedMotion ? 0 : pressX * sink * Tokens.tileTilt
    readonly property real pressScale: 1 - sink * (1 - Tokens.tilePressScale)
    default property alias content: column.data
    // The content patterns it shows, the status word among them (tiles.md, "Tile content patterns").
    readonly property int patterns: {
        let count = word !== "" ? 1 : 0;
        for (const item of column.children) {
            if (item.visible && ((item as Stat) || (item as Sparkline) || (item as Progress) || (item as TileMessage)))
                count++;
        }
        return count;
    }

    // A place change turns a tile as one part (motion.md, "Place change").
    readonly property bool turnsWhole: true

    signal activated

    // Keeps the press until the place turn takes the tile away; one activated without a press sinks now, in its
    // centre (rekta.js turn.leave()). Returns how long it still sinks, in ms.
    function keepPressed(): real {
        if (!press.held)
            press.start(0, 0);
        kept = true;
        return Math.max(0, Tokens.durationPress - (Date.now() - press.since));
    }

    // A tile combines at most two or three patterns; past that it has become a page that needs its own screen.
    function warnIfCrowded() {
        if (patterns > 3)
            console.warn(`Tile: ${patterns} content patterns; a tile combines at most two or three, more needs a place of its own (tiles.md)`);
    }

    // Live tile news: kind "peek" for a new number, "flip" for a new status, "" for a continuous reading; change()
    // makes the change at the moment the motion needs it.
    function news(kind: string, change: var) {
        liveNews.tell(kind, change);
    }

    // Only an arriving place builds in: never after a turn, never for new live data. Each tile rises duration-stagger
    // after the one before it, from ten on all together (rekta.css:91).
    function followArrival() {
        if (arrival !== "arriving") {
            buildInRun.complete();
            return;
        }
        buildIn.progress = 0;
        buildInRun.restart();
    }

    onPatternsChanged: warnIfCrowded()
    onArrivalChanged: followArrival()
    Component.onCompleted: followArrival()

    implicitWidth: columns * Tokens.tileUnit + (columns - 1) * Tokens.spaceS
    implicitHeight: rows * Tokens.tileUnit + (rows - 1) * Tokens.spaceS
    opacity: buildIn.progress
    // A peek's old number leaves through the tile's edge.
    clip: liveNews.peeking
    activeFocusOnTab: opens
    Accessible.role: opens ? Accessible.Button : Accessible.Grouping
    Accessible.description: word
    Accessible.onPressAction: {
        if (opens)
            activated();
    }

    Behavior on sink {
        NumberAnimation {
            duration: tile.pressed ? Tokens.durationPress : Tokens.durationShort
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeBase
        }
    }

    // translateY(build-in rise) perspective(turnstile-perspective) rotateX(-py · tilt + flip) rotateY(px · tilt)
    // scale(press-scale) around the centre (rekta.css:110, :115–116), flattened to the item's plane as Qt's own
    // Rotation does.
    transform: Matrix4x4 {
        matrix: {
            const rad = Math.PI / 180;
            const ax = (tile.tiltX + liveNews.flipAngle) * rad;
            const ay = tile.tiltY * rad;
            const s = tile.pressScale;
            const cx = tile.width / 2;
            const cy = tile.height / 2;
            const toCentre = Qt.matrix4x4(1, 0, 0, -cx, 0, 1, 0, -cy, 0, 0, 1, 0, 0, 0, 0, 1);
            const back = Qt.matrix4x4(1, 0, 0, cx, 0, 1, 0, cy + (1 - buildIn.progress) * Geometry.buildInRise, 0, 0, 1, 0, 0, 0, 0, 1);
            const perspective = Qt.matrix4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, -1 / Tokens.turnstilePerspective, 1);
            const rotateX = Qt.matrix4x4(1, 0, 0, 0, 0, Math.cos(ax), -Math.sin(ax), 0, 0, Math.sin(ax), Math.cos(ax), 0, 0, 0, 0, 1);
            const rotateY = Qt.matrix4x4(Math.cos(ay), 0, Math.sin(ay), 0, 0, 1, 0, 0, -Math.sin(ay), 0, Math.cos(ay), 0, 0, 0, 0, 1);
            const scale = Qt.matrix4x4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1);
            return back.times(perspective).times(rotateX).times(rotateY).times(scale).times(toCentre);
        }
    }

    Rectangle {
        objectName: "fill"
        anchors.fill: parent
        radius: Tokens.radiusTile
        color: {
            switch (tile.status) {
            case "info":
                return Tokens.color.statusInfoTile;
            case "success":
                return Tokens.color.statusSuccessTile;
            case "warning":
                return Tokens.color.statusWarningTile;
            case "error":
                return Tokens.color.statusErrorTile;
            default:
                return Tokens.color.surface;
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Tokens.durationShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeBase
            }
        }

        // Hover tints a tile that opens (rekta.css:1019); it is an image in the stylesheet, so it changes at once.
        Rectangle {
            objectName: "tint"
            anchors.fill: parent
            radius: parent.radius
            visible: tile.opens && hover.hovered
            color: Tokens.color.hover
        }
    }

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Geometry.tilePadding
        spacing: Tokens.spaceS
    }

    TileNews {
        id: liveNews

        objectName: "news"
        anchors.fill: parent
        content: column
        held: tile.held
    }

    Text {
        objectName: "word"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Geometry.tileWordTop
        anchors.rightMargin: Geometry.tileWordRight
        visible: text !== ""
        text: tile.word
        font.family: Tokens.fontSans
        font.pixelSize: Tokens.fontSizeXs
        font.weight: Tokens.fontWeightSemibold
        color: Tokens.color.textPrimary
    }

    // On a fill the ring sits inside in the text colour (rekta.css:93).
    FocusRing {
        onFill: true
        ink: Tokens.color.textPrimary
        shown: tile.activeFocus
    }

    HoverHandler {
        id: hover

        enabled: tile.opens
        cursorShape: Qt.PointingHandCursor
    }

    Keys.onPressed: event => {
        if (!opens || (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space))
            return;
        event.accepted = true;
        if (event.isAutoRepeat)
            return;
        press.start(0, 0);
        // Enter acts as it goes down, the space bar as it comes up, as a link and a button do.
        if (event.key !== Qt.Key_Space)
            activated();
    }
    Keys.onReleased: event => {
        if (!opens || (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) || event.isAutoRepeat)
            return;
        event.accepted = true;
        if (event.key === Qt.Key_Space && press.held)
            activated();
        press.release(false);
    }

    // Enter may open something that takes the focus; the press still plays out, as rekta.js lets go on any keyup
    // and no sooner than duration-press.
    onActiveFocusChanged: {
        if (!activeFocus)
            press.release(false);
    }

    // The press, after rekta.js press() (:255–330): a mouse presses at once, a finger after tap-delay; moving past the
    // slop gives up; a quick tap still shows the whole sink, since the press lets go no sooner than duration-press.
    QtObject {
        id: press

        objectName: "press"
        property bool held: false
        property real x: 0
        property real y: 0
        property double since: 0

        function start(px: real, py: real) {
            letGo.stop();
            x = px;
            y = py;
            since = Date.now();
            held = true;
        }

        function release(now: bool) {
            const wait = now ? 0 : Math.max(0, Tokens.durationPress - (Date.now() - since));
            if (wait === 0) {
                letGo.stop();
                held = false;
                return;
            }
            letGo.interval = wait;
            letGo.restart();
        }
    }

    // Building in: 0 to 1 over duration-moderate, eased in; it fades up and rises by buildInRise. Before its turn
    // comes it waits unseen, as the CSS animation fills backwards.
    QtObject {
        id: buildIn

        objectName: "buildIn"
        property real progress: 1
    }

    SequentialAnimation {
        id: buildInRun

        objectName: "buildInRun"

        PauseAnimation {
            duration: Math.min(tile.buildIndex, Geometry.buildInStaggerCap) * Tokens.durationStagger
        }
        NumberAnimation {
            target: buildIn
            property: "progress"
            from: 0
            to: 1
            duration: Tokens.durationModerate
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeIn
        }
    }

    Timer {
        id: letGo

        onTriggered: press.held = false
    }

    Timer {
        id: tapDelay

        interval: Tokens.durationTapDelay
        onTriggered: area.pressAtStart()
    }

    // While pressed, the hit area reaches space-m past the tile, so a release on an edge that sank away still lands
    // (rekta.css:119–123). A press there before the tile is pressed belongs to whatever lies beneath. A scroller around
    // the tile may take a drag over, as a page scrolls under a finger; the press then gives up.
    MouseArea {
        id: area

        property point start
        property bool touch: false
        property bool moved: false

        function pressAtStart() {
            press.start(Math.max(-1, Math.min(1, (start.x - Tokens.spaceM) / tile.width * 2 - 1)), Math.max(-1, Math.min(1, (start.y - Tokens.spaceM) / tile.height * 2 - 1)));
        }

        anchors.fill: parent
        anchors.margins: -Tokens.spaceM
        enabled: tile.opens

        onPressed: mouse => {
            const inside = mouse.x >= Tokens.spaceM && mouse.x <= width - Tokens.spaceM && mouse.y >= Tokens.spaceM && mouse.y <= height - Tokens.spaceM;
            if (!inside || mouse.button !== Qt.LeftButton) {
                mouse.accepted = false;
                return;
            }
            start = Qt.point(mouse.x, mouse.y);
            touch = mouse.source !== Qt.MouseEventNotSynthesized;
            moved = false;
            if (touch)
                tapDelay.restart();
            else
                pressAtStart();
        }
        onPositionChanged: mouse => {
            if (moved || Math.hypot(mouse.x - start.x, mouse.y - start.y) <= (touch ? Geometry.pressSlopTouch : Geometry.pressSlopMouse))
                return;
            // Dragging, or selecting, never activates.
            moved = true;
            tapDelay.stop();
            press.release(true);
        }
        onReleased: mouse => {
            if (tapDelay.running) {
                tapDelay.stop();
                pressAtStart();
            }
            const landed = !moved && mouse.x >= 0 && mouse.x <= width && mouse.y >= 0 && mouse.y <= height;
            press.release(false);
            if (landed)
                tile.activated();
        }
        onCanceled: {
            tapDelay.stop();
            moved = true;
            press.release(true);
        }
    }
}
