import QtQuick
import Quickshell
import Quickshell.Wayland

// As the session is left for another user, a clear surface over the whole primary screen that holds the keyboard, so
// nothing is typed into an app meanwhile. KWin's fade-back knows it by its namespace: the windows on every screen step
// back while it holds the keyboard and come forward once it hands the keyboard over or goes.
PanelWindow {
    id: surface

    required property ShellScreen primaryScreen
    // From the choice until the session is locked or the windows are forward again.
    required property bool leaving
    required property bool holdsKeyboard
    // The fade-back takes a single commit without the keyboard for asking anew. Nothing changes here after the
    // hand-over, so the surface draws one frame more then, to say it let go.
    property bool confirmingHandOver: false

    screen: primaryScreen
    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: leaving
    WlrLayershell.namespace: "rekta-leave"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: holdsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onHoldsKeyboardChanged: confirmingHandOver = !holdsKeyboard && leaving

    Connections {
        target: surface.contentItem.Window.window

        function onFrameSwapped() {
            if (surface.confirmingHandOver) {
                surface.confirmingHandOver = false;
                surface.contentItem.Window.window.update();
            }
        }
    }
}
