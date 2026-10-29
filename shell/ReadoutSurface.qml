import QtQuick
import Quickshell
import Quickshell.Wayland
import Readout
import Rekta
import "services"

// The key readout alone, where the bar that carries it is out of sight under a full-screen window: along the bottom
// edge of the primary screen, above that window, and mapped only while the display shows. It takes no input and no
// keys, and no zone: not the namespace "dock" (KWin would give it a strut) and not "on-screen-display" (KWin's
// fading popups would fade it in a second time).
PanelWindow {
    id: host

    required property ShellScreen primaryScreen
    required property KeyReadout readout
    required property Windows windows

    screen: primaryScreen
    visible: primaryScreen !== null && alone.mapped
    anchors.bottom: true
    implicitWidth: alone.implicitWidth
    implicitHeight: alone.implicitHeight
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "rekta-readout"
    WlrLayershell.layer: WlrLayer.Overlay
    // A deliberate deviation as in the bar: KWin's blur has its own strength. Only at rest: a region moving in the
    // window or out of it leaves KWin's blur an empty framebuffer.
    BackgroundEffect.blurRegion: Region {
        item: alone.settled ? alone.glass : null
    }

    ReadoutAlone {
        id: alone

        anchors.fill: parent
        away: host.windows.fullScreenOn(host.primaryScreen)
        word: host.readout.word
        level: host.readout.level
        valueText: host.readout.valueText
    }

    Connections {
        target: host.readout

        function onPressed() {
            alone.press();
        }
    }
}
