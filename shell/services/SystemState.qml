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
    readonly property StatusWords words: model

    // Untyped, as qmllint sees Pipewire's own opaque copy of the model type, which lacks `values`.
    readonly property var nodes: Pipewire.nodes
    readonly property list<PwNode> streams: nodes.values.filter(node => node.isStream)
    // ponytail: a capture stream counts while it is connected, also when it is paused; PwNode has no state to tell.
    readonly property bool capturing: streams.some(node => node.properties["media.class"] === "Stream/Input/Audio" && node.properties["stream.capture.sink"] !== "true")
    // UPower's WarningLevel: 3 low, 4 critical, 5 action.
    readonly property int lowWarning: 3
    // ponytail: with NetworkManager's connectivity check off it reports Unknown and never "offline"; count the connected
    // devices then.
    readonly property bool offline: Networking.connectivity === NetworkConnectivity.None

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

    StatusWords {
        id: model

        muted: system.sink?.audio?.muted ?? false
        doNotDisturb: system.doNotDisturb
        microphoneInUse: system.capturing
        batteryLow: (battery.properties.WarningLevel ?? 0) >= system.lowWarning
        batteryPercent: Math.round(battery.properties.Percentage ?? 0)
        offline: system.offline
    }
}
