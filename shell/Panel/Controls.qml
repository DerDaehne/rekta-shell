pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The facet "steuerung": the session's settings that act at once, as rows of toggles, segments and buttons, never as
// tiles (tiles.md: a tile never changes data). The groups stand in a fixed order, ton, verbindungen, anzeige, sitzung;
// one without rows falls away. The host runs what the rows ask for and feeds back the state they show. In ton a select
// chooses the default device of each kind; in verbindungen a level lists the paired Bluetooth devices to connect.
Column {
    id: controls

    // Quickshell's BluetoothAdapterState and BluetoothDeviceState, as this module goes without Quickshell.
    enum AdapterState {
        Disabled = 0,
        Enabled = 1,
        Enabling = 2,
        Disabling = 3,
        Blocked = 4
    }

    enum DeviceState {
        Disconnected = 0,
        Connected = 1,
        Disconnecting = 2,
        Connecting = 3
    }

    // The text of kdeglobals, which names Plasma's pair of light and dark global themes.
    property string kdeglobals
    readonly property bool dark: Prefs.resolvedTheme === "dark"
    readonly property alias doNotDisturb: quietToggle.checked
    // The power profile daemon: whether it runs, its profile (0 power saver, 1 balanced, 2 performance), and whether it
    // offers performance on this machine.
    property bool hasPowerProfiles: false
    property int powerProfile: 1
    property bool hasPerformanceProfile: false
    // The default output and input as PipeWire has them, or null: nodes with a description and their audio's volume
    // (1 for 100%) and muted. The rows set those two on the node itself.
    property var output: null
    property var input: null
    // The devices of each kind to choose from, nodes as above.
    property var outputs: []
    property var inputs: []
    // The default Bluetooth adapter as Quickshell has it, or null: its enabled and state.
    property var bluetooth: null
    // Its paired devices: name, connected, state, pairing, batteryAvailable and battery (0 to 1).
    property var bluetoothDevices: []
    readonly property bool bluetoothOn: bluetooth?.enabled ?? false

    // A command for the host to run on the session.
    signal run(var command)
    signal powerProfileChosen(int profile)
    // A device to make the default of its kind.
    signal deviceChosen(var node)
    // The session's actions, which the host shows in place of the panel.
    signal sessionAsked
    signal bluetoothChosen(bool on)
    // A Bluetooth device to connect, or to disconnect.
    signal connectionChosen(var device, bool connect)
    // System Settings is to pair a new device: the shell has no BlueZ agent to answer a pairing.
    signal pairingAsked

    function deviceName(node: var): string {
        return node?.description || node?.name || "";
    }

    // On its way between connected and not; a connection that fails takes the device back to where it was.
    function waiting(device: var): bool {
        return device.pairing || device.state === Controls.Connecting || device.state === Controls.Disconnecting;
    }

    // A device connects or disconnects; one on its way has the system's answer to wait for.
    function pressBluetooth(row: MenuItem) {
        if (row === pairRow) {
            pairingAsked();
            return;
        }
        const device = (row as BluetoothDeviceItem)?.device;
        if (device && !waiting(device))
            connectionChosen(device, !device.connected);
    }

    width: parent ? parent.width : 0

    PanelGroup {
        objectName: "sound"
        title: "ton"

        DeviceRow {
            node: controls.output
            devices: controls.outputs
            kind: "output"
            name: "ausgang"
        }

        VolumeRow {
            node: controls.output
            kind: "output"
            name: "ausgang"
        }

        MuteRow {
            node: controls.output
            kind: "output"
            name: "ausgang"
        }

        DeviceRow {
            node: controls.input
            devices: controls.inputs
            kind: "input"
            name: "eingang"
        }

        VolumeRow {
            node: controls.input
            kind: "input"
            name: "eingang"
        }

        MuteRow {
            node: controls.input
            kind: "input"
            name: "eingang"
        }
    }

    PanelGroup {
        objectName: "connections"
        title: "verbindungen"
        levels: [
            PanelLevel {
                id: bluetoothLevel

                objectName: "bluetoothDevices"
                name: "geräte"
                onActivated: row => controls.pressBluetooth(row)

                Repeater {
                    model: controls.bluetoothDevices

                    BluetoothDeviceItem {}
                }

                MenuItem {
                    id: pairRow

                    objectName: "pairDevice"
                    text: "neues gerät koppeln"
                    activeFocusOnTab: true
                }
            }
        ]

        PanelRow {
            label: "bluetooth"
            present: controls.bluetooth !== null

            Toggle {
                objectName: "bluetooth"
                onWord: "an"
                offWord: "aus"
                checked: controls.bluetoothOn
                disabledReason: controls.bluetooth?.state === Controls.Blocked ? "funk gesperrt" : ""
                Accessible.name: "bluetooth"
                // It shows what the adapter has: a switch the system did not take springs back.
                onToggled: {
                    controls.bluetoothChosen(checked);
                    checked = Qt.binding(() => controls.bluetoothOn);
                }
            }
        }

        PanelRow {
            label: `geräte · ${controls.bluetoothDevices.filter(device => device.connected).length} verbunden`
            present: controls.bluetooth !== null

            Button {
                id: devicesOpener

                objectName: "chooseBluetoothDevice"
                text: "wählen"
                Accessible.name: "geräte wählen"
                onClicked: bluetoothLevel.show(devicesOpener)
            }
        }
    }

    PanelGroup {
        objectName: "display"
        title: "anzeige"

        PanelRow {
            label: "dunkel"

            Toggle {
                id: darkToggle

                objectName: "dark"
                onWord: "an"
                offWord: "aus"
                checked: controls.dark
                Accessible.name: "dunkel"
                onToggled: controls.run(LookAndFeel.command(checked, controls.kdeglobals))
            }
        }

        // ponytail: kept in memory only, so a restart of the shell turns it off; keep it once the shell has a config.
        PanelRow {
            label: "nicht stören"

            Toggle {
                id: quietToggle

                objectName: "doNotDisturb"
                onWord: "an"
                offWord: "aus"
                Accessible.name: "nicht stören"
            }
        }
    }

    PanelGroup {
        objectName: "session"
        title: "sitzung"

        PanelRow {
            label: "energieprofil"
            present: controls.hasPowerProfiles

            Segments {
                id: profiles

                objectName: "powerProfile"
                options: controls.hasPerformanceProfile ? ["sparen", "ausgewogen", "leistung"] : ["sparen", "ausgewogen"]
                currentIndex: controls.powerProfile
                onActivated: index => controls.powerProfileChosen(index)
            }
        }

        PanelRow {
            Button {
                objectName: "lock"
                text: "sperren"
                onClicked: controls.run(["loginctl", "lock-session"])
            }
        }

        PanelRow {
            Button {
                objectName: "sessionActions"
                text: "sitzung …"
                onClicked: controls.sessionAsked()
            }
        }
    }

    // A choice made here shows at once; a change from elsewhere (System Settings, another tool) shows as it comes.
    // ponytail: a command that fails leaves the choice showing until the system changes next; follow the command's
    // exit once the host reports it.
    Connections {
        target: controls

        function onDarkChanged() {
            darkToggle.checked = controls.dark;
        }

        function onPowerProfileChanged() {
            profiles.currentIndex = controls.powerProfile;
        }
    }

    // The default device of one kind in a select of the devices of that kind; choosing one asks for it as the default.
    // The select always shows the default PipeWire has, so a change from elsewhere shows at once.
    component DeviceRow: PanelRow {
        id: deviceRow

        required property var node
        required property var devices
        // output or input, which names its controls.
        required property string kind
        required property string name

        label: name
        present: node !== null

        Select {
            id: picker

            objectName: `${deviceRow.kind}Device`
            // As wide as the row, so it stands below its label (forms.md, "Fields"; rekta.css:265, an input is 100% wide).
            implicitWidth: deviceRow.width
            label: deviceRow.name
            options: deviceRow.devices.map(node => ({ text: controls.deviceName(node), value: node }))
            currentIndex: deviceRow.devices.indexOf(deviceRow.node)
            // The choice it made ends that binding: it comes back, and the new default shows once PipeWire has it.
            onActivated: index => {
                controls.deviceChosen(deviceRow.devices[index]);
                currentIndex = Qt.binding(() => deviceRow.devices.indexOf(deviceRow.node));
            }
        }
    }

    // ponytail: a volume raised above 100% shows as 100%, and moving the slider brings it back onto the scale; widen the
    // scale once a raised maximum is wanted.
    component VolumeRow: PanelRow {
        id: volumeRow

        required property var node
        required property string kind
        required property string name
        readonly property real volume: Math.min(1, node?.audio?.volume ?? 0)

        label: "lautstärke"
        present: node !== null
        // A change from elsewhere (a key, an app) moves the slider, as moving it ends its binding.
        onVolumeChanged: volumeSlider.value = volume

        Slider {
            id: volumeSlider

            objectName: `${volumeRow.kind}Volume`
            // As wide as the row, so it stands below the words (rekta.css:367, a range is 100% wide).
            implicitWidth: volumeRow.width
            value: volumeRow.volume
            valueText: `${Math.round(value * 100)}%`
            label: `lautstärke ${volumeRow.name}`
            onMoved: volumeRow.node.audio.volume = value
        }
    }

    component MuteRow: PanelRow {
        id: muteRow

        required property var node
        required property string kind
        required property string name
        readonly property bool muted: node?.audio?.muted ?? false

        label: "stumm"
        present: node !== null
        onMutedChanged: muteToggle.checked = muted

        Toggle {
            id: muteToggle

            objectName: `${muteRow.kind}Muted`
            onWord: "an"
            offWord: "aus"
            checked: muteRow.muted
            Accessible.name: `stumm ${muteRow.name}`
            onToggled: muteRow.node.audio.muted = checked
        }
    }

    // A paired device: its name, its battery where it tells, and its state as a status word of the shell's own, each on
    // one of Rekta's statuses (colour.md, "Status vocabulary"): verbunden is active, wartet waiting, getrennt none.
    // ponytail: a connection that fails shows only the state from before, as Quickshell reports no cause; say why once it
    // does.
    component BluetoothDeviceItem: MenuItem {
        id: deviceItem

        required property var modelData
        readonly property var device: modelData
        readonly property bool waits: controls.waiting(device)
        readonly property string battery: device.batteryAvailable ? `${Math.round(device.battery * 100)}%` : ""

        text: device.name
        activeFocusOnTab: true
        Accessible.name: [text, stateTag.word, battery !== "" ? `akku ${battery}` : ""].filter(part => part !== "").join(", ")

        // A number to read as data (typography.md, "Weight and case").
        Meta {
            objectName: "battery"
            anchors.verticalCenter: parent.verticalCenter
            visible: deviceItem.battery !== ""
            text: deviceItem.battery
            font.weight: Tokens.fontWeightMedium
        }

        StatusTag {
            id: stateTag

            objectName: "state"
            anchors.verticalCenter: parent.verticalCenter
            status: deviceItem.waits ? "warning" : deviceItem.device.connected ? "info" : ""
            word: deviceItem.waits ? "wartet" : deviceItem.device.connected ? "verbunden" : "getrennt"
        }
    }
}
