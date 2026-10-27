import QtQuick
import Quickshell
import Quickshell.Wayland
import Rekta
import Settings

// The ground of one screen, the one surface below every window: the echo or plain bg, as the setting "background"
// says, and no input.
PanelWindow {
    id: panel

    required property ShellScreen modelData
    required property Layers settings

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
        solid: panel.settings.value("background") === "solid"
    }
}
