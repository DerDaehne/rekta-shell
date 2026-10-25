import QtQuick

// One row of a long list (rekta.css:466–476): an icon and its text at the density's row height, on a hairline. Chosen,
// it takes the accent fill with on-accent text, loses its hairline and shows a checkmark in its leading padding, at
// once, as a row drawn again while scrolling does (motion.md, "Checkmark"). It nudges where it is pressed, by up to
// row-tilt, and shrinks to row-press-scale; under reduced motion it only shrinks (rekta.css:726–733, :1212).
Item {
    id: row

    property string text
    // An image URL for its icon, empty for none.
    property string icon
    property bool chosen: false
    // Shows the focus ring inside: the row the keys are on, while the list has the focus.
    property bool ringed: false
    property bool held: false
    // Where it was pressed, -1 to 1 from the centre; 0 0 for the keyboard.
    property real pressX: 0
    property real pressY: 0
    property double since: 0
    // How far it has sunk, 0 to 1, eased like a CSS transition: in over duration-press, back over duration-short.
    property real sink: held ? 1 : 0
    readonly property real tilt: Tokens.reducedMotion ? 0 : sink * Tokens.rowTilt
    readonly property color ink: chosen ? Tokens.color.textOnAccent : Tokens.color.textPrimary
    // A place change turns a row as one part (motion.md, "Place change").
    readonly property bool turnsWhole: true

    signal clicked

    function press(x: real, y: real) {
        letGo.stop();
        pressX = x;
        pressY = y;
        since = Date.now();
        held = true;
    }

    // Lets go now, or no sooner than duration-press after the press began, so a quick click shows the whole sink.
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

    implicitHeight: Tokens.rowHeight
    Accessible.role: Accessible.ListItem
    Accessible.name: text
    Accessible.selected: chosen

    Behavior on sink {
        id: sinking

        NumberAnimation {
            // The Behavior knows where it goes before a binding on `held` may have updated.
            duration: sinking.targetValue > 0 ? Tokens.durationPress : Tokens.durationShort
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeBase
        }
    }

    // perspective(turnstile-perspective) rotateX(-py · tilt) rotateY(px · tilt) scale(press-scale) around the centre
    // (rekta.css:731), flattened to the item's plane as Qt's own Rotation does.
    transform: Matrix4x4 {
        matrix: {
            const rad = Math.PI / 180;
            const ax = -row.pressY * row.tilt * rad;
            const ay = row.pressX * row.tilt * rad;
            const s = 1 - row.sink * (1 - Tokens.rowPressScale);
            const cx = row.width / 2;
            const cy = row.height / 2;
            const toCentre = Qt.matrix4x4(1, 0, 0, -cx, 0, 1, 0, -cy, 0, 0, 1, 0, 0, 0, 0, 1);
            const back = Qt.matrix4x4(1, 0, 0, cx, 0, 1, 0, cy, 0, 0, 1, 0, 0, 0, 0, 1);
            const perspective = Qt.matrix4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, -1 / Tokens.turnstilePerspective, 1);
            const rotateX = Qt.matrix4x4(1, 0, 0, 0, 0, Math.cos(ax), -Math.sin(ax), 0, 0, Math.sin(ax), Math.cos(ax), 0, 0, 0, 0, 1);
            const rotateY = Qt.matrix4x4(Math.cos(ay), 0, Math.sin(ay), 0, 0, 1, 0, 0, -Math.sin(ay), 0, Math.cos(ay), 0, 0, 0, 0, 1);
            const scale = Qt.matrix4x4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1);
            return back.times(perspective).times(rotateX).times(rotateY).times(scale).times(toCentre);
        }
    }

    // The accent comes over duration-short; from the accent made clear, so only its alpha moves (CSS transitions mix
    // premultiplied colours, Qt's do not).
    Rectangle {
        objectName: "fill"
        anchors.fill: parent
        color: row.chosen ? Tokens.color.accent : Qt.rgba(Tokens.color.accent.r, Tokens.color.accent.g, Tokens.color.accent.b, 0)

        Behavior on color {
            ColorAnimation {
                duration: Tokens.durationShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeBase
            }
        }
    }

    // Hover tints the row over its fill (rekta.css:1036).
    Rectangle {
        objectName: "tint"
        anchors.fill: parent
        visible: hover.hovered
        color: Tokens.color.hover
    }

    Item {
        objectName: "check"
        x: Tokens.spaceXs
        y: row.height / 2 - Geometry.listCheckRaise
        width: Geometry.listCheckWidth
        height: Geometry.listCheckHeight
        rotation: Geometry.listCheckAngle
        visible: row.chosen

        Rectangle {
            width: Geometry.listCheckStroke
            height: parent.height
            color: Tokens.color.textOnAccent
        }

        Rectangle {
            y: parent.height - Geometry.listCheckStroke
            width: parent.width
            height: Geometry.listCheckStroke
            color: Tokens.color.textOnAccent
        }
    }

    Image {
        id: icon

        objectName: "icon"
        x: Geometry.listRowLead + Tokens.spaceS
        anchors.verticalCenter: parent.verticalCenter
        width: Geometry.iconSize
        height: Geometry.iconSize
        sourceSize: Qt.size(width, height)
        source: row.icon
    }

    Body {
        objectName: "text"
        x: icon.x + icon.width + Tokens.spaceM
        width: row.width - x - Tokens.spaceS
        anchors.verticalCenter: parent.verticalCenter
        text: row.text
        color: row.ink
        wrapMode: Text.NoWrap
        maximumLineCount: 1
        elide: Text.ElideRight

        Behavior on color {
            ColorAnimation {
                duration: Tokens.durationShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeBase
            }
        }
    }

    // On a chosen row text-contrast-low turns clear, and with it the hairline (rekta.css:735).
    Hairline {
        objectName: "hairline"
        y: row.height - height
        width: row.width
        visible: !row.chosen
    }

    FocusRing {
        offset: -Geometry.focusRingInsetInRow
        shown: row.ringed
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    Timer {
        id: letGo

        onTriggered: row.held = false
    }

    Timer {
        id: tapDelay

        interval: Tokens.durationTapDelay
        onTriggered: area.pressAtStart()
    }

    // The press, after rekta.js press() (:283–323): a mouse presses at once, a finger after tap-delay, so the start of
    // a scroll never sinks the row; moving past the slop, or the list taking over to scroll, gives up.
    MouseArea {
        id: area

        property point start
        property bool touch: false
        property bool moved: false

        function pressAtStart() {
            row.press(Math.max(-1, Math.min(1, start.x / row.width * 2 - 1)), Math.max(-1, Math.min(1, start.y / row.height * 2 - 1)));
        }

        anchors.fill: parent

        onPressed: mouse => {
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
            moved = true;
            tapDelay.stop();
            row.release(true);
        }
        onReleased: {
            if (tapDelay.running) {
                tapDelay.stop();
                pressAtStart();
            }
            row.release(false);
            if (!moved && containsMouse)
                row.clicked();
        }
        onCanceled: {
            tapDelay.stop();
            moved = true;
            row.release(true);
        }
    }
}
