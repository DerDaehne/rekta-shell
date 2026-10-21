import QtQuick

// The loading line along a region's first hairline (states.md, "Data states"). It shows only once the work has taken
// busy-delay, and once shown it stays at least busy-min, so it never flashes. Under reduced motion it stands still at
// full width in text-contrast-medium.
Item {
    id: line

    property bool busy: false
    // Whether the line is on screen; the line sets it itself from busy and the two timings.
    property bool shown: false

    implicitHeight: Geometry.busyLineHeight
    visible: shown

    onBusyChanged: {
        if (busy) {
            if (!shown)
                delay.restart();
            return;
        }
        delay.stop();
        if (!minimum.running)
            shown = false;
    }

    Timer {
        id: delay

        interval: Tokens.durationBusyDelay
        onTriggered: {
            line.shown = true;
            minimum.restart();
        }
    }

    Timer {
        id: minimum

        interval: Tokens.durationBusyMin
        onTriggered: {
            if (!line.busy)
                line.shown = false;
        }
    }

    BusySegment {
        objectName: "busySegment"
        anchors.fill: parent
        ink: Tokens.reducedMotion ? Tokens.color.textContrastMedium : Tokens.color.textPrimary
    }
}
