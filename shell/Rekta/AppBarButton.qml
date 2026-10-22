pragma ComponentBehavior: Bound

import QtQuick

// A control of the app bar (navigation.md, "App bar"; rekta.css:621–629, :1025): a glyph and a word, never a glyph
// alone, at least 48px square in every density, no frame; hover and press lay `hover` under it. A click gives no focus,
// so the ring shows only for the keyboard. A control that cannot act stays focusable and is read with its reason; the
// reason shows as its tooltip and moves into "more" with it. A deliberate deviation: Rekta puts a hint beside it and no
// tooltip (forms.md, "Disabled controls say why"), which here takes the room of the bar's middle. A count follows the
// word ("meldungen 3"); a new count peeks in as a live tile's news does (motion.md, "Live tile news"; rekta.js
// tileUpdate()): the old one leaves upwards over 0.6 × duration-moderate while the new one rises from below over 0.8 ×,
// after 0.2 ×.
Item {
    id: control

    property string icon
    property string text
    // 0 shows none.
    property int count: 0
    readonly property string words: count > 0 ? `${text} ${count}` : text
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
    Accessible.name: words
    Accessible.description: disabledReason
    Accessible.onPressAction: click()

    // The first count is no news.
    Component.onCompleted: {
        peek.now = count;
        peek.ready = true;
    }
    onCountChanged: {
        if (!peek.ready)
            return;
        peek.was = peek.now;
        peek.now = count;
        peekRun.restart();
    }

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
        readonly property real content: control.face ? control.face.implicitWidth : glyph + label.implicitWidth + figure.implicitWidth

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

        // The space before the count belongs to it, so at 0 the word stands alone.
        CountText {
            id: figure

            objectName: "count"
            value: peek.now
            opacity: peek.rising
            transform: Translate {
                y: Geometry.peekShift * figure.height * (1 - peek.rising)
            }
        }

        CountText {
            id: ghost

            objectName: "ghost"
            value: peek.was
            visible: peekRun.running
            opacity: 1 - peek.leaving
            Accessible.ignored: true
            transform: Translate {
                y: -Geometry.peekShift * ghost.height * peek.leaving
            }
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

    component CountText: Text {
        property int value

        visible: !control.face && value > 0
        x: label.x + label.implicitWidth
        anchors.verticalCenter: parent.verticalCenter
        text: value > 0 ? ` ${value}` : ""
        font.family: Tokens.fontSans
        font.pixelSize: Tokens.fontSizeXs
        font.weight: Tokens.fontWeightSemibold
        font.features: ({ "tnum": 1 })
        color: control.ink
    }

    // The count as it was and as it is; phase runs 0 to 1, linear, and each count eases its own share of it.
    QtObject {
        id: peek

        objectName: "peek"
        property bool ready: false
        property int was: 0
        property int now: 0
        property real phase: 1
        readonly property easingCurve easeOut: ({ type: Easing.Bezier, bezierCurve: Tokens.easeOut })
        readonly property easingCurve easeIn: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })
        readonly property real leaving: easeOut.valueForProgress(Math.min(1, phase / 0.6))
        readonly property real rising: easeIn.valueForProgress(Math.max(0, (phase - 0.2) / 0.8))
    }

    NumberAnimation {
        id: peekRun

        objectName: "peekRun"
        target: peek
        property: "phase"
        from: 0
        to: 1
        duration: Tokens.durationModerate
    }
}
