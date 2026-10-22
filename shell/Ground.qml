import QtQuick
import Quickshell
import Quickshell.Wayland
import Rekta

// The ground of one screen, the one surface below every window: the echo or plain bg, and no input. The option comes
// from the package's wrapper; without it, in the nested session, the echo shows.
PanelWindow {
    id: panel

    required property ShellScreen modelData

    screen: modelData
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"
    mask: Region {}
    // Not "desktop": KWin lists that namespace among the windows to switch between.
    WlrLayershell.namespace: "rekta-background"
    WlrLayershell.layer: WlrLayer.Background

    Backdrop {
        anchors.fill: parent
        // ponytail: an environment variable until the shell has a configuration format.
        solid: Quickshell.env("REKTA_BACKGROUND") === "solid"
    }
}
