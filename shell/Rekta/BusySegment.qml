import QtQuick

// The segment that runs along the loading line and an unknown progress (rekta.css:873–886); under reduced motion it
// stands still across the whole width.
Item {
    id: track

    property color ink: Tokens.color.textPrimary
    property bool running: visible

    clip: true

    Rectangle {
        id: segment

        objectName: "segment"
        // Where its leading edge is, as a share of the width.
        property real position: Tokens.busyFrom

        width: Tokens.reducedMotion ? track.width : track.width * Tokens.busySegment
        height: track.height
        x: Tokens.reducedMotion ? 0 : position * track.width
        color: track.ink

        NumberAnimation on position {
            from: Tokens.busyFrom
            to: Tokens.busyTo
            duration: Tokens.durationBusy
            loops: Animation.Infinite
            running: track.running && !Tokens.reducedMotion
        }
    }
}
