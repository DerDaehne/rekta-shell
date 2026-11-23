import QtQuick

// A search field (collections.md, "Search and filters"; `.rk-search`, rekta.css:943–945): Rekta's input with the
// magnifier `search` before the text. A press or a tap puts the focus in it, which also calls up an on-screen keyboard.
Rectangle {
    id: field

    property string placeholder
    property alias text: input.text
    property alias readOnly: input.readOnly
    // The focus is in it: the field is no focus scope, so its own activeFocus stays false.
    readonly property alias inputFocus: input.activeFocus

    function focusInput() {
        input.forceActiveFocus();
    }

    // Its text's baseline, as an inline input lines up with the words beside it.
    baselineOffset: input.y + input.baselineOffset
    implicitWidth: Geometry.searchMaxWidth
    implicitHeight: Tokens.controlHeight
    radius: Tokens.radiusS
    color: Tokens.color.bg
    border.width: Geometry.inputBorder
    border.color: input.activeFocus ? Tokens.color.textPrimary : Tokens.color.textContrastMedium

    Behavior on border.color {
        ColorAnimation {
            duration: Tokens.durationShort
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeBase
        }
    }

    Icon {
        objectName: "magnifier"
        x: Geometry.searchIconStart
        anchors.verticalCenter: parent.verticalCenter
        name: "search"
        size: Geometry.searchIconSize
        color: Tokens.color.textContrastHigh
    }

    TextInput {
        id: input

        objectName: "input"
        anchors.fill: parent
        leftPadding: Geometry.searchPaddingStart
        rightPadding: Geometry.inputPadding
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        activeFocusOnTab: true
        font.family: Tokens.fontSans
        font.pixelSize: Tokens.fontSizeS
        color: Tokens.color.textPrimary
        selectionColor: Tokens.color.accent
        selectedTextColor: Tokens.color.textOnAccent
        Accessible.name: field.placeholder

        Text {
            objectName: "placeholder"
            anchors.fill: parent
            leftPadding: input.leftPadding
            verticalAlignment: Text.AlignVCenter
            visible: input.text === ""
            text: field.placeholder
            font: input.font
            color: Tokens.color.textContrastMedium
        }
    }

    FocusRing {
        objectName: "ring"
        shown: input.activeFocus
    }
}
