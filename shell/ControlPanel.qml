pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland
import org.kde.plasma.workspace.dbus as DBus
import Notices
import Settings
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
    // Opens its write gate for the density only.
    required property Layers settings
    required property ShellScreen primaryScreen
    // The Start stands in front, from its opening to its hand-over; it stands on the primary screen.
    required property bool startInFront
    // The default audio devices, bound by their tracker so their volume and muted are valid.
    required property PwNode sink
    required property PwNode source
    required property NoticeBoard notices
    // The screen it opens on, null once that one has gone; the panel hides meanwhile.
    property ShellScreen shownOn: primaryScreen
    readonly property alias doNotDisturb: controls.doNotDisturb
    readonly property alias hasPowerProfiles: controls.hasPowerProfiles
    // Untyped, as qmllint sees Pipewire's own opaque copy of the model type, which lacks `values`.
    readonly property var nodes: Pipewire.nodes
    // The sound cards and other audio devices, not the programs playing or recording.
    readonly property list<PwNode> audioDevices: nodes.values.filter(node => node.audio && !node.isStream)
    // The network cards, only once NetworkManager runs; untyped for the same reason.
    readonly property var networkModel: networkManager.registered ? Networking.devices : null
    readonly property var networkDevices: networkModel?.values ?? []

    // The panel has gone, and with it the surface.
    signal panelClosed
    // "sitzung …": the panel goes, and the session banner is to come.
    signal sessionAsked

    // Opens the panel on a screen with a facet, or closes it when that facet shows there already.
    function toggle(onScreen: ShellScreen, index: int) {
        if (shownOn !== onScreen) {
            shownOn = onScreen;
            panel.show(index);
            return;
        }
        panel.toggle(index);
    }

    // Opens "steuerung" on a screen, at a place of it (a name from Controls.places) or at the top.
    function openAt(onScreen: ShellScreen, place: string) {
        shownOn = onScreen;
        panel.show(0);
        panel.reveal(controls.places[place] ?? null);
    }

    function close() {
        panel.close();
    }

    // The nested session reaches the host's system bus: only the session's own shell acts on it, elsewhere it logs.
    function actOnSystemBus(what: string, act: var) {
        if (launcher.starts)
            act();
        else
            console.info(`ControlPanel: would ${what}`);
    }

    screen: shownOn
    anchors.right: true
    anchors.top: true
    anchors.bottom: true
    implicitWidth: panel.panelWidth
    // No zone of its own (Quickshell's Auto would keep its width clear), yet clear of the app bar's.
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    visible: shownOn !== null && panel.open
    // A dock to KWin: a namespace it does not know makes a normal window, which tiling scripts move like an app's.
    WlrLayershell.namespace: "dock"
    WlrLayershell.layer: startInFront && shownOn === primaryScreen ? WlrLayer.Overlay : WlrLayer.Top
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
            density: surface.settings.value("density")
            onDensityChosen: density => surface.settings.set("density", density)
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
            // Bluetooth is asked only once BlueZ runs, for the same reason as PowerProfiles. Quickshell's type info names the
            // adapter's type without its C++ namespace, so qmllint cannot resolve it.
            bluetooth: bluez.registered ? Bluetooth.defaultAdapter : null // qmllint disable unresolved-type
            // Untyped, as with Pipewire's model above.
            bluetoothDevices: (controls.bluetooth?.devices.values ?? []).filter(device => device.paired || device.bonded)
            onBluetoothChosen: on => surface.actOnSystemBus(`switch bluetooth ${on ? "on" : "off"}`, () => controls.bluetooth.enabled = on)
            onConnectionChosen: (device, connect) => surface.actOnSystemBus(`${connect ? "connect" : "disconnect"} ${device.name}`, () => connect ? device.connect() : device.disconnect())
            sheets: panel.sheets
            // NetworkManager is asked only once it runs, for the same reason as BlueZ. Quickshell's models are untyped.
            networking: networkManager.registered ? Networking : null
            wifiDevice: surface.networkDevices.find(device => device.type === DeviceType.Wifi) ?? null
            wiredDevice: surface.networkDevices.find(device => device.type === DeviceType.Wired) ?? null
            onWifiChosen: on => surface.actOnSystemBus(`switch wifi ${on ? "on" : "off"}`, () => Networking.wifiEnabled = on)
            onScanWanted: on => surface.actOnSystemBus(`${on ? "start" : "stop"} scanning for networks`, () => {
                if (controls.wifiDevice)
                    controls.wifiDevice.scannerEnabled = on;
            })
            onNetworkChosen: network => surface.actOnSystemBus(`join ${network.name}`, () => network.connect())
            onPasswordChosen: (network, password) => surface.actOnSystemBus(`join ${network.name} with a password`, () => network.connectWithPsk(password))
            onDisconnectAsked: network => surface.actOnSystemBus(`leave ${network.name}`, () => network.disconnect())
            onPairingAsked: {
                panel.close();
                const settings = DesktopEntries.byId("kcm_bluetooth");
                if (settings)
                    surface.launcher.launch(settings);
                else
                    console.warn("ControlPanel: no System Settings page kcm_bluetooth to pair a device in");
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

    DBus.DBusServiceWatcher {
        id: networkManager

        busType: DBus.BusType.System
        watchedService: "org.freedesktop.NetworkManager"
    }

    DBus.DBusServiceWatcher {
        id: bluez

        busType: DBus.BusType.System
        watchedService: "org.bluez"
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
