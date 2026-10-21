import QtQuick

// A text field (forms.md, "Fields"): the label above, the input, and below it a hint that turns into the error when
// there is one. Required fields carry no mark; an optional one says so in its label. A field that cannot be edited
// stays focusable and says why.
Column {
    id: field

    property string label
    property bool optional: false
    property string optionalWord: "(optional)"
    property string hint
    property string error
    property string placeholder
    property string disabledReason
    property alias text: input.text
    readonly property bool hasError: error !== ""
    readonly property bool disabled: disabledReason !== ""

    signal accepted

    spacing: Tokens.spaceXs

    // The label in xs semibold (rekta.css:264); "(optional)" after it in regular (:279).
    Row {
        Text {
            objectName: "label"
            text: field.label
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.fontSizeXs
            font.weight: Tokens.fontWeightSemibold
            color: Tokens.color.textContrastHigh
        }

        Text {
            objectName: "optional"
            visible: field.optional
            // The space belongs to the label's text, as in `<label>name <span class="rk-optional">`.
            text: ` ${field.optionalWord}`
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.fontSizeXs
            font.weight: Tokens.fontWeightRegular
            color: Tokens.color.textContrastHigh
        }
    }

    Rectangle {
        id: box

        objectName: "box"
        width: field.width
        implicitHeight: Tokens.controlHeight
        radius: Tokens.radiusS
        color: Tokens.color.bg
        border.width: field.hasError ? Geometry.inputErrorBorder : Geometry.inputBorder
        border.color: {
            if (field.hasError)
                return Tokens.color.statusErrorFull;
            if (field.disabled)
                return Tokens.color.disabled;
            return input.activeFocus ? Tokens.color.textPrimary : Tokens.color.textContrastMedium;
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Tokens.durationShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeBase
            }
        }

        TextInput {
            id: input

            objectName: "input"
            anchors.fill: parent
            // The thicker error border takes its extra pixel from the padding, so the text stays where it was.
            leftPadding: Geometry.inputPadding - (box.border.width - Geometry.inputBorder)
            rightPadding: leftPadding
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            readOnly: field.disabled
            activeFocusOnTab: true
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.fontSizeS
            color: field.disabled ? Tokens.color.disabled : Tokens.color.textPrimary
            selectionColor: Tokens.color.accent
            selectedTextColor: Tokens.color.textOnAccent
            Accessible.name: field.label
            Accessible.description: hintLine.text

            onAccepted: field.accepted()

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
            shown: input.activeFocus
        }
    }

    Row {
        width: field.width
        visible: hintLine.text !== ""
        spacing: Geometry.tagGap

        // An error starts with the error square, the tag's 8px mark 6px before the words (rekta.css:277).
        Rectangle {
            objectName: "errorMark"
            // An inline-block sits on the baseline of the first line.
            y: hintLine.baselineOffset - height
            visible: field.hasError
            width: Geometry.tagMark
            height: Geometry.tagMark
            color: Tokens.color.statusErrorFull
        }

        Hint {
            id: hintLine

            objectName: "hint"
            width: parent.width - (field.hasError ? Geometry.tagMark + parent.spacing : 0)
            text: field.hasError ? field.error : field.disabled ? field.disabledReason : field.hint
            color: field.hasError ? Tokens.color.textPrimary : Tokens.color.textContrastHigh
        }
    }
}
