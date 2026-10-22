import QtQuick
import Quickshell
import Quickshell.Wayland
import Rekta

// The toasts' surface: along the top of the primary screen, above every window, so a critical toast shows over a
// full-screen one too. It takes input only over the open toast and never the keyboard. Not the namespace
// "notification": KWin would slide that in with an effect of its own.
PanelWindow {
    id: host

    readonly property alias toaster: region

    anchors.left: true
    anchors.right: true
    anchors.top: true
    implicitHeight: region.implicitHeight
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"
    mask: Region {
        item: region.open
    }
    WlrLayershell.namespace: "rekta-toasts"
    WlrLayershell.layer: WlrLayer.Overlay

    Toaster {
        id: region

        width: host.width
    }
}
