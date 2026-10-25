pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import org.kde.plasma.workspace.dbus as DBus
import Panel
import "services"

// The side panel's surface: the whole of the screen it opens on, above every window and the app bar, the rest of the
// screen shaded and blurred behind it. It is mapped only while the panel shows and holds the keyboard meanwhile; once
// it has gone, KWin gives the keyboard back to the window that had it.
// ponytail: a new layer surface takes some 60ms to its first frame, so the first frames of the way in may not show;
// keep the surface mapped, as the Start does, should that show.
PanelWindow {
    id: surface

    required property Launcher launcher
    required property ShellScreen primaryScreen
    readonly property alias doNotDisturb: controls.doNotDisturb

    // Opens the panel on a screen with a facet, or closes it when that facet shows there already.
    function toggle(onScreen: ShellScreen, index: int) {
        if (screen !== onScreen) {
            screen = onScreen;
            panel.show(index);
            return;
        }
        panel.toggle(index);
    }

    screen: primaryScreen
    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: panel.open
    WlrLayershell.namespace: "rekta-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    // A deliberate deviation, as for the app bar: KWin blurs at the strength of its blur effect, not the shading's
    // blur(4px) (rekta.css:832).
    BackgroundEffect.blurRegion: Region {
        item: panel
    }

    SidePanel {
        id: panel

        anchors.fill: parent
        focus: true
        titles: ["steuerung", "meldungen"]

        Controls {
            id: controls

            // PowerProfiles is asked only once the daemon runs: asked before, it would have the system bus start it.
            hasPowerProfiles: powerProfiles.registered
            powerProfile: hasPowerProfiles ? PowerProfiles.profile : PowerProfile.Balanced
            hasPerformanceProfile: hasPowerProfiles && PowerProfiles.hasPerformanceProfile
            onRun: command => surface.launcher.run(command)
            // The nested session reaches the host's system bus: only the session's own shell sets the profile.
            onPowerProfileChosen: profile => {
                if (surface.launcher.starts)
                    PowerProfiles.profile = profile;
                else
                    console.info(`ControlPanel: would set the power profile ${PowerProfile.toString(profile)}`);
            }
        }

        // "meldungen", the notification centre's place.
        Item {}
    }

    GlobalShortcut {
        name: "controls"
        text: "Open the controls"
        keys: [Qt.MetaModifier | Qt.Key_A]
        onPressed: surface.toggle(surface.primaryScreen, 0)
    }

    IpcHandler {
        target: "panel"

        function toggle(): void {
            surface.toggle(surface.primaryScreen, 0);
        }
    }

    DBus.DBusServiceWatcher {
        id: powerProfiles

        busType: DBus.BusType.System
        watchedService: "org.freedesktop.UPower.PowerProfiles"
    }

    FileView {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/kdeglobals`
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: controls.kdeglobals = text()
        onLoadFailed: controls.kdeglobals = ""
    }
}
