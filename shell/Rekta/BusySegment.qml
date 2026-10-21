import QtQuick

// The segment that runs along the loading line and an unknown progress (rekta.css:666–671); under reduced motion it
// stands still across the whole width.
Item {
    id: track

    property color ink: Tokens.color.textPrimary
    property bool running: visible

    clip: true

    Rectangle {
        id: segment

        objectName: "segment"
        // background-position p puts the segment at p × (width − segment width)
        property real position: Geometry.busyFrom

        width: Tokens.reducedMotion ? track.width : track.width * Geometry.busySegment
        height: track.height
        x: Tokens.reducedMotion ? 0 : position * (track.width - width)
        color: track.ink

        NumberAnimation on position {
            from: Geometry.busyFrom
            to: Geometry.busyTo
            duration: Tokens.durationBusy
            loops: Animation.Infinite
            running: track.running && !Tokens.reducedMotion
        }
    }
}
