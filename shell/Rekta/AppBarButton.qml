import QtQuick

// A control of the app bar (navigation.md, "App bar"; rekta.css:621–629, :1025): a glyph and a word, never a glyph
// alone, at least 48px square in every density, no frame; hover and press lay `hover` under it. A click gives no focus,
// so the ring shows only for the keyboard. A control that cannot act stays focusable and is read with its reason; the
// reason shows as its tooltip and moves into "more" with it. A deliberate deviation: Rekta puts a hint beside it and no
// tooltip (forms.md, "Disabled controls say why"), which here takes the room of the bar's middle.
Item {
    id: control

    property string icon
    property string text
    property string disabledReason
    // Higher stays longer when the bar is full; the least important moves into "more" first (rekta.js appbar()).
    property int priority: 0
    // Shown instead of the glyph and the word, from the padding on, such as a clock's two lines; `text` still names it.
    property Item face: null
    // Moved into "more"; the bar sets it.
    property bool overflowed: false
    readonly property bool disabled: disabledReason !== ""
    readonly property bool hovered: hover.hovered
    readonly property bool pressed: tap.pressed
    readonly property color ink: disabled ? Tokens.color.disabled : Tokens.color.textPrimary

    signal clicked

    // Every way of pressing the control ends here; it acts only when it may.
    function click() {
        if (!disabled)
            clicked();
    }

    implicitWidth: box.width
    implicitHeight: box.height
    visible: !overflowed
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.description: disabledReason
    Accessible.onPressAction: click()

    // Focus comes only from the keyboard, so the reason shows at once.
    onActiveFocusChanged: {
        if (!disabled)
            return;
        if (activeFocus)
            Tips.show(box, disabledReason);
        else
            Tips.leave(box);
    }

    onFaceChanged: {
        if (face)
            face.parent = box;
    }

    Keys.onPressed: event => {
        if (![Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].includes(event.key))
            return;
        event.accepted = true;
        // A held key acts once.
        if (!event.isAutoRepeat)
            click();
    }

    Item {
        id: box

        readonly property real glyph: control.icon !== "" && !control.face ? Geometry.appBarGlyph + Geometry.appBarControlGap : 0
        readonly property real content: control.face ? control.face.implicitWidth : glyph + label.implicitWidth

        objectName: "box"
        // Whole pixels, so the bar sets its controls on whole pixels.
        width: Math.ceil(Math.max(Geometry.appBarControl, content + 2 * Geometry.appBarControlPadding))
        height: Geometry.appBarControl

        Rectangle {
            objectName: "press"
            anchors.fill: parent
            radius: Tokens.radiusS
            color: Tokens.color.hover
            opacity: (control.hovered || control.pressed) && !control.disabled ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.durationShort
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.easeBase
                }
            }
        }

        Icon {
            objectName: "glyph"
            x: Geometry.appBarControlPadding
            anchors.verticalCenter: parent.verticalCenter
            visible: box.glyph > 0
            name: control.icon
            size: Geometry.appBarGlyph
            color: control.ink
        }

        Text {
            id: label

            objectName: "label"
            visible: !control.face
            x: Geometry.appBarControlPadding + box.glyph
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.fontSizeXs
            font.weight: Tokens.fontWeightSemibold
            color: control.ink
        }

        FocusRing {
            shown: control.activeFocus
        }

        TapHandler {
            id: tap

            // A slow click is still a click.
            longPressThreshold: 0

            onTapped: control.click()
            onPressedChanged: {
                if (pressed)
                    Tips.hide();
            }
        }

        HoverHandler {
            id: hover

            cursorShape: control.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor

            // Only a mouse or pen hovers, so touch never brings the reason.
            onHoveredChanged: {
                if (!control.disabled)
                    return;
                if (hovered)
                    Tips.rest(box, control.disabledReason);
                else
                    Tips.leave(box);
            }
        }
    }
}
