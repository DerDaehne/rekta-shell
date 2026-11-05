import QtQuick

// A toggle button (forms.md:54–65; rekta.css:335–346): one frequent state that a press switches at once, for a
// compact row of them. Its icon beside its word, the state word below in xs. Pressed, it takes the accent fill with
// on-accent words, as a chosen segment does; not pressed, it is a quiet button. The fill eases in and out like every
// button's background (rekta.css:324). Focus and a disabled reason are every button's: the ring shows only for the
// keyboard, and disabled it keeps its state (pressed, a disabled fill) and says why below. Its place gives its width;
// words too long for it are cut.
Item {
    id: toggleButton

    property string text
    property string icon
    property bool checked: false
    property string onWord: "on"
    property string offWord: "off"
    // A short value that stands for the state, such as the network's name. It is read with the name; on and off are not,
    // as the pressed state says them.
    property string value
    property string disabledReason
    // ponytail: Rekta has no part yet for what belongs to the state (its networks, its devices); until it has, a chevron
    // at the end opens it, and so do a right click and the menu key. A screen reader learns of it only by the menu key.
    property bool details: false
    readonly property bool disabled: disabledReason !== ""
    readonly property bool hovered: hover.hovered
    readonly property bool pressed: tap.pressed
    readonly property string stateWord: value !== "" ? value : checked ? onWord : offWord
    readonly property color ink: {
        if (disabled)
            return checked ? Tokens.color.bg : Tokens.color.disabled;
        if (checked)
            return Tokens.color.textOnAccent;
        return hovered ? Tokens.color.textPrimary : Tokens.color.textContrastHigh;
    }
    // From the outer edge to the content: the frame and the padding (rekta.css:322).
    readonly property real inner: Geometry.buttonBorder + Tokens.controlPadding
    // Where the chevron's part begins: a press from there on opens the details.
    readonly property real detailsStart: width - inner - Geometry.iconSize - Tokens.spaceS

    signal toggled
    signal detailsAsked

    function toggle() {
        if (disabled)
            return;
        checked = !checked;
        toggled();
    }

    function askDetails() {
        if (details && !disabled)
            detailsAsked();
    }

    // Untyped, so a test can hand it a held key.
    function handleKey(event: var) {
        if (event.key === Qt.Key_Menu && details) {
            event.accepted = true;
            askDetails();
            return;
        }
        if (![Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].includes(event.key))
            return;
        event.accepted = true;
        // A held key switches once.
        if (!event.isAutoRepeat)
            toggle();
    }

    implicitWidth: 2 * inner + Geometry.iconSize + Tokens.spaceS + Math.max(word.implicitWidth, stateLine.implicitWidth) + (details ? Tokens.spaceS + Geometry.iconSize : 0)
    implicitHeight: box.height + (disabled ? Tokens.spaceXs + why.height : 0)
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: value !== "" ? `${text} ${value}` : text
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.description: disabledReason
    Accessible.onPressAction: toggle()
    Accessible.onToggleAction: toggle()

    Keys.onPressed: event => handleKey(event)

    Item {
        id: box

        objectName: "box"
        width: toggleButton.width
        // No padding above or below: the two lines may make it taller than the control height (rekta.css:322, :344).
        height: Math.max(Tokens.controlHeight, 2 * Geometry.buttonBorder + word.height + stateLine.height)

        Rectangle {
            objectName: "fill"
            anchors.fill: parent
            radius: Tokens.radiusS
            color: toggleButton.disabled ? Tokens.color.disabled : Tokens.color.accent
            opacity: toggleButton.checked ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.durationShort
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.easeBase
                }
            }
        }

        // Hover and press lay `hover` over it, never on a disabled one; pressed, it is an image over the accent and
        // comes at once (rekta.css:340, :1332).
        Rectangle {
            objectName: "press"
            anchors.fill: parent
            radius: Tokens.radiusS
            color: Tokens.color.hover
            opacity: (toggleButton.hovered || toggleButton.pressed) && !toggleButton.disabled ? 1 : 0

            Behavior on opacity {
                enabled: !toggleButton.checked

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
            border.color: toggleButton.disabled ? Tokens.color.disabled : toggleButton.checked ? Tokens.color.accent : "transparent"
        }

        Icon {
            objectName: "glyph"
            x: toggleButton.inner
            anchors.verticalCenter: parent.verticalCenter
            size: Geometry.iconSize
            name: toggleButton.icon
            color: toggleButton.ink
        }

        Column {
            x: toggleButton.inner + Geometry.iconSize + Tokens.spaceS
            anchors.verticalCenter: parent.verticalCenter
            width: (toggleButton.details ? toggleButton.detailsStart : toggleButton.width - toggleButton.inner) - x

            TextRole {
                id: word

                objectName: "word"
                width: parent.width
                text: toggleButton.text
                elide: Text.ElideRight
                font.pixelSize: Tokens.fontSizeS
                font.weight: Tokens.fontWeightSemibold
                color: toggleButton.ink

                OverflowTip {}
            }

            TextRole {
                id: stateLine

                objectName: "state"
                width: parent.width
                text: toggleButton.stateWord
                elide: Text.ElideRight
                lineHeightFactor: Tokens.lineHeightCompact
                font.pixelSize: Tokens.fontSizeXs
                font.weight: Tokens.fontWeightRegular
                color: toggleButton.ink

                OverflowTip {}
            }
        }

        Icon {
            objectName: "chevron"
            x: toggleButton.width - toggleButton.inner - Geometry.iconSize
            anchors.verticalCenter: parent.verticalCenter
            visible: toggleButton.details
            size: Geometry.iconSize
            name: "chevron-right"
            color: toggleButton.ink
        }

        FocusRing {
            objectName: "ring"
            shown: toggleButton.activeFocus
        }

        TapHandler {
            id: tap

            acceptedButtons: Qt.LeftButton | Qt.RightButton
            // A slow click is still a click.
            longPressThreshold: 0

            onTapped: (eventPoint, button) => {
                if (button === Qt.RightButton || (toggleButton.details && eventPoint.position.x >= toggleButton.detailsStart))
                    toggleButton.askDetails();
                else
                    toggleButton.toggle();
            }
        }

        HoverHandler {
            id: hover

            cursorShape: toggleButton.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
        }
    }

    Hint {
        id: why

        objectName: "why"
        y: box.height + Tokens.spaceXs
        width: toggleButton.width
        visible: toggleButton.disabled
        text: toggleButton.disabledReason
    }
}
