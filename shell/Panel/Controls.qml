pragma ComponentBehavior: Bound

import QtQuick
import Rekta
import State

// The facet "steuerung": the session's settings that act at once, as rows of toggles, segments and buttons, never as
// tiles (tiles.md: a tile never changes data). What a media player plays stands at the top while it plays; the groups
// follow in a fixed order, ton, verbindungen, anzeige, sitzung; one without rows falls away. The states switched most,
// "wlan", "bluetooth", "nicht stören" and "dunkel", are toggle buttons at the panel's edge nearest the app bar
// (`edge`). The host runs what the rows ask for and feeds back the state they show. In ton each kind has two rows, a
// select of its devices, then a button that mutes before the volume slider; between the output and the input each
// stream another program plays has a row with a button and a slider of its own; in anzeige each display that can be
// dimmed has a slider; in verbindungen the paired Bluetooth devices and the strongest wireless networks unfold below
// their rows, up to five, and a level lists them all. A secured network the system does not know asks for its password
// in a sheet.
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
    readonly property bool doNotDisturb: quiet.on
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
    // The programs' streams as PipeWire has them once tracked: id, name, properties (media.class, application.name,
    // application.icon-name, application.process.id, media.name) and audio as above.
    property var streams: []
    // The shell's own process, whose streams are never listed.
    property int ownProcessId: -1
    // The picture of an icon theme's icon by its name, or "" where the theme has none; the host asks its theme.
    property var iconFor: name => ""
    // The streams other programs play, in the order they came.
    readonly property var playing: streams.filter(node => playsAlong(node))
    // Once one stream has an icon, the words of all start at one edge.
    readonly property bool streamIcons: playing.some(node => streamIcon(node) !== "")
    // The ids of the streams the rows show or are about to show.
    property var streamIds: []
    // The displays that can be dimmed, a ListModel of name, title, brightness and max (in powerdevil's units), or null.
    property var displays: null
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
    // Where the quick settings stand: the host's edge nearest the app bar.
    property Item edge
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

    // The shell's choice among the media players, which the bar's middle shares.
    property PlayerChoice choice: PlayerChoice {}
    // "nicht stören" and how long it lasts, which the bar's middle shows.
    property DoNotDisturb quiet: DoNotDisturb {}
    // The density as the shell has it: auto, comfortable or compact.
    property string density: "auto"

    // A command for the host to run on the session.
    signal run(var command)
    signal lockAsked
    signal powerProfileChosen(int profile)
    // A device to make the default of its kind.
    signal deviceChosen(var node)
    // A display to set, by name, to a value of its own scale.
    signal brightnessChosen(string name, int value)
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

    // The dark and the quiet buttons do this; the Start's commands too.
    function setDark(on: bool) {
        run(LookAndFeel.command(on, kdeglobals));
    }

    function setDoNotDisturb(on: bool) {
        if (on)
            quiet.choose("open");
        else
            quiet.stop();
    }

    // So the few that show are the ones in use; each group keeps its order.
    function connectedFirst(devices: var): var {
        return devices.filter(device => device.connected).concat(devices.filter(device => !device.connected));
    }

    function deviceName(node: var): string {
        return node?.description || node?.name || "";
    }

    // Playback of another program that lasts: recording, video, the shell's own and event sounds are left out. An event
    // sound (libcanberra's, the shell's own among them, played by a process of its own) lasts a moment and would only
    // flicker in and out; pavucontrol leaves them out too.
    function playsAlong(node: var): bool {
        const role = (node.properties["media.role"] ?? "").toLowerCase();
        return node.properties["media.class"] === "Stream/Output/Audio"
            && Number(node.properties["application.process.id"]) !== ownProcessId
            && role !== "event" && role !== "notification";
    }

    // The program's icon by the name it gave its stream; none where it gave none or the theme lacks it.
    // ponytail: a program that names no icon shows none; look up its desktop entry by application.process.binary
    // should many do so.
    function streamIcon(node: var): string {
        const name = node.properties["application.icon-name"] ?? "";
        return name === "" ? "" : iconFor(name);
    }

    // What a stream's row shows: the program's icon and "program · what it plays", both as the program writes them
    // (states.md:143–145), and the stream's volume.
    function streamLook(node: var): var {
        const program = node.properties["application.name"] || node.name;
        return {
            words: [program, node.properties["media.name"]].filter(word => word).join(" · "),
            icon: streamIcon(node),
            volume: Math.min(1, node.audio.volume),
            muted: node.audio.muted
        };
    }

    function streamRows(): list<Item> {
        return Array.from({ length: streamItems.count }, (_, index) => streamItems.itemAt(index));
    }

    // The rows follow the streams by id: rows that stay keep their item and its focus, new ones are appended in the
    // order they came, so nothing moves under the pointer. They come and go as rows do, and what lies below makes room
    // or closes the gap (motion.md:24).
    // ponytail: the focus in a row that leaves goes with it; hand it on to the next control as Messages.remove() does,
    // should that strand a keyboard user.
    function followStreams() {
        const ids = playing.map(node => node.id);
        if (String(ids) === String(streamIds))
            return;
        streamIds = ids;
        streamPresence.finish();
        const rows = streamRows();
        const going = rows.filter(row => !ids.includes(row.nodeId));
        const coming = ids.filter(id => !rows.some(row => row.nodeId === id));
        const staying = [...Array.from(soundGroup.rows), ...Array.from(controls.children)].filter(item => item instanceof Item && !going.includes(item));
        streamPresence.change(going, staying, () => showStreams(ids), () => streamRows().filter(row => coming.includes(row.nodeId)), coming.length);
    }

    function showStreams(ids: var) {
        for (let index = shownStreams.count - 1; index >= 0; index--) {
            if (!ids.includes(shownStreams.get(index).nodeId))
                shownStreams.remove(index);
        }
        const shown = Array.from({ length: shownStreams.count }, (_, index) => shownStreams.get(index).nodeId);
        ids.filter(id => !shown.includes(id)).forEach(id => shownStreams.append({ nodeId: id }));
        soundGroup.layOutNow();
        controls.forceLayout();
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
            doNotDisturb: quietButton,
            power: powerRow.present ? powerRow : sessionGroup
        })

    width: parent ? parent.width : 0
    onPlayingChanged: followStreams()
    Component.onCompleted: followStreams()

    ListModel {
        id: shownStreams
    }

    Presence {
        id: streamPresence

        objectName: "streamPresence"
    }

    NowPlaying {
        objectName: "nowPlaying"
        choice: controls.choice
    }

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
            glyph: "speaker"
        }

        Repeater {
            id: streamItems

            model: shownStreams

            StreamRow {}
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
            glyph: "microphone"
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

        Repeater {
            model: controls.displays

            BrightnessRow {}
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
                onClicked: controls.lockAsked()
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
            darkButton.checked = controls.dark;
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
            quietBranch.fold();
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

    // The states switched most, each a toggle button (forms.md:54–56: wireless, do not disturb, dark appearance), in two
    // columns space-s apart as a row of buttons is (rekta.css:353). Unlike Rekta's groups (states.md:186) they have no
    // heading and stand at the edge nearest the app bar, so the way from "steuerung" in the bar to them stays short. One
    // whose device is missing is gone. The details of wlan and bluetooth are their lists in verbindungen, unfolded with
    // the focus on them; those of "nicht stören" are how long it lasts, unfolded below the buttons. Escape folds them and
    // gives the focus back to the button (behaviour.md:826).
    Column {
        objectName: "edgeSettings"
        parent: controls.edge
        width: parent ? parent.width : 0
        visible: controls.visible
        spacing: Tokens.spaceS

        Grid {
            id: quickSettings

            readonly property real cellWidth: (width - spacing) / 2

            objectName: "quickSettings"
            width: parent ? parent.width : 0
            columns: 2
            spacing: Tokens.spaceS

            ToggleButton {
                id: wifiButton

                objectName: "wifi"
                width: quickSettings.cellWidth
                visible: controls.networking !== null && controls.wifiDevice !== null
                icon: "wireless"
                text: "wlan"
                onWord: "an"
                offWord: "aus"
                value: controls.connectedNetwork?.name ?? ""
                checked: controls.wifiOn
                disabledReason: controls.networking?.wifiHardwareEnabled === false ? "funk gesperrt" : ""
                details: controls.wifiOn
                // It shows what the system has: a switch it did not take springs back.
                onToggled: {
                    controls.wifiChosen(checked);
                    checked = Qt.binding(() => controls.wifiOn);
                }
                onDetailsAsked: wifiBranch.expandFocused(wifiButton)
            }

            ToggleButton {
                id: bluetoothButton

                objectName: "bluetooth"
                width: quickSettings.cellWidth
                visible: controls.bluetooth !== null
                icon: "bluetooth"
                text: "bluetooth"
                onWord: "an"
                offWord: "aus"
                checked: controls.bluetoothOn
                disabledReason: controls.bluetooth?.state === Controls.Blocked ? "funk gesperrt" : ""
                details: true
                // It shows what the adapter has: a switch the system did not take springs back.
                onToggled: {
                    controls.bluetoothChosen(checked);
                    checked = Qt.binding(() => controls.bluetoothOn);
                }
                onDetailsAsked: bluetoothBranch.expandFocused(bluetoothButton)
            }

            // A plain press switches it on without an end; the details choose how long it lasts.
            ToggleButton {
                id: quietButton

                objectName: "doNotDisturb"
                width: quickSettings.cellWidth
                icon: "bell"
                text: "nicht stören"
                onWord: "an"
                offWord: "aus"
                value: controls.quiet.endWord
                checked: controls.quiet.on
                details: true
                onToggled: {
                    controls.setDoNotDisturb(checked);
                    checked = Qt.binding(() => controls.quiet.on);
                }
                onDetailsAsked: quietBranch.expandFocused(quietButton)
            }

            ToggleButton {
                id: darkButton

                objectName: "dark"
                width: quickSettings.cellWidth
                icon: "theme"
                text: "dunkel"
                onWord: "an"
                offWord: "aus"
                checked: controls.dark
                onToggled: controls.setDark(checked)
            }
        }

        // A press on a length switches it on at once with that end.
        PanelBranch {
            id: quietBranch

            objectName: "quietBranch"
            opener: quietLength

            Segments {
                id: quietLength

                objectName: "quietLength"
                options: ["bis aus", "1 stunde", "bis morgen"]
                currentIndex: controls.quiet.chosen
                onActivated: index => {
                    controls.quiet.choose(controls.quiet.choices[index]);
                    currentIndex = Qt.binding(() => controls.quiet.chosen);
                }
            }
        }
    }

    // The default device of one kind in a select of the devices of that kind; choosing one asks for it as the default.
    // The select always shows the default PipeWire has, so a change from elsewhere shows at once. Its label stands above
    // it as a field's does, and the select reads it with the chosen device.
    component DeviceRow: PanelRow {
        id: deviceRow

        required property var node
        required property var devices
        // output or input, which names its controls.
        required property string kind
        required property string name

        present: node !== null

        // A field's label above its control, space-xs apart (forms.md:5; rekta.css:386–387).
        Column {
            spacing: Tokens.spaceXs

            FieldLabel {
                objectName: `${deviceRow.kind}DeviceLabel`
                text: deviceRow.name
            }

            Select {
                id: picker

                objectName: `${deviceRow.kind}Device`
                // As wide as the row (rekta.css:388, an input is 100% wide).
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
    }

    // The volume of the default device of one kind, after the icon button that mutes it.
    component VolumeRow: PanelRow {
        id: volumeRow

        required property var node
        required property string kind
        required property string name
        required property string glyph

        present: node !== null

        VolumeControl {
            implicitWidth: volumeRow.width
            node: volumeRow.node
            kind: volumeRow.kind
            name: volumeRow.name
            glyph: volumeRow.glyph
            volume: Math.min(1, volumeRow.node?.audio?.volume ?? 0)
            muted: volumeRow.node?.audio?.muted ?? false
        }
    }

    // Another program's playback stream: its icon and words, and below them a mute button and a volume of its own,
    // which set this stream alone. A row whose stream has ended leaves showing what it last showed.
    component StreamRow: PanelRow {
        id: streamRow

        required property int nodeId
        readonly property var node: controls.playing.find(node => node.id === nodeId) ?? null
        readonly property var look: node ? controls.streamLook(node) : null
        property var seen: ({
                words: "",
                icon: "",
                volume: 0,
                muted: false
            })

        function keep() {
            if (look)
                seen = look;
        }

        objectName: "stream"
        label: seen.words
        icon: seen.icon
        iconSlot: controls.streamIcons
        onLookChanged: keep()
        Component.onCompleted: keep()

        VolumeControl {
            implicitWidth: streamRow.width
            node: streamRow.node
            kind: "stream"
            name: streamRow.seen.words
            glyph: "speaker"
            volume: streamRow.seen.volume
            muted: streamRow.seen.muted
        }
    }

    // A button that mutes, then the volume slider to the end of the line. Muted, the glyph is struck through
    // (shell.md:13–15) and the slider rests, its value saying why (forms.md, "Disabled controls say why"). Both follow
    // the node, so a change from elsewhere shows at once. A node that has gone takes nothing more.
    // ponytail: a volume raised above 100% shows as 100%, and moving the slider brings it back onto the scale; widen the
    // scale once a raised maximum is wanted.
    component VolumeControl: Item {
        id: volumeControl

        required property var node
        // output, input or stream, which names its controls.
        required property string kind
        // What it sets, read with the names of its controls.
        required property string name
        // speaker or microphone; muted, its -muted form.
        required property string glyph
        required property real volume
        required property bool muted
        // What a press does, as the button's tip; its name says what it sets too (forms.md:287–292).
        readonly property string pressWord: muted ? "ton an" : "stumm schalten"

        implicitHeight: Math.max(muteButton.implicitHeight, volumeSlider.implicitHeight)
        // A change from elsewhere (a key, an app) moves the slider, as moving it ends its binding.
        onVolumeChanged: volumeSlider.value = volume

        IconButton {
            id: muteButton

            objectName: `${volumeControl.kind}Mute`
            anchors.verticalCenter: parent.verticalCenter
            icon: volumeControl.muted ? `${volumeControl.glyph}-muted` : volumeControl.glyph
            label: `${volumeControl.name} ${volumeControl.pressWord}`
            tip: volumeControl.pressWord
            onClicked: {
                if (volumeControl.node)
                    volumeControl.node.audio.muted = !volumeControl.muted;
            }
        }

        // The rest of the line, space-m after the button as the value is after the track (rekta.css:527).
        Slider {
            id: volumeSlider

            objectName: `${volumeControl.kind}Volume`
            anchors.verticalCenter: parent.verticalCenter
            x: muteButton.implicitWidth + Tokens.spaceM
            width: parent.width - x
            value: volumeControl.volume
            disabledReason: volumeControl.muted ? "stumm" : ""
            valueText: disabledReason || `${Math.round(value * 100)}%`
            label: `lautstärke ${volumeControl.name}`
            onMoved: {
                if (volumeControl.node)
                    volumeControl.node.audio.volume = value;
            }
        }
    }

    // A display powerdevil can dim, with the same slider as the volume. A change from elsewhere moves it unless the pointer
    // holds it; it then takes what powerdevil last told.
    // ponytail: a step is 1% of the scale, so a display with fewer than 100 steps snaps to the nearest one; take the display's
    // own step as the slider's stepSize if that shows. A slider moved by the keyboard takes every echo, as only the pointer holds it.
    component BrightnessRow: PanelRow {
        id: brightnessRow

        required property string name
        required property string title
        required property real brightness
        required property real max
        readonly property real share: max > 0 ? Math.min(1, brightness / max) : 0

        label: `helligkeit ${title}`
        onShareChanged: {
            if (!brightnessSlider.pressed)
                brightnessSlider.value = share;
        }

        Slider {
            id: brightnessSlider

            objectName: `${brightnessRow.name}Brightness`
            implicitWidth: brightnessRow.width
            value: brightnessRow.share
            valueText: `${Math.round(value * 100)}%`
            label: `helligkeit ${brightnessRow.title}`
            onMoved: controls.brightnessChosen(brightnessRow.name, Math.round(value * brightnessRow.max))
            onPressedChanged: {
                if (!pressed)
                    value = brightnessRow.share;
            }
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
