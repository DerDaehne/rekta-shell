pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The facet "steuerung": the session's settings that act at once, as rows of toggles, segments and buttons, never as
// tiles (tiles.md: a tile never changes data). The groups stand in a fixed order, ton, verbindungen, anzeige, sitzung;
// one without rows falls away. The host runs what the rows ask for and feeds back the state they show. In ton a select
// chooses the default device of each kind; in verbindungen the paired Bluetooth devices and the strongest wireless
// networks unfold below their rows, up to five, and a level lists them all. A secured network the system does not know
// asks for its password in a sheet.
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

    // Quickshell's WifiSecurityType and ConnectionFailReason, of which only these values matter here.
    enum Security {
        Owe = 9,
        Open = 10
    }

    enum FailReason {
        NoSecrets = 1,
        WifiClientDisconnected = 2,
        WifiClientFailed = 3,
        WifiAuthTimeout = 4,
        WifiNetworkLost = 5
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
    // The network as Quickshell's Networking has it, or null without NetworkManager: wifiEnabled and wifiHardwareEnabled.
    property var networking: null
    // Its wireless device (networks with their values, scannerEnabled) and its wired one (connected), or null.
    property var wifiDevice: null
    property var wiredDevice: null
    // Where sheets stand: the host's surface over the panel.
    property Item sheets
    readonly property bool bluetoothOn: bluetooth?.enabled ?? false
    readonly property bool wifiOn: networking?.wifiEnabled ?? false
    readonly property var networkList: wifiDevice?.networks.values ?? []
    readonly property var connectedNetwork: networkList.find(network => network.connected) ?? null
    readonly property bool joining: networkList.some(network => network.stateChanging)
    // The networks by signal while the list shows (inline or in the level), kept in that order meanwhile: the signal
    // moves with every scan, and rows that jump under the pointer cannot be pressed. The cause of a failed connection by
    // network name, until the next attempt.
    property var ranked: []
    property var failures: ({})
    readonly property int inlineNetworkLimit: 5
    readonly property var networksInline: ranked.slice(0, inlineNetworkLimit)
    readonly property bool listing: wifiBranch.expanded || networksLevel.open
    readonly property int inlineDeviceLimit: 5
    readonly property var devicesInline: connectedFirst(bluetoothDevices).slice(0, inlineDeviceLimit)

    // The density as the shell has it: auto, comfortable or compact.
    property string density: "auto"

    // A command for the host to run on the session.
    signal run(var command)
    signal powerProfileChosen(int profile)
    // A device to make the default of its kind.
    signal deviceChosen(var node)
    // The session's actions, which the host shows in place of the panel.
    signal sessionAsked
    // A density to keep: auto, comfortable or compact.
    signal densityChosen(string density)
    signal bluetoothChosen(bool on)
    // A Bluetooth device to connect, or to disconnect.
    signal connectionChosen(var device, bool connect)
    // System Settings is to pair a new device: the shell has no BlueZ agent to answer a pairing.
    signal pairingAsked
    signal wifiChosen(bool on)
    // The system is to scan for networks, or to stop: while a list of them shows.
    signal scanWanted(bool on)
    // A network to join that needs nothing more, or to leave.
    signal networkChosen(var network)
    signal disconnectAsked(var network)
    // A secured network joins with the password the sheet asked for.
    signal passwordChosen(var network, string password)

    // So the few that show are the ones in use; each group keeps its order.
    function connectedFirst(devices: var): var {
        return devices.filter(device => device.connected).concat(devices.filter(device => !device.connected));
    }

    function deviceName(node: var): string {
        return node?.description || node?.name || "";
    }

    // On its way between connected and not; a connection that fails takes the device back to where it was.
    function waiting(device: var): bool {
        return device.pairing || device.state === Controls.Connecting || device.state === Controls.Disconnecting;
    }

    // A device connects or disconnects; one on its way has the system's answer to wait for.
    function pressBluetooth(row: MenuItem) {
        if (row instanceof PairItem) {
            pairingAsked();
            return;
        }
        const device = (row as BluetoothDeviceItem)?.device;
        if (device && !waiting(device))
            connectionChosen(device, !device.connected);
    }

    // Networks already listed keep their place and the vanished ones drop out; new ones follow by signal.
    function rank() {
        const kept = ranked.filter(network => networkList.includes(network));
        const fresh = networkList.filter(network => network.name !== "" && !kept.includes(network));
        fresh.sort((a, b) => b.signalStrength - a.signalStrength || a.name.localeCompare(b.name));
        ranked = kept.concat(fresh);
    }

    // Without wireless, or without its device, nothing of the list stays open and nothing is scanned for.
    function dropNetworkList() {
        wifiBranch.fold();
        networksLevel.leave();
    }

    function needsPassword(network: var): bool {
        return network.security !== Controls.Open && network.security !== Controls.Owe;
    }

    function failureWord(reason: int): string {
        switch (reason) {
        case Controls.NoSecrets:
            return "kein passwort";
        case Controls.WifiClientDisconnected:
            return "verbindung abgebrochen";
        case Controls.WifiClientFailed:
            return "fehlgeschlagen";
        case Controls.WifiAuthTimeout:
            return "zeitüberschreitung";
        case Controls.WifiNetworkLost:
            return "netz verloren";
        default:
            return "unbekannter fehler";
        }
    }

    function failed(network: var, reason: int) {
        failures = Object.assign({}, failures, { [network.name]: failureWord(reason) });
    }

    function forgetFailure(network: var) {
        const rest = Object.assign({}, failures);
        delete rest[network.name];
        failures = rest;
    }

    // Open or known, it joins at once; a secured one the system does not know asks for its password first. One on its
    // way, or already joined, takes no press (leaving is the button in its row).
    function pressNetwork(row: MenuItem) {
        const network = (row as NetworkItem)?.network;
        if (!network || network.connected || network.stateChanging)
            return;
        forgetFailure(network);
        if (network.known || !needsPassword(network))
            networkChosen(network);
        else
            passwordSheet.ask(network, row);
    }

    readonly property list<string> densities: ["auto", "comfortable", "compact"]
    // Where a status word of the app bar leads, by name; the energy profile, where it is offered, else its group.
    readonly property var places: ({
            sound: soundGroup,
            connections: connectionsGroup,
            doNotDisturb: quietRow,
            power: powerRow.present ? powerRow : sessionGroup
        })

    width: parent ? parent.width : 0

    PanelGroup {
        id: soundGroup

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
        id: connectionsGroup

        objectName: "connections"
        title: "verbindungen"
        levels: [
            PanelLevel {
                id: networksLevel

                objectName: "networks"
                name: "netze"
                onActivated: row => controls.pressNetwork(row)

                Repeater {
                    model: controls.ranked

                    NetworkItem {}
                }
            },
            PanelLevel {
                id: bluetoothLevel

                objectName: "bluetoothDevices"
                name: "geräte"
                onActivated: row => controls.pressBluetooth(row)

                Repeater {
                    model: controls.bluetoothDevices

                    BluetoothDeviceItem {}
                }

                PairItem {
                    objectName: "pairDevice"
                }
            }
        ]

        PanelRow {
            label: "wlan"
            present: controls.networking !== null && controls.wifiDevice !== null

            Toggle {
                objectName: "wifi"
                onWord: "an"
                offWord: "aus"
                checked: controls.wifiOn
                disabledReason: controls.networking?.wifiHardwareEnabled === false ? "funk gesperrt" : ""
                Accessible.name: "wlan"
                // It shows what the system has: a switch it did not take springs back.
                onToggled: {
                    controls.wifiChosen(checked);
                    checked = Qt.binding(() => controls.wifiOn);
                }
            }
        }

        PanelRow {
            label: controls.connectedNetwork ? `netz · ${controls.connectedNetwork.name}` : "netz"
            present: controls.wifiOn && controls.wifiDevice !== null

            Keys.onPressed: event => event.accepted = wifiBranch.handleKey(event)

            Item {
                implicitWidth: wifiState.implicitWidth + Tokens.spaceS + networksOpener.implicitWidth
                implicitHeight: networksOpener.implicitHeight

                StatusTag {
                    id: wifiState

                    objectName: "wifiState"
                    anchors.verticalCenter: parent.verticalCenter
                    status: controls.joining ? "warning" : controls.connectedNetwork ? "info" : ""
                    word: controls.joining ? "wartet" : controls.connectedNetwork ? "verbunden" : "getrennt"
                }

                Button {
                    id: networksOpener

                    objectName: "chooseNetwork"
                    x: wifiState.implicitWidth + Tokens.spaceS
                    text: "wählen"
                    Accessible.name: "netze wählen"

                    ExpandedState {
                        target: networksOpener
                        expanded: wifiBranch.expanded
                    }
                    onClicked: wifiBranch.toggle()
                }
            }
        }

        PanelBranch {
            id: wifiBranch

            objectName: "wifiBranch"
            opener: networksOpener
            onActivated: row => {
                if (row === allNetworksRow)
                    networksLevel.show(networksOpener);
                else
                    controls.pressNetwork(row);
            }

            Empty {
                objectName: "noNetworks"
                visible: controls.ranked.length === 0
                width: parent.width
                text: "keine netze gefunden, die suche läuft"
            }

            Repeater {
                model: controls.networksInline

                NetworkItem {}
            }

            MenuItem {
                id: allNetworksRow

                objectName: "allNetworks"
                visible: controls.ranked.length > controls.inlineNetworkLimit
                text: "alle netze …"
                opensLevel: true
                activeFocusOnTab: true
            }
        }

        PanelRow {
            label: "kabel"
            present: controls.wiredDevice !== null

            StatusTag {
                objectName: "wiredState"
                status: controls.wiredDevice?.connected ? "info" : ""
                word: controls.wiredDevice?.connected ? "verbunden" : "getrennt"
            }
        }

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

            Keys.onPressed: event => event.accepted = bluetoothBranch.handleKey(event)

            Button {
                id: devicesOpener

                objectName: "chooseBluetoothDevice"
                text: "wählen"
                Accessible.name: "geräte wählen"

                ExpandedState {
                    target: devicesOpener
                    expanded: bluetoothBranch.expanded
                }
                onClicked: bluetoothBranch.toggle()
            }
        }

        PanelBranch {
            id: bluetoothBranch

            objectName: "bluetoothBranch"
            opener: devicesOpener
            onActivated: row => {
                if (row === allDevicesRow)
                    bluetoothLevel.show(devicesOpener);
                else
                    controls.pressBluetooth(row);
            }

            Repeater {
                model: controls.devicesInline

                BluetoothDeviceItem {}
            }

            MenuItem {
                id: allDevicesRow

                objectName: "allDevices"
                visible: controls.bluetoothDevices.length > controls.inlineDeviceLimit
                text: "alle geräte …"
                opensLevel: true
                activeFocusOnTab: true
            }

            PairItem {
                objectName: "pairDeviceInline"
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
            id: quietRow

            label: "nicht stören"

            Toggle {
                id: quietToggle

                objectName: "doNotDisturb"
                onWord: "an"
                offWord: "aus"
                Accessible.name: "nicht stören"
            }
        }

        PanelRow {
            label: "dichte"

            Segments {
                objectName: "density"
                options: ["automatisch", "bequem", "kompakt"]
                currentIndex: controls.densities.indexOf(controls.density)
                // The choice ends the binding; it comes back, so a refused write shows what the shell has.
                onActivated: index => {
                    controls.densityChosen(controls.densities[index]);
                    currentIndex = Qt.binding(() => controls.densities.indexOf(controls.density));
                }
            }
        }
    }

    PanelGroup {
        id: sessionGroup

        objectName: "session"
        title: "sitzung"

        PanelRow {
            id: powerRow

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

        // Out of sight, or with no adapter, the devices come back folded.
        function onVisibleChanged() {
            if (controls.visible)
                return;
            bluetoothBranch.fold();
            wifiBranch.fold();
            passwordSheet.close("cancel");
        }

        function onBluetoothChanged() {
            if (!controls.bluetooth)
                bluetoothBranch.fold();
        }

        // Opening starts the list afresh; folding leaves its rows to fold away with it.
        function onListingChanged() {
            if (controls.listing) {
                controls.ranked = [];
                controls.failures = ({});
                controls.rank();
            }
            controls.scanWanted(controls.listing);
        }

        // A network that came or went while the list shows re-ranks it; folded, the rows are dropped with their objects.
        function onNetworkListChanged() {
            if (controls.listing)
                controls.rank();
            else
                controls.ranked = [];
            if (!controls.networkList.includes(passwordSheet.network))
                passwordSheet.close("gone");
        }

        function onWifiOnChanged() {
            if (!controls.wifiOn)
                controls.dropNetworkList();
        }

        function onWifiDeviceChanged() {
            if (!controls.wifiDevice)
                controls.dropNetworkList();
        }
    }

    PasswordSheet {
        id: passwordSheet

        objectName: "passwordSheet"
        parent: controls.sheets
        anchors.fill: parent
        onSubmitted: (network, password) => controls.passwordChosen(network, password)
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

    // A network: its name, what it is (secured, known) and its signal in percent. A joined one has a quiet button to leave;
    // one that failed to join says why in its row until the next attempt. One on its way says so.
    component NetworkItem: MenuItem {
        id: networkItem

        required property var modelData
        readonly property var network: modelData
        readonly property string cause: controls.failures[network.name] ?? ""
        readonly property bool waits: network.stateChanging
        readonly property string kinds: [network.security !== Controls.Open ? "gesichert" : "", network.known ? "bekannt" : ""].filter(part => part !== "").join(" · ")
        readonly property string strength: `${Math.round(network.signalStrength * 100)}%`

        text: network.name
        activeFocusOnTab: true
        Accessible.name: [text, cause, waits ? "wartet" : "", network.connected ? "verbunden" : kinds, `signal ${strength}`].filter(part => part !== "").join(", ")

        StatusTag {
            objectName: "failure"
            anchors.verticalCenter: parent.verticalCenter
            visible: networkItem.cause !== "" && !networkItem.waits
            status: "error"
            word: networkItem.cause
        }

        StatusTag {
            objectName: "joining"
            anchors.verticalCenter: parent.verticalCenter
            visible: networkItem.waits
            status: "warning"
            word: "wartet"
        }

        Meta {
            objectName: "kinds"
            anchors.verticalCenter: parent.verticalCenter
            visible: networkItem.kinds !== "" && !networkItem.network.connected && !networkItem.waits && networkItem.cause === ""
            text: networkItem.kinds
        }

        // A number to read as data (typography.md, "Weight and case").
        Meta {
            objectName: "signal"
            anchors.verticalCenter: parent.verticalCenter
            text: networkItem.strength
            font.weight: Tokens.fontWeightMedium
        }

        Button {
            objectName: "leave"
            anchors.verticalCenter: parent.verticalCenter
            visible: networkItem.network.connected
            variant: "quiet"
            text: "trennen"
            Accessible.name: `${networkItem.text} trennen`
            onClicked: controls.disconnectAsked(networkItem.network)
        }

        Connections {
            target: networkItem.network

            function onConnectionFailed(reason: int) {
                controls.failed(networkItem.network, reason);
            }
        }
    }

    component PairItem: MenuItem {
        text: "neues gerät koppeln"
        activeFocusOnTab: true
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
