import QtQuick
import "Status.js" as Status

// Progress (data.md, "Progress"): with a value the label and the percentage stand above a bar that fills to it;
// without one (value < 0) a segment runs along the bar. It draws in the current text colour over a faint track of
// the same colour.
Column {
    id: progress

    property real value: -1 // 0 to 1, or below 0 when the amount is unknown
    property string label
    property color ink: Tokens.color.textPrimary
    readonly property bool known: value >= 0
    readonly property string percentText: `${Math.round(Math.min(1, Math.max(0, value)) * 100)}%`

    spacing: Tokens.spaceXs
    Accessible.role: Accessible.ProgressBar
    Accessible.name: label
    Accessible.description: known ? percentText : ""

    Item {
        visible: progress.known && progress.label !== ""
        width: progress.width
        height: visible ? percent.implicitHeight : 0

        Text {
            anchors.left: parent.left
            anchors.baseline: percent.baseline
            text: progress.label
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.fontSizeXs
            color: Status.secondaryInk(progress, Tokens.color)
        }

        Text {
            id: percent

            objectName: "percent"
            anchors.right: parent.right
            text: progress.percentText
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.fontSizeS
            font.weight: Tokens.fontWeightMedium
            font.features: ({ "tnum": 1 })
            color: Tokens.color.textPrimary
        }
    }

    Item {
        width: progress.width
        height: Geometry.progressHeight

        Rectangle {
            anchors.fill: parent
            color: progress.ink
            opacity: Geometry.progressTrackOpacity
        }

        Rectangle {
            objectName: "fill"
            visible: progress.known
            width: parent.width * Math.min(1, Math.max(0, progress.value))
            height: parent.height
            color: progress.ink

            Behavior on width {
                NumberAnimation {
                    duration: Tokens.durationModerate
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.easeBase
                }
            }
        }

        BusySegment {
            objectName: "busySegment"
            anchors.fill: parent
            visible: !progress.known
            ink: progress.ink
        }
    }
}
