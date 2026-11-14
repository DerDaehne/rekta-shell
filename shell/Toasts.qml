import QtQuick
import Quickshell
import Quickshell.Wayland
import Rekta
import "services"

// The toasts' surface: along the bottom of the primary screen, kept clear of the app bar's zone, so a toast rises from the
// top of the bar; under a full-screen window, where the bar and its zone have gone, from the screen's edge. On the overlay
// layer, above every window, so a critical toast shows over a full-screen one too, and above the Start and the side panel,
// which keep to the top layer. On the top layer while the app bar has a floating surface open (`stepsBack`, which the bar
// sets): KWin keeps popups between the two. Mapped only while a toast shows: KWin puts a newly mapped surface that takes
// no keys below the active surface of its layer (Workspace::addWaylandWindow, restackWindowUnderActive), so a toast that
// comes while a sheet holds the keyboard stays below it. A toast starts its way below the surface's edge, which hides it there. It takes
// input only over the open toast, and the keyboard only once the session's key has brought it to a toast that stays: KWin
// activates a layer surface as soon as it wants keys, and hands the keyboard on to the next window once the surface goes.
// ponytail: a toast that replaces the one the key reached keeps the keyboard until it goes too; give it back to the window
// that had it, as the Start does, should that show. Not the namespace "notification": KWin would slide that in with
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
    color: "transparent"
    mask: Region {
        item: region.open
    }
    WlrLayershell.namespace: "dock"
    WlrLayershell.layer: stepsBack ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: region.reached ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Toaster {
        id: region

        undoWord: "rückgängig"
        dismissWord: "entfernen"

        width: host.width
        Keys.onPressed: event => KeyLayers.dispatch(event, Window.activeFocusItem)
    }

    GlobalShortcut {
        name: "toast"
        text: "Go to the urgent notification"
        keys: [Qt.MetaModifier | Qt.ShiftModifier | Qt.Key_N]
        onPressed: region.reach()
    }
}
