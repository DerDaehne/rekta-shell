pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtTest
import Notices
import Panel
import Rekta

TestCase {
    id: testCase

    name: "Panel"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 720

    // What the panel asked the host to run, and the power profiles chosen in it, oldest first.
    property var commands: []
    property int locksAsked: 0
    property var chosenProfiles: []
    property var chosenDensities: []
    property var chosenDevices: []
    // The brightness the sliders asked for, as [display, value], oldest first.
    property var brightnessSets: []
    // The options chosen in a level, by index.
    property var chosenOptions: []
    // How often "sitzung …" asked for the session banner.
    property int sessionAsked: 0
    // The Bluetooth switches asked for, whether the adapter takes them, and how often pairing was asked for.
    property var bluetoothSwitches: []
    property bool bluetoothTakes: true
    property int pairingAsked: 0
    // The network switches asked for and whether the system takes them, the scans asked for, the networks joined,
    // the passwords they were joined with and the networks left, oldest first.
    property var wifiSwitches: []
    property bool wifiTakes: true
    property var scans: []
    property var joined: []
    property var passwordsSent: []
    property var leaves: []
    property Item scene
    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var side
    property var controls
    property NoticeBoard board
    property Toaster toaster

    // What lies behind the panel: a place with a title, a line and the control that opened it.
    component Behind: Rectangle {
        color: Tokens.color.bg

        Column {
            x: Tokens.spaceL
            y: Tokens.spaceL
            width: parent.width - 2 * Tokens.spaceL
            spacing: Tokens.spaceM

            Title {
                width: parent.width
                text: "nightly builds"
            }

            Body {
                width: parent.width
                text: "The builds of every branch, run at two each night and kept for thirty days."
            }

            Button {
                objectName: "opener"
                text: "steuerung"
            }
        }
    }

    component ShellPanel: SidePanel {
        id: panel

        property alias controls: controlsFacet

        titles: ["steuerung", "meldungen"]

        Controls {
            id: controlsFacet

            objectName: "controls"
            hasPowerProfiles: true
            onRun: command => testCase.commands = [...testCase.commands, command]
            onLockAsked: testCase.locksAsked++
            onDensityChosen: density => testCase.chosenDensities = [...testCase.chosenDensities, density]
            onPowerProfileChosen: profile => testCase.chosenProfiles = [...testCase.chosenProfiles, profile]
            onDeviceChosen: node => testCase.chosenDevices = [...testCase.chosenDevices, node]
            onBrightnessChosen: (name, value) => testCase.brightnessSets = [...testCase.brightnessSets, [name, value]]
            onSessionAsked: testCase.sessionAsked += 1
            // As the host and Quickshell have it: the adapter switches at once, a device goes on its way.
            onBluetoothChosen: on => {
                testCase.bluetoothSwitches = [...testCase.bluetoothSwitches, on];
                if (testCase.bluetoothTakes)
                    controlsFacet.bluetooth.enabled = on;
            }
            onConnectionChosen: (device, connect) => connect ? device.connect() : device.disconnect()
            onPairingAsked: testCase.pairingAsked += 1
            sheets: panel.sheets
            edge: panel.edge
            // As the host has it, with the networks' own calls.
            onWifiChosen: on => {
                testCase.wifiSwitches = [...testCase.wifiSwitches, on];
                if (testCase.wifiTakes)
                    controlsFacet.networking.wifiEnabled = on;
            }
            onScanWanted: on => testCase.scans = [...testCase.scans, on]
            onNetworkChosen: network => {
                testCase.joined = [...testCase.joined, network.name];
                network.connect();
            }
            onPasswordChosen: (network, password) => {
                testCase.passwordsSent = [...testCase.passwordsSent, password];
                network.connectWithPsk(password);
            }
            onDisconnectAsked: network => {
                testCase.leaves = [...testCase.leaves, network.name];
                network.disconnect();
            }
        }

        Item {
            objectName: "messages"
        }
    }

    Component {
        id: sceneComponent

        Item {
            width: 900
            height: 640

            Behind {
                anchors.fill: parent
            }

            Toaster {
                id: region

                objectName: "toaster"
                width: parent.width
                clock: () => 0
            }

            // As the shell has it: "nicht stören" makes the board quiet.
            NoticeBoard {
                objectName: "board"
                toaster: region
                quiet: scenePanel.controls.doNotDisturb
            }

            ShellPanel {
                id: scenePanel

                objectName: "panel"
                anchors.fill: parent
            }
        }
    }

    // An audio device as PipeWire has it: its description and its audio's volume and muted.
    component FakeDevice: QtObject {
        property string description
        property bool isSink: true
        property QtObject audio: QtObject {
            property real volume: 0.5
            property bool muted: false
        }
    }

    Component {
        id: deviceComponent

        FakeDevice {}
    }

    // A stream's audio as PipeWire has it: volume and muted.
    Component {
        id: audioComponent

        QtObject {
            property real volume: 0.5
            property bool muted: false
        }
    }

    // A Bluetooth adapter as Quickshell has it: enabled and its state.
    component FakeAdapter: QtObject {
        property bool enabled: true
        property int state: Controls.Enabled
    }

    Component {
        id: adapterComponent

        FakeAdapter {}
    }

    // A paired Bluetooth device as Quickshell has it. Like Quickshell's, connect() and disconnect() set the state on its
    // way at once and record the call; the answer is the test's to give.
    component FakeBluetoothDevice: QtObject {
        property string name
        property bool connected: false
        property int state: connected ? Controls.Connected : Controls.Disconnected
        property bool pairing: false
        property bool batteryAvailable: false
        property real battery: 0
        property var calls: []

        function connect() {
            calls = [...calls, "connect"];
            state = Controls.Connecting;
        }

        function disconnect() {
            calls = [...calls, "disconnect"];
            state = Controls.Disconnecting;
        }
    }

    // Quickshell's Networking as the controls read it, and its wireless and wired devices.
    component FakeNetworking: QtObject {
        property bool wifiEnabled: true
        property bool wifiHardwareEnabled: true
    }
    Component {
        id: networkingComponent
        FakeNetworking {}
    }
    component FakeWifiDevice: QtObject {
        property QtObject networks: QtObject {
            property var values: []
        }
    }
    Component {
        id: wifiDeviceComponent
        FakeWifiDevice {}
    }
    component FakeWiredDevice: QtObject {
        property bool connected: true
    }
    Component {
        id: wiredDeviceComponent
        FakeWiredDevice {}
    }
    // A wireless network as Quickshell has it: connect() and disconnect() set stateChanging at once and record the call;
    // the answer, a connection or connectionFailed(), is the test's to give.
    component FakeNetwork: QtObject {
        property string name
        property real signalStrength: 0.5
        property int security: Controls.Open
        property bool known: false
        property bool connected: false
        property bool stateChanging: false
        property var calls: []
        signal connectionFailed(int reason)
        function connect() {
            calls = [...calls, "connect"];
            stateChanging = true;
        }
        function connectWithPsk(psk: string) {
            calls = [...calls, `psk ${psk}`];
            stateChanging = true;
        }
        function disconnect() {
            calls = [...calls, "disconnect"];
            stateChanging = true;
        }
    }
    Component {
        id: networkComponent
        FakeNetwork {}
    }
    // A branch below the fold of a scroller.
    Component {
        id: scrolledBranchComponent

        Flickable {
            property alias branch: lowBranch
            property alias spacer: above
            property alias lateRow: late

            width: 300
            height: 200
            contentHeight: column.height

            Column {
                id: column

                width: parent.width

                Item {
                    id: above

                    width: parent.width
                    height: 400
                }

                PanelBranch {
                    id: lowBranch

                    MenuItem { text: "one" }
                    MenuItem { text: "two" }
                    MenuItem { text: "three" }
                    MenuItem { id: late; text: "late"; visible: false }
                }
            }
        }
    }

    Component {
        id: bluetoothDeviceComponent

        FakeBluetoothDevice {}
    }

    Component {
        id: spyComponent

        SignalSpy {}
    }

    // Something behind the panel that scrolls.
    Component {
        id: scrollerBehindComponent

        Flickable {
            anchors.fill: parent
            z: -1
            contentHeight: 5000
        }
    }

    // A panel with a group whose button opens a level in place of its rows, as a list of networks would.
    Component {
        id: levelPanelComponent

        SidePanel {
            width: 900
            height: 640
            titles: ["steuerung"]

            Column {
                width: parent ? parent.width : 0

                PanelGroup {
                    objectName: "networks"
                    title: "verbindungen"
                    levels: [
                        PanelLevel {
                            id: networks

                            objectName: "level"
                            name: "wlan"
                            options: ["home", "office"]
                            currentIndex: 0
                            onChosen: index => testCase.chosenOptions = [...testCase.chosenOptions, index]
                        }
                    ]

                    PanelRow {
                        label: "wlan · home"

                        Button {
                            id: chooser

                            objectName: "chooseNetwork"
                            text: "wählen"
                            onClicked: networks.show(chooser)
                        }
                    }

                    PanelRow {
                        label: "an"

                        Toggle {}
                    }
                }
            }
        }
    }

    // A group whose one row is absent, such as one waiting for a service.
    Component {
        id: absentGroupComponent

        PanelGroup {
            title: "verbindungen"

            PanelRow {
                label: "wlan"
                present: false

                Toggle {}
            }
        }
    }

    Component {
        id: contactComponent

        // The panel open over a place, as wide as a small window.
        Item {
            width: 760
            height: 640

            Behind {
                anchors.fill: parent
            }

            ShellPanel {
                objectName: "panel"
                anchors.fill: parent
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "off";
        commands = [];
        locksAsked = 0;
        chosenProfiles = [];
        chosenDensities = [];
        chosenDevices = [];
        brightnessSets = [];
        chosenOptions = [];
        sessionAsked = 0;
        bluetoothSwitches = [];
        bluetoothTakes = true;
        pairingAsked = 0;
        wifiSwitches = [];
        wifiTakes = true;
        scans = [];
        joined = [];
        passwordsSent = [];
        leaves = [];
        scene = createTemporaryObject(sceneComponent, testCase);
        side = findChild(scene, "panel");
        controls = side.controls;
        board = findChild(scene, "board");
        toaster = findChild(scene, "toaster");
        named("opener").forceActiveFocus();
    }

    function cleanup() {
        Tips.hide();
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function named(name: string): var {
        return findChild(scene, name);
    }

    function control(name: string): var {
        return findChild(controls, name);
    }

    // The row a control stands in.
    function rowOf(item: var): var {
        let row = item;
        while (row && !(row instanceof PanelRow))
            row = row.parent;
        return row;
    }

    // The hairlines that show inside an item, its own included.
    function hairlinesIn(item: var): var {
        const own = item instanceof Hairline && item.visible ? [item] : [];
        return Array.from(item.children).reduce((lines, child) => lines.concat(hairlinesIn(child)), own);
    }

    // Two outputs and two inputs, the first of each the default, as the host hands them to the controls.
    function giveSound(target: var): var {
        const device = (description, isSink) => createTemporaryObject(deviceComponent, testCase, { description, isSink });
        const sound = {
            speakers: device("Speakers", true),
            headphones: device("Headphones", true),
            microphone: device("Microphone", false),
            headset: device("Headset Microphone", false)
        };
        target.outputs = [sound.speakers, sound.headphones];
        target.inputs = [sound.microphone, sound.headset];
        target.output = sound.speakers;
        target.input = sound.microphone;
        return sound;
    }

    // A program's stream as PipeWire has it once tracked: a playback stream of another process unless `properties`
    // say otherwise.
    function stream(id: int, properties: var, volume: real): var {
        return {
            id,
            name: `node-${id}`,
            properties: Object.assign({
                "media.class": "Stream/Output/Audio",
                "application.process.id": "4242"
            }, properties),
            audio: createTemporaryObject(audioComponent, testCase, { volume })
        };
    }

    // Two tabs of a browser and a music player, as the host hands them to the controls; only the browser names an icon
    // the theme has.
    function giveStreams(target: var): var {
        target.ownProcessId = 1000;
        target.iconFor = name => name === "firefox" ? Qt.resolvedUrl("pictures/blue-32.png").toString() : "";
        const streams = {
            tab: stream(51, { "application.name": "Firefox", "application.icon-name": "firefox", "media.name": "AudioStream" }, 1),
            otherTab: stream(52, { "application.name": "Firefox", "application.icon-name": "firefox", "media.name": "AudioStream" }, 0.4),
            music: stream(53, { "application.name": "Elisa", "application.icon-name": "elisa", "media.name": "Gymnopédie No. 1" }, 0.7)
        };
        target.streams = [streams.tab, streams.otherTab, streams.music];
        return streams;
    }

    function streamRows(): var {
        return shownRows(findChild(controls, "sound")).filter(row => row.objectName === "stream");
    }

    function streamRow(words: string): var {
        return streamRows().find(row => row.label === words) ?? null;
    }

    Component {
        id: displayModelComponent

        ListModel {}
    }

    // A laptop panel at 20% and a monitor at 30%, as the shell's source hands them to the controls.
    function giveDisplays(target: var): var {
        const model = createTemporaryObject(displayModelComponent, testCase);
        model.append({ name: "display0", title: "Built-in Screen", brightness: 51, max: 255 });
        model.append({ name: "display1", title: "Monitor", brightness: 30, max: 100 });
        target.displays = model;
        return model;
    }

    // An adapter that is on and three paired devices: headphones connected with their battery, a speaker and a mouse.
    function giveBluetooth(target: var): var {
        const device = properties => createTemporaryObject(bluetoothDeviceComponent, testCase, properties);
        const bluetooth = {
            adapter: createTemporaryObject(adapterComponent, testCase),
            headphones: device({ name: "Headphones", connected: true, batteryAvailable: true, battery: 0.8 }),
            speaker: device({ name: "Speaker" }),
            mouse: device({ name: "Mouse" })
        };
        target.bluetooth = bluetooth.adapter;
        target.bluetoothDevices = [bluetooth.headphones, bluetooth.speaker, bluetooth.mouse];
        return bluetooth;
    }

    // Paired devices after the three of giveBluetooth, up to `total`; the last is connected.
    function givePairedDevices(target: var, total: int) {
        const more = Array.from({ length: total - 3 }, (_, index) => createTemporaryObject(bluetoothDeviceComponent, testCase, { name: `Device ${index + 4}`, connected: index === total - 4 }));
        target.bluetoothDevices = [...target.bluetoothDevices, ...more];
    }

    // Wireless on, with eight networks in no order: Home (joined, known, secured), Office (known), Guest and Library (open),
    // Neighbour, Cafe, Shop and Hotel (secured, unknown), by falling signal in that order.
    function giveNetworks(target: var): var {
        const network = (name, signalStrength, extra) => createTemporaryObject(networkComponent, testCase, Object.assign({ name, signalStrength, security: 3 }, extra));
        const networks = {
            cafe: network("Cafe", 0.35),
            home: network("Home", 0.9, { connected: true, known: true }),
            office: network("Office", 0.7, { known: true }),
            guest: network("Guest", 0.6, { security: Controls.Open }),
            neighbour: network("Neighbour", 0.5),
            hotel: network("Hotel", 0.2),
            library: network("Library", 0.45, { security: Controls.Open }),
            shop: network("Shop", 0.3)
        };
        const device = createTemporaryObject(wifiDeviceComponent, testCase);
        device.networks.values = Object.values(networks);
        target.networking = createTemporaryObject(networkingComponent, testCase);
        target.wifiDevice = device;
        networks.device = device;
        return networks;
    }
    // The rows that show in a branch of the controls.
    function rowsOf(branchName: string): var {
        const list = Array.from(control(branchName).children).find(child => child instanceof Column);
        return Array.from(list.children).filter(row => row instanceof MenuItem && row.visible);
    }
    function typeText(text: string) {
        Array.from(text).forEach(letter => keyClick(letter));
    }
    function sheet(): var {
        return findChild(side, "passwordSheet");
    }
    // The rows that show in the unfolded devices.
    function branchRows(): var {
        const list = Array.from(control("bluetoothBranch").children).find(child => child instanceof Column);
        return Array.from(list.children).filter(row => row instanceof MenuItem && row.visible);
    }

    // The Bluetooth level of the controls, which the row "alle geräte …" opens; here opened directly.
    function showBluetoothLevel(): var {
        side.show(0);
        control("bluetoothDevices").show(control("chooseBluetoothDevice"));
        const level = control("bluetoothDevices");
        verify(level.open);
        waitForRendering(side);
        return level;
    }

    // The side panel open on a facet once its slide has ended, so that clicks land where the controls stand.
    function showSettled(index: int) {
        side.show(index);
        tryCompare(side, "entry", 1, Tokens.durationModerate * 4);
        waitForRendering(side);
    }

    // The level panel, open and drawn.
    function showLevelPanel(): var {
        const panel = createTemporaryObject(levelPanelComponent, testCase);
        panel.show(0);
        waitForRendering(panel);
        return panel;
    }

    // The rows of a level: the back row first, then one per option.
    function levelRows(level: var): var {
        return Array.from(level.children).filter(row => row instanceof MenuItem);
    }

    // The words a pointer coming to rest on a text brings up, "" for none; coming on from another tip, they show at once.
    function tipOver(text: var): string {
        mouseMove(scene, 1, 1);
        Tips.hiddenAt = Date.now();
        mouseMove(text);
        return Tips.target === text ? Tips.text : "";
    }

    // The option rows of a select, in order.
    function optionRows(select: var): var {
        return Array.from(findChild(select, "options").children).filter(row => row.objectName === "option");
    }

    // A signal as a notification has them, to connect() to; the test emit()s it.
    function signal() {
        const handlers = [];
        return {
            connect: handler => handlers.push(handler),
            emit: (...args) => handlers.forEach(handler => handler(...args))
        };
    }

    // A notification as the server hands it over, in plain JS (see tst_notices).
    function notify(properties) {
        const fake = Object.assign({
            lastGeneration: false,
            appName: "chat",
            appIcon: "",
            summary: "anna",
            body: "lunch at noon?",
            urgency: NoticeBoard.Normal,
            expireTimeout: -1,
            transient: false,
            desktopEntry: "org.example.chat",
            image: "",
            hints: {},
            actions: [],
            closed: signal(),
            summaryChanged: signal(),
            bodyChanged: signal()
        }, properties);
        fake.expire = () => fake.closed.emit(NoticeBoard.Expired);
        fake.dismiss = () => fake.closed.emit(NoticeBoard.Dismissed);
        board.arrive(fake);
        return fake;
    }

    function test_the_panel_stands_at_the_trailing_edge_the_full_height_two_and_a_half_tile_units_wide_with_a_sheets_padding() {
        side.show(0);
        const panel = findChild(side, "panel");
        const contentWidth = 2.5 * Tokens.tileUnit + Tokens.spaceS;
        compare(panel.width, Geometry.hairline + 2 * Tokens.spaceM + contentWidth);
        compare(panel.x, 900 - panel.width, "at the trailing edge");
        compare(panel.y, 0);
        compare(panel.height, 640, "the full height");
        const pivot = findChild(side, "pivot");
        compare(pivot.mapToItem(panel, 0, 0).x, Geometry.hairline + Tokens.spaceM, "space-m at the sides");
        compare(pivot.y, Tokens.spaceL, "space-l at the top");
        compare(pivot.width, contentWidth);
        const facets = findChild(side, "facets");
        compare(facets.mapToItem(panel, 0, 0).x, Geometry.hairline + Tokens.spaceM, "its facets too");
        compare(facets.width, contentWidth);
        const scroller = findChild(side, "scroller");
        compare(scroller.width, panel.width - Geometry.hairline, "they scroll across the ground, so no focus ring at their edge is cut off");
        const edge = findChild(side, "edge");
        compare(edge.y + edge.height, 640 - Tokens.spaceL, "and at the bottom, below the quick settings");
        compare(scroller.y + scroller.height, edge.y - Tokens.spaceM, "which stand space-m below the facet's scroll");
        side.show(1);
        compare(edge.height, 0, "meldungen keeps nothing at the edge");
        compare(scroller.y + scroller.height, 640 - Tokens.spaceL, "and scrolls down to the padding");
        scene.height = 400;
        compare(panel.height, 400);
    }

    function test_the_panel_lies_on_the_ground_with_a_hairline_along_its_leading_edge() {
        side.show(0);
        const panel = findChild(side, "panel");
        const ground = findChild(side, "ground");
        compare(panel.color, Tokens.color.textContrastLow, "the hairline shows under the ground");
        compare(ground.x, Geometry.hairline);
        compare(ground.width, panel.width - Geometry.hairline);
        compare(ground.color, Tokens.color.bg);
    }

    function test_nothing_beside_it_is_shaded() {
        side.show(0);
        waitForRendering(scene);
        const image = grabImage(scene);
        verify(Qt.colorEqual(image.pixel(900 - side.panelWidth - 4, 600), Tokens.color.bg), "the place beside it");
        verify(Qt.colorEqual(image.pixel(4, 600), Tokens.color.bg));
    }

    function test_its_pivot_is_a_places_strip_with_a_hairline_below() {
        side.show(0);
        const pivot = findChild(side, "pivot");
        compare(pivot.level, "nav");
        compare(pivot.titles, ["steuerung", "meldungen"]);
        compare(pivot.placeWidth, 2.5 * Tokens.tileUnit + Tokens.spaceS, "the panel is the place");
        verify(pivot.compact, "and a narrow one, so the strip takes the facet sizes");
        const under = findChild(side, "underPivot");
        compare(under.y, pivot.y + pivot.height);
        compare(under.width, pivot.width);
        compare(findChild(side, "scroller").y, under.y + Geometry.hairline);
    }

    // Its ground is bg, not glass, so an inactive title keeps the pivot colour of Rekta (rekta.css:244).
    function test_on_its_ground_the_pivots_inactive_title_keeps_text_contrast_medium() {
        side.show(0);
        compare(findChild(findChild(findChild(side, "pivot"), "title-1"), "word").color, Tokens.color.textContrastMedium);
    }

    function test_it_slides_all_the_way_in_from_the_trailing_edge_over_duration_moderate_with_ease_out() {
        Prefs.motion = "on";
        const comingIn = findChild(side, "comingIn");
        compare(comingIn.duration, Tokens.durationModerate);
        compare(comingIn.easing.type, Easing.Bezier);
        compare(comingIn.easing.bezierCurve, Tokens.easeOut);
        side.show(0);
        const panel = findChild(side, "panel");
        compare(panel.x, 900, "it starts wholly beyond the trailing edge");
        side.entry = 0.5;
        compare(panel.x, 900 - panel.width / 2, "it moves, never fades or scales");
        compare(panel.opacity, 1);
        compare(panel.y, 0);
        tryCompare(comingIn, "running", false, Tokens.durationModerate * 4);
        compare(side.entry, 1);
        compare(panel.x, 900 - panel.width, "and stands at the trailing edge");
    }

    function test_it_slides_out_the_way_it_came_in_0_8_duration_moderate_with_ease_out_and_is_closed_once_gone() {
        Prefs.motion = "on";
        const goingOut = findChild(side, "goingOut");
        compare(goingOut.duration, 0.8 * Tokens.durationModerate);
        compare(goingOut.easing.type, Easing.Bezier);
        compare(goingOut.easing.bezierCurve, Tokens.easeOut);
        const closed = createTemporaryObject(spyComponent, testCase, { target: side, signalName: "closed" });
        side.show(0);
        tryCompare(side, "entry", 1, Tokens.durationModerate * 4);
        side.close();
        verify(side.open, "it is open while it leaves");
        compare(closed.count, 0);
        const panel = findChild(side, "panel");
        tryVerify(() => panel.x > 900 - panel.width, Tokens.durationModerate * 4, "towards the trailing edge");
        tryCompare(closed, "count", 1, Tokens.durationModerate * 4);
        verify(!side.open);
        compare(side.entry, 0, "wholly beyond the trailing edge again");
        compare(panel.x, 900);
    }

    function test_shown_again_while_it_leaves_it_comes_back() {
        Prefs.motion = "on";
        side.show(0);
        tryCompare(side, "entry", 1, Tokens.durationModerate * 4);
        side.close();
        side.show(0);
        tryCompare(side, "entry", 1, Tokens.durationModerate * 4);
        wait(Tokens.durationModerate);
        verify(side.open, "it stays");
    }

    function test_under_reduced_motion_the_panel_stands_at_once_and_goes_at_once() {
        Prefs.motion = "off";
        side.show(0);
        compare(side.entry, 1, "in at once");
        compare(findChild(side, "panel").x, 900 - side.panelWidth);
        side.close();
        verify(!side.open, "gone at once, never skipped");
        verify(!side.visible);
    }

    function test_escape_closes_it_and_the_focus_goes_back_to_where_it_was() {
        side.show(0);
        verify(!named("opener").activeFocus, "the panel holds the focus");
        keyClick(Qt.Key_Escape);
        verify(!side.open);
        verify(named("opener").activeFocus, "and gives it back");
    }

    function test_escape_closes_it_from_every_control() {
        for (const name of ["dark", "doNotDisturb", "density", "powerProfile", "lock", "sessionActions"]) {
            side.show(0);
            control(name).forceActiveFocus();
            keyClick(Qt.Key_Escape);
            verify(!side.open, name);
        }
    }

    function test_what_lies_beside_it_takes_presses_and_the_wheel_and_the_panel_stays_open() {
        const opener = named("opener");
        const clicked = createTemporaryObject(spyComponent, testCase, { target: opener, signalName: "clicked" });
        const behind = createTemporaryObject(scrollerBehindComponent, scene);
        showSettled(0);
        mouseWheel(scene, 200, 300, 0, -120);
        tryVerify(() => behind.contentY > 0, 1000, "the wheel scrolls what lies beside it");
        mouseClick(opener);
        compare(clicked.count, 1, "a press reaches it");
        verify(side.open, "and leaves the panel open");
    }

    function test_toggle_closes_it_on_the_facet_in_sight_and_turns_to_another() {
        side.toggle(0);
        verify(side.open);
        side.toggle(1);
        verify(side.open, "another facet");
        compare(side.currentIndex, 1);
        side.toggle(1);
        verify(!side.open, "the same facet");
    }

    function test_it_opens_on_the_facet_asked_for_without_sliding_it_in() {
        Prefs.motion = "on";
        side.show(1);
        compare(side.currentIndex, 1);
        verify(findChild(side, "messages").visible);
        verify(!controls.visible);
        compare(findChild(side, "shift").x, 0, "the facet stands");
        compare(findChild(side, "holder").opacity, 1);
    }

    function test_after_it_opened_on_a_facet_the_next_one_still_comes_from_the_trailing_edge_going_forward() {
        Prefs.motion = "on";
        side.show(0);
        side.show(1);
        side.close();
        tryCompare(side, "open", false, Tokens.durationModerate * 4);
        side.show(0);
        side.show(1);
        verify(findChild(side, "shift").x > 0, "forward, from the trailing edge");
    }

    function test_going_to_steuerung_its_quick_settings_at_the_edge_come_in_with_it() {
        Prefs.motion = "on";
        showSettled(1);
        side.show(0);
        const edge = findChild(side, "edge");
        compare(findChild(side, "shift").x, -Tokens.slideDistance, "the facet comes back from the leading edge");
        compare(edge.opacity, 0, "the quick settings fade in with it");
        const edgeShift = findChild(side, "edgeShift");
        compare(edgeShift.x, -Tokens.slideDistance, "and travel with it");
        tryCompare(edge, "opacity", 1, Tokens.durationModerate * 4);
        compare(edgeShift.x, 0);
    }

    function test_under_reduced_motion_the_quick_settings_stand_at_once_with_steuerung() {
        Prefs.motion = "off";
        showSettled(1);
        side.show(0);
        compare(findChild(side, "edgeShift").x, 0);
        compare(findChild(side, "edge").opacity, 1);
    }

    function test_on_their_way_in_the_quick_settings_are_cut_off_at_the_ground_and_leave_the_hairline_a_hairline() {
        giveNetworks(controls);
        Prefs.motion = "on";
        showSettled(1);
        side.show(0);
        // Held at the start of the way, past the ground's edge, at full opacity so that a pixel over the hairline shows.
        findChild(side, "enter").stop();
        findChild(side, "shift").x = -Tokens.slideDistance;
        findChild(side, "holder").opacity = 1;
        waitForRendering(scene);
        const wifi = control("wifi");
        verify(wifi.checked, "wlan on, an accent fill");
        verify(wifi.mapToItem(findChild(side, "ground"), 0, 0).x < 0, "the row reaches past the ground");
        const hairline = findChild(side, "panel").mapToItem(scene, 0, 0);
        const besideWifi = wifi.mapToItem(scene, 0, wifi.height / 2);
        verify(Qt.colorEqual(grabImage(scene).pixel(Math.floor(hairline.x), Math.floor(besideWifi.y)), Tokens.color.textContrastLow));
    }

    function test_the_focus_ring_of_a_quick_setting_at_the_grounds_padding_is_not_cut_off() {
        giveNetworks(controls);
        showSettled(0);
        const wifi = control("wifi");
        wifi.forceActiveFocus(Qt.TabFocusReason);
        waitForRendering(scene);
        const ring = findChild(wifi, "ring");
        verify(ring.visible);
        const leftStroke = ring.mapToItem(scene, Geometry.focusRingWidth / 2, ring.height / 2);
        verify(Qt.colorEqual(grabImage(scene).pixel(Math.floor(leftStroke.x), Math.floor(leftStroke.y)), Tokens.color.focus));
    }

    function test_the_pivot_picks_steuerung_or_meldungen_and_their_facet_shows() {
        side.show(0);
        verify(controls.visible);
        verify(!findChild(side, "messages").visible);
        findChild(side, "pivot").forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(side.currentIndex, 1);
        verify(findChild(side, "messages").visible);
        verify(!controls.visible);
        keyClick(Qt.Key_Left);
        compare(side.currentIndex, 0);
        verify(controls.visible);
    }

    function test_focus_starts_at_the_first_control_and_on_an_empty_facet_at_the_pivot() {
        side.show(0);
        verify(control("density").activeFocus, "the first control in steuerung");
        side.close();
        side.show(1);
        verify(findChild(side, "pivot").activeFocus, "meldungen has none yet");
    }

    function ringOf(name: string): var {
        return findChild(control(name), "ring");
    }

    function test_opened_by_a_pointer_no_control_shows_a_focus_ring_until_a_key_is_pressed() {
        side.show(0, true);
        verify(control("density").activeFocus, "the focus is on the first control all the same");
        compare(ringsShowing(control("density")), 0);
        keyClick(Qt.Key_Tab);
        verify(control("powerProfile").activeFocus);
        compare(ringsShowing(control("powerProfile")), 1, "the keyboard brings the ring");
    }

    // The focus rings that show inside an item.
    function ringsShowing(item: var): int {
        let count = item instanceof FocusRing && item.visible ? 1 : 0;
        for (const child of item.children)
            count += ringsShowing(child);
        return count;
    }

    // A panel in a window of its own, so the window can be inactive when the panel opens, as a layer-shell surface is.
    Component {
        id: windowedComponent

        Window {
            property alias panel: windowedPanel
            property alias first: firstToggle

            width: 600
            height: 600

            SidePanel {
                id: windowedPanel

                anchors.fill: parent
                titles: ["steuerung"]

                Column {
                    width: parent ? parent.width : 0

                    Toggle {
                        id: firstToggle

                        activeFocusOnTab: true
                    }

                    Toggle {
                        objectName: "second"
                        activeFocusOnTab: true
                    }
                }
            }
        }
    }

    function test_the_activation_of_the_window_after_a_pointer_open_keeps_the_rings_away() {
        const window = createTemporaryObject(windowedComponent, testCase);
        window.panel.show(0, true);
        window.show();
        window.requestActivate();
        tryVerify(() => window.active);
        tryVerify(() => window.first.activeFocus, 2000, "the window's activation hands the focus to the first control");
        compare(ringsShowing(window.contentItem), 0, "the activation is no key");
    }

    function test_a_key_on_the_pivot_after_a_pointer_open_brings_its_ring() {
        side.show(1, true);
        const pivot = findChild(side, "pivot");
        verify(pivot.activeFocus);
        compare(ringsShowing(pivot), 0);
        keyClick(Qt.Key_Right);
        compare(ringsShowing(pivot), 1, "the arrow moved the selection, and the keyboard has a ring");
    }

    function test_space_on_a_toggle_button_after_a_pointer_open_brings_the_ring() {
        side.show(0, true);
        control("dark").forceActiveFocus();
        // The focus move above would bring the ring on its own; the key is what is under test.
        side.ringsHidden = true;
        compare(ringsShowing(control("dark")), 0);
        keyClick(Qt.Key_Space);
        compare(ringsShowing(control("dark")), 1, "the control took the key itself, and the keyboard has a ring");
    }

    function test_an_arrow_on_a_slider_after_a_pointer_open_brings_the_ring() {
        giveSound(controls);
        side.show(0, true);
        const slider = control("outputVolume");
        slider.forceActiveFocus();
        // The focus move above would bring the ring on its own; the key is what is under test.
        side.ringsHidden = true;
        compare(ringsShowing(slider), 0);
        keyClick(Qt.Key_Right);
        compare(ringsShowing(slider), 1, "the slider took the key itself, and the keyboard has a ring");
    }

    function test_shift_tab_after_a_pointer_open_brings_the_ring() {
        side.show(0, true);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        verify(findChild(side, "pivot").activeFocus);
        compare(ringsShowing(findChild(side, "pivot")), 1);
    }

    function test_opened_by_the_keyboard_the_first_control_shows_its_focus_ring() {
        side.show(0, false);
        compare(ringsShowing(control("density")), 1);
    }

    // The quick settings at the bottom edge come last, as they stand.
    function test_tab_and_the_arrows_reach_every_control_in_order() {
        giveBluetooth(controls);
        side.show(0);
        const names = ["chooseBluetoothDevice", "density", "powerProfile", "lock", "sessionActions", "bluetooth", "doNotDisturb", "dark"];
        const order = names.map(name => control(name));
        verify(order[0].activeFocus);
        for (let k = 1; k < order.length; k++) {
            keyClick(Qt.Key_Tab);
            verify(order[k].activeFocus, `Tab to ${names[k]}`);
        }
        for (let k = order.length - 2; k >= 0; k--) {
            keyClick(Qt.Key_Tab, Qt.ShiftModifier);
            verify(order[k].activeFocus, `Shift+Tab to ${names[k]}`);
        }
        keyClick(Qt.Key_Down);
        verify(order[1].activeFocus, "↓ to the next");
        order[0].forceActiveFocus();
        keyClick(Qt.Key_Up);
        verify(findChild(side, "pivot").activeFocus, "↑ from the first to the pivot");
        keyClick(Qt.Key_Down);
        verify(order[0].activeFocus, "↓ from the pivot to the first");
        order[4].forceActiveFocus();
        keyClick(Qt.Key_Down);
        verify(order[5].activeFocus, "↓ from the last row into the quick settings");
        keyClick(Qt.Key_Down);
        verify(order[6].activeFocus, "and through them");
        keyClick(Qt.Key_Up);
        verify(order[5].activeFocus, "↑ to the one before");
        order[7].forceActiveFocus();
        keyClick(Qt.Key_Down);
        verify(order[7].activeFocus, "the arrows never leave the panel");
    }

    function test_every_row_works_from_the_keyboard() {
        controls.hasPerformanceProfile = true;
        controls.kdeglobals = "";
        side.show(0);
        verify(control("density").activeFocus);
        keyClick(Qt.Key_Right);
        compare(chosenDensities, ["comfortable"], "dichte, where the arrows choose");
        keyClick(Qt.Key_Tab);
        verify(control("powerProfile").activeFocus);
        keyClick(Qt.Key_Right);
        compare(chosenProfiles, [2], "energieprofil, where the arrows choose");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        compare(locksAsked, 1, "sperren");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        compare(sessionAsked, 1, "sitzung …");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Space);
        verify(controls.doNotDisturb, "nicht stören");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        compare(commands, [["plasma-apply-lookandfeel", "--apply", "org.kde.breezedark.desktop"]], "dunkel");
    }

    function test_dunkel_applies_the_dark_theme_of_plasmas_pair_and_the_light_one_back() {
        controls.kdeglobals = "[General]\nColorScheme=RektaLight\n\n[KDE]\nDefaultDarkLookAndFeel=org.example.night\nDefaultLightLookAndFeel=org.example.day\nLookAndFeelPackage=org.example.day\n";
        showSettled(0);
        verify(!control("dark").checked, "light now");
        mouseClick(control("dark"));
        compare(commands, [["plasma-apply-lookandfeel", "--apply", "org.example.night"]]);
        mouseClick(control("dark"));
        compare(commands[1], ["plasma-apply-lookandfeel", "--apply", "org.example.day"]);
    }

    function test_without_a_pair_in_kdeglobals_dunkel_switches_between_breeze_and_breeze_dark() {
        compare(LookAndFeel.pair(""), { light: "org.kde.breeze.desktop", dark: "org.kde.breezedark.desktop" });
        compare(LookAndFeel.pair("[KDE]\nAnimationDurationFactor=0.5\n").dark, "org.kde.breezedark.desktop");
        compare(LookAndFeel.pair("[KDE][$i]\nDefaultDarkLookAndFeel[$i]=org.example.night\n").dark, "org.example.night", "KConfig flags");
        compare(LookAndFeel.pair("[Icons]\nDefaultDarkLookAndFeel=org.example.night\n").dark, "org.kde.breezedark.desktop", "only [KDE]");
        compare(LookAndFeel.pair("[KDE Action Restrictions]\nDefaultDarkLookAndFeel=org.example.night\n").dark, "org.kde.breezedark.desktop");
        compare(LookAndFeel.pair("[KDE]\nDefaultLightLookAndFeel = org.example.day\n").light, "org.example.day");
    }

    function test_dunkel_shows_the_systems_scheme_also_after_a_change_elsewhere() {
        Prefs.theme = "dark";
        const darkScene = createTemporaryObject(sceneComponent, testCase);
        verify(findChild(darkScene, "dark").checked, "dark from the start");
        darkScene.destroy();
        Prefs.theme = "light";
        showSettled(0);
        Prefs.theme = "dark";
        verify(control("dark").checked);
        compare(findChild(control("dark"), "state").text, "an");
        mouseClick(control("dark"));
        verify(!control("dark").checked, "the choice shows at once");
        Prefs.theme = "light";
        Prefs.theme = "dark";
        verify(control("dark").checked, "and the system's next change too");
        Prefs.theme = "light";
        verify(!control("dark").checked);
        compare(findChild(control("dark"), "state").text, "aus");
    }

    function test_with_nicht_stoeren_only_critical_notifications_toast_and_the_others_go_quietly_into_the_list() {
        showSettled(0);
        mouseClick(control("doNotDisturb"));
        verify(controls.doNotDisturb);
        notify({ summary: "anna" });
        compare(toaster.open, null, "no toast");
        compare(board.rows.length, 1, "but in the list");
        verify(board.rows[0].unseen);
        notify({ summary: "battery low", urgency: NoticeBoard.Critical });
        verify(toaster.open !== null, "a critical one toasts");
        compare(toaster.open.title, "battery low");
        mouseClick(control("doNotDisturb"));
        verify(!board.quiet, "off again");
    }

    function test_the_power_profile_segments_set_the_profile_and_offer_leistung_only_where_the_machine_has_it() {
        side.show(0);
        const segments = control("powerProfile");
        compare(segments.options, ["sparen", "ausgewogen"]);
        compare(segments.currentIndex, 1, "balanced");
        controls.hasPerformanceProfile = true;
        compare(segments.options, ["sparen", "ausgewogen", "leistung"]);
        segments.forceActiveFocus();
        keyClick(Qt.Key_Left);
        compare(chosenProfiles, [0]);
        controls.powerProfile = 2;
        compare(segments.currentIndex, 2, "a profile set elsewhere shows");
    }

    function test_the_density_segments_offer_automatisch_bequem_kompakt_and_ask_for_the_chosen_density() {
        side.show(0);
        const segments = control("density");
        compare(segments.options, ["automatisch", "bequem", "kompakt"]);
        compare(segments.currentIndex, 0);
        segments.choose(2);
        compare(chosenDensities, ["compact"]);
        controls.density = "compact";
        segments.choose(0);
        compare(chosenDensities, ["compact", "auto"]);
    }

    function test_the_density_segments_show_the_density_the_shell_has_not_the_one_asked_for() {
        side.show(0);
        const segments = control("density");
        segments.choose(1);
        compare(segments.currentIndex, 0, "a refused write leaves the shown density");
        controls.density = "compact";
        compare(segments.currentIndex, 2, "a density set elsewhere shows");
    }

    function test_without_the_power_profile_daemon_its_row_is_gone() {
        side.show(0);
        verify(rowOf(control("powerProfile")).visible);
        controls.hasPowerProfiles = false;
        verify(!rowOf(control("powerProfile")).visible);
        verify(findChild(controls, "session").visible, "sperren still stands in sitzung");
    }

    function test_sperren_locks_the_session() {
        showSettled(0);
        mouseClick(control("lock"));
        compare(locksAsked, 1);
        compare(commands, []);
    }

    function test_sitzung_asks_for_the_session_banner_below_sperren() {
        showSettled(0);
        const sessionActions = control("sessionActions");
        compare(sessionActions.text, "sitzung …");
        verify(rowOf(sessionActions).y > rowOf(control("lock")).y, "in the group sitzung, below sperren");
        mouseClick(sessionActions);
        compare(sessionAsked, 1);
        compare(commands, [], "it runs nothing itself");
    }

    // The rows of a group that show, in their order.
    function shownRows(group: var): var {
        return Array.from(findChild(group, "rows").children).filter(row => row instanceof PanelRow && row.visible);
    }

    // The tooltip shows as drawn: its ink at its padding, left of the words.
    function drawnAsInk(tip: var): bool {
        waitForRendering(side);
        const at = tip.mapToItem(scene, Tokens.spaceS / 2, tip.height / 2);
        return Qt.colorEqual(grabImage(scene).pixel(at.x, at.y), Tokens.color.textPrimary);
    }

    function glyphOf(name: string): string {
        return findChild(control(name), "glyph").name;
    }

    function test_each_device_has_two_rows_its_select_then_its_mute_button_before_the_volume_slider() {
        const sound = giveSound(controls);
        sound.speakers.audio.volume = 0.62;
        side.show(0);
        waitForRendering(side);
        const group = findChild(controls, "sound");
        compare(findChild(group, "heading").text, "ton");
        tryCompare(group, "y", 0, 1000, "the first group");
        compare(shownRows(group), [rowOf(control("outputDevice")), rowOf(control("outputVolume")), rowOf(control("inputDevice")), rowOf(control("inputVolume"))], "no row of its own for stumm");
        for (const kind of ["output", "input"]) {
            const select = control(`${kind}Device`);
            verify(!findChild(rowOf(select), "words").visible, `${kind}: no words before the select`);
            compare(select.mapToItem(rowOf(select), 0, 0).x, 0, kind);
            compare(select.width, rowOf(select).width, `${kind}: the select as wide as the row`);
            const row = rowOf(control(`${kind}Volume`));
            const box = findChild(control(`${kind}Mute`), "box");
            compare(rowOf(control(`${kind}Mute`)), row, `${kind}: the button stands in the volume's row`);
            compare(box.mapToItem(row, 0, 0).x, 0, `${kind}: the button at the start`);
            compare(box.width, Tokens.controlHeight, `${kind}: a square icon button`);
            const slider = control(`${kind}Volume`);
            compare(slider.mapToItem(row, 0, 0).x, box.width + Tokens.spaceM, `${kind}: the slider space-m after it`);
            compare(slider.mapToItem(row, slider.width, 0).x, row.width, `${kind}: to the end of the row`);
            compare(row.height, Tokens.controlHeight, `${kind}: on one line`);
        }
        compare(glyphOf("outputMute"), "speaker");
        compare(glyphOf("inputMute"), "microphone");
        compare(control("outputDevice").currentText, "Speakers");
        compare(control("inputDevice").currentText, "Microphone");
        compare(findChild(control("outputVolume"), "output").text, "62%");
        compare(findChild(control("outputVolume"), "output").font.features, { "tnum": 1 }, "in tabular figures");
        compare(control("outputDevice").Accessible.name, "ausgang Speakers", "the kind is read with the select");
        compare(control("inputDevice").Accessible.name, "eingang Microphone");
        compare(control("outputVolume").Accessible.name, "lautstärke ausgang");
        compare(control("inputVolume").Accessible.name, "lautstärke eingang");
    }

    function test_the_slider_sets_the_device_and_follows_changes_from_elsewhere() {
        const sound = giveSound(controls);
        showSettled(0);
        const slider = control("outputVolume");
        slider.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(sound.speakers.audio.volume, 0.51, "a step up sets the device's volume");
        sound.speakers.audio.volume = 0.8;
        compare(slider.value, 0.8, "a key or an app moves the slider");
        compare(findChild(slider, "output").text, "80%");
        sound.speakers.audio.volume = 1.4;
        compare(slider.value, 1, "a raised volume shows as the end of the scale");
        control("inputVolume").forceActiveFocus();
        keyClick(Qt.Key_Left);
        compare(sound.microphone.audio.volume, 0.49, "the microphone the same");
    }

    function test_the_button_mutes_its_device_strikes_its_glyph_through_and_rests_the_slider_whose_value_says_stumm() {
        const sound = giveSound(controls);
        sound.speakers.audio.volume = 0.62;
        showSettled(0);
        const slider = control("outputVolume");
        mouseClick(findChild(control("outputMute"), "box"));
        verify(sound.speakers.audio.muted, "a press mutes the device");
        compare(glyphOf("outputMute"), "speaker-muted");
        verify(slider.disabled, "the slider rests");
        compare(findChild(slider, "output").text, "stumm", "its value says why");
        compare(findChild(slider, "output").color, Tokens.color.disabled, "in grey");
        compare(slider.Accessible.description, "stumm");
        verify(!findChild(slider, "why").visible, "and nothing below says it again");
        compare(rowOf(slider).height, Tokens.controlHeight);
        slider.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(sound.speakers.audio.volume, 0.62, "a resting slider takes no step");
        mouseClick(findChild(control("outputMute"), "box"));
        verify(!sound.speakers.audio.muted, "a second press brings the sound back");
        compare(glyphOf("outputMute"), "speaker");
        verify(!slider.disabled);
        compare(findChild(slider, "output").text, "62%");
        mouseClick(findChild(control("inputMute"), "box"));
        verify(sound.microphone.audio.muted, "the microphone the same");
        compare(glyphOf("inputMute"), "microphone-muted");
        verify(control("inputVolume").disabled);
        verify(!sound.speakers.audio.muted, "only its own device");
    }

    function test_a_mute_from_elsewhere_shows_at_once_in_the_glyph_the_slider_and_the_name() {
        const sound = giveSound(controls);
        side.show(0);
        sound.speakers.audio.muted = true;
        compare(glyphOf("outputMute"), "speaker-muted");
        verify(control("outputVolume").disabled);
        compare(findChild(control("outputVolume"), "output").text, "stumm");
        compare(control("outputMute").Accessible.name, "ausgang ton an");
        sound.speakers.audio.muted = false;
        compare(glyphOf("outputMute"), "speaker");
        verify(!control("outputVolume").disabled);
        compare(findChild(control("outputVolume"), "output").text, "50%");
        sound.microphone.audio.muted = true;
        compare(glyphOf("inputMute"), "microphone-muted");
        verify(control("inputVolume").disabled);
    }

    function test_the_mute_button_is_named_and_tipped_by_what_a_press_does() {
        const sound = giveSound(controls);
        side.show(0);
        const button = control("outputMute");
        compare(button.Accessible.name, "ausgang stumm schalten");
        compare(control("inputMute").Accessible.name, "eingang stumm schalten");
        button.forceActiveFocus();
        compare(Tips.target, findChild(button, "box"), "keyboard focus shows its tip");
        compare(Tips.text, "stumm schalten");
        keyClick(Qt.Key_Space);
        compare(button.Accessible.name, "ausgang ton an");
        compare(Tips.text, "ton an", "the tip that shows says the new words");
        sound.speakers.audio.muted = false;
        compare(button.Accessible.name, "ausgang stumm schalten", "both follow a change from elsewhere");
        compare(Tips.text, "stumm schalten");
    }

    function test_the_panel_draws_the_tip_of_its_control_above_it_and_scrolling_hides_it() {
        giveSound(controls);
        showSettled(0);
        const tip = named("tip");
        const words = findChild(tip, "words");
        const box = findChild(control("outputMute"), "box");
        verify(!tip.visible);
        control("outputMute").forceActiveFocus();
        verify(tip.visible, "the panel's window draws its own tips");
        compare(words.text, "stumm schalten");
        const at = box.mapToItem(tip.parent, 0, 0);
        compare(tip.side, "above");
        compare(tip.y, Math.round(at.y - Tokens.tipGap - tip.height), "tip-gap above its control");
        verify(tip.x < at.x + box.width && tip.x + tip.width > at.x, "over it");
        verify(tip.x >= Tokens.spaceS && tip.x + tip.width <= tip.parent.width - Tokens.spaceS, "within the panel");
        verify(drawnAsInk(tip), "an ink strip");
        keyClick(Qt.Key_Space);
        verify(tip.visible);
        compare(words.text, "ton an", "it says what the next press does");
        named("scroller").contentY = 1;
        verify(!tip.visible, "scrolling hides it");
    }

    function test_escape_hides_a_tip_that_shows_and_only_a_second_escape_closes_the_panel() {
        giveSound(controls);
        showSettled(0);
        const tip = named("tip");
        control("outputMute").forceActiveFocus();
        verify(tip.visible);
        keyClick(Qt.Key_Escape);
        verify(!tip.visible, "the tip takes Escape first");
        verify(side.open, "the panel stays open");
        verify(control("outputMute").activeFocus, "and its control keeps the focus");
        keyClick(Qt.Key_Escape);
        verify(!side.open, "a second Escape closes it");
    }

    function test_a_press_anywhere_in_the_panel_hides_a_tip_and_reaches_what_it_lands_on() {
        const sound = giveSound(controls);
        showSettled(0);
        const tip = named("tip");
        const slider = control("outputVolume");
        control("outputMute").forceActiveFocus();
        verify(tip.visible);
        mousePress(slider, slider.width / 4, slider.height / 2);
        verify(!tip.visible, "a press on the slider hides it");
        verify(sound.speakers.audio.volume < 0.5, "and the slider takes the press");
        mouseRelease(slider, slider.width / 4, slider.height / 2);
        control("inputMute").forceActiveFocus();
        verify(tip.visible);
        const ground = findChild(side, "ground");
        mousePress(ground, ground.width / 2, ground.height - Tokens.spaceL / 2, Qt.RightButton);
        verify(!tip.visible, "a press of any button on the bare ground hides it too");
        mouseRelease(ground, ground.width / 2, ground.height - Tokens.spaceL / 2, Qt.RightButton);
        verify(side.open);
    }

    function test_ton_works_from_the_keyboard() {
        const sound = giveSound(controls);
        sound.speakers.audio.volume = 0.6;
        side.show(0);
        verify(control("outputDevice").activeFocus, "the first control");
        keyClick(Qt.Key_Tab);
        verify(control("outputMute").activeFocus, "Tab to the button");
        keyClick(Qt.Key_Space);
        verify(sound.speakers.audio.muted, "Space mutes");
        keyClick(Qt.Key_Down);
        verify(control("outputVolume").activeFocus, "↓ to the slider, which a keyboard still reaches while it rests");
        keyClick(Qt.Key_Right);
        compare(sound.speakers.audio.volume, 0.6);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        verify(control("outputMute").activeFocus, "Shift+Tab back to the button");
        keyClick(Qt.Key_Return);
        verify(!sound.speakers.audio.muted, "Enter brings the sound back");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Right);
        compare(sound.speakers.audio.volume, 0.61, "then the slider steps");
        keyClick(Qt.Key_Tab);
        verify(control("inputDevice").activeFocus, "Tab on to the input's select");
        keyClick(Qt.Key_Tab);
        verify(control("inputMute").activeFocus);
        keyClick(Qt.Key_Enter);
        verify(sound.microphone.audio.muted, "the microphone the same");
        keyClick(Qt.Key_Up);
        verify(control("inputDevice").activeFocus, "↑ back to its select");
    }

    function test_rows_follow_another_default_device() {
        const sound = giveSound(controls);
        side.show(0);
        sound.headphones.audio.volume = 0.3;
        controls.output = sound.headphones;
        compare(control("outputDevice").currentText, "Headphones");
        compare(control("outputVolume").value, 0.3);
    }

    function test_anzeige_shows_a_slider_for_each_display_with_its_name_and_percent() {
        giveDisplays(controls);
        side.show(0);
        waitForRendering(side);
        const slider = control("display0Brightness");
        compare(findChild(rowOf(slider), "words").text, "helligkeit Built-in Screen");
        compare(slider.value, 0.2);
        compare(findChild(slider, "output").text, "20%");
        compare(findChild(slider, "output").font.features, { "tnum": 1 });
        compare(slider.Accessible.name, "helligkeit Built-in Screen");
        compare(control("display1Brightness").value, 0.3);
        compare(slider.width, rowOf(slider).width, "as wide as the row, below its words");
        verify(rowOf(slider).y < rowOf(control("density")).y, "above the other rows of anzeige");
    }

    function test_a_step_of_a_brightness_slider_asks_for_that_display_in_its_own_units() {
        giveDisplays(controls);
        side.show(0);
        control("display1Brightness").forceActiveFocus();
        keyClick(Qt.Key_Right);
        control("display0Brightness").forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(brightnessSets, [["display1", 31], ["display0", 54]]);
    }

    function test_a_brightness_slider_follows_a_change_from_elsewhere() {
        const displays = giveDisplays(controls);
        side.show(0);
        control("display0Brightness").forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(control("display0Brightness").value, 0.21, "a step ends the slider's binding");
        displays.setProperty(0, "brightness", 102);
        compare(control("display0Brightness").value, 0.4);
        compare(findChild(control("display0Brightness"), "output").text, "40%");
        displays.setProperty(1, "max", 200);
        compare(control("display1Brightness").value, 0.15, "a new range moves it too");
        compare(brightnessSets, [["display0", 54]], "following asks for nothing more than the step");
    }

    function test_a_brightness_slider_held_by_the_pointer_ignores_changes_until_released() {
        const displays = giveDisplays(controls);
        showSettled(0);
        const slider = control("display1Brightness");
        const track = findChild(slider, "track");
        mousePress(track, track.width / 2, 3);
        verify(slider.pressed);
        const held = slider.value;
        displays.setProperty(1, "brightness", 90);
        compare(slider.value, held, "an echo of an earlier value does not pull the thumb back");
        mouseRelease(track, track.width / 2, 3);
        compare(slider.value, 0.9, "released, it shows what powerdevil last told");
    }

    function test_a_display_that_comes_and_goes_adds_and_removes_its_slider() {
        const displays = giveDisplays(controls);
        side.show(0);
        displays.append({ name: "display2", title: "Tablet", brightness: 5, max: 10 });
        compare(control("display2Brightness").value, 0.5);
        displays.remove(0);
        verify(!control("display0Brightness"));
        compare(control("display1Brightness").value, 0.3, "the others keep their place and value");
    }

    function test_without_a_display_that_can_be_dimmed_anzeige_has_no_brightness_slider_and_keeps_its_other_rows() {
        side.show(0);
        verify(!control("display0Brightness"));
        verify(findChild(controls, "display").visible);
        giveDisplays(controls).clear();
        verify(!control("display0Brightness"));
        verify(rowOf(control("density")).visible);
    }

    function test_without_audio_devices_ton_falls_away_and_without_an_input_only_its_rows_go() {
        const sound = giveSound(controls);
        side.show(0);
        controls.input = null;
        verify(findChild(controls, "sound").visible);
        verify(!rowOf(control("inputDevice")).visible);
        verify(!rowOf(control("inputVolume")).visible);
        controls.output = null;
        verify(!findChild(controls, "sound").visible);
    }

    function test_each_stream_another_program_plays_has_a_row_in_ton_between_the_output_and_the_input() {
        giveSound(controls);
        giveStreams(controls);
        showSettled(0);
        const group = findChild(controls, "sound");
        const rows = streamRows();
        compare(shownRows(group), [rowOf(control("outputDevice")), rowOf(control("outputVolume")), ...rows, rowOf(control("inputDevice")), rowOf(control("inputVolume"))]);
        compare(rows.map(row => row.label), ["Firefox · AudioStream", "Firefox · AudioStream", "Elisa · Gymnopédie No. 1"], "one row per stream, in the order they came, as the programs write them");
        for (const row of rows) {
            const words = findChild(row, "words");
            const button = findChild(row, "streamMute");
            const slider = findChild(row, "streamVolume");
            compare(words.x, Geometry.iconSize + Tokens.spaceS, `${row.label}: the words space-s after the icon's room`);
            compare(button.mapToItem(row, 0, 0).y, words.height + Tokens.spaceXs, `${row.label}: the controls space-xs below the words`);
            compare(findChild(button, "box").mapToItem(row, 0, 0).x, 0, `${row.label}: the button at the start`);
            compare(slider.mapToItem(row, 0, 0).x, findChild(button, "box").width + Tokens.spaceM, `${row.label}: the slider space-m after it`);
            compare(slider.mapToItem(row, slider.width, 0).x, row.width, `${row.label}: to the end of the row`);
            compare(findChild(button, "glyph").name, "speaker");
        }
        const icon = findChild(rows[0], "icon");
        verify(icon.visible);
        compare(icon.source, Qt.resolvedUrl("pictures/blue-32.png"), "the program's icon");
        compare(icon.width, Geometry.iconSize, "20px in a row");
        compare(icon.mapToItem(rows[0], 0, 0).x, 0, "at the start");
        verify(!findChild(rows[2], "icon").visible, "none where the theme lacks it");
        compare(findChild(rows[2], "words").x, findChild(rows[0], "words").x, "its words start where the others do");
        compare(findChild(findChild(rows[1], "streamVolume"), "output").text, "40%");
        compare(findChild(findChild(rows[2], "streamVolume"), "output").text, "70%");
    }

    function test_a_stream_without_media_name_or_icons_shows_the_program_alone_with_its_words_at_the_start() {
        giveSound(controls);
        controls.streams = [stream(61, { "application.name": "mpv" }, 0.5), stream(62, {}, 0.5)];
        side.show(0);
        const rows = streamRows();
        compare(rows.map(row => row.label), ["mpv", "node-62"], "the node's name where the program gives none");
        compare(findChild(rows[0], "words").x, 0, "without an icon in the list, no room for one");
    }

    function test_only_the_playback_streams_of_other_programs_have_rows() {
        giveSound(controls);
        controls.ownProcessId = 1000;
        controls.streams = [
            stream(71, { "media.class": "Stream/Input/Audio", "application.name": "Recorder" }, 0.5),
            stream(72, { "media.class": "Stream/Input/Audio", "stream.capture.sink": "true", "application.name": "Meter" }, 0.5),
            stream(73, { "media.class": "Stream/Output/Video", "application.name": "KWin" }, 0.5),
            stream(74, { "application.name": "Shell", "application.process.id": "1000" }, 0.5),
            stream(75, { "media.class": "Audio/Sink", "application.name": "Card" }, 0.5),
            stream(78, { "application.name": "canberra-gtk-play", "media.role": "event" }, 0.5),
            stream(79, { "application.name": "Chat", "media.role": "Notification" }, 0.5),
            Object.assign(stream(76, {}, 0.5), { properties: {} }),
            stream(77, { "application.name": "Player" }, 0.5)
        ];
        side.show(0);
        compare(streamRows().map(row => row.label), ["Player"], "no recording, monitor, video, own, device, untracked or event stream");
    }

    function test_a_streams_button_and_slider_set_that_stream_alone_and_follow_changes_from_elsewhere() {
        const sound = giveSound(controls);
        sound.speakers.audio.volume = 0.6;
        const streams = giveStreams(controls);
        showSettled(0);
        const row = streamRows()[1];
        const slider = findChild(row, "streamVolume");
        mouseClick(findChild(findChild(row, "streamMute"), "box"));
        verify(streams.otherTab.audio.muted, "a press mutes the stream");
        compare(findChild(findChild(row, "streamMute"), "glyph").name, "speaker-muted");
        verify(slider.disabled, "its slider rests");
        compare(findChild(slider, "output").text, "stumm", "its value says why");
        compare(findChild(slider, "output").color, Tokens.color.disabled, "in grey");
        verify(!streams.tab.audio.muted && !streams.music.audio.muted && !sound.speakers.audio.muted, "nothing else is muted");
        mouseClick(findChild(findChild(row, "streamMute"), "box"));
        verify(!streams.otherTab.audio.muted, "a second press brings it back");
        slider.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(streams.otherTab.audio.volume, 0.41, "a step sets the stream's volume");
        compare(streams.tab.audio.volume, 1, "the other tab keeps its own");
        compare(sound.speakers.audio.volume, 0.6, "the output keeps its own");
        streams.otherTab.audio.volume = 0.8;
        compare(slider.value, 0.8, "a change from elsewhere moves the slider");
        streams.otherTab.audio.muted = true;
        compare(findChild(findChild(row, "streamMute"), "glyph").name, "speaker-muted", "a mute from elsewhere shows at once");
        verify(slider.disabled);
    }

    function test_a_streams_controls_are_named_by_its_words_and_what_a_press_does() {
        giveSound(controls);
        const streams = giveStreams(controls);
        side.show(0);
        const row = streamRow("Elisa · Gymnopédie No. 1");
        const button = findChild(row, "streamMute");
        compare(button.Accessible.name, "Elisa · Gymnopédie No. 1 stumm schalten");
        compare(findChild(row, "streamVolume").Accessible.name, "lautstärke Elisa · Gymnopédie No. 1");
        button.forceActiveFocus();
        compare(Tips.text, "stumm schalten");
        keyClick(Qt.Key_Space);
        verify(streams.music.audio.muted);
        compare(button.Accessible.name, "Elisa · Gymnopédie No. 1 ton an");
        compare(Tips.text, "ton an");
    }

    function test_the_keyboard_reaches_each_streams_button_and_slider_between_the_output_and_the_input() {
        giveSound(controls);
        const streams = giveStreams(controls);
        side.show(0);
        control("outputVolume").forceActiveFocus();
        for (const row of streamRows()) {
            keyClick(Qt.Key_Tab);
            verify(findChild(row, "streamMute").activeFocus, `Tab to the button of ${row.label}`);
            keyClick(Qt.Key_Down);
            verify(findChild(row, "streamVolume").activeFocus, `↓ to its slider`);
        }
        keyClick(Qt.Key_Left);
        compare(streams.music.audio.volume, 0.69, "the slider steps its stream");
        keyClick(Qt.Key_Tab);
        verify(control("inputDevice").activeFocus, "then on to the input");
        keyClick(Qt.Key_Up);
        verify(findChild(streamRows()[2], "streamVolume").activeFocus, "↑ back");
    }

    function test_a_stream_that_comes_is_appended_and_arrives_from_above_with_a_fade_while_the_rows_below_make_room() {
        giveSound(controls);
        const streams = giveStreams(controls);
        showSettled(0);
        Prefs.motion = "on";
        const presence = findChild(controls, "streamPresence");
        const input = rowOf(control("inputDevice"));
        const player = stream(54, { "application.name": "Haruna", "media.name": "clip.mkv" }, 0.9);
        controls.streams = [streams.tab, streams.otherTab, streams.music, player];
        const rows = streamRows();
        compare(rows.map(row => row.label).pop(), "Haruna · clip.mkv", "appended after the others");
        const coming = presence.moving.find(motion => motion.item === rows[3]);
        verify(coming, "it arrives");
        compare(coming.from.y, -Geometry.arriveShift, "from just above");
        compare(coming.from.opacity, 0, "with a fade");
        compare(coming.duration, Tokens.durationShort);
        compare(coming.curve, Tokens.easeIn);
        const making = presence.moving.find(motion => motion.item === input);
        verify(making, "the input's row glides down");
        compare(making.from.y, -(rows[3].height + Tokens.spaceM), "from where it stood, the new row and its space higher");
        compare(making.duration, Tokens.durationModerate);
        tryVerify(() => !presence.running, Tokens.durationModerate * 4);
        compare(rows[3].opacity, 1, "whole once it rests");
    }

    function test_a_stream_that_ends_leaves_as_it_was_drifting_to_the_trailing_edge_and_the_rest_close_the_gap() {
        giveSound(controls);
        const streams = giveStreams(controls);
        streams.tab.audio.muted = true;
        showSettled(0);
        Prefs.motion = "on";
        const presence = findChild(controls, "streamPresence");
        const leaving = streamRows()[0];
        const below = streamRows()[1];
        const gap = leaving.height + Tokens.spaceM;
        controls.streams = [streams.otherTab, streams.music];
        const going = presence.moving.find(motion => motion.item === leaving);
        verify(going, "it leaves");
        compare(going.to.x, Geometry.leaveRowDrift, "towards the trailing edge");
        compare(going.to.opacity, 0, "with a fade");
        compare(going.duration, Geometry.leaveShare * Tokens.durationShort);
        compare(going.curve, Tokens.easeOut);
        compare(leaving.label, "Firefox · AudioStream", "showing its words");
        compare(findChild(findChild(leaving, "streamMute"), "glyph").name, "speaker-muted", "and its state");
        tryVerify(() => streamRows().length === 2, Tokens.durationShort * 4, "then it is gone");
        const closing = presence.moving.find(motion => motion.item === below);
        verify(closing, "the next row glides up");
        compare(closing.from.y, gap, "from where it stood, the gone row and its space lower");
        compare(closing.curve, Tokens.easeBase);
    }

    function test_a_stream_that_names_a_new_track_while_another_leaves_shows_it_and_the_leaving_goes_on() {
        giveSound(controls);
        const streams = giveStreams(controls);
        showSettled(0);
        Prefs.motion = "on";
        const presence = findChild(controls, "streamPresence");
        const leaving = streamRows()[0];
        controls.streams = [streams.otherTab, streams.music];
        verify(presence.moving.some(motion => motion.item === leaving), "the tab leaves");
        // Quickshell hands the same node with new properties; the stand-in is a new object with the same id.
        const renamed = Object.assign({}, streams.music, {
            properties: Object.assign({}, streams.music.properties, { "media.name": "Gnossienne No. 1" })
        });
        controls.streams = [streams.otherTab, renamed];
        verify(presence.moving.some(motion => motion.item === leaving), "the tab goes on leaving");
        compare(streamRows().length, 3, "in its place meanwhile");
        compare(streamRows()[2].label, "Elisa · Gnossienne No. 1", "the player shows its new track");
        tryVerify(() => streamRows().length === 2, Tokens.durationShort * 4, "then the tab is gone");
    }

    function test_under_reduced_motion_streams_come_and_go_at_once() {
        giveSound(controls);
        const streams = giveStreams(controls);
        side.show(0);
        controls.streams = [streams.music];
        compare(streamRows().map(row => row.label), ["Elisa · Gymnopédie No. 1"]);
        controls.streams = [streams.music, streams.tab];
        compare(streamRows().map(row => row.label), ["Elisa · Gymnopédie No. 1", "Firefox · AudioStream"]);
        verify(!findChild(controls, "streamPresence").running);
    }

    function test_without_streams_ton_shows_its_device_rows_alone() {
        giveSound(controls);
        side.show(0);
        compare(streamRows(), []);
        compare(shownRows(findChild(controls, "sound")).length, 4);
    }

    function test_the_output_select_expands_in_place_pushes_the_rows_below_down_and_a_click_asks_for_another_default() {
        const sound = giveSound(controls);
        showSettled(0);
        const select = control("outputDevice");
        const volumeRow = rowOf(control("outputVolume"));
        const before = volumeRow.mapToItem(controls, 0, 0).y;
        mouseClick(findChild(select, "box"));
        verify(select.expanded);
        const options = optionRows(select);
        compare(options.map(row => findChild(row, "label").text), ["Speakers", "Headphones"]);
        compare(options.map(row => findChild(row, "fill").visible), [true, false], "the default in the accent");
        const growth = findChild(select, "box").height - Tokens.controlHeight;
        tryVerify(() => volumeRow.mapToItem(controls, 0, 0).y === before + growth, 1000, "the volume's row moves down by what the select grows");
        waitForRendering(side);
        mouseClick(options[1]);
        compare(chosenDevices, [sound.headphones], "a click chooses");
        verify(!select.expanded);
        compare(select.currentText, "Speakers", "the default PipeWire has, until it changes");
        controls.output = sound.headphones;
        compare(select.currentText, "Headphones");
        tryVerify(() => volumeRow.mapToItem(controls, 0, 0).y === before, 1000, "and back up");
        verify(findChild(findChild(controls, "sound"), "rows").visible, "the rows stay in place");
    }

    function test_the_input_select_lists_the_inputs() {
        const sound = giveSound(controls);
        showSettled(0);
        const select = control("inputDevice");
        mouseClick(findChild(select, "box"));
        const options = optionRows(select);
        compare(options.map(row => findChild(row, "label").text), ["Microphone", "Headset Microphone"]);
        waitForRendering(side);
        mouseClick(options[1]);
        compare(chosenDevices, [sound.headset]);
    }

    function test_from_the_keyboard_it_expands_a_device_is_chosen_and_the_focus_stays() {
        const sound = giveSound(controls);
        side.show(0);
        const select = control("outputDevice");
        verify(select.activeFocus, "the first control in steuerung");
        keyClick(Qt.Key_Down);
        verify(select.expanded, "↓ expands it rather than moving on");
        compare(select.highlighted, 0, "the keys start on the default");
        keyClick(Qt.Key_Down);
        compare(select.highlighted, 1);
        keyClick(Qt.Key_Down);
        verify(select.activeFocus, "the last option keeps ↓ in the select");
        keyClick(Qt.Key_Return);
        compare(chosenDevices, [sound.headphones], "Enter chooses");
        verify(!select.expanded);
        verify(select.activeFocus, "the focus stays on the select");
        verify(side.open);
    }

    function test_escape_collapses_the_select_and_leaves_the_panel_open() {
        giveSound(controls);
        side.show(0);
        const select = control("outputDevice");
        keyClick(Qt.Key_Return);
        verify(select.expanded);
        keyClick(Qt.Key_Escape);
        verify(!select.expanded);
        verify(side.open, "the panel stays");
        verify(select.activeFocus);
        compare(chosenDevices, []);
        keyClick(Qt.Key_Escape);
        verify(!side.open, "the next Escape closes the panel");
    }

    function test_escape_folds_a_select_a_pointer_expanded_without_focus_and_only_a_second_escape_closes_the_panel() {
        giveSound(controls);
        showSettled(0);
        const select = control("inputDevice");
        mouseClick(findChild(select, "box"));
        verify(select.expanded);
        verify(!select.activeFocus, "a press gives no focus");
        Tips.show(control("inputMute"), "stumm schalten");
        keyClick(Qt.Key_Escape);
        verify(!Tips.target, "a tip takes Escape before the list");
        verify(select.expanded);
        keyClick(Qt.Key_Escape);
        verify(!select.expanded, "Escape folds the list first");
        verify(side.open, "the panel stays");
        keyClick(Qt.Key_Escape);
        verify(!side.open, "a second Escape closes the panel");
    }

    function test_escape_folds_a_branch_a_pointer_unfolded_without_focus_and_only_a_second_escape_closes_the_panel() {
        giveSound(controls);
        giveBluetooth(controls);
        showSettled(0);
        const branch = control("bluetoothBranch");
        mouseClick(control("chooseBluetoothDevice"));
        verify(branch.expanded);
        verify(!side.within(rowOf(control("chooseBluetoothDevice")), side.Window.activeFocusItem), "nor in the row of its opener");
        verify(!side.within(branch, side.Window.activeFocusItem), "the focus is not in the branch");
        Tips.show(control("dark"), "dunkel");
        keyClick(Qt.Key_Escape);
        verify(!Tips.target, "a tip takes Escape before the branch");
        verify(branch.expanded);
        keyClick(Qt.Key_Escape);
        verify(!branch.expanded, "Escape folds the branch first");
        verify(side.open, "the panel stays");
        keyClick(Qt.Key_Escape);
        verify(!side.open, "a second Escape closes the panel");
    }

    function test_escape_in_another_window_leaves_an_open_select_and_branch_open() {
        giveSound(controls);
        giveBluetooth(controls);
        showSettled(0);
        const select = control("inputDevice");
        const branch = control("bluetoothBranch");
        mouseClick(findChild(select, "box"));
        mouseClick(control("chooseBluetoothDevice"));
        const elsewhere = createTemporaryObject(windowedComponent, testCase).first;
        const escape = { key: Qt.Key_Escape };
        verify(!select.foldOnEscape(escape, elsewhere));
        verify(!branch.foldOnEscape(escape, elsewhere));
        verify(select.expanded);
        verify(branch.expanded);
    }

    function test_another_key_or_a_sheet_over_them_leaves_an_open_select_and_branch_open() {
        giveSound(controls);
        giveBluetooth(controls);
        showSettled(0);
        const select = control("inputDevice");
        const branch = control("bluetoothBranch");
        mouseClick(findChild(select, "box"));
        mouseClick(control("chooseBluetoothDevice"));
        const focused = side.Window.activeFocusItem;
        verify(!select.foldOnEscape({ key: Qt.Key_Down }, focused), "only Escape");
        verify(!branch.foldOnEscape({ key: Qt.Key_Down }, focused), "only Escape");
        KeyLayers.opened(side.sheets);
        verify(!select.foldOnEscape({ key: Qt.Key_Escape }, focused), "a sheet over it is nearer");
        verify(!branch.foldOnEscape({ key: Qt.Key_Escape }, focused), "a sheet over it is nearer");
        KeyLayers.closed(side.sheets);
        verify(select.expanded);
        verify(branch.expanded);
    }

    function test_the_select_collapses_with_the_panel() {
        giveSound(controls);
        side.show(0);
        keyClick(Qt.Key_Return);
        verify(control("outputDevice").expanded);
        side.close();
        verify(!side.open);
        verify(!control("outputDevice").expanded);
        side.show(0);
        verify(!control("outputDevice").expanded, "and stays collapsed when it comes back");
    }

    function test_an_expanded_select_brings_its_options_into_view_in_the_panels_scroller() {
        giveSound(controls);
        scene.height = 360;
        side.show(0);
        waitForRendering(side);
        const scroller = findChild(side, "scroller");
        const select = control("inputDevice");
        const top = () => select.mapToItem(scroller, 0, 0).y;
        compare(scroller.contentY, 0);
        verify(top() + select.expandedHeight > scroller.height, "below the view once expanded");
        select.forceActiveFocus();
        keyClick(Qt.Key_Down);
        verify(select.expanded);
        tryVerify(() => Math.abs(top() + select.height - scroller.height) < 0.5, 1000, "its last option at the foot of the view");
        verify(top() >= 0);
    }

    function atTopOfView(item: var, scroller: var): bool {
        return Math.abs(item.mapToItem(scroller, 0, 0).y) < 0.5 || scroller.contentY + scroller.height >= scroller.contentHeight - 0.5;
    }

    function test_revealing_a_place_from_a_closed_panel_scrolls_to_it_once_the_facet_has_laid_out() {
        giveSound(controls);
        scene.height = 360;
        const row = controls.places.power;
        side.show(0);
        side.reveal(row);
        const scroller = findChild(side, "scroller");
        tryVerify(() => atTopOfView(row, scroller));
        verify(scroller.contentY > 0);
        wait(200);
        verify(atTopOfView(row, scroller), "and stays there");
    }

    function test_revealing_nothing_scrolls_back_to_the_top_and_a_hand_on_the_view_lets_the_place_go() {
        giveSound(controls);
        scene.height = 360;
        side.show(0);
        waitForRendering(side);
        const scroller = findChild(side, "scroller");
        side.reveal(controls.places.power);
        tryVerify(() => scroller.contentY > 0);
        side.reveal(null);
        compare(scroller.contentY, 0);
        side.reveal(controls.places.power);
        mouseWheel(scroller, 10, 10, 0, 120);
        verify(side.revealed === null, "the wheel takes the view");
    }

    function test_a_word_leads_to_its_place_in_the_controls() {
        giveBluetooth(controls);
        compare(controls.places.sound, findChild(side, "sound"));
        compare(controls.places.connections, findChild(side, "connections"));
        compare(controls.places.doNotDisturb, control("doNotDisturb"), "nicht stören is its button");
        compare(controls.places.power.label, "energieprofil");
        controls.hasPowerProfiles = false;
        compare(controls.places.power, findChild(side, "session"), "without profiles the group it would stand in");
    }

    function test_revealing_a_place_puts_the_focus_on_its_first_control() {
        giveSound(controls);
        giveBluetooth(controls);
        scene.height = 360;
        side.show(0);
        side.reveal(controls.places.connections);
        const first = findChild(side, "chooseBluetoothDevice");
        tryVerify(() => first.activeFocus);
        side.reveal(controls.places.sound);
        tryVerify(() => findChild(side, "outputDevice").activeFocus || side.within(controls.places.sound, scene.Window.activeFocusItem));
    }

    function test_revealing_a_quick_setting_puts_the_focus_on_it_and_scrolls_the_facet_to_the_top() {
        giveSound(controls);
        scene.height = 360;
        side.show(0);
        const scroller = findChild(side, "scroller");
        scroller.contentY = 40;
        side.reveal(controls.places.doNotDisturb);
        verify(control("doNotDisturb").activeFocus, "the button itself, at the edge and always in view");
        compare(side.revealed, null, "there is nothing to hold in view");
        compare(scroller.contentY, 0);
    }

    function test_the_place_is_let_go_once_the_facet_has_laid_out() {
        giveSound(controls);
        scene.height = 360;
        side.show(0);
        side.reveal(controls.places.power);
        verify(side.revealed !== null);
        tryVerify(() => side.revealed === null);
    }

    function test_a_device_list_unfolding_after_the_jump_scrolls_itself_whole_into_view() {
        giveSound(controls);
        giveBluetooth(controls);
        scene.height = 360;
        side.show(0);
        side.reveal(controls.places.connections);
        tryVerify(() => side.revealed === null);
        const scroller = findChild(side, "scroller");
        const branch = control("bluetoothBranch");
        branch.expand();
        const bottom = () => branch.mapToItem(scroller, 0, branch.height).y;
        tryVerify(() => branch.unfolded === 1 && bottom() <= scroller.height + 0.5, 3000, `the list ends at ${bottom()} in a view ${scroller.height} high`);
    }

    function test_a_later_change_of_the_content_does_not_pull_the_view_back_to_the_place() {
        giveSound(controls);
        scene.height = 360;
        side.show(0);
        side.reveal(controls.places.power);
        tryVerify(() => side.revealed === null);
        const scroller = findChild(side, "scroller");
        scroller.contentY = 0;
        controls.hasPowerProfiles = false;
        waitForRendering(side);
        wait(100);
        compare(scroller.contentY, 0);
    }

    function test_revealing_a_place_that_is_not_there_leaves_the_view_at_the_top() {
        side.show(0);
        side.reveal(controls.places.connections);
        compare(findChild(side, "scroller").contentY, 0);
        compare(side.revealed, null);
    }

    function test_a_long_device_name_is_cut_in_its_select_and_in_its_row() {
        const sound = giveSound(controls);
        sound.speakers.description = "Navi 21/23 HDMI/DP Audio Controller Digital Stereo (HDMI 3)".repeat(Math.ceil(Tokens.tileUnit / 40));
        showSettled(0);
        const select = control("outputDevice");
        verify(findChild(select, "chosen").truncated, "in the select");
        mouseClick(findChild(select, "box"));
        waitForRendering(side);
        const label = findChild(optionRows(select)[0], "label");
        verify(label.truncated, "in its row");
        verify(label.mapToItem(select, label.width, 0).x <= select.width - Geometry.inputPadding);
    }

    function test_a_level_opens_in_place_of_its_groups_rows_headed_by_zurück() {
        const panel = showLevelPanel();
        const group = findChild(panel, "networks");
        const level = findChild(panel, "level");
        mouseClick(findChild(panel, "chooseNetwork"));
        verify(level.open);
        verify(level.visible);
        verify(!findChild(group, "rows").visible, "the list replaces the rows");
        compare(findChild(group, "heading").text, "verbindungen", "under the group's heading");
        const rows = levelRows(level);
        compare(rows.map(row => row.text), ["zurück · wlan", "home", "office"]);
        compare(rows[0].glyph, "back");
        compare(rows.slice(1).map(row => row.kind), ["radio", "radio"]);
        compare(rows.slice(1).map(row => row.checked), [true, false], "the current one is marked as a chosen menu option");
        waitForRendering(panel);
        mouseClick(rows[2]);
        compare(chosenOptions, [1], "a click chooses");
        verify(!level.open, "and goes back");
        verify(findChild(group, "rows").visible);
    }

    function test_the_back_row_goes_back_without_choosing() {
        const panel = showLevelPanel();
        const level = findChild(panel, "level");
        mouseClick(findChild(panel, "chooseNetwork"));
        waitForRendering(panel);
        mouseClick(levelRows(level)[0]);
        verify(!level.open);
        compare(chosenOptions, []);
    }

    function test_from_the_keyboard_a_level_opens_an_option_is_chosen_and_the_focus_goes_back() {
        const panel = showLevelPanel();
        const opener = findChild(panel, "chooseNetwork");
        verify(opener.activeFocus, "the first control");
        keyClick(Qt.Key_Space);
        const level = findChild(panel, "level");
        verify(level.open);
        const rows = levelRows(level);
        verify(rows[1].activeFocus, "the focus starts on the current option");
        keyClick(Qt.Key_Down);
        verify(rows[2].activeFocus, "↓ to the next");
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Up);
        verify(rows[0].activeFocus, "↑ to the back row");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(chosenOptions, [1], "Enter chooses");
        verify(!level.open, "and goes back");
        verify(opener.activeFocus, "to the control that opened it");
    }

    function test_escape_and_left_leave_a_level_and_the_panel_open() {
        const panel = showLevelPanel();
        const opener = findChild(panel, "chooseNetwork");
        const level = findChild(panel, "level");
        for (const key of [Qt.Key_Escape, Qt.Key_Left]) {
            opener.forceActiveFocus();
            keyClick(Qt.Key_Return);
            verify(level.open);
            keyClick(key);
            verify(!level.open, `${key} goes back`);
            verify(panel.open, "the panel stays");
            verify(opener.activeFocus);
        }
        opener.forceActiveFocus();
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Return);
        verify(!level.open, "Enter on the back row goes back");
        compare(chosenOptions, []);
    }

    function test_a_level_comes_in_from_the_trailing_edge_and_the_rows_come_back_from_the_leading_edge() {
        Prefs.motion = "on";
        const panel = showLevelPanel();
        tryCompare(panel, "entry", 1, Tokens.durationModerate * 4);
        const group = findChild(panel, "networks");
        const enter = findChild(group, "enter");
        compare(enter.duration, 0.75 * Tokens.durationModerate, "the next item, same place");
        compare(enter.animations[0].easing.bezierCurve, Tokens.easeOut);
        const shift = findChild(group, "shift");
        compare(shift.x, 0, "the rows stand at first");
        findChild(panel, "chooseNetwork").forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(shift.x, Tokens.slideDistance, "forward, from the trailing edge");
        compare(findChild(group, "holder").opacity, 0, "with a fade");
        tryCompare(shift, "x", 0, Tokens.durationModerate * 4);
        keyClick(Qt.Key_Escape);
        compare(shift.x, -Tokens.slideDistance, "back, from the leading edge");
        tryCompare(shift, "x", 0, Tokens.durationModerate * 4);
    }

    function test_under_reduced_motion_a_level_changes_at_once() {
        const panel = showLevelPanel();
        const group = findChild(panel, "networks");
        findChild(panel, "chooseNetwork").forceActiveFocus();
        keyClick(Qt.Key_Return);
        verify(findChild(panel, "level").visible, "in at once");
        compare(findChild(group, "shift").x, 0);
        compare(findChild(group, "holder").opacity, 1);
        keyClick(Qt.Key_Escape);
        verify(findChild(group, "rows").visible, "and back at once");
        compare(findChild(group, "shift").x, 0);
    }

    function test_the_panel_opens_again_on_the_groups_rows() {
        const panel = showLevelPanel();
        mouseClick(findChild(panel, "chooseNetwork"));
        verify(findChild(panel, "level").open);
        panel.close();
        panel.show(0);
        verify(!findChild(panel, "level").open);
        verify(findChild(findChild(panel, "networks"), "rows").visible);
        verify(findChild(panel, "chooseNetwork").activeFocus);
    }

    function test_a_long_option_is_cut_in_a_level() {
        const panel = showLevelPanel();
        findChild(panel, "level").options = ["home", "Navi 21/23 HDMI/DP Audio Controller Digital Stereo (HDMI 3) guest network"];
        mouseClick(findChild(panel, "chooseNetwork"));
        waitForRendering(panel);
        const row = levelRows(findChild(panel, "level"))[2];
        const label = findChild(row, "label");
        verify(label.truncated);
        verify(label.x + label.width <= row.width - Tokens.spaceM);
    }

    function test_a_cut_option_of_a_level_shows_whole_in_a_tip_under_the_pointer_and_at_once_for_keyboard_focus() {
        const long = "Navi 21/23 HDMI/DP Audio Controller Digital Stereo (HDMI 3) guest network";
        const panel = showLevelPanel();
        const level = findChild(panel, "level");
        level.options = ["home", long];
        findChild(panel, "chooseNetwork").forceActiveFocus();
        keyClick(Qt.Key_Space);
        verify(level.open);
        waitForRendering(panel);
        const rows = levelRows(level);
        verify(rows[1].activeFocus);
        compare(Tips.target, null, "home fits");
        keyClick(Qt.Key_Down);
        compare(Tips.target, findChild(rows[2], "label"), "keyboard focus on a cut option");
        compare(Tips.text, long);
        verify(findChild(panel, "tip").visible, "drawn in the panel");
        keyClick(Qt.Key_Up);
        compare(Tips.target, null, "the focus leaving takes it away");
        compare(tipOver(findChild(rows[2], "label")), long, "a resting pointer");
        compare(tipOver(findChild(rows[1], "label")), "");
        mouseMove(scene, 1, 1);
        Tips.hide();
        panel.ringsHidden = true;
        rows[2].forceActiveFocus();
        compare(Tips.target, null, "focus a pointer gave shows none");
    }

    function test_a_cut_network_name_in_verbindungen_shows_whole_in_a_tip_under_the_pointer_and_for_keyboard_focus() {
        const long = "the guest network of the house by the lake, second floor, room two";
        const networks = giveNetworks(controls);
        networks.office.name = long;
        showSettled(0);
        control("chooseNetwork").forceActiveFocus();
        keyClick(Qt.Key_Return);
        waitForRendering(side);
        const office = findChild(rowsOf("wifiBranch")[1], "label");
        verify(office.truncated);
        compare(tipOver(office), long, "a resting pointer");
        compare(tipOver(findChild(rowsOf("wifiBranch")[0], "label")), "", "Home fits");
        mouseMove(scene, 1, 1);
        Tips.hide();
        keyClick(Qt.Key_Down);
        compare(Tips.target, null);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        verify(rowsOf("wifiBranch")[1].activeFocus);
        compare(Tips.target, office, "keyboard focus shows it at once");
        compare(Tips.text, long);
    }

    function test_a_cut_device_name_shows_whole_in_a_tip_over_the_select_and_over_its_option_and_scrolling_hides_it() {
        const long = "Navi 21/23 HDMI/DP Audio Controller Digital Stereo (HDMI 3) of the monitor on the left";
        giveSound(controls).speakers.description = long;
        showSettled(0);
        const select = control("outputDevice");
        const chosen = findChild(select, "chosen");
        compare(tipOver(chosen), long, "over the select");
        compare(findChild(named("tip"), "words").text, long, "drawn in the panel");
        named("scroller").contentY = 1;
        compare(Tips.target, null, "scrolling hides it");
        named("scroller").contentY = 0;
        mouseClick(findChild(select, "box"));
        waitForRendering(side);
        const options = optionRows(select);
        compare(tipOver(findChild(options[0], "label")), long, "over its option");
        compare(tipOver(findChild(options[1], "label")), "", "Headphones fits");
        compare(tipOver(chosen), "", "the box's own words lie under the options");
    }

    function test_keyboard_focus_on_a_select_shows_its_cut_choice_at_once_and_its_options_and_pointer_focus_show_none() {
        const long = "Navi 21/23 HDMI/DP Audio Controller Digital Stereo (HDMI 3) of the monitor on the left";
        giveSound(controls).speakers.description = long;
        showSettled(0);
        const select = control("outputDevice");
        verify(select.activeFocus, "the first control, from the keyboard");
        compare(Tips.target, findChild(select, "chosen"));
        compare(Tips.text, long);
        control("density").forceActiveFocus();
        compare(Tips.target, null, "the focus leaving takes it away");
        select.forceActiveFocus();
        compare(Tips.target, findChild(select, "chosen"), "and coming back by keyboard brings it again");
        keyClick(Qt.Key_Down);
        verify(select.expanded);
        compare(Tips.target, null, "expanded, the options stand over it");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Up);
        compare(Tips.target, null, "the keys move only the highlight");
        keyClick(Qt.Key_Escape);
        side.close();
        tryVerify(() => !side.open);
        side.show(0, true);
        verify(select.activeFocus);
        compare(Tips.target, null, "focus a pointer gave shows none");
    }

    function test_the_cut_word_or_state_of_a_quick_setting_shows_whole_in_a_tip_and_keyboard_focus_shows_neither() {
        const long = "the guest network of the house by the lake, second floor";
        giveNetworks(controls).home.name = long;
        showSettled(0);
        const wifi = control("wifi");
        compare(tipOver(findChild(wifi, "state")), long, "its state");
        compare(tipOver(findChild(wifi, "word")), "", "wlan fits");
        wifi.text = "the wireless network of the house";
        compare(tipOver(findChild(wifi, "word")), "the wireless network of the house", "its word");
        mouseMove(scene, 1, 1);
        Tips.hide();
        wifi.forceActiveFocus();
        compare(Tips.target, null);
    }

    function test_the_cut_words_of_a_row_show_whole_in_a_tip_and_keyboard_focus_on_its_control_shows_none() {
        const long = "the density of every surface of the shell, from comfortable to compact";
        showSettled(0);
        const density = control("density");
        const words = findChild(rowOf(density), "words");
        compare(tipOver(words), "", "dichte fits");
        rowOf(density).label = long;
        waitForRendering(side);
        compare(tipOver(words), long);
        mouseMove(scene, 1, 1);
        Tips.hide();
        density.forceActiveFocus();
        compare(Tips.target, null);
    }

    function test_the_bluetooth_button_switches_the_adapter_and_shows_what_the_adapter_has() {
        const bluetooth = giveBluetooth(controls);
        side.show(0);
        const toggle = control("bluetooth");
        compare(toggle.text, "bluetooth");
        compare(toggle.icon, "bluetooth");
        compare(findChild(toggle, "state").text, "an");
        verify(toggle.checked, "on, as the adapter is");
        toggle.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(bluetoothSwitches, [false]);
        verify(!bluetooth.adapter.enabled);
        verify(!toggle.checked);
        bluetooth.adapter.enabled = true;
        verify(toggle.checked, "a change from elsewhere shows");
        bluetoothTakes = false;
        keyClick(Qt.Key_Space);
        compare(bluetoothSwitches, [false, false]);
        verify(toggle.checked, "a switch the system did not take springs back");
    }

    function test_a_blocked_adapter_greys_the_bluetooth_button_which_says_why() {
        const bluetooth = giveBluetooth(controls);
        bluetooth.adapter.enabled = false;
        bluetooth.adapter.state = Controls.Blocked;
        side.show(0);
        const toggle = control("bluetooth");
        verify(toggle.disabled);
        verify(findChild(toggle, "why").visible);
        compare(findChild(toggle, "why").text, "funk gesperrt");
        toggle.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(bluetoothSwitches, []);
        verify(!toggle.checked);
    }

    function test_geräte_unfolds_the_paired_devices_in_place_with_their_state_and_battery() {
        giveBluetooth(controls);
        showSettled(0);
        const opener = control("chooseBluetoothDevice");
        const branch = control("bluetoothBranch");
        const below = findChild(controls, "display");
        compare(findChild(rowOf(opener), "words").text, "geräte · 1 verbunden");
        verify(!branch.visible, "folded it takes no room");
        waitForRendering(side);
        const before = below.y;
        mouseClick(opener);
        verify(branch.expanded);
        waitForRendering(side);
        verify(control("bluetooth").visible, "the switch stays in sight");
        verify(opener.visible);
        const rows = branchRows();
        compare(rows.map(row => row.text), ["Headphones", "Speaker", "Mouse", "neues gerät koppeln"]);
        verify(!control("bluetoothDevices").open, "no level");
        compare(below.y, before + branch.height + Tokens.spaceM, "what stands below moves down");
        compare(rows[0].Accessible.name, "Headphones, verbunden, akku 80%");
        compare(findChild(rows[1], "state").word, "getrennt");
        compare(findChild(rows[0], "battery").text, "80%");
        mouseClick(opener);
        verify(!branch.expanded);
        tryCompare(below, "y", before);
    }

    function test_with_more_than_five_devices_five_unfold_connected_first_and_alle_geräte_opens_all_in_a_level() {
        giveBluetooth(controls);
        givePairedDevices(controls, 7);
        showSettled(0);
        mouseClick(control("chooseBluetoothDevice"));
        waitForRendering(side);
        const rows = branchRows();
        compare(rows.map(row => row.text), ["Headphones", "Device 7", "Speaker", "Mouse", "Device 4", "alle geräte …", "neues gerät koppeln"]);
        mouseClick(rows[5]);
        const level = control("bluetoothDevices");
        verify(level.open);
        compare(levelRows(level).map(row => row.text).slice(1, 8), ["Headphones", "Speaker", "Mouse", "Device 4", "Device 5", "Device 6", "Device 7"]);
        keyClick(Qt.Key_Escape);
        verify(control("chooseBluetoothDevice").activeFocus);
    }

    function test_up_to_five_devices_have_no_alle_geräte_row() {
        giveBluetooth(controls);
        givePairedDevices(controls, 5);
        showSettled(0);
        mouseClick(control("chooseBluetoothDevice"));
        waitForRendering(side);
        compare(branchRows().length, 6, "five devices and neues gerät koppeln");
        verify(!control("allDevices").visible);
    }

    function test_the_unfolded_devices_connect_and_pair_like_those_of_the_level() {
        const bluetooth = giveBluetooth(controls);
        showSettled(0);
        mouseClick(control("chooseBluetoothDevice"));
        waitForRendering(side);
        const rows = branchRows();
        mouseClick(rows[1]);
        compare(bluetooth.speaker.calls, ["connect"]);
        compare(findChild(rows[1], "state").word, "wartet");
        mouseClick(rows[1]);
        compare(bluetooth.speaker.calls, ["connect"], "one on its way waits for the answer");
        mouseClick(rows[3]);
        compare(pairingAsked, 1);
        verify(control("bluetoothBranch").expanded, "it stays unfolded");
    }

    function test_the_devices_unfold_over_duration_short_with_ease_in_and_fold_in_0_7_of_that_with_ease_out() {
        giveBluetooth(controls);
        showSettled(0);
        Prefs.motion = "on";
        const branch = control("bluetoothBranch");
        const unfolding = findChild(branch, "unfolding");
        compare(unfolding.duration, Tokens.durationShort);
        compare(unfolding.easing.bezierCurve, Tokens.easeIn);
        const folding = findChild(branch, "folding");
        compare(folding.duration, 0.7 * Tokens.durationShort);
        compare(folding.easing.bezierCurve, Tokens.easeOut);
        mouseClick(control("chooseBluetoothDevice"));
        tryVerify(() => branch.unfolded > 0.2 && branch.unfolded < 0.8, Tokens.durationShort);
        compare(branch.opacity, branch.unfolded, "it fades in as it grows");
        tryCompare(branch, "unfolded", 1, 4 * Tokens.durationShort);
        mouseClick(control("chooseBluetoothDevice"));
        verify(branch.unfolded > 0, "it folds over time, it does not jump");
        tryCompare(branch, "unfolded", 0, 4 * Tokens.durationShort);
    }

    function test_with_reduced_motion_the_devices_show_their_end_state_at_once() {
        giveBluetooth(controls);
        side.show(0);
        const branch = control("bluetoothBranch");
        keyClick(Qt.Key_Return);
        compare(branch.unfolded, 1);
        keyClick(Qt.Key_Escape);
        compare(branch.unfolded, 0);
    }

    function test_geräte_unfolds_from_the_keyboard_and_escape_folds_it() {
        const bluetooth = giveBluetooth(controls);
        side.show(0);
        const opener = control("chooseBluetoothDevice");
        verify(opener.activeFocus);
        const branch = control("bluetoothBranch");
        keyClick(Qt.Key_Escape);
        verify(!side.open, "folded, Escape leaves the panel");
        side.show(0);
        keyClick(Qt.Key_Return);
        verify(branch.expanded, "Enter unfolds");
        keyClick(Qt.Key_Return);
        verify(!branch.expanded, "and folds");
        keyClick(Qt.Key_Space);
        verify(branch.expanded, "Space too");
        keyClick(Qt.Key_Down);
        const rows = branchRows();
        verify(rows[0].activeFocus, "Down goes into the devices");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(bluetooth.speaker.calls, ["connect"], "Enter connects");
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Space);
        compare(bluetooth.headphones.calls, ["disconnect"], "Space too");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        verify(rows[3].activeFocus);
        keyClick(Qt.Key_Return);
        compare(pairingAsked, 1);
        keyClick(Qt.Key_Escape);
        verify(!branch.expanded);
        verify(opener.activeFocus, "the focus goes back to geräte");
        verify(side.open);
    }

    function test_an_unfolding_branch_scrolls_itself_whole_into_view() {
        const scroller = createTemporaryObject(scrolledBranchComponent, testCase);
        compare(scroller.contentY, 0);
        scroller.branch.expand();
        tryVerify(() => scroller.contentY > 0);
        compare(scroller.contentY, 400 + 3 * Tokens.rowHeight - scroller.height, "its bottom in sight");
    }

    function test_an_open_branch_leaves_the_view_alone_when_something_moves() {
        const scroller = createTemporaryObject(scrolledBranchComponent, testCase);
        scroller.branch.expand();
        tryVerify(() => scroller.contentY > 0);
        wait(300);
        scroller.contentY = 0;
        scroller.lateRow.visible = true;
        scroller.spacer.height = 500;
        waitForRendering(scroller);
        wait(50);
        compare(scroller.contentY, 0, "a new row or a move above does not pull the view");
    }

    function test_the_devices_come_back_folded_after_the_panel_was_away() {
        giveBluetooth(controls);
        showSettled(0);
        mouseClick(control("chooseBluetoothDevice"));
        side.close();
        tryVerify(() => !side.visible);
        showSettled(0);
        verify(!control("bluetoothBranch").expanded);
    }

    function test_geräte_opens_a_level_of_the_paired_devices_with_their_state_and_battery() {
        giveBluetooth(controls);
        const level = showBluetoothLevel();
        const rows = levelRows(level);
        compare(rows.map(row => row.text), ["zurück · geräte", "Headphones", "Speaker", "Mouse", "neues gerät koppeln"]);
        compare(rows.slice(1).map(row => row.kind), ["item", "item", "item", "item"], "no option to choose one of");
        const states = rows.slice(1, 4).map(row => findChild(row, "state"));
        compare(states.map(tag => tag.word), ["verbunden", "getrennt", "getrennt"]);
        compare(states.map(tag => tag.status), ["info", "", ""]);
        const battery = findChild(rows[1], "battery");
        verify(battery.visible);
        compare(battery.text, "80%");
        compare(battery.font.features, { "tnum": 1 }, "in tabular figures");
        compare(battery.font.weight, Tokens.fontWeightMedium, "a number to read as data");
        verify(!findChild(rows[2], "battery").visible, "where the device tells none");
        waitForRendering(side);
        const end = findChild(rows[1], "end");
        compare(end.x + end.width, rows[1].width - Tokens.spaceM, "state and battery at the row's end");
    }

    function test_a_press_connects_or_disconnects_and_the_device_waits_until_the_answer() {
        const bluetooth = giveBluetooth(controls);
        const level = showBluetoothLevel();
        const rows = levelRows(level);
        const stateOf = row => findChild(row, "state");
        mouseClick(rows[2]);
        compare(bluetooth.speaker.calls, ["connect"]);
        verify(level.open, "the level stays");
        compare(stateOf(rows[2]).word, "wartet");
        compare(stateOf(rows[2]).status, "warning");
        mouseClick(rows[2]);
        compare(bluetooth.speaker.calls, ["connect"], "one on its way waits for the answer");
        bluetooth.speaker.connected = true;
        bluetooth.speaker.state = Controls.Connected;
        compare(stateOf(rows[2]).word, "verbunden");
        compare(stateOf(rows[2]).status, "info");
        mouseClick(rows[1]);
        compare(bluetooth.headphones.calls, ["disconnect"]);
        compare(stateOf(rows[1]).word, "wartet");
        bluetooth.headphones.state = Controls.Connected;
        compare(stateOf(rows[1]).word, "verbunden", "a disconnection that fails shows the state from before");
        mouseClick(rows[3]);
        bluetooth.mouse.state = Controls.Disconnected;
        compare(stateOf(rows[3]).word, "getrennt", "so does a connection that fails");
        bluetooth.mouse.pairing = true;
        compare(stateOf(rows[3]).word, "wartet", "pairing waits too");
        keyClick(Qt.Key_Escape);
        compare(findChild(rowOf(control("chooseBluetoothDevice")), "words").text, "geräte · 2 verbunden");
    }

    function test_neues_gerät_koppeln_asks_for_system_settings_to_pair_a_device() {
        giveBluetooth(controls);
        const level = showBluetoothLevel();
        const pair = control("pairDevice");
        compare(levelRows(level).slice(-1)[0], pair, "the last row");
        mouseClick(pair);
        compare(pairingAsked, 1);
    }

    function test_without_an_adapter_the_bluetooth_rows_are_gone_and_verbindungen_falls_away_quietly() {
        giveBluetooth(controls);
        side.show(0);
        verify(findChild(controls, "connections").visible);
        controls.bluetooth = null;
        controls.bluetoothDevices = [];
        verify(!control("bluetooth").visible, "its quick setting too");
        verify(!rowOf(control("chooseBluetoothDevice")).visible);
        verify(!findChild(controls, "connections").visible, "with no other row the group falls away");
    }

    function test_bluetooth_works_from_the_keyboard() {
        const bluetooth = giveBluetooth(controls);
        side.show(0);
        control("bluetooth").forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(bluetoothSwitches, [false], "its quick setting");
        const opener = control("chooseBluetoothDevice");
        opener.forceActiveFocus();
        const level = control("bluetoothDevices");
        level.show(opener);
        const rows = levelRows(level);
        verify(rows[1].activeFocus, "the focus starts on the first device");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(bluetooth.speaker.calls, ["connect"], "Enter connects");
        verify(rows[2].activeFocus, "the focus stays");
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Space);
        compare(bluetooth.headphones.calls, ["disconnect"], "Space too");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Tab);
        verify(rows[4].activeFocus, "Tab to neues gerät koppeln");
        keyClick(Qt.Key_Return);
        compare(pairingAsked, 1);
        keyClick(Qt.Key_Left);
        verify(!level.open, "← goes back");
        verify(opener.activeFocus, "to geräte");
        verify(side.open);
    }

    function test_a_long_device_name_is_cut_before_its_state() {
        const bluetooth = giveBluetooth(controls);
        bluetooth.headphones.name = "Navi 21/23 HDMI/DP Audio Controller Digital Stereo Headphones of the guest room";
        const level = showBluetoothLevel();
        const row = levelRows(level)[1];
        const label = findChild(row, "label");
        verify(label.truncated);
        compare(label.x + label.width, findChild(row, "end").x - Tokens.spaceS);
    }

    function test_the_wlan_button_switches_wireless_and_shows_what_the_system_has() {
        giveNetworks(controls);
        showSettled(0);
        const toggle = control("wifi");
        verify(toggle.checked);
        compare(toggle.text, "wlan");
        compare(toggle.icon, "wireless");
        mouseClick(toggle);
        compare(wifiSwitches, [false]);
        verify(!toggle.checked);
        verify(!control("chooseNetwork").visible, "without wireless there is no list of networks");
        wifiTakes = false;
        mouseClick(toggle);
        compare(wifiSwitches, [false, true]);
        verify(!toggle.checked, "a switch the system did not take springs back");
        controls.networking.wifiEnabled = true;
        verify(toggle.checked, "a change from elsewhere shows");
    }

    function test_the_wlan_button_names_the_joined_network_as_its_state() {
        const networks = giveNetworks(controls);
        side.show(0);
        const state = findChild(control("wifi"), "state");
        compare(state.text, "Home");
        compare(control("wifi").Accessible.name, "wlan Home");
        networks.home.connected = false;
        compare(state.text, "an", "on, without a network");
        compare(control("wifi").Accessible.name, "wlan");
        controls.networking.wifiEnabled = false;
        compare(state.text, "aus");
    }

    function test_a_blocked_radio_greys_the_wlan_button_which_says_why() {
        giveNetworks(controls);
        controls.networking.wifiHardwareEnabled = false;
        showSettled(0);
        const toggle = control("wifi");
        verify(toggle.disabled);
        compare(toggle.disabledReason, "funk gesperrt");
        mouseClick(toggle);
        compare(wifiSwitches, []);
    }

    function test_netz_names_the_joined_network_with_its_state_as_a_status_word() {
        const networks = giveNetworks(controls);
        side.show(0);
        waitForRendering(side);
        const words = findChild(rowOf(control("chooseNetwork")), "words");
        compare(words.text, "netz · Home");
        compare(control("wifiState").word, "verbunden");
        networks.office.stateChanging = true;
        compare(control("wifiState").word, "wartet");
        networks.office.stateChanging = false;
        networks.home.connected = false;
        compare(words.text, "netz");
        compare(control("wifiState").word, "getrennt");
    }

    function test_kabel_shows_the_wired_connection_as_a_status_word() {
        side.show(0);
        waitForRendering(side);
        verify(!control("wiredState").visible, "without a wired device the row is gone");
        controls.wiredDevice = createTemporaryObject(wiredDeviceComponent, testCase);
        compare(findChild(rowOf(control("wiredState")), "words").text, "kabel");
        compare(control("wiredState").word, "verbunden");
        compare(control("wiredState").status, "info");
        controls.wiredDevice.connected = false;
        compare(control("wiredState").word, "getrennt");
    }

    function test_without_networkmanager_the_network_rows_are_gone() {
        side.show(0);
        waitForRendering(side);
        verify(!control("wifi").visible);
        verify(!control("chooseNetwork").visible);
        verify(!control("wiredState").visible);
    }

    function test_with_eight_networks_the_five_strongest_unfold_and_alle_netze_opens_all_in_a_level() {
        giveNetworks(controls);
        showSettled(0);
        const opener = control("chooseNetwork");
        const below = findChild(controls, "display");
        const before = below.y;
        mouseClick(opener);
        waitForRendering(side);
        verify(control("wifi").visible, "the switch stays in sight");
        compare(rowsOf("wifiBranch").map(row => row.text), ["Home", "Office", "Guest", "Neighbour", "Library", "alle netze …"]);
        compare(below.y, before + control("wifiBranch").height + Tokens.spaceM, "what stands below moves down");
        verify(!control("networks").open, "no level yet");
        mouseClick(control("allNetworks"));
        const level = control("networks");
        verify(level.open);
        compare(levelRows(level).slice(1).map(row => row.text), ["Home", "Office", "Guest", "Neighbour", "Library", "Cafe", "Shop", "Hotel"]);
        keyClick(Qt.Key_Escape);
        verify(opener.activeFocus, "back on the row that opened it");
    }

    function test_up_to_five_networks_have_no_alle_netze_row() {
        const networks = giveNetworks(controls);
        networks.device.networks.values = [networks.home, networks.office, networks.guest, networks.neighbour, networks.library];
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        compare(rowsOf("wifiBranch").length, 5);
    }

    function test_a_network_row_tells_what_it_is_and_its_signal_in_percent() {
        giveNetworks(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        const rows = rowsOf("wifiBranch");
        compare(findChild(rows[0], "signal").text, "90%");
        verify(findChild(rows[0], "leave").visible, "the joined one can be left");
        verify(!findChild(rows[0], "kinds").visible, "the joined one needs no more words");
        compare(findChild(rows[1], "kinds").text, "gesichert · bekannt");
        compare(findChild(rows[2], "kinds").text, "");
        compare(findChild(rows[3], "kinds").text, "gesichert");
        verify(!findChild(rows[1], "leave").visible);
        compare(rows[1].Accessible.name, "Office, gesichert · bekannt, signal 70%");
    }

    function test_the_scan_runs_while_the_list_shows_and_stops_with_it() {
        giveNetworks(controls);
        showSettled(0);
        compare(scans, []);
        mouseClick(control("chooseNetwork"));
        compare(scans, [true]);
        waitForRendering(side);
        mouseClick(control("allNetworks"));
        verify(control("networks").open);
        compare(scans, [true], "the level goes on with the same scan");
        keyClick(Qt.Key_Escape);
        mouseClick(control("chooseNetwork"));
        compare(scans, [true, false]);
        waitForRendering(side);
        mouseClick(control("chooseNetwork"));
        compare(scans, [true, false, true]);
        side.close();
        tryVerify(() => !side.visible);
        compare(scans, [true, false, true, false], "closing the panel stops it");
    }

    function test_the_networks_keep_their_order_while_the_list_shows_though_the_signal_moves() {
        const networks = giveNetworks(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        networks.shop.signalStrength = 0.95;
        compare(rowsOf("wifiBranch").map(row => row.text).slice(0, 2), ["Home", "Office"]);
        compare(findChild(rowsOf("wifiBranch")[0], "signal").text, "90%");
        mouseClick(control("chooseNetwork"));
        tryVerify(() => !control("wifiBranch").visible);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        compare(rowsOf("wifiBranch")[0].text, "Shop", "folded and unfolded again it is ranked anew");
    }

    function test_a_known_or_open_network_joins_at_once() {
        const networks = giveNetworks(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        const rows = rowsOf("wifiBranch");
        mouseClick(rows[1]);
        compare(networks.office.calls, ["connect"]);
        compare(findChild(rows[1], "joining").word, "wartet");
        mouseClick(rows[1]);
        compare(networks.office.calls, ["connect"], "one on its way waits for the answer");
        mouseClick(rows[2]);
        compare(networks.guest.calls, ["connect"]);
        compare(joined, ["Office", "Guest"]);
        verify(!sheet().open);
    }

    function test_a_secured_unknown_network_asks_for_its_password_in_a_sheet_and_joins_with_it() {
        const networks = giveNetworks(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        mouseClick(rowsOf("wifiBranch")[3]);
        verify(sheet().open);
        compare(sheet().title, "passwort für Neighbour");
        compare(networks.neighbour.calls, [], "nothing is joined before the password");
        const input = findChild(findChild(sheet(), "password"), "input");
        verify(input.activeFocus);
        compare(input.echoMode, TextInput.Password);
        typeText("secret");
        keyClick(Qt.Key_Return);
        compare(networks.neighbour.calls, ["psk secret"]);
        compare(passwordsSent, ["secret"]);
        verify(!sheet().open);
        compare(findChild(findChild(sheet(), "password"), "input").text, "", "the password is not kept");
        verify(rowsOf("wifiBranch")[3].activeFocus, "the focus goes back to the row");
    }

    function test_the_tip_of_the_password_sheets_close_button_is_drawn_over_the_sheet() {
        giveNetworks(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        mouseClick(rowsOf("wifiBranch")[3]);
        verify(sheet().open);
        const close = findChild(sheet(), "close");
        close.forceActiveFocus();
        const tip = named("tip");
        verify(tip.visible);
        compare(findChild(tip, "words").text, close.label);
        verify(drawnAsInk(tip), "over the sheet");
    }

    function test_an_empty_password_is_refused_at_the_field_and_escape_leaves_the_sheet_alone_of_the_panel() {
        const networks = giveNetworks(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        mouseClick(rowsOf("wifiBranch")[3]);
        keyClick(Qt.Key_Return);
        verify(sheet().open);
        compare(findChild(sheet(), "password").error, "passwort fehlt");
        typeText("x");
        compare(findChild(sheet(), "password").error, "");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Escape);
        verify(sheet().open, "typed input is asked about before it goes");
        verify(sheet().asking);
        compare(findChild(sheet(), "keep").text, "weiter bearbeiten");
        compare(findChild(sheet(), "discard").text, "änderungen verwerfen");
        compare(sheet().askKicker, "ungespeichert");
        keyClick(Qt.Key_Escape);
        verify(!sheet().asking, "Escape while asking keeps editing");
        keyClick(Qt.Key_Escape);
        mouseClick(findChild(sheet(), "discard"));
        verify(!sheet().open, "discarding leaves the sheet");
        verify(side.open, "and the panel stays");
        compare(networks.neighbour.calls, []);
        compare(passwordsSent, []);
    }

    function test_an_untouched_password_sheet_leaves_without_asking() {
        giveNetworks(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        mouseClick(rowsOf("wifiBranch")[3]);
        keyClick(Qt.Key_Escape);
        verify(!sheet().open);
        verify(side.open);
    }

    function test_the_sheet_closes_when_its_network_goes() {
        const networks = giveNetworks(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        mouseClick(rowsOf("wifiBranch")[3]);
        typeText("pw");
        networks.device.networks.values = networks.device.networks.values.filter(network => network !== networks.neighbour);
        tryVerify(() => !sheet().open);
        compare(passwordsSent, []);
    }

    function test_the_sheet_goes_with_the_panel() {
        giveNetworks(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        mouseClick(rowsOf("wifiBranch")[3]);
        verify(sheet().open);
        side.close();
        tryVerify(() => !side.visible);
        tryVerify(() => !sheet().open);
    }

    function test_a_failed_connection_says_why_in_its_row_until_the_next_attempt() {
        const networks = giveNetworks(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        mouseClick(rowsOf("wifiBranch")[1]);
        networks.office.stateChanging = false;
        networks.office.connectionFailed(Controls.WifiAuthTimeout);
        const failure = findChild(rowsOf("wifiBranch")[1], "failure");
        verify(failure.visible);
        compare(failure.word, "zeitüberschreitung");
        compare(failure.status, "error");
        verify(!findChild(rowsOf("wifiBranch")[1], "kinds").visible, "the cause takes the words' place");
        compare(rowsOf("wifiBranch")[1].Accessible.name, "Office, zeitüberschreitung, gesichert · bekannt, signal 70%");
        mouseClick(rowsOf("wifiBranch")[1]);
        verify(!failure.visible, "a new attempt clears it");
        networks.office.stateChanging = false;
        networks.office.connectionFailed(Controls.NoSecrets);
        compare(failure.word, "kein passwort");
        networks.office.stateChanging = false;
        networks.office.connectionFailed(99);
        compare(failure.word, "unbekannter fehler");
    }

    function test_the_joined_network_is_left_by_its_quiet_button_and_a_press_on_its_row_does_nothing() {
        const networks = giveNetworks(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        const home = rowsOf("wifiBranch")[0];
        const leave = findChild(home, "leave");
        compare(leave.variant, "quiet");
        mouseClick(home, 10, home.height / 2);
        compare(networks.home.calls, []);
        mouseClick(leave);
        compare(leaves, ["Home"]);
        compare(networks.home.calls, ["disconnect"]);
        compare(joined, []);
    }

    function test_the_network_list_works_from_the_keyboard() {
        const networks = giveNetworks(controls);
        side.show(0);
        waitForRendering(side);
        control("chooseNetwork").forceActiveFocus();
        keyClick(Qt.Key_Return);
        verify(control("wifiBranch").expanded);
        waitForRendering(side);
        keyClick(Qt.Key_Down);
        verify(rowsOf("wifiBranch")[0].activeFocus);
        keyClick(Qt.Key_Down);
        verify(findChild(rowsOf("wifiBranch")[0], "leave").activeFocus, "the joined network's button comes before the next row");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(networks.office.calls, ["connect"], "Enter joins a known network");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        verify(rowsOf("wifiBranch")[4].activeFocus);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        verify(control("networks").open, "alle netze … opens the level");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Space);
        verify(sheet().open, "a secured unknown network asks for its password");
        compare(sheet().title, "passwort für Neighbour");
        typeText("pw");
        keyClick(Qt.Key_Return);
        compare(networks.neighbour.calls, ["psk pw"]);
        keyClick(Qt.Key_Escape);
        verify(!control("networks").open);
        verify(control("chooseNetwork").activeFocus, "back where it began");
    }

    function test_two_open_lists_do_not_fight_over_the_view() {
        giveNetworks(controls);
        giveBluetooth(controls);
        givePairedDevices(controls, 7);
        scene.height = 420;
        showSettled(0);
        const scroller = findChild(side, "scroller");
        mouseClick(control("chooseNetwork"));
        wait(300);
        mouseClick(control("chooseBluetoothDevice"));
        wait(300);
        verify(scroller.contentHeight > scroller.height + 100, "there is room to scroll");
        scroller.contentY = 0;
        controls.wifiDevice.networks.values = controls.wifiDevice.networks.values.slice(0, 5);
        wait(150);
        compare(scroller.contentY, 0, "a network gone does not pull the view");
        controls.bluetoothDevices = controls.bluetoothDevices.slice(0, 5);
        wait(150);
        compare(scroller.contentY, 0, "a device gone does not either");
    }

    function test_the_networks_come_back_folded_after_the_panel_was_away() {
        giveNetworks(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        side.close();
        tryVerify(() => !side.visible);
        showSettled(0);
        verify(!control("wifiBranch").expanded);
    }

    function test_after_trennen_the_row_does_not_say_it_is_connecting_and_bluetooth_says_the_same_word() {
        const networks = giveNetworks(controls);
        const bluetooth = giveBluetooth(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        mouseClick(findChild(rowsOf("wifiBranch")[0], "leave"));
        compare(networks.home.calls, ["disconnect"]);
        compare(control("wifiState").word, "wartet");
        compare(findChild(rowsOf("wifiBranch")[0], "joining").word, "wartet");
        mouseClick(control("chooseBluetoothDevice"));
        waitForRendering(side);
        bluetooth.speaker.connect();
        compare(findChild(branchRows()[1], "state").word, "wartet");
    }

    function test_the_cause_for_a_lost_connection_is_not_the_word_for_an_idle_row() {
        const networks = giveNetworks(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        networks.home.connected = false;
        networks.home.connectionFailed(Controls.WifiClientDisconnected);
        compare(control("wifiState").word, "getrennt");
        const cause = findChild(rowsOf("wifiBranch").find(row => row.text === "Home"), "failure");
        compare(cause.word, "verbindung abgebrochen");
        verify(cause.word !== control("wifiState").word);
    }

    function test_an_empty_list_says_what_is_empty_while_the_scan_runs() {
        const networks = giveNetworks(controls);
        networks.device.networks.values = [];
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        const hint = control("noNetworks");
        verify(hint.visible);
        compare(hint.text, "keine netze gefunden, die suche läuft");
        verify(findChild(hint, "line").visible, "on Rekta's empty hairline");
        verify(control("wifiBranch").height > 0, "the unfolded branch is not empty");
        compare(scans, [true]);
        networks.device.networks.values = [networks.home];
        waitForRendering(side);
        verify(!hint.visible, "the first network takes its place");
    }

    function test_networks_that_come_or_go_while_the_list_is_open_leave_the_others_in_their_place() {
        const networks = giveNetworks(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        networks.shop.signalStrength = 0.95;
        const faraway = createTemporaryObject(networkComponent, testCase, { name: "Faraway", signalStrength: 0.05, security: 3 });
        const near = createTemporaryObject(networkComponent, testCase, { name: "Near", signalStrength: 0.8, security: 3 });
        networks.device.networks.values = [...networks.device.networks.values, faraway, near];
        compare(controls.ranked.map(network => network.name), ["Home", "Office", "Guest", "Neighbour", "Library", "Cafe", "Shop", "Hotel", "Near", "Faraway"]);
        networks.device.networks.values = networks.device.networks.values.filter(network => network !== networks.office);
        compare(controls.ranked.map(network => network.name).slice(0, 3), ["Home", "Guest", "Neighbour"], "a gone network drops out in place");
    }

    function test_folding_the_list_keeps_its_rows_while_it_folds_and_never_shows_the_empty_sentence() {
        giveNetworks(controls);
        showSettled(0);
        Prefs.motion = "on";
        const branch = control("wifiBranch");
        mouseClick(control("chooseNetwork"));
        tryCompare(branch, "unfolded", 1, 4 * Tokens.durationShort);
        waitForRendering(side);
        const fullHeight = branch.height;
        const hint = control("noNetworks");
        verify(!hint.visible);
        mouseClick(control("chooseNetwork"));
        verify(branch.unfolded > 0, "it folds over time");
        verify(!hint.visible, "the empty sentence does not show while it folds");
        compare(rowsOf("wifiBranch").length, 6, "the rows stay until it has folded");
        verify(branch.height <= fullHeight && branch.height > 0);
        tryCompare(branch, "unfolded", 0, 4 * Tokens.durationShort);
        verify(!hint.visible);
    }

    function test_wlan_off_closes_the_level_and_stops_the_scan() {
        giveNetworks(controls);
        showSettled(0);
        mouseClick(control("chooseNetwork"));
        waitForRendering(side);
        mouseClick(control("allNetworks"));
        verify(control("networks").open);
        compare(scans, [true]);
        controls.networking.wifiEnabled = false;
        verify(!control("networks").open);
        verify(!control("wifiBranch").expanded);
        compare(scans, [true, false]);
    }

    function test_the_groups_stand_in_order_with_headings_and_a_group_without_rows_falls_away() {
        side.show(0);
        const groups = ["sound", "connections", "display", "session"].map(name => findChild(controls, name));
        verify(!groups[0].visible, "ton without audio devices");
        verify(!groups[1].visible, "verbindungen has no rows yet");
        verify(groups[2].visible);
        verify(groups[3].visible);
        compare(findChild(groups[2], "heading").text, "anzeige");
        compare(findChild(groups[3], "heading").text, "sitzung");
        tryCompare(groups[2], "y", 0, 1000, "the first in sight at the top");
        verify(groups[3].y > groups[2].y);
    }

    // Its rows are a form's controls, not a list (forms.md); groups stand apart by their headings and space.
    function test_the_rows_of_a_group_stand_space_m_apart_on_no_hairline_and_no_hairline_divides_the_groups() {
        giveSound(controls);
        side.show(0);
        waitForRendering(side);
        for (const name of ["sound", "display", "session"]) {
            const group = findChild(controls, name);
            verify(group.visible, name);
            compare(hairlinesIn(group).length, 0, name);
        }
        const device = rowOf(control("outputDevice"));
        const volume = rowOf(control("outputVolume"));
        compare(volume.y - (device.y + device.height), Tokens.spaceM, "a section's parts are space-m apart");
        const display = findChild(controls, "display");
        const session = findChild(controls, "session");
        compare(session.y - (display.y + display.height), 0, "the groups' own space-l above and below parts them");
    }

    function test_a_group_whose_rows_are_all_absent_falls_away() {
        const group = createTemporaryObject(absentGroupComponent, testCase);
        verify(!group.visible);
        group.rows[0].present = true;
        verify(group.visible);
    }

    function test_a_group_takes_space_xl_above_space_l_below_and_its_heading_stands_space_m_above_its_rows() {
        side.show(0);
        const group = findChild(controls, "display");
        const heading = findChild(group, "heading");
        const rows = findChild(group, "rows");
        waitForRendering(side);
        compare(heading.mapToItem(group, 0, 0).y, Tokens.spaceXl);
        compare(rows.mapToItem(group, 0, 0).y, Tokens.spaceXl + heading.height + Tokens.spaceM);
        compare(group.height, Tokens.spaceXl + heading.height + Tokens.spaceM + rows.height + Tokens.spaceL);
    }

    function test_a_row_has_its_words_at_the_start_and_its_control_at_the_end() {
        controls.wiredDevice = createTemporaryObject(wiredDeviceComponent, testCase);
        side.show(0);
        const toggle = control("wiredState");
        const row = rowOf(toggle);
        waitForRendering(side);
        const words = findChild(row, "words");
        compare(words.text, "kabel");
        compare(words.x, 0);
        compare(findChild(row, "holder").x, row.width - toggle.implicitWidth, "the control at the end");
        compare(row.height, Math.max(words.height, toggle.implicitHeight), "the height of its line");
        compare(findChild(rowOf(control("lock")), "holder").x, 0, "a row without words has its control at the start");
    }

    function test_a_row_whose_words_and_control_do_not_fit_puts_the_control_below_and_cuts_long_words() {
        controls.wiredDevice = createTemporaryObject(wiredDeviceComponent, testCase);
        side.show(0);
        const toggle = control("wiredState");
        const row = rowOf(toggle);
        row.label = "a long word for the wired connection that cannot share its line with its state";
        waitForRendering(side);
        const words = findChild(row, "words");
        compare(findChild(row, "holder").x, 0);
        compare(findChild(row, "holder").y, words.height + Tokens.spaceXs, "space-xs below the words");
        compare(row.height, words.height + Tokens.spaceXs + toggle.implicitHeight);
        compare(words.width, row.width);
        verify(words.truncated, "the words are cut, not wrapped");
        compare(words.lineCount, 1);
    }

    // The way from "steuerung" in the app bar at the bottom to them stays short.
    function test_the_quick_settings_stand_in_two_columns_at_the_bottom_edge_above_the_app_bar_without_a_heading() {
        giveNetworks(controls);
        giveBluetooth(controls);
        showSettled(0);
        const edge = findChild(side, "edge");
        const ground = findChild(side, "ground");
        const buttons = ["wifi", "bluetooth", "doNotDisturb", "dark"].map(name => control(name));
        const cell = (side.contentWidth - Tokens.spaceS) / 2;
        const at = button => button.mapToItem(ground, 0, 0);
        for (const button of buttons) {
            verify(button instanceof ToggleButton);
            verify(side.within(edge, button), `${button.objectName} at the edge`);
            compare(button.width, cell, `${button.objectName}: half the width, space-s between`);
        }
        compare(buttons.map(button => button.text), ["wlan", "bluetooth", "nicht stören", "dunkel"]);
        compare(buttons.map(button => button.icon), ["wireless", "bluetooth", "bell", "theme"]);
        compare(at(buttons[0]).x, Tokens.spaceM);
        compare(at(buttons[1]).x, Tokens.spaceM + cell + Tokens.spaceS);
        compare(at(buttons[1]).y, at(buttons[0]).y);
        compare(at(buttons[2]).x, Tokens.spaceM);
        compare(at(buttons[2]).y, at(buttons[0]).y + buttons[0].height + Tokens.spaceS);
        compare(at(buttons[3]).y, at(buttons[2]).y);
        compare(at(buttons[3]).y + buttons[3].height, ground.height - Tokens.spaceL, "on the panel's padding at the bottom");
        verify(!findChild(edge, "heading"), "no heading over them");
        verify(!side.within(findChild(side, "scroller"), buttons[0]), "out of the scroll");
    }

    function test_a_quick_setting_whose_device_is_missing_is_gone_and_the_rest_close_up() {
        showSettled(0);
        verify(!control("wifi").visible, "no wireless device");
        verify(!control("bluetooth").visible, "no adapter");
        const quiet = control("doNotDisturb");
        const dark = control("dark");
        compare(dark.y, quiet.y, "nicht stören and dunkel share the first line");
        compare(dark.x, quiet.width + Tokens.spaceS);
        const edge = findChild(side, "edge");
        compare(edge.height, quiet.height);
        giveBluetooth(controls);
        verify(control("bluetooth").visible);
        waitForRendering(side);
        compare(control("bluetooth").x, 0);
        compare(quiet.x, dark.width + Tokens.spaceS, "bluetooth takes the first place");
        compare(dark.x, 0);
        verify(dark.y > quiet.y, "and dunkel wraps to the next line");
    }

    function test_the_switches_have_left_their_groups() {
        giveSound(controls);
        giveNetworks(controls);
        giveBluetooth(controls);
        giveDisplays(controls);
        side.show(0);
        const rows = item => (item instanceof PanelRow ? [item] : []).concat(...Array.from(item.children).map(rows));
        const labels = rows(findChild(side, "scroller")).map(row => row.label);
        for (const word of ["wlan", "bluetooth", "nicht stören", "dunkel"])
            verify(!labels.includes(word), `no row ${word} in a group`);
        for (const name of ["wifi", "bluetooth", "doNotDisturb", "dark"])
            verify(!side.within(findChild(side, "scroller"), control(name)), name);
    }

    function test_nicht_stoeren_switches_with_a_press_and_follows_a_switch_from_elsewhere() {
        showSettled(0);
        const quiet = control("doNotDisturb");
        mouseClick(quiet);
        verify(controls.doNotDisturb);
        compare(findChild(quiet, "state").text, "an");
        controls.setDoNotDisturb(false);
        verify(!quiet.checked, "as the Start's command does");
        verify(!controls.doNotDisturb);
    }

    function test_the_chevron_of_wlan_unfolds_the_networks_in_verbindungen_with_the_focus_on_the_first() {
        giveNetworks(controls);
        showSettled(0);
        const wifi = control("wifi");
        const chevron = findChild(wifi, "chevron");
        verify(chevron.visible);
        mouseClick(wifi, chevron.x + chevron.width / 2, wifi.height / 2);
        verify(control("wifiBranch").expanded);
        verify(rowsOf("wifiBranch")[0].activeFocus, "on the strongest network");
        compare(rowsOf("wifiBranch")[0].text, "Home");
        verify(wifi.checked, "wlan stays on");
        compare(wifiSwitches, []);
        keyClick(Qt.Key_Escape);
        verify(!control("wifiBranch").expanded, "Escape folds them as ever");
        verify(wifi.activeFocus, "and gives the focus back to wlan, which opened them");
        mouseClick(wifi, 10, 10, Qt.RightButton);
        verify(control("wifiBranch").expanded, "a right click does the same");
        verify(rowsOf("wifiBranch")[0].activeFocus);
        keyClick(Qt.Key_Escape);
        verify(wifi.activeFocus);
        keyClick(Qt.Key_Menu);
        verify(control("wifiBranch").expanded, "and the menu key");
        verify(rowsOf("wifiBranch")[0].activeFocus);
        keyClick(Qt.Key_Escape);
        verify(wifi.activeFocus);
    }

    function test_unfolded_by_its_own_opener_after_the_details_escape_goes_back_to_that_opener() {
        giveNetworks(controls);
        showSettled(0);
        mouseClick(control("wifi"), 10, 10, Qt.RightButton);
        keyClick(Qt.Key_Escape);
        const choose = control("chooseNetwork");
        choose.forceActiveFocus();
        keyClick(Qt.Key_Return);
        verify(control("wifiBranch").expanded);
        keyClick(Qt.Key_Escape);
        verify(!control("wifiBranch").expanded);
        verify(choose.activeFocus);
    }

    function test_without_wireless_wlan_has_no_details() {
        giveNetworks(controls);
        controls.networking.wifiEnabled = false;
        showSettled(0);
        const wifi = control("wifi");
        verify(!findChild(wifi, "chevron").visible);
        mouseClick(wifi, 10, 10, Qt.RightButton);
        verify(!control("wifiBranch").expanded);
        verify(!wifi.checked, "nor does a right click switch it");
    }

    function test_a_right_click_on_bluetooth_unfolds_the_devices_with_the_focus_on_the_first() {
        giveBluetooth(controls);
        showSettled(0);
        const bluetooth = control("bluetooth");
        verify(findChild(bluetooth, "chevron").visible);
        mouseClick(bluetooth, 10, 10, Qt.RightButton);
        verify(control("bluetoothBranch").expanded);
        verify(branchRows()[0].activeFocus, "on the first device");
        compare(bluetoothSwitches, []);
        keyClick(Qt.Key_Escape);
        verify(!control("bluetoothBranch").expanded);
        verify(bluetooth.activeFocus, "Escape gives the focus back to bluetooth, which opened them");
    }

    // The rows show only once the branch does, a frame after it starts to unfold.
    function test_unfolding_with_motion_the_focus_goes_to_the_first_row_once_it_shows() {
        Prefs.motion = "on";
        giveBluetooth(controls);
        showSettled(0);
        mouseClick(control("bluetooth"), 10, 10, Qt.RightButton);
        tryVerify(() => branchRows().length > 0 && branchRows()[0].activeFocus, 4 * Tokens.durationShort);
    }

    function test_a_plain_press_on_nicht_stoeren_switches_it_on_without_an_end() {
        showSettled(0);
        mouseClick(control("doNotDisturb"));
        compare(controls.quiet.choice, "open");
        compare(controls.quiet.middleParts, [], "no time left to show");
        compare(findChild(control("doNotDisturb"), "state").text, "an");
        verify(!control("quietBranch").expanded, "the details stay folded");
    }

    function quietOptions(): var {
        return Array.from(findChild(control("quietLength"), "options").children).filter(item => item instanceof Rectangle);
    }

    function test_the_details_of_nicht_stoeren_unfold_its_lengths_below_the_buttons_and_a_press_on_one_switches_it_on() {
        controls.quiet.clock = () => Date.UTC(2026, 10, 8, 13, 0);
        controls.quiet.zoneOffset = () => 60;
        showSettled(0);
        const quiet = control("doNotDisturb");
        verify(findChild(quiet, "chevron").visible);
        mouseClick(quiet, 10, 10, Qt.RightButton);
        verify(control("quietBranch").expanded);
        verify(!controls.doNotDisturb, "opening the details alone does not switch it");
        const lengths = control("quietLength");
        verify(lengths.activeFocus, "the focus on the lengths");
        compare(lengths.options, ["bis aus", "1 stunde", "bis morgen"]);
        compare(lengths.currentIndex, -1, "none chosen while off");
        const buttons = findChild(controls.edge, "quickSettings");
        tryVerify(() => Math.abs(control("quietBranch").mapToItem(controls.edge, 0, 0).y - buttons.height - Tokens.spaceS) < 0.01, 1000, "below the buttons, space-s apart");
        waitForRendering(side);
        mouseClick(quietOptions()[1]);
        verify(controls.doNotDisturb, "on at once");
        compare(controls.quiet.choice, "hour");
        compare(lengths.currentIndex, 1);
        compare(findChild(quiet, "state").text, "bis 15:00", "the state word is its end");
        compare(quiet.Accessible.name, "nicht stören bis 15:00");
        compare(controls.quiet.middleParts, ["nicht stören", "bis 15:00"]);
        keyClick(Qt.Key_Escape);
        verify(!control("quietBranch").expanded);
        verify(quiet.activeFocus, "Escape gives the focus back to the button");
        mouseClick(quiet);
        verify(!controls.doNotDisturb, "a press switches it off");
        compare(findChild(quiet, "state").text, "aus");
    }

    function test_the_keys_choose_a_length_of_nicht_stoeren_at_once() {
        showSettled(0);
        control("doNotDisturb").forceActiveFocus();
        keyClick(Qt.Key_Menu);
        verify(control("quietLength").activeFocus);
        keyClick(Qt.Key_Right);
        compare(controls.quiet.choice, "open", "the first length");
        keyClick(Qt.Key_End);
        compare(controls.quiet.choice, "morning");
        verify(controls.quiet.endWord.startsWith("bis "));
    }

    function test_dunkel_has_no_details() {
        showSettled(0);
        verify(!findChild(control("dark"), "chevron").visible);
        mouseClick(control("dark"), 10, 10, Qt.RightButton);
        verify(!control("dark").checked, "a right click does nothing");
        compare(commands, []);
    }

    // The panel follows the one current theme and density, so the contact sheet is drawn once per pair.
    function test_contact_sheet_of_the_panel_in_both_themes_and_densities() {
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const contact = createTemporaryObject(contactComponent, testCase);
                const panel = findChild(contact, "panel");
                panel.controls.hasPerformanceProfile = true;
                const sound = giveSound(panel.controls);
                sound.speakers.audio.volume = 0.62;
                sound.microphone.audio.muted = true;
                giveDisplays(panel.controls);
                giveBluetooth(panel.controls).speaker.state = Controls.Connecting;
                panel.show(0);
                waitForRendering(contact);
                grabImage(contact).save(`panel-sheet-${theme}-${density}.png`);
                findChild(contact, "outputDevice").forceActiveFocus();
                keyClick(Qt.Key_Down);
                waitForRendering(contact);
                grabImage(contact).save(`panel-select-sheet-${theme}-${density}.png`);
                verify(findChild(contact, "outputDevice").expanded);
                // Without sound, verbindungen stands first: its level open, the devices connected, on their way and not.
                keyClick(Qt.Key_Escape);
                panel.controls.output = null;
                panel.controls.input = null;
                waitForRendering(contact);
                grabImage(contact).save(`panel-display-sheet-${theme}-${density}.png`);
                const networks = giveNetworks(panel.controls);
                panel.controls.wiredDevice = createTemporaryObject(wiredDeviceComponent, testCase);
                networks.office.stateChanging = true;
                waitForRendering(contact);
                findChild(contact, "chooseNetwork").forceActiveFocus();
                keyClick(Qt.Key_Return);
                waitForRendering(contact);
                networks.office.stateChanging = false;
                networks.office.connectionFailed(Controls.WifiAuthTimeout);
                networks.guest.stateChanging = true;
                waitForRendering(contact);
                grabImage(contact).save(`panel-wifi-sheet-${theme}-${density}.png`);
                findChild(contact, "allNetworks").forceActiveFocus();
                keyClick(Qt.Key_Return);
                waitForRendering(contact);
                grabImage(contact).save(`panel-wifi-level-sheet-${theme}-${density}.png`);
                keyClick(Qt.Key_Down);
                keyClick(Qt.Key_Down);
                keyClick(Qt.Key_Down);
                keyClick(Qt.Key_Down);
                keyClick(Qt.Key_Return);
                typeText("pass");
                waitForRendering(contact);
                grabImage(contact).save(`panel-wifi-password-sheet-${theme}-${density}.png`);
                verify(findChild(panel, "passwordSheet").open, `${theme} ${density}`);
                keyClick(Qt.Key_Escape);
                keyClick(Qt.Key_Escape);
                panel.controls.networking.wifiEnabled = false;
                findChild(contact, "chooseBluetoothDevice").forceActiveFocus();
                keyClick(Qt.Key_Return);
                waitForRendering(contact);
                grabImage(contact).save(`panel-bluetooth-sheet-${theme}-${density}.png`);
                verify(findChild(contact, "bluetoothBranch").expanded);
                const more = Array.from({ length: 4 }, (_, index) => createTemporaryObject(bluetoothDeviceComponent, testCase, { name: `Device ${index + 4}` }));
                panel.controls.bluetoothDevices = [...panel.controls.bluetoothDevices, ...more];
                waitForRendering(contact);
                findChild(contact, "allDevices").forceActiveFocus();
                keyClick(Qt.Key_Return);
                waitForRendering(contact);
                grabImage(contact).save(`panel-bluetooth-level-sheet-${theme}-${density}.png`);
                verify(findChild(contact, "bluetoothDevices").open);
                verify(panel.open, `${theme} ${density}`);
                contact.destroy();
            }
        }
    }
}
