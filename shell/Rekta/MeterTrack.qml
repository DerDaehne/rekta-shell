import QtQuick

// Rekta's meter itself, without its head (`.rk-meter`, rekta.css:735–736): a 6px track that fills to the value, and
// glides to a new one.
Rectangle {
    id: track

    property real value: 0 // 0 to 1
    property color mark: Tokens.color.textPrimary

    implicitHeight: Geometry.meterHeight
    color: Tokens.color.textContrastLow
    clip: true

    Rectangle {
        objectName: "fill"
        width: track.width * Math.min(1, Math.max(0, track.value))
        height: track.height
        color: track.mark

        Behavior on width {
            NumberAnimation {
                duration: Tokens.durationModerate
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeBase
            }
        }
    }
}
