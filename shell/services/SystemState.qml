import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.Pipewire
import org.kde.plasma.workspace.dbus as DBus
import State

// Where the app bar's status words come from: the default output from PipeWire (muted), the capture streams of
// programs from PipeWire (microphone in use), KWin's screencasts that programs receive from PipeWire (screen shared), the
// display battery from UPower (its own warning level, so the threshold is the system's) and the network from
// NetworkManager. "Do not disturb" is the shell's own and comes in from the panel.
Scope {
    id: system

    // The default audio output, bound by its tracker (ReadoutSources).
    required property PwNode sink
    required property bool doNotDisturb
    // KWin's nodes of the shell's own window previews, which never count as a shared screen.
    required property list<int> previewNodes
    // freespacenotifier's notice is open, and what it says (NoticeBoard).
    required property bool storageFull
    required property string storageText
    required property bool storageRemedy
    readonly property StatusWords words: model
    readonly property Battery battery: stand
    readonly property SystemBanners banners: bannerModel
    readonly property bool offline: networkManagerRunning && Sources.offline(Networking.connectivity, NetworkConnectivity.None)
    // NetworkManager is asked only once it runs: Quickshell picks its network backend when the singleton is first read.
    readonly property alias networkManagerRunning: networkManager.registered

    // Untyped, as qmllint sees Pipewire's own opaque copy of the model type, which lacks `values`.
    readonly property var nodes: Pipewire.nodes
    readonly property list<PwNode> streams: nodes.values.filter(node => node.isStream)

    PwObjectTracker {
        objects: system.streams
    }

    readonly property var linkGroups: Pipewire.linkGroups
    // The previews' sources, each kept until its links are gone.
    property list<int> ownScreencasts: []

    function keepOwnScreencasts() {
        ownScreencasts = Sources.ownScreencasts(previewNodes, ownScreencasts, linkGroups.values);
    }

    onPreviewNodesChanged: keepOwnScreencasts()

    Connections {
        target: system.linkGroups

        function onValuesChanged() {
            system.keepOwnScreencasts();
        }
    }

    // The sources of all links, as KWin's media name is in their properties, which stay empty until tracked.
    PwObjectTracker {
        objects: system.linkGroups.values.map(group => group.source)
    }

    DBus.Properties {
        id: upower

        busType: DBus.BusType.System
        service: "org.freedesktop.UPower"
        path: "/org/freedesktop/UPower/devices/DisplayDevice"
        iface: "org.freedesktop.UPower.Device"
    }

    Battery {
        id: stand

        present: upower.properties.IsPresent ?? false
        kind: upower.properties.Type ?? 0
        percentage: upower.properties.Percentage ?? 0
        state: upower.properties.State ?? 0
        timeToEmpty: upower.properties.TimeToEmpty ?? 0
        timeToFull: upower.properties.TimeToFull ?? 0
        warningLevel: upower.properties.WarningLevel ?? 0
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
        screenShared: Sources.screenShared(system.linkGroups.values, system.ownScreencasts)
        batteryLow: stand.low
        batteryPercent: stand.percent
        batteryNote: stand.note
        offline: system.offline
    }

    SystemBanners {
        id: bannerModel

        batteryCritical: Sources.batteryCritical(upower.properties.WarningLevel)
        batteryPercent: stand.percent
        offline: system.offline
        storageFull: system.storageFull
        storageText: system.storageText
        storageRemedy: system.storageRemedy
    }
}
