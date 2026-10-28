import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.Pipewire
import org.kde.plasma.workspace.dbus as DBus
import State

// Where the app bar's status words come from: the default output from PipeWire (muted), the capture streams of
// programs from PipeWire (microphone in use), the display battery from UPower (its own warning level, so the threshold
// is the system's) and the network from NetworkManager. "Do not disturb" is the shell's own and comes in from the panel.
Scope {
    id: system

    // The default audio output, bound by its tracker (ReadoutSources).
    required property PwNode sink
    required property bool doNotDisturb
    // Whether the energy profile can be chosen in the panel, so the battery word names the place it opens.
    required property bool powerProfiles
    readonly property StatusWords words: model
    // NetworkManager is asked only once it runs: Quickshell picks its network backend when the singleton is first read.
    readonly property alias networkManagerRunning: networkManager.registered

    // Untyped, as qmllint sees Pipewire's own opaque copy of the model type, which lacks `values`.
    readonly property var nodes: Pipewire.nodes
    readonly property list<PwNode> streams: nodes.values.filter(node => node.isStream)

    PwObjectTracker {
        objects: system.streams
    }

    DBus.Properties {
        id: battery

        busType: DBus.BusType.System
        service: "org.freedesktop.UPower"
        path: "/org/freedesktop/UPower/devices/DisplayDevice"
        iface: "org.freedesktop.UPower.Device"
    }

    DBus.DBusServiceWatcher {
        id: networkManager

        busType: DBus.BusType.System
        watchedService: "org.freedesktop.NetworkManager"
    }

    StatusWords {
        id: model

        muted: system.sink?.audio?.muted ?? false
        doNotDisturb: system.doNotDisturb
        microphoneInUse: Sources.microphoneInUse(system.streams, Quickshell.processId)
        batteryLow: Sources.batteryLow(battery.properties.WarningLevel)
        batteryPercent: Math.round(battery.properties.Percentage ?? 0)
        offline: system.networkManagerRunning && Sources.offline(Networking.connectivity, NetworkConnectivity.None)
        powerProfiles: system.powerProfiles
    }
}
