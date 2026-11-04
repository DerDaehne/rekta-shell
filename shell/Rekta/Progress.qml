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
    // What stands above the bar at its end: the percentage beside a label, or a value of its own such as a track's time;
    // in a tile it has neither (tiles.md, "Progress").
    property string valueText: label !== "" ? percentText : ""
    // The fill eases to a new value over duration-moderate (rekta.css:209). A value that moves on by itself every frame
    // (a track that plays) moves it at once: an ease restarted every frame never gets past its slow start.
    property bool eased: true

    spacing: Tokens.spaceXs
    Accessible.role: Accessible.ProgressBar
    Accessible.name: label
    Accessible.description: known ? valueText || percentText : ""

    Item {
        visible: progress.known && progress.valueText !== ""
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
            text: progress.valueText
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.fontSizeS
            font.weight: Tokens.fontWeightMedium
            font.features: ({ "tnum": 1 })
            color: Tokens.color.textPrimary
        }
    }

    Item {
        // The bar is one element, track and fill: a place change turns it as one part (motion.md, "Place change").
        readonly property bool turnsWhole: true

        objectName: "bar"
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
                enabled: progress.eased

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
