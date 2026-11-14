import QtQuick

// A press anywhere in its parent hides a tip and goes on to what it lands on (rekta.js tips() listens for it while it
// captures). Declared last, it lies over everything there and sees the press before a control takes it for itself.
Item {
    id: catcher

    // Each press, for a host that has more to do on it.
    signal pressed

    anchors.fill: parent

    PointHandler {
        acceptedButtons: Qt.AllButtons
        onActiveChanged: {
            if (!active)
                return;
            Tips.hide();
            catcher.pressed();
        }
    }
}
