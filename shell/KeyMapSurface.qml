pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import KeyMap
import Rekta
import org.kde.plasma.workspace.dbus as DBus
import "services"

// The key map's surface: the whole primary screen above every window, the Start and the bar, mapped only while the
// sheet shows. Asked for by `?` or the search, it holds the keyboard until it goes; shown while Meta is held, it takes
// neither keys nor the pointer, so the window under it keeps both, and it goes as Meta comes up. Namespace "dock" for
// the reason the session banner's surface gives.
PanelWindow {
    id: surface

    required property Launcher launcher
    required property ShellScreen primaryScreen
    readonly property alias hold: metaHold

    // `?` asked for the list.
    signal asked

    function show() {
        map.showAsked();
    }

    screen: primaryScreen
    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: primaryScreen !== null && map.open
    mask: map.held ? empty : null
    WlrLayershell.namespace: "dock"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: map.held ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
    // A deliberate deviation, as for the session banner: KWin blurs at the strength of its blur effect.
    BackgroundEffect.blurRegion: Region {
        item: map.open ? map : null
    }

    Region {
        id: empty
    }

    KeyMap {
        id: map

        anchors.fill: parent
        focus: true
        launcher: surface.launcher
        Keys.onPressed: event => KeyLayers.dispatch(event, Window.activeFocusItem)
        onAsked: surface.asked()
    }

    MetaHold {
        id: metaHold

        onShowingChanged: showing ? map.showHeld() : map.holdEnded()
    }

    IpcHandler {
        target: "keymap"

        // Not "show": `qs ipc call keymap show` describes the target instead of calling it.
        function open(): void {
            surface.show();
        }
    }

    // KWin's rekta-metahold effect; without it Meta held does nothing.
    DBus.SignalWatcher {
        service: "org.kde.KWin"
        path: "/RektaMetaHold"
        iface: "org.kde.rekta.MetaHold"

        function dbusalone() {
            metaHold.alone();
        }

        function dbusended() {
            metaHold.ended();
        }
    }
}
