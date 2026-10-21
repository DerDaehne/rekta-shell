import QtQuick

// A button (forms.md, "One size of control"; rekta.css:211–231). One height per density; the kind ranks it, not its
// size: the primary takes the accent, a quiet one has no frame, a destructive one is framed in the error colour and
// never filled. A running action says what it does at the same width and runs the line under it (states.md, "Pending
// actions"); a button that cannot act stays focusable and says why beside it (forms.md, "Disabled controls say why").
// A click gives no focus, so the ring shows only for the keyboard, like :focus-visible.
Row {
    id: button

    property string text
    // A glyph before the words; without words the button is square (see IconButton).
    property string icon
    // "" (framed) | primary | quiet | destructive
    property string variant: ""
    property bool pending: false
    property string pendingText: `${text}…`
    property string disabledReason
    // In a list row or a table an icon button takes the row's height.
    property bool inRow: false
    // A running action refuses clicks but keeps its colours (rekta.css:223–225).
    readonly property bool refuses: pending || disabledReason !== ""
    readonly property bool disabled: disabledReason !== "" && !pending
    // In an actions row the row says why, after its controls (rekta.css:290).
    readonly property bool inActions: (parent?.parent as Actions) !== null
    readonly property bool hovered: hover.hovered
    readonly property bool pressed: tap.pressed
    readonly property color ink: {
        if (disabled)
            return Tokens.color.disabled;
        switch (variant) {
        case "primary":
            return Tokens.color.textOnAccent;
        case "destructive":
            return Tokens.color.statusErrorFull;
        case "quiet":
            return hovered ? Tokens.color.textPrimary : Tokens.color.textContrastHigh;
        default:
            return Tokens.color.textPrimary;
        }
    }

    signal clicked

    // Every way of pressing the button ends here; it acts only when it may.
    function click() {
        if (!refuses)
            clicked();
    }

    spacing: Tokens.spaceS
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: pending ? pendingText : text
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

        readonly property bool square: button.text === ""
        readonly property real side: Math.max(button.inRow ? Tokens.rowHeight : Tokens.controlHeight, Prefs.systemHasTouch ? Tokens.touchTarget : 0)
        readonly property real glyph: button.icon !== "" ? Geometry.buttonGlyph + Tokens.spaceS : 0

        objectName: "box"
        anchors.verticalCenter: parent.verticalCenter
        // The words' baseline, so the reason beside it sits on the same line.
        baselineOffset: content.y + label.y + label.baselineOffset
        // Pending keeps at least the width the resting label gave it, like rekta.js pending() sets min-width.
        width: square ? side : Math.max(glyph + resting.implicitWidth, (button.pending ? 0 : glyph) + label.implicitWidth) + 2 * (Tokens.controlPadding + Geometry.buttonBorder)
        height: square ? side : Tokens.controlHeight

        Rectangle {
            objectName: "fill"
            anchors.fill: parent
            radius: Tokens.radiusS
            color: button.variant === "primary" && !button.disabled ? Tokens.color.accent : "transparent"
        }

        // Hover and press lay `hover` over the fill; never on a disabled button.
        Rectangle {
            objectName: "press"
            anchors.fill: parent
            radius: Tokens.radiusS
            color: Tokens.color.hover
            opacity: (button.hovered || button.pressed) && !button.disabled ? 1 : 0

            // The stylesheet eases the background colour; the primary's overlay is an image and changes at once.
            Behavior on opacity {
                enabled: button.variant !== "primary"

                NumberAnimation {
                    duration: Tokens.durationShort
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.easeBase
                }
            }
        }

        Rectangle {
            objectName: "frame"
            anchors.fill: parent
            radius: Tokens.radiusS
            color: "transparent"
            border.width: Geometry.buttonBorder
            border.color: {
                if (button.disabled)
                    return Tokens.color.disabled;
                switch (button.variant) {
                case "primary":
                    return Tokens.color.accent;
                case "destructive":
                    return Tokens.color.statusErrorFull;
                case "quiet":
                    return "transparent";
                default:
                    return Tokens.color.textPrimary;
                }
            }
        }

        Row {
            id: content

            anchors.centerIn: parent
            spacing: Tokens.spaceS

            Icon {
                objectName: "glyph"
                anchors.verticalCenter: parent.verticalCenter
                // rekta.js pending() replaces the whole content, glyph included, with the words.
                visible: button.icon !== "" && !button.pending
                name: button.icon
                size: Geometry.buttonGlyph
                color: button.ink
            }

            Text {
                id: label

                objectName: "label"
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: button.pending ? button.pendingText : button.text
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.fontSizeS
                font.weight: Tokens.fontWeightSemibold
                color: button.ink
            }
        }

        Text {
            id: resting

            visible: false
            text: button.text
            font: label.font
        }

        // `inset: auto 0 -6px` on the padding box (rekta.css:681): under the button, as wide as inside its frame.
        BusyLine {
            objectName: "pendingLine"
            x: Geometry.buttonBorder
            y: box.height - Geometry.buttonBorder + Geometry.pendingLineBelow - height
            width: box.width - 2 * Geometry.buttonBorder
            busy: button.pending
            // pending() takes the line away with the label (rekta.js:1631–1649): no busy-min under a button, and a
            // new run waits busy-delay again.
            onBusyChanged: {
                if (!busy)
                    shown = false;
            }
        }

        FocusRing {
            shown: button.activeFocus
        }

        TapHandler {
            id: tap

            // A slow click is still a click: no long press on a button.
            longPressThreshold: 0

            onTapped: button.click()
        }

        HoverHandler {
            id: hover

            cursorShape: button.pending ? Qt.BusyCursor : button.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
        }
    }

    Hint {
        objectName: "why"
        anchors.baseline: box.baseline
        visible: button.disabledReason !== "" && !button.inActions
        text: button.disabledReason
    }
}
