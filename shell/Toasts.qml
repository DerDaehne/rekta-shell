import QtQuick
import Quickshell
import Quickshell.Wayland
import Rekta

// The toasts' surface: along the top of the primary screen, above every window, so a critical toast shows over a
// full-screen one too. It takes input only over the open toast and never the keyboard. Not the namespace
// "notification": KWin would slide that in with an effect of its own.
PanelWindow {
    id: host

    required property ShellScreen primaryScreen
    readonly property alias toaster: region

    // Mapped only while a toast shows. KWin puts a newly mapped surface that takes no keys below the active surface of its
    // layer (Workspace::addWindow, restackWindowUnderActive), and the open Start is one; mapped on the top layer the
    // surface goes to the top of the stack instead, and lifted to the overlay layer after its first frame it stays there.
    property bool lifted: false

    screen: primaryScreen
    visible: primaryScreen !== null && (region.open !== null || region.leaving > 0)
    onVisibleChanged: lifted = false
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
    WlrLayershell.layer: lifted ? WlrLayer.Overlay : WlrLayer.Top

    Toaster {
        id: region

        undoWord: "rückgängig"

        width: host.width
    }

    Connections {
        target: host.contentItem.Window.window

        function onFrameSwapped() {
            host.lifted = true;
        }
    }
}
