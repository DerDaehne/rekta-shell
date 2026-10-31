import QtQuick
import Quickshell
import Quickshell.Wayland
import Rekta
import State

// The system states as Rekta's banner along the top of the primary screen, in flow: the windows start below it. Over a
// full-screen window only the urgent state shows, above it and without a zone; the others wait for it to end. A dock to
// KWin, as the bar is, for the zone it keeps clear. It takes no keys; the remedy is pressed with the pointer, and the
// same place opens from the status word.
// ponytail: the zone jumps to the final height instead of gliding with the banner (KWin lays the windows out anew at
// every change of a zone).
PanelWindow {
    id: host

    required property ShellScreen primaryScreen
    required property SystemBanners states
    required property bool fullScreen
    required property ControlPanel controlPanel
    required property Toaster toaster
    // The room kept clear at the top, for the Start to begin below.
    readonly property real zone: states.zone(banner, fullScreen)

    function runRemedy(name: string) {
        if (name === "storage")
            host.cleanUp();
        else
            controlPanel.openAt(primaryScreen, states.places[name]);
    }

    signal cleanUp

    screen: primaryScreen
    visible: primaryScreen !== null && states.shows(banner, fullScreen)
    anchors.left: true
    anchors.right: true
    anchors.top: true
    implicitHeight: banner.implicitHeight
    exclusiveZone: zone
    color: "transparent"
    WlrLayershell.namespace: "dock"
    WlrLayershell.layer: fullScreen ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Banner {
        id: banner

        width: host.width
        toaster: host.toaster
        order: host.states.order
        bannerStates: host.states.states
        remedy: name => host.runRemedy(name)
    }

    Connections {
        target: host.states

        function onActiveChanged() {
            host.states.apply(banner);
        }

        function onSentencesChanged() {
            host.states.apply(banner);
        }
    }

    Component.onCompleted: states.apply(banner)
}
