pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland
import org.kde.plasma.workspace.dbus as DBus
import Notices
import Panel
import "services"

// The side panel's surface at the trailing edge of the screen it opens on: as wide as the panel, from the top down to
// the app bar, over the windows, which keep their size; on the app bar's layer, so a full-screen window lies above it.
// It is mapped only while the panel shows and takes the keyboard as it opens; a click into a window takes the keyboard
// without closing the panel. While the Start stands in front, up to its hand-over, it rises to the Start's layer.
// ponytail: a new layer surface takes some 60ms to its first frame, so the first frames of the way in may not show;
// keep the surface mapped, as the Start does, should that show.
PanelWindow {
    id: surface

    required property Launcher launcher
    required property ShellScreen primaryScreen
    // The Start stands in front, from its opening to its hand-over; it stands on the primary screen.
    required property bool startInFront
    // The default audio devices, bound by their tracker so their volume and muted are valid.
    required property PwNode sink
    required property PwNode source
    required property NoticeBoard notices
    readonly property alias doNotDisturb: controls.doNotDisturb
    // Untyped, as qmllint sees Pipewire's own opaque copy of the model type, which lacks `values`.
    readonly property var nodes: Pipewire.nodes
    // The sound cards and other audio devices, not the programs playing or recording.
    readonly property list<PwNode> audioDevices: nodes.values.filter(node => node.audio && !node.isStream)

    // The panel has gone, and with it the surface.
    signal panelClosed
    // "sitzung …": the panel goes, and the session banner is to come.
    signal sessionAsked

    // Opens the panel on a screen with a facet, or closes it when that facet shows there already.
    function toggle(onScreen: ShellScreen, index: int) {
        if (screen !== onScreen) {
            screen = onScreen;
            panel.show(index);
            return;
        }
        panel.toggle(index);
    }

    function close() {
        panel.close();
    }

    screen: primaryScreen
    anchors.right: true
    anchors.top: true
    anchors.bottom: true
    implicitWidth: panel.panelWidth
    // No zone of its own (Quickshell's Auto would keep its width clear), yet clear of the app bar's.
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    visible: panel.open
    // A dock to KWin: a namespace it does not know makes a normal window, which tiling scripts move like an app's.
    WlrLayershell.namespace: "dock"
    WlrLayershell.layer: startInFront && screen === primaryScreen ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    SidePanel {
        id: panel

        anchors.fill: parent
        focus: true
        titles: ["steuerung", "meldungen"]
        onClosed: surface.panelClosed()

        Controls {
            id: controls

            // PowerProfiles is asked only once the daemon runs: asked before, it would have the system bus start it.
            hasPowerProfiles: powerProfiles.registered
            powerProfile: hasPowerProfiles ? PowerProfiles.profile : PowerProfile.Balanced
            hasPerformanceProfile: hasPowerProfiles && PowerProfiles.hasPerformanceProfile
            output: surface.sink
            input: surface.source
            outputs: surface.audioDevices.filter(node => node.isSink)
            inputs: surface.audioDevices.filter(node => !node.isSink)
            onRun: command => surface.launcher.run(command)
            // The nested session reaches the host's system bus: only the session's own shell sets the profile.
            onPowerProfileChosen: profile => {
                if (surface.launcher.starts)
                    PowerProfiles.profile = profile;
                else
                    console.info(`ControlPanel: would set the power profile ${PowerProfile.toString(profile)}`);
            }
            onSessionAsked: {
                panel.close();
                surface.sessionAsked();
            }
            onDeviceChosen: node => {
                if (node.isSink)
                    Pipewire.preferredDefaultAudioSink = node;
                else
                    Pipewire.preferredDefaultAudioSource = node;
            }
        }

        Messages {
            board: surface.notices
            onActed: panel.close()
        }
    }

    GlobalShortcut {
        name: "controls"
        text: "Open the controls"
        keys: [Qt.MetaModifier | Qt.Key_A]
        onPressed: surface.toggle(surface.primaryScreen, 0)
    }

    GlobalShortcut {
        name: "notifications"
        text: "Open the notifications"
        keys: [Qt.MetaModifier | Qt.Key_N]
        onPressed: surface.toggle(surface.primaryScreen, 1)
    }

    IpcHandler {
        target: "panel"

        function toggle(): void {
            surface.toggle(surface.primaryScreen, 0);
        }

        function notifications(): void {
            surface.toggle(surface.primaryScreen, 1);
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
