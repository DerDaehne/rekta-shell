pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Session
import "services"

// The session banner's surface: the whole primary screen, above every window, the app bar and the Start, the screen
// behind shaded and blurred. It is mapped only while the banner shows and holds the keyboard meanwhile; once it has
// gone, KWin gives the keyboard back to the window that had it. Namespace "dock": KWin types a layer surface by its
// namespace only and takes any other for a normal window, which window-managing scripts move (a tiling script pushes
// it into the area beside the app bar); of the special types, dock is the one KWin's own effects leave alone (fading
// popups fade splash and on-screen-display surfaces, sliding notifications slide notification ones).
// ponytail: a new layer surface takes some 60ms to its first frame, so the first frames of the way in may not show;
// keep the surface mapped, as the Start does, should that show.
PanelWindow {
    id: surface

    required property Launcher launcher
    required property ShellScreen primaryScreen

    // The banner has gone, and with it the surface.
    signal gone
    // An action started an app.
    signal launched

    // Opens with the focus on the named action ("lock", "switchUser", "logout", "reboot", "shutdown", "systemMonitor"),
    // or on "sperren" for any other name.
    function show(focusOn: string) {
        banner.show(focusOn);
    }

    screen: primaryScreen
    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: banner.open
    WlrLayershell.namespace: "dock"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    // A deliberate deviation, as for the app bar: KWin blurs at the strength of its blur effect, not the shading's
    // blur(4px) (rekta.css:832).
    // ponytail: the blur stands at once while the shading fades in; fade the surface in KWin, as the fade-back does
    // the Start, should that show.
    BackgroundEffect.blurRegion: Region {
        item: banner
    }

    SessionBanner {
        id: banner

        anchors.fill: parent
        focus: true
        actions: session.actions
        onClosed: surface.gone()
    }

    SessionActions {
        id: session

        launcher: surface.launcher
        seatPath: Quickshell.env("XDG_SEAT_PATH") ?? ""
        // From the list rather than byId(), so it follows the entries as they are read and change.
        systemMonitor: Array.from(DesktopEntries.applications.values).find(entry => entry.id === "org.kde.plasma-systemmonitor") ?? null

        onLaunched: surface.launched()
    }

    IpcHandler {
        target: "session"

        // Not "show": `qs ipc call session show` describes the target instead of calling it.
        function open(): void {
            surface.show("");
        }
    }
}
