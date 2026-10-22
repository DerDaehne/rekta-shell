import QtQuick
import Quickshell
import Quickshell.Wayland
import Rekta

// The plain ground under everything on one screen: Rekta's bg, the Start's glass lies on it while no window is open.
PanelWindow {
    required property ShellScreen modelData

    screen: modelData
    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    color: Tokens.color.bg
    mask: Region {}
    WlrLayershell.namespace: "rekta-ground"
    WlrLayershell.layer: WlrLayer.Background
}
