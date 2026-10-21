import QtQuick
import "Status.js" as Status

// A tile (tiles.md; rekta.css:81–94, :115–125): its whole area is one fill, and the fill is its status. It opens
// something or it only informs; it never changes data. A tile that opens nudges back where it is pressed, by up to
// tile-tilt, and shrinks to tile-press-scale (motion.md, "Press"; rekta.js press()). Its content sits at the bottom.
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
    // On a status fill only the primary text colour clears AA; Status.secondaryInk() reads this (rekta.css:63–65).
    readonly property bool statusFill: status !== ""
    readonly property bool pressed: press.held
    // Where it was pressed, -1 to 1 from the centre; 0 0 for the keyboard.
    readonly property real pressX: press.x
    readonly property real pressY: press.y
    // How far it has sunk, 0 to 1, eased like a CSS transition: in over duration-press, back over duration-short.
    property real sink: press.held ? 1 : 0
    // The tilt the sink has reached, in degrees; none under reduced motion, where a press only shrinks (rekta.css:1211).
    readonly property real tiltX: Tokens.reducedMotion ? 0 : -pressY * sink * Tokens.tileTilt
    readonly property real tiltY: Tokens.reducedMotion ? 0 : pressX * sink * Tokens.tileTilt
    readonly property real pressScale: 1 - sink * (1 - Tokens.tilePressScale)
    default property alias content: column.data
    // The content patterns it shows, the status word among them (tiles.md, "Tile content patterns").
    readonly property int patterns: {
        let count = word !== "" ? 1 : 0;
        for (const item of column.children) {
            if (item.visible && ((item as Stat) || (item as Progress) || (item as TileMessage)))
                count++;
        }
        return count;
    }

    signal activated

    // A tile combines at most two or three patterns; past that it has become a page that needs its own screen.
    function warnIfCrowded() {
        if (patterns > 3)
            console.warn(`Tile: ${patterns} content patterns; a tile combines at most two or three, more needs a place of its own (tiles.md)`);
    }

    onPatternsChanged: warnIfCrowded()

    implicitWidth: columns * Tokens.tileUnit + (columns - 1) * Tokens.spaceS
    implicitHeight: rows * Tokens.tileUnit + (rows - 1) * Tokens.spaceS
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

    // perspective(turnstile-perspective) rotateX(-py · tilt) rotateY(px · tilt) scale(press-scale) around the centre
    // (rekta.css:115–116), flattened to the item's plane as Qt's own Rotation does.
    transform: Matrix4x4 {
        matrix: {
            const rad = Math.PI / 180;
            const ax = tile.tiltX * rad;
            const ay = tile.tiltY * rad;
            const s = tile.pressScale;
            const cx = tile.width / 2;
            const cy = tile.height / 2;
            const toCentre = Qt.matrix4x4(1, 0, 0, -cx, 0, 1, 0, -cy, 0, 0, 1, 0, 0, 0, 0, 1);
            const back = Qt.matrix4x4(1, 0, 0, cx, 0, 1, 0, cy, 0, 0, 1, 0, 0, 0, 0, 1);
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
    // (rekta.css:119–123). A press there before the tile is pressed belongs to whatever lies beneath.
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
        preventStealing: true

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
