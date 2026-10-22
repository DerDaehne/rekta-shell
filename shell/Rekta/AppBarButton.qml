import QtQuick

// A control of the app bar (navigation.md, "App bar"; rekta.css:621–629, :1025): a glyph and a word, never a glyph
// alone, at least 48px square in every density, no frame; hover and press lay `hover` under it. A click gives no focus,
// so the ring shows only for the keyboard. A control that cannot act stays focusable and says why beside it, and the
// reason moves into "more" with it (forms.md, "Disabled controls say why").
Item {
    id: control

    property string icon
    property string text
    property string disabledReason
    // Higher stays longer when the bar is full; the least important moves into "more" first (rekta.js appbar()).
    property int priority: 0
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

    // The reason counts while the control is moved too (visible is the effective visibility), so it moves back whole.
    implicitWidth: box.width + (disabled ? Tokens.spaceXs + Math.ceil(why.implicitWidth) : 0)
    implicitHeight: box.height
    visible: !overflowed
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.description: disabledReason
    Accessible.onPressAction: click()

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

        readonly property real glyph: control.icon !== "" ? Geometry.appBarGlyph + Geometry.appBarControlGap : 0

        objectName: "box"
        // The words' baseline, so the reason beside it sits on the same line.
        baselineOffset: label.y + label.baselineOffset
        // Whole pixels, so the bar sets its controls on whole pixels.
        width: Math.ceil(Math.max(Geometry.appBarControl, glyph + label.implicitWidth + 2 * Geometry.appBarControlPadding))
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
            visible: control.icon !== ""
            name: control.icon
            size: Geometry.appBarGlyph
            color: control.ink
        }

        Text {
            id: label

            objectName: "label"
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
        }

        HoverHandler {
            id: hover

            cursorShape: control.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
        }
    }

    Hint {
        id: why

        objectName: "why"
        x: box.width + Tokens.spaceXs
        anchors.baseline: box.baseline
        visible: control.disabled
        text: control.disabledReason
        // One line in the bar; the bar moves the whole control into "more" before it would wrap.
        wrapMode: Text.NoWrap
    }
}
