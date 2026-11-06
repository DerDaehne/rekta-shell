import QtQuick
import Quickshell
import Quickshell.Wayland
import Rekta

// The toasts' surface: along the bottom of the primary screen, kept clear of the app bar's zone, so a toast rises from the
// top of the bar; under a full-screen window, where the bar and its zone have gone, from the screen's edge. On the overlay
// layer, above every window, so a critical toast shows over a full-screen one too, and above the Start and the side panel,
// which keep to the top layer. On the top layer while the app bar has a floating surface open (`stepsBack`, which the bar
// sets): KWin keeps popups between the two. Mapped only while a toast shows: KWin puts a newly mapped surface that takes
// no keys below the active surface of its layer (Workspace::addWaylandWindow, restackWindowUnderActive), so a toast that
// comes while a sheet holds the keyboard stays below it. A toast starts its way below the surface's edge, which hides it there. It takes
// input only over the open toast and never the keyboard. Not the namespace "notification": KWin would slide that in with
// an effect of its own.
PanelWindow {
    id: host

    required property ShellScreen primaryScreen
    readonly property alias toaster: region
    property bool stepsBack: false

    screen: primaryScreen
    visible: primaryScreen !== null && (region.open !== null || region.leaving > 0)
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    implicitHeight: region.implicitHeight
    exclusionMode: ExclusionMode.Normal
    focusable: false
    color: "transparent"
    mask: Region {
        item: region.open
    }
    WlrLayershell.namespace: "rekta-toasts"
    WlrLayershell.layer: stepsBack ? WlrLayer.Top : WlrLayer.Overlay

    Toaster {
        id: region

        undoWord: "rückgängig"

        width: host.width
    }
}
