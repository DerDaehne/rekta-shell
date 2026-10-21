import QtQuick

// A quantity against its whole (data.md, "Meters"): the label and the value above a 6px track that fills in ink, or
// in a status's full colour when the value means that status, with the status tag at the label.
Column {
    id: meter

    property string label
    property real value: 0 // 0 to 1
    property string valueText
    property string status: "" // info | success | warning | error, or "" when the value means no status
    // The value in words for assistive technology, e.g. "81%, nearly full".
    property string valueWords: valueText

    spacing: Tokens.spaceXs
    Accessible.role: Accessible.ProgressBar
    Accessible.name: label
    Accessible.description: valueWords

    Item {
        width: meter.width
        height: Math.max(head.implicitHeight, amount.implicitHeight)

        Row {
            id: head

            anchors.left: parent.left
            anchors.baseline: amount.baseline
            // A row has no baseline of its own; the label's lines the head up with the value.
            baselineOffset: labelText.baselineOffset
            spacing: Tokens.spaceS

            Text {
                id: labelText

                text: meter.label
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.fontSizeXs
                color: Tokens.color.textContrastHigh
            }

            StatusTag {
                visible: meter.status !== ""
                status: meter.status
            }
        }

        Text {
            id: amount

            anchors.right: parent.right
            text: meter.valueText
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.fontSizeS
            font.weight: Tokens.fontWeightMedium
            font.features: ({ "tnum": 1 })
            color: Tokens.color.textPrimary
        }
    }

    Rectangle {
        id: track

        width: meter.width
        height: Geometry.meterHeight
        color: Tokens.color.textContrastLow
        clip: true

        Rectangle {
            objectName: "fill"
            width: track.width * Math.min(1, Math.max(0, meter.value))
            height: track.height
            color: meter.status === "" ? Tokens.color.textPrimary : statusMark.mark

            Behavior on width {
                NumberAnimation {
                    duration: Tokens.durationModerate
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.easeBase
                }
            }
        }
    }

    StatusTag {
        id: statusMark

        visible: false
        status: meter.status
    }
}
