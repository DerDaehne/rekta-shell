pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtTest
import Notices
import Panel
import Rekta
import "ContactSheets.js" as ContactSheets
import "Glide.js" as Glide

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
    // The keys that no part of the panel took and that reached what lies behind it, oldest first.
    property var keysPast: []
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
            levels: panel.levels
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

    FakeNotifications {
        id: fakes
    }

    Component {
        id: sceneComponent

        Item {
            width: 900
            height: 640
            Keys.onPressed: event => testCase.keysPast = [...testCase.keysPast, event.key]

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
        keysPast = [];
        scene = createTemporaryObject(sceneComponent, testCase);
        side = findChild(scene, "panel");
        controls = side.controls;
        board = findChild(scene, "board");
        toaster = findChild(scene, "toaster");
        named("opener").forceActiveFocus();
    }

    // The theme, ground and contrast of a contact sheet's colour set.
    function useColours(set: string) {
        Prefs.theme = set === "light" ? "light" : "dark";
        Prefs.ground = set.startsWith("black") ? "black" : "normal";
        Prefs.contrast = set === "black-contrast" ? "more" : "system";
    }

    function cleanup() {
        Prefs.ground = "normal";
        Prefs.contrast = "system";
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
    // The rows that show in a list of the controls: the networks or devices of a level, or a list of all of them chosen
    // in place, its back row first.
    function rowsOf(listName: string): var {
        return Array.from(control(listName).children).filter(row => row instanceof MenuItem && row.visible);
    }
    function typeText(text: string) {
        Array.from(text).forEach(letter => keyClick(letter));
    }
    function sheet(): var {
        return findChild(side, "passwordSheet");
    }

    // What the controls put off with Qt.callLater has run: calls put off later run after it.
    function settleLater() {
        let ran = false;
        Qt.callLater(() => ran = true);
        tryVerify(() => ran);
    }

    // A frame drawn after this point. waitForRendering alone waits for the next frame, which never comes once a scene
    // has nothing left to draw, and then runs out its whole timeout.
    function waitForFrame(item: Item) {
        item.Window.window.update();
        waitForRendering(item);
    }

    // The side panel open on a facet once its slide has ended, so that clicks land where the controls stand.
    function showSettled(index: int) {
        side.show(index);
        tryVerify(() => !findChild(side, "comingIn").running, Tokens.durationModerate * 4, "it has come in");
        waitForFrame(side);
    }

    // The side panel settled on steuerung with an area's level open, as a press on its tile opens it, and drawn.
    function showLevel(name: string): var {
        showSettled(0);
        const level = findChild(controls, name);
        side.reveal(level);
        verify(level.open, name);
        waitForFrame(side);
        return level;
    }

    // A control in the level of an area; the output's mute button and volume stand above the grid too.
    function inLevel(level: string, name: string): var {
        return findChild(findChild(controls, level), name);
    }

    function inSound(name: string): var {
        return inLevel("sound", name);
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

    // The option rows of a select's list, in order.
    function optionRows(select: var): var {
        return select.optionRows();
    }

    // A notification arrives as the server hands it over.
    function notify(properties) {
        const fake = fakes.make(properties, []);
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
        compare(pivot.width, contentWidth - Tokens.touchTarget, "clear of the close button");
        const facets = findChild(side, "facets");
        compare(facets.mapToItem(panel, 0, 0).x, Geometry.hairline + Tokens.spaceM, "its facets too");
        compare(facets.width, contentWidth);
        const scroller = findChild(side, "scroller");
        compare(scroller.width, panel.width - Geometry.hairline, "they scroll across the ground, so no focus ring at their edge is cut off");
        compare(scroller.y + scroller.height, 640, "down to the bottom edge");
        compare(scroller.contentHeight, facets.height + Tokens.spaceL, "the sheet's padding at its foot scrolls with the facet");
        side.show(1);
        compare(scroller.y + scroller.height, 640, "meldungen too");
        compare(scroller.contentHeight, facets.height + Tokens.spaceL);
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
        compare(under.width, 2.5 * Tokens.tileUnit + Tokens.spaceS, "across the content, below the close button too");
        compare(findChild(side, "scroller").y, under.y + Geometry.hairline);
    }

    // Its ground is bg, not glass, so an inactive title keeps the pivot colour of Rekta (rekta.css:254).
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

    function test_a_quiet_close_button_named_schliessen_stands_space_xs_from_the_top_trailing_corner_clear_of_the_pivot() {
        side.show(0);
        const button = findChild(side, "close");
        const ground = findChild(side, "ground");
        compare(button.parent, ground);
        compare(button.x + button.width, ground.width - Tokens.spaceXs);
        compare(button.y, Tokens.spaceXs);
        compare(button.icon, "close");
        compare(button.variant, "quiet");
        compare(button.Accessible.name, "schließen");
        compare(button.tip, "schließen", "its tip reads its name");
        const pivot = findChild(side, "pivot");
        compare(pivot.x + pivot.width, Tokens.spaceM + side.contentWidth - Tokens.touchTarget, "the pivot keeps a touch target clear");
    }

    function test_the_close_button_sends_it_away_the_way_escape_does_and_the_focus_goes_back() {
        Prefs.motion = "on";
        showSettled(0);
        mouseClick(findChild(side, "close"));
        verify(findChild(side, "goingOut").running, "it leaves the way it came");
        tryCompare(side, "open", false, Tokens.durationModerate * 4);
        verify(named("opener").activeFocus, "and gives the focus back");
    }

    function test_tab_reaches_the_close_button_last_and_space_on_it_closes_the_panel() {
        side.show(1);
        const button = findChild(side, "close");
        verify(findChild(side, "pivot").activeFocus, "an empty facet starts at the pivot, not at the button");
        keyClick(Qt.Key_Tab);
        verify(button.activeFocus, "the last stop in meldungen");
        keyClick(Qt.Key_Space);
        verify(!side.open);
        verify(named("opener").activeFocus, "and the focus goes back");
    }

    // A finger, or the mouse, laid on the panel's ground beside its content and moved sideways by dx; gives back the
    // letting go.
    function pullSideways(dx: real, byTouch: bool): var {
        const x = 900 - side.panelWidth + Geometry.hairline + Tokens.spaceM / 2;
        const y = 160;
        const touch = byTouch ? touchEvent(scene) : null;
        if (touch)
            touch.press(0, scene, x, y).commit();
        else
            mousePress(scene, x, y);
        for (let step = 1; step <= 10; ++step) {
            if (touch)
                touch.move(0, scene, x + dx * step / 10, y).commit();
            else
                mouseMove(scene, x + dx * step / 10, y);
        }
        // Qt Quick holds back a touch move that comes before the frame it waits for and hands it over with that frame;
        // asking for one keeps the wait short when the move itself changes nothing to draw.
        scene.Window.window.update();
        waitForRendering(scene);
        return () => touch ? touch.release(0, scene, x + dx, y).commit() : mouseRelease(scene, x + dx, y);
    }

    function test_the_panel_follows_a_finger_towards_the_trailing_edge_and_past_half_its_width_it_goes() {
        side.show(0);
        const panel = findChild(side, "panel");
        const letGo = pullSideways(0.6 * side.panelWidth, true);
        fuzzyCompare(panel.x, 900 - 0.4 * side.panelWidth, 1, "it follows the finger");
        letGo();
        verify(!side.open, "let go past half its width, it goes");
        verify(named("opener").activeFocus, "and gives the focus back");
    }

    function test_a_finger_let_go_before_half_its_width_has_the_panel_come_back() {
        side.show(0);
        pullSideways(0.4 * side.panelWidth, true)();
        tryCompare(side, "entry", 1, Tokens.durationModerate * 4);
        verify(side.open, "it stays");
        verify(control("doNotDisturb").activeFocus, "with the focus where it was");
    }

    function test_a_finger_moved_towards_the_leading_edge_leaves_the_panel_at_its_place() {
        side.show(0);
        const letGo = pullSideways(-0.4 * side.panelWidth, true);
        compare(side.entry, 1, "it never comes further in than its place");
        compare(findChild(side, "panel").x, 900 - side.panelWidth);
        letGo();
        compare(side.entry, 1);
        verify(side.open);
    }

    function test_a_finger_swipe_over_an_open_sheet_leaves_the_panel_and_the_sheet_where_they_are() {
        giveNetworks(controls);
        showLevel("network");
        mouseClick(rowsOf("networkRows")[3]);
        verify(sheet().open);
        const letGo = pullSideways(0.6 * side.panelWidth, true);
        compare(side.entry, 1, "the panel does not follow the finger");
        letGo();
        verify(side.open);
        verify(sheet().open);
    }

    function test_a_finger_during_the_leaving_changes_nothing_and_the_panel_ends_gone() {
        Prefs.motion = "on";
        showSettled(0);
        side.close();
        pullSideways(0.2 * side.panelWidth, true)();
        tryCompare(side, "open", false, Tokens.durationModerate * 4);
        compare(side.entry, 0, "wholly beyond the trailing edge");
    }

    function test_a_finger_moved_along_a_slider_sets_the_slider_and_leaves_the_panel_open() {
        giveSound(controls);
        showSettled(0);
        const slider = control("outputVolume");
        const from = slider.mapToItem(scene, slider.width * 0.3, slider.height / 2);
        const touch = touchEvent(scene);
        touch.press(0, scene, from.x, from.y).commit();
        for (let step = 1; step <= 10; ++step)
            touch.move(0, scene, from.x + 0.06 * slider.width * step, from.y).commit();
        touch.release(0, scene, from.x + 0.6 * slider.width, from.y).commit();
        verify(controls.output.audio.volume > 0.8, "the slider follows the finger");
        verify(side.open, "the panel stays");
        compare(side.entry, 1);
    }

    function test_in_a_panel_that_scrolls_a_finger_swipe_on_its_ground_still_sends_it_away() {
        giveSound(controls);
        giveBluetooth(controls);
        scene.height = 360;
        side.show(0);
        verify(named("scroller").interactive, "the facet scrolls");
        pullSideways(0.6 * side.panelWidth, true)();
        verify(!side.open);
    }

    function test_a_mouse_drag_towards_the_trailing_edge_leaves_the_panel_where_it_is() {
        side.show(0);
        const letGo = pullSideways(0.8 * side.panelWidth, false);
        compare(side.entry, 1, "it does not follow the mouse");
        letGo();
        verify(side.open);
    }

    function test_a_swipe_from_away_draws_the_panel_in_on_steuerung_and_it_follows_the_swipe() {
        side.show(1);
        side.close();
        const panel = findChild(side, "panel");
        side.drawIn(0.3);
        verify(side.open, "it shows as the swipe comes in");
        compare(side.currentIndex, 0, "on steuerung");
        compare(side.entry, 0.3);
        fuzzyCompare(panel.x, 900 - 0.3 * side.panelWidth, 0.01);
        side.drawIn(0.6);
        fuzzyCompare(panel.x, 900 - 0.6 * side.panelWidth, 0.01, "it follows");
        side.drawIn(0.2);
        fuzzyCompare(panel.x, 900 - 0.2 * side.panelWidth, 0.01, "also back");
        side.drawIn(1.4);
        compare(side.entry, 1, "never further in than its place");
        side.drawIn(-0.3);
        compare(side.entry, 0, "nor further out than the trailing edge");
        verify(side.open, "and it shows until the swipe lets go");
    }

    function test_a_swipe_let_go_at_half_its_width_has_the_panel_come_in_with_the_focus_on_its_first_control() {
        Prefs.motion = "on";
        side.drawIn(0.5);
        side.letGoIn();
        verify(findChild(side, "comingIn").running, "it comes in from where it stands");
        compare(side.entry, 0.5);
        tryCompare(side, "entry", 1, Tokens.durationModerate * 4);
        verify(side.open);
        compare(side.currentIndex, 0);
        verify(control("doNotDisturb").activeFocus, "the first control holds the focus");
        compare(ringsShowing(control("doNotDisturb")), 0, "without a ring, as after a pointer");
    }

    function test_a_swipe_let_go_before_half_its_width_has_the_panel_go_and_give_the_focus_back() {
        Prefs.motion = "on";
        const closed = createTemporaryObject(spyComponent, testCase, { target: side, signalName: "closed" });
        side.drawIn(0.49);
        side.letGoIn();
        verify(findChild(side, "goingOut").running, "it goes the way it leaves");
        tryCompare(closed, "count", 1, Tokens.durationModerate * 4);
        verify(!side.open);
        compare(side.entry, 0);
        verify(named("opener").activeFocus, "and the focus goes back");
    }

    function test_a_swipe_that_has_not_come_in_opens_nothing() {
        side.drawIn(0);
        side.drawIn(-0.2);
        verify(!side.open);
        side.letGoIn();
        verify(!side.open);
        verify(named("opener").activeFocus);
    }

    function test_a_swipe_drawing_in_leaves_the_open_panel_where_it_is() {
        side.show(1);
        side.drawIn(0.3);
        compare(side.entry, 1);
        compare(side.currentIndex, 1, "and on its facet");
        side.letGoIn();
        verify(side.open);
        compare(side.entry, 1);
    }

    function test_shown_while_a_swipe_draws_it_in_it_comes_in_and_the_letting_go_changes_nothing() {
        side.drawIn(0.2);
        side.show(0);
        compare(side.entry, 1);
        verify(control("doNotDisturb").activeFocus);
        side.letGoIn();
        verify(side.open);
        compare(side.entry, 1);
    }

    function test_shown_while_a_swipe_draws_it_in_the_same_swipe_moves_it_no_more() {
        side.drawIn(0.2);
        side.show(0);
        side.drawIn(0.3);
        compare(side.entry, 1, "the swipe moving on leaves it in");
        side.close();
        verify(!side.open);
        side.drawIn(0.5);
        verify(!side.open, "and once it has gone, the same swipe does not bring it back");
        side.letGoIn();
        side.drawIn(0.3);
        verify(side.open, "the next swipe draws it in again");
        compare(side.entry, 0.3);
    }

    function test_closed_while_a_swipe_draws_it_in_the_same_swipe_moving_on_opens_it_no_more() {
        Prefs.motion = "on";
        side.drawIn(0.4);
        side.toggle(0, false);
        tryCompare(side, "open", false, Tokens.durationModerate * 4);
        side.drawIn(0.5);
        verify(!side.open, "the swipe moving on after the close leaves it away");
        side.letGoIn();
        verify(!side.open);
        side.drawIn(0.3);
        verify(side.open, "the next swipe draws it in again");
        compare(side.entry, 0.3);
    }

    function test_under_reduced_motion_a_close_mid_swipe_holds_against_the_swipe_moving_on() {
        side.drawIn(0.4);
        side.close();
        verify(!side.open, "gone at once");
        side.drawIn(0.45);
        verify(!side.open, "the next step of the same swipe leaves it away");
    }

    function test_closed_while_a_swipe_draws_it_out_its_letting_go_brings_it_back_no_more() {
        Prefs.motion = "on";
        showSettled(0);
        side.drawOut(0.3);
        side.close();
        side.letGoOut();
        verify(!findChild(side, "comingIn").running, "the letting go does not bring it back");
        tryCompare(side, "open", false, Tokens.durationModerate * 4);
        verify(!findChild(side, "comingIn").running, "nothing draws it after it has gone");
        compare(side.entry, 0);
    }

    function test_a_swipe_drawing_out_while_the_panel_goes_leaves_it_going() {
        Prefs.motion = "on";
        showSettled(0);
        side.close();
        side.drawOut(0.2);
        side.letGoOut();
        verify(!findChild(side, "comingIn").running, "the swipe does not bring it back");
        tryCompare(side, "open", false, Tokens.durationModerate * 4);
        verify(!findChild(side, "comingIn").running, "nothing draws it after it has gone");
        compare(side.entry, 0);
    }

    function test_closed_while_a_swipe_draws_it_in_it_goes_and_its_letting_go_brings_it_back_no_more() {
        Prefs.motion = "on";
        side.drawIn(0.8);
        side.toggle(0, false);
        verify(findChild(side, "goingOut").running, "it goes");
        side.letGoIn();
        verify(!findChild(side, "comingIn").running, "the letting go does not bring it back");
        tryCompare(side, "open", false, Tokens.durationModerate * 4);
        side.drawIn(0);
        verify(!side.open, "nor does the swipe, back where it set out");
    }

    function test_a_swipe_drawing_out_follows_and_past_half_its_width_the_panel_goes_and_gives_the_focus_back() {
        side.show(0);
        const panel = findChild(side, "panel");
        side.drawOut(0.3);
        fuzzyCompare(panel.x, 900 - 0.7 * side.panelWidth, 0.01, "it follows towards the trailing edge");
        side.drawOut(0.6);
        fuzzyCompare(panel.x, 900 - 0.4 * side.panelWidth, 0.01);
        side.letGoOut();
        verify(!side.open, "let go past half its width, it goes");
        verify(named("opener").activeFocus, "and gives the focus back");
    }

    function test_a_swipe_drawing_out_let_go_before_half_its_width_has_the_panel_come_back() {
        Prefs.motion = "on";
        showSettled(0);
        side.drawOut(0.4);
        side.letGoOut();
        verify(findChild(side, "comingIn").running, "it comes back");
        tryCompare(side, "entry", 1, Tokens.durationModerate * 4);
        verify(side.open);
        verify(control("doNotDisturb").activeFocus, "with the focus where it was");
    }

    function test_each_swipe_is_let_go_only_by_its_own_letting_go() {
        side.drawIn(0.3);
        side.drawOut(0.6);
        compare(side.entry, 0.3, "a swipe out leaves the swipe in where it is");
        side.letGoOut();
        verify(side.open, "and so does its letting go");
        compare(side.entry, 0.3);
        side.drawIn(0.8);
        side.letGoIn();
        compare(side.entry, 1);
        side.drawOut(0.3);
        side.letGoIn();
        fuzzyCompare(side.entry, 0.7, 0.0001, "and a swipe in let go the swipe out");
    }

    function test_a_swipe_drawing_out_while_the_panel_is_away_or_over_an_open_sheet_does_nothing() {
        side.drawOut(0.6);
        side.letGoOut();
        verify(!side.open, "away, it stays away");
        compare(side.entry, 1);
        giveNetworks(controls);
        showLevel("network");
        mouseClick(rowsOf("networkRows")[3]);
        verify(sheet().open);
        side.drawOut(0.6);
        compare(side.entry, 1, "over a sheet the panel keeps still");
        side.letGoOut();
        verify(side.open);
        verify(sheet().open);
    }

    function test_under_reduced_motion_the_panel_follows_a_swipe_and_its_end_stands_at_once() {
        side.drawIn(0.4);
        compare(side.entry, 0.4, "it follows, moved by hand");
        side.drawIn(0.7);
        side.letGoIn();
        compare(side.entry, 1, "in at once");
        side.drawOut(0.3);
        fuzzyCompare(side.entry, 0.7, 0.0001, "it follows out as well");
        side.letGoOut();
        compare(side.entry, 1, "back at once");
        side.drawOut(0.6);
        side.letGoOut();
        verify(!side.open, "gone at once");
        side.drawIn(0.3);
        side.letGoIn();
        verify(!side.open, "a short swipe in goes at once");
        compare(side.entry, 0);
    }

    function test_escape_closes_it_from_every_control() {
        for (const name of ["dark", "doNotDisturb", "powerProfile", "lock", "sessionActions", "displayTile"]) {
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

    function test_it_shows_a_facet_from_show_until_it_has_gone_and_a_turn_to_another_facet_moves_that() {
        Prefs.motion = "on";
        verify(!side.shows(0) && !side.shows(1), "away, it shows none");
        side.show(0);
        verify(side.shows(0));
        verify(!side.shows(1));
        side.show(1);
        verify(side.shows(1), "turned to the other facet");
        verify(!side.shows(0));
        tryCompare(side, "entry", 1, Tokens.durationModerate * 4);
        side.close();
        verify(side.shows(1), "still while it leaves");
        tryVerify(() => !side.open, Tokens.durationModerate * 4);
        verify(!side.shows(1), "not once it has gone");
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

    function test_the_toggle_buttons_and_the_grid_stand_in_the_facets_scroll_and_the_panel_has_no_edge_of_its_own() {
        showSettled(0);
        const facets = findChild(side, "facets");
        verify(side.within(facets, control("toggles")), "the toggle buttons");
        verify(side.within(facets, control("areas")), "the grid");
        compare(side.edge, undefined, "no holder at the edge");
    }

    function test_on_their_way_in_the_quick_settings_are_cut_off_at_the_ground_and_leave_the_hairline_a_hairline() {
        controls.setDoNotDisturb(true);
        Prefs.motion = "on";
        showSettled(1);
        side.show(0);
        // Held at the start of the way, past the ground's edge, at full opacity so that a pixel over the hairline shows.
        findChild(side, "enter").stop();
        findChild(side, "shift").x = -Tokens.slideDistance;
        findChild(side, "holder").opacity = 1;
        waitForRendering(scene);
        const quiet = control("doNotDisturb");
        verify(quiet.checked, "nicht stören on, an ink fill");
        verify(quiet.mapToItem(findChild(side, "ground"), 0, 0).x < 0, "the row reaches past the ground");
        const hairline = findChild(side, "panel").mapToItem(scene, 0, 0);
        const besideQuiet = quiet.mapToItem(scene, 0, quiet.height / 2);
        verify(Qt.colorEqual(grabImage(scene).pixel(Math.floor(hairline.x), Math.floor(besideQuiet.y)), Tokens.color.textContrastLow));
    }

    function test_the_focus_ring_of_a_quick_setting_at_the_grounds_padding_is_not_cut_off() {
        showSettled(0);
        const quiet = control("doNotDisturb");
        quiet.forceActiveFocus(Qt.TabFocusReason);
        waitForRendering(scene);
        const ring = findChild(quiet, "ring");
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
        verify(control("doNotDisturb").activeFocus, "the first control in steuerung");
        side.close();
        side.show(1);
        verify(findChild(side, "pivot").activeFocus, "meldungen has none yet");
    }

    function ringOf(name: string): var {
        return findChild(control(name), "ring");
    }

    function test_opened_by_a_pointer_no_control_shows_a_focus_ring_until_a_key_is_pressed() {
        side.show(0, true);
        verify(control("doNotDisturb").activeFocus, "the focus is on the first control all the same");
        compare(ringsShowing(control("doNotDisturb")), 0);
        keyClick(Qt.Key_Tab);
        verify(control("dark").activeFocus);
        compare(ringsShowing(control("dark")), 1, "the keyboard brings the ring");
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
        compare(ringsShowing(control("doNotDisturb")), 1);
    }

    // As they stand: the toggle buttons, the groups, the grid at the foot as one stop, then the close button.
    function test_tab_and_the_arrows_reach_every_control_in_order() {
        giveBluetooth(controls);
        side.show(0);
        const names = ["doNotDisturb", "dark", "powerProfile", "lock", "sessionActions", "bluetoothTile", "close"];
        const order = names.map(name => findChild(side, name));
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
        verify(order[5].activeFocus, "↓ from the last row into the grid");
        keyClick(Qt.Key_Down);
        verify(order[5].activeFocus, "the grid's arrows stay at its edge");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Down);
        verify(findChild(side, "close").activeFocus, "the arrows never leave the panel");
    }

    // Whole in sight with its ring, in the facet's scroll or a level's.
    function shownWhole(item: var, scroller = named("scroller")): bool {
        const ring = Geometry.focusRingOffset + Geometry.focusRingWidth;
        const top = item.mapToItem(scroller, 0, 0).y - ring;
        return side.within(scroller, item) && top >= -0.5 && top + item.height + 2 * ring <= scroller.height + 0.5;
    }

    function test_in_a_short_panel_tab_and_shift_tab_bring_every_stop_whole_into_sight() {
        giveSound(controls);
        giveBluetooth(controls);
        scene.height = 360;
        showSettled(0);
        const names = [];
        for (const modifier of [Qt.NoModifier, Qt.ShiftModifier]) {
            if (modifier === Qt.ShiftModifier) {
                control("soundTile").forceActiveFocus();
                named("scroller").contentY = 0;
            }
            for (let k = 0; k < 40; k++) {
                keyClick(Qt.Key_Tab, modifier);
                const focused = side.Window.activeFocusItem;
                if (!side.holds(focused) || focused === findChild(side, "pivot"))
                    break;
                names.push(focused.objectName);
                // The close button stands at the top corner, always in sight.
                verify(focused === findChild(side, "close") || shownWhole(focused), `${focused.objectName} in sight`);
            }
        }
        for (const name of ["outputVolume", "dark", "lock", "sessionActions", "soundTile"])
            verify(names.includes(name), `Tab reached ${name}`);
        verify(named("scroller").contentY > 0, "the view followed the focus");
    }

    function test_a_focus_that_scrolls_its_control_into_sight_keeps_the_tip_it_brought() {
        giveSound(controls);
        scene.height = 360;
        const scroller = showLevel("sound");
        verify(scroller.interactive, "a level longer than its room");
        const mute = inSound("inputMute");
        verify(!shownWhole(mute, scroller), "below the view");
        mute.forceActiveFocus(Qt.TabFocusReason);
        verify(shownWhole(mute, scroller));
        verify(named("tip").visible, "its tip stays");
        compare(findChild(named("tip"), "words").text, "stumm schalten");
    }

    function test_every_row_works_from_the_keyboard() {
        controls.hasPerformanceProfile = true;
        controls.kdeglobals = "";
        side.show(0);
        verify(control("doNotDisturb").activeFocus);
        keyClick(Qt.Key_Space);
        verify(controls.doNotDisturb, "nicht stören");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        compare(commands, [["plasma-apply-lookandfeel", "--apply", "org.kde.breezedark.desktop"]], "dunkel");
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
        keyClick(Qt.Key_Return);
        verify(control("density").activeFocus, "anzeige's level, its first control");
        keyClick(Qt.Key_Right);
        compare(chosenDensities, ["comfortable"], "dichte, where the arrows choose");
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

    // A laptop battery as UPower reports it, with the values `values` over them.
    function giveBattery(target: var, values: var) {
        const battery = target.battery;
        const stand = Object.assign({ present: true, kind: 2, percentage: 64, state: 2, timeToEmpty: 12000, timeToFull: 0, warningLevel: 1 }, values ?? {});
        for (const key of Object.keys(stand))
            battery[key] = stand[key];
    }

    function test_without_a_battery_there_is_no_akku_tile_and_the_energy_profile_stays_in_sitzung() {
        showSettled(0);
        verify(!control("batteryTile").visible, "a desktop has no akku");
        verify(rowOf(control("powerProfile")).visible, "the profile stays in the group");
        verify(!rowOf(findChild(controls, "batteryProfile")).visible);
        compare(controls.places.battery, findChild(side, "session"));
    }

    function test_with_a_battery_the_akku_tile_stands_before_anzeige_and_the_energy_profile_moves_into_its_level() {
        giveBattery(controls);
        showSettled(0);
        const tile = control("batteryTile");
        verify(tile.visible);
        compare(tile.glyph, "battery");
        compare(tile.name, "akku");
        compare(control("areas").shownTiles(), [tile, control("displayTile")]);
        verify(!rowOf(control("powerProfile")).visible, "no longer in sitzung");
        verify(findChild(controls, "session").visible, "sperren still stands there");
        compare(controls.places.battery, findChild(controls, "battery"));
        const level = showLevel("battery");
        verify(side.within(level, rowOf(findChild(controls, "batteryProfile"))));
        verify(rowOf(findChild(controls, "batteryProfile")).visible);
    }

    function test_the_akku_tile_says_the_stand_whether_it_charges_or_is_full() {
        giveBattery(controls, { percentage: 64, state: 2 });
        showSettled(0);
        compare(stateOf("batteryTile"), "64 %");
        giveBattery(controls, { state: 1 });
        compare(stateOf("batteryTile"), "64 % · lädt");
        giveBattery(controls, { percentage: 100, state: 4 });
        compare(stateOf("batteryTile"), "voll");
        giveBattery(controls, { percentage: 80, state: 5 });
        compare(stateOf("batteryTile"), "80 %", "held at a charge limit");
    }

    function test_the_akku_tile_says_knapp_on_the_error_colour_from_low_on_and_not_before() {
        giveBattery(controls, { percentage: 20, warningLevel: 2 });
        showSettled(0);
        const tile = control("batteryTile");
        compare(tile.status, "");
        compare(tile.word, "");
        giveBattery(controls, { percentage: 9, warningLevel: 3 });
        tryCompare(tile, "status", "error");
        compare(tile.word, "knapp", "the product's word, not Rekta's failed");
        compare(tile.Accessible.name, "akku, 9 %, knapp");
        giveBattery(controls, { percentage: 4, warningLevel: 4 });
        compare(tile.status, "error");
        compare(tile.word, "knapp");
    }

    function test_a_new_knapp_comes_to_the_akku_tile_as_news_that_waits_while_the_tile_is_held() {
        giveBattery(controls, { percentage: 20, warningLevel: 2 });
        showSettled(0);
        const tile = control("batteryTile");
        tile.held = true;
        giveBattery(controls, { percentage: 9, warningLevel: 3 });
        compare(tile.status, "", "news waits for a held tile");
        tile.held = false;
        tryCompare(tile, "status", "error");
    }

    function test_the_akku_tile_reads_akku_the_stand_and_that_it_charges() {
        giveBattery(controls, { state: 1 });
        showSettled(0);
        compare(control("batteryTile").Accessible.name, "akku, 64 %, lädt");
        giveBattery(controls, { state: 2 });
        compare(control("batteryTile").Accessible.name, "akku, 64 %");
        giveBattery(controls, { percentage: 100, state: 4 });
        compare(control("batteryTile").Accessible.name, "akku, voll");
    }

    function test_the_level_shows_stand_state_time_and_then_the_energy_profile_in_that_order() {
        giveBattery(controls, { percentage: 64, state: 2, timeToEmpty: 12000 });
        showLevel("battery");
        const rows = ["batteryStand", "batteryState", "batteryEstimate", "batteryProfile"].map(name => rowOf(inLevel("battery", name)));
        compare(rows.map(row => row.label), ["stand", "zustand", "restzeit", "energieprofil"]);
        compare(inLevel("battery", "batteryStand").text, "64 %");
        compare(inLevel("battery", "batteryState").text, "entlädt");
        compare(inLevel("battery", "batteryEstimate").text, "noch 3 h 20 min");
        verify(rows.every(row => row.visible));
        for (let k = 1; k < rows.length; k++)
            verify(rows[k].mapToItem(controls, 0, 0).y > rows[k - 1].mapToItem(controls, 0, 0).y, `row ${k} below row ${k - 1}`);
    }

    function test_the_level_says_how_long_until_full_while_charging_and_has_no_time_row_without_an_estimate() {
        giveBattery(controls, { state: 1, timeToFull: 4200 });
        showLevel("battery");
        compare(inLevel("battery", "batteryState").text, "lädt");
        compare(inLevel("battery", "batteryEstimate").text, "bis voll 1 h 10 min");
        giveBattery(controls, { state: 1, timeToFull: 0 });
        verify(!rowOf(inLevel("battery", "batteryEstimate")).visible, "no estimate, no row");
        giveBattery(controls, { state: 4, percentage: 100, timeToFull: 4200 });
        verify(!rowOf(inLevel("battery", "batteryEstimate")).visible, "none once full");
        compare(inLevel("battery", "batteryState").text, "voll");
    }

    function test_the_level_has_no_state_row_while_upower_reports_no_state() {
        giveBattery(controls, { state: 0 });
        showLevel("battery");
        verify(!rowOf(inLevel("battery", "batteryState")).visible);
        compare(inLevel("battery", "batteryStand").text, "64 %");
    }

    function test_the_level_follows_a_battery_that_changes_while_it_stands() {
        giveBattery(controls, { percentage: 64 });
        showLevel("battery");
        giveBattery(controls, { percentage: 63, timeToEmpty: 11400 });
        compare(inLevel("battery", "batteryStand").text, "63 %");
        compare(inLevel("battery", "batteryEstimate").text, "noch 3 h 10 min");
    }

    function test_the_energy_profile_in_the_level_sets_the_profile_and_follows_the_system() {
        giveBattery(controls);
        showLevel("battery");
        const segments = inLevel("battery", "batteryProfile");
        compare(segments.currentIndex, 1);
        segments.forceActiveFocus();
        keyClick(Qt.Key_Left);
        compare(chosenProfiles, [0]);
        compare(segments.currentIndex, 1, "it shows the profile the system has until the system changes it");
        controls.powerProfile = 0;
        compare(segments.currentIndex, 0);
        controls.hasPowerProfiles = false;
        verify(!rowOf(segments).visible, "without the daemon the row is gone");
    }

    function test_a_battery_that_goes_brings_the_energy_profile_back_to_sitzung_and_takes_the_tile() {
        giveBattery(controls);
        showSettled(0);
        controls.battery.present = false;
        verify(!control("batteryTile").visible);
        verify(rowOf(control("powerProfile")).visible);
        compare(controls.places.battery, findChild(side, "session"));
    }

    // The level of akku in both themes: charging with an estimate, and low.
    function test_contact_sheet_of_akku_in_both_themes() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            for (const look of [["charging", { state: 1, percentage: 64, timeToFull: 4200 }], ["low", { state: 2, percentage: 9, warningLevel: 3, timeToEmpty: 1500 }]]) {
                const contact = createTemporaryObject(contactComponent, testCase);
                contact.height = 800;
                const panel = findChild(contact, "panel");
                giveSound(panel.controls);
                giveDisplays(panel.controls);
                giveBattery(panel.controls, look[1]);
                panel.show(0, true);
                waitForRendering(contact);
                grabImage(contact).save(`panel-battery-tile-sheet-${look[0]}-${theme}.png`);
                findChild(contact, "batteryTile").forceActiveFocus();
                keyClick(Qt.Key_Return);
                waitForRendering(contact);
                verify(findChild(contact, "battery").open, `${look[0]} ${theme}`);
                grabImage(contact).save(`panel-battery-sheet-${look[0]}-${theme}.png`);
                contact.destroy();
            }
        }
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
        const group = showLevel("sound");
        compare(findChild(group, "back").text, "zurück · ton", "under its back row, without a heading");
        compare(shownRows(group), [rowOf(inSound("outputDevice")), rowOf(inSound("outputVolume")), rowOf(inSound("inputDevice")), rowOf(inSound("inputVolume"))], "no row of its own for stumm");
        for (const kind of ["output", "input"]) {
            const select = inSound(`${kind}Device`);
            verify(!findChild(rowOf(select), "words").visible, `${kind}: no words before the select`);
            compare(select.mapToItem(rowOf(select), 0, 0).x, 0, kind);
            compare(select.width, rowOf(select).width, `${kind}: the select as wide as the row`);
            const row = rowOf(inSound(`${kind}Volume`));
            const box = findChild(inSound(`${kind}Mute`), "box");
            compare(rowOf(inSound(`${kind}Mute`)), row, `${kind}: the button stands in the volume's row`);
            compare(box.mapToItem(row, 0, 0).x, 0, `${kind}: the button at the start`);
            compare(box.width, Tokens.controlHeight, `${kind}: a square icon button`);
            const slider = inSound(`${kind}Volume`);
            compare(slider.mapToItem(row, 0, 0).x, box.width + Tokens.spaceM, `${kind}: the slider space-m after it`);
            compare(slider.mapToItem(row, slider.width, 0).x, row.width, `${kind}: to the end of the row`);
            compare(row.height, Tokens.controlHeight, `${kind}: on one line`);
        }
        compare(findChild(inSound("outputMute"), "glyph").name, "speaker");
        compare(findChild(inSound("inputMute"), "glyph").name, "microphone");
        compare(inSound("outputDevice").currentText, "Speakers");
        compare(inSound("inputDevice").currentText, "Microphone");
        compare(findChild(inSound("outputVolume"), "output").text, "62%");
        compare(findChild(inSound("outputVolume"), "output").font.features, { "tnum": 1 }, "in tabular figures");
        compare(inSound("outputDevice").Accessible.name, "ausgang Speakers", "the kind is read with the select");
        compare(inSound("inputDevice").Accessible.name, "eingang Microphone");
        compare(inSound("outputVolume").Accessible.name, "lautstärke ausgang");
        compare(inSound("inputVolume").Accessible.name, "lautstärke eingang");
    }

    function test_each_device_select_has_its_visible_field_label_above_it_space_xs_apart() {
        giveSound(controls);
        side.show(0);
        waitForRendering(side);
        for (const [kind, word] of [["output", "ausgang"], ["input", "eingang"]]) {
            const label = control(`${kind}DeviceLabel`);
            const select = control(`${kind}Device`);
            compare(label.text, word);
            compare(label.font.pixelSize, Tokens.fontSizeXs, `${kind}: xs`);
            compare(label.font.weight, Tokens.fontWeightSemibold, `${kind}: semibold`);
            compare(label.color, Tokens.color.textContrastHigh);
            compare(select.mapToItem(label, 0, 0).y, label.height + Tokens.spaceXs, `${kind}: select space-xs below its label`);
            compare(select.mapToItem(label, 0, 0).x, 0, `${kind}: at one start edge`);
            compare(rowOf(label).height, label.height + Tokens.spaceXs + select.height, `${kind}: the row holds both`);
        }
        compare(control("outputDevice").Accessible.name, "ausgang Speakers");
        compare(control("inputDevice").Accessible.name, "eingang Microphone");
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
        showLevel("sound");
        const slider = inSound("outputVolume");
        mouseClick(findChild(inSound("outputMute"), "box"));
        verify(sound.speakers.audio.muted, "a press mutes the device");
        compare(findChild(inSound("outputMute"), "glyph").name, "speaker-muted");
        verify(slider.disabled, "the slider rests");
        compare(findChild(slider, "output").text, "stumm", "its value says why");
        compare(findChild(slider, "output").color, Tokens.color.disabled, "in grey");
        compare(slider.Accessible.description, "stumm");
        verify(!findChild(slider, "why").visible, "and nothing below says it again");
        compare(rowOf(slider).height, Tokens.controlHeight);
        slider.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(sound.speakers.audio.volume, 0.62, "a resting slider takes no step");
        mouseClick(findChild(inSound("outputMute"), "box"));
        verify(!sound.speakers.audio.muted, "a second press brings the sound back");
        compare(findChild(inSound("outputMute"), "glyph").name, "speaker");
        verify(!slider.disabled);
        compare(findChild(slider, "output").text, "62%");
        mouseClick(findChild(inSound("inputMute"), "box"));
        verify(sound.microphone.audio.muted, "the microphone the same");
        compare(findChild(inSound("inputMute"), "glyph").name, "microphone-muted");
        verify(inSound("inputVolume").disabled);
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
        const level = showLevel("sound");
        const tip = named("tip");
        const words = findChild(tip, "words");
        const box = findChild(inSound("outputMute"), "box");
        verify(!tip.visible);
        inSound("outputMute").forceActiveFocus();
        verify(tip.visible, "the panel's window draws its own tips");
        compare(words.text, "stumm schalten");
        const at = box.mapToItem(tip.parent, 0, 0);
        compare(tip.side, "above");
        compare(tip.y, Math.round(at.y - Tokens.tipGap - tip.height), "tip-gap above its control");
        verify(tip.x < at.x + box.width && tip.x + tip.width > at.x, "over it");
        compare(tip.x, Tokens.spaceM, "space-m from the panel's leading edge");
        verify(drawnAsInk(tip), "an ink strip");
        keyClick(Qt.Key_Space);
        verify(tip.visible);
        compare(words.text, "ton an", "it says what the next press does");
        level.contentY = 1;
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
        showLevel("sound");
        verify(inSound("outputDevice").activeFocus, "the first control");
        keyClick(Qt.Key_Tab);
        verify(inSound("outputMute").activeFocus, "Tab to the button");
        keyClick(Qt.Key_Space);
        verify(sound.speakers.audio.muted, "Space mutes");
        keyClick(Qt.Key_Down);
        verify(inSound("outputVolume").activeFocus, "↓ to the slider, which a keyboard still reaches while it rests");
        keyClick(Qt.Key_Right);
        compare(sound.speakers.audio.volume, 0.6);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        verify(inSound("outputMute").activeFocus, "Shift+Tab back to the button");
        keyClick(Qt.Key_Return);
        verify(!sound.speakers.audio.muted, "Enter brings the sound back");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Right);
        compare(sound.speakers.audio.volume, 0.61, "then the slider steps");
        keyClick(Qt.Key_Tab);
        verify(inSound("inputDevice").activeFocus, "Tab on to the input's select");
        keyClick(Qt.Key_Tab);
        verify(inSound("inputMute").activeFocus);
        keyClick(Qt.Key_Enter);
        verify(sound.microphone.audio.muted, "the microphone the same");
        keyClick(Qt.Key_Up);
        verify(inSound("inputDevice").activeFocus, "↑ back to its select");
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
        showLevel("display");
        verify(!control("display0Brightness"));
        verify(findChild(controls, "display").visible);
        verify(control("displayTile").visible);
        giveDisplays(controls).clear();
        verify(!control("display0Brightness"));
        verify(rowOf(control("density")).visible);
    }

    function test_without_audio_devices_ton_falls_away_and_without_an_input_only_its_rows_go() {
        const sound = giveSound(controls);
        showLevel("sound");
        controls.input = null;
        verify(control("soundTile").visible);
        verify(!rowOf(inSound("inputDevice")).visible);
        verify(!rowOf(inSound("inputVolume")).visible);
        controls.output = null;
        verify(!control("soundTile").visible, "its tile falls away");
    }

    function test_each_stream_another_program_plays_has_a_row_in_ton_between_the_output_and_the_input() {
        giveSound(controls);
        giveStreams(controls);
        const group = showLevel("sound");
        const rows = streamRows();
        compare(shownRows(group), [rowOf(inSound("outputDevice")), rowOf(inSound("outputVolume")), ...rows, rowOf(inSound("inputDevice")), rowOf(inSound("inputVolume"))]);
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
        showLevel("sound");
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
        showLevel("sound");
        compare(streamRows().map(row => row.label), ["Player"], "no recording, monitor, video, own, device, untracked or event stream");
    }

    function test_a_streams_button_and_slider_set_that_stream_alone_and_follow_changes_from_elsewhere() {
        const sound = giveSound(controls);
        sound.speakers.audio.volume = 0.6;
        const streams = giveStreams(controls);
        showLevel("sound");
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
        showLevel("sound");
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
        showLevel("sound");
        inSound("outputVolume").forceActiveFocus();
        for (const row of streamRows()) {
            keyClick(Qt.Key_Tab);
            verify(findChild(row, "streamMute").activeFocus, `Tab to the button of ${row.label}`);
            keyClick(Qt.Key_Down);
            verify(findChild(row, "streamVolume").activeFocus, `↓ to its slider`);
        }
        keyClick(Qt.Key_Left);
        compare(streams.music.audio.volume, 0.69, "the slider steps its stream");
        keyClick(Qt.Key_Tab);
        verify(inSound("inputDevice").activeFocus, "then on to the input");
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        verify(findChild(streamRows()[2], "streamVolume").activeFocus, "Shift+Tab back");
    }

    function test_a_stream_that_comes_is_appended_and_once_the_rows_below_have_made_room_arrives_from_above_with_a_fade() {
        giveSound(controls);
        const streams = giveStreams(controls);
        showLevel("sound");
        Prefs.motion = "on";
        const presence = findChild(controls, "streamPresence");
        const input = rowOf(inSound("inputDevice"));
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
        compare(rows[3].opacity, 0, "unseen while they make room");
        const glided = presence.moving.filter(motion => !motion.fades).map(glide => Glide.record(glide, "progress"));
        const shows = Glide.record(rows[3], "opacity");
        tryVerify(() => !presence.running, Tokens.durationModerate * 4);
        const landed = Math.max(...glided.map(steps => steps[steps.length - 1].order));
        verify(shows.length > 0 && shows.every(step => step.order > landed), "it fades in only once every row below has glided to its place");
        compare(rows[3].opacity, 1, "whole once it rests");
    }

    function test_a_stream_that_ends_leaves_as_it_was_drifting_to_the_trailing_edge_and_the_rest_close_the_gap() {
        giveSound(controls);
        const streams = giveStreams(controls);
        streams.tab.audio.muted = true;
        showLevel("sound");
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
        showLevel("sound");
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
        showLevel("sound");
        controls.streams = [streams.music];
        compare(streamRows().map(row => row.label), ["Elisa · Gymnopédie No. 1"]);
        controls.streams = [streams.music, streams.tab];
        compare(streamRows().map(row => row.label), ["Elisa · Gymnopédie No. 1", "Firefox · AudioStream"]);
        verify(!findChild(controls, "streamPresence").running);
    }

    function test_without_streams_ton_shows_its_device_rows_alone() {
        giveSound(controls);
        showLevel("sound");
        compare(streamRows(), []);
        compare(shownRows(findChild(controls, "sound")).length, 4);
    }

    function test_the_output_select_opens_a_list_floating_over_the_rows_below_and_a_click_asks_for_another_default() {
        const sound = giveSound(controls);
        showLevel("sound");
        const select = inSound("outputDevice");
        const volumeRow = rowOf(inSound("outputVolume"));
        const before = volumeRow.mapToItem(controls, 0, 0).y;
        mouseClick(findChild(select, "box"));
        verify(select.expanded);
        const options = optionRows(select);
        compare(options.map(row => row.text), ["Speakers", "Headphones"]);
        compare(options.map(row => row.checked), [true, false], "the default carries the tick");
        compare(volumeRow.mapToItem(controls, 0, 0).y, before, "the volume's row stays where it was");
        waitForRendering(side);
        mouseClick(options[1]);
        compare(chosenDevices, [sound.headphones], "a click chooses");
        verify(!select.expanded);
        compare(select.currentText, "Speakers", "the default PipeWire has, until it changes");
        controls.output = sound.headphones;
        compare(select.currentText, "Headphones");
        verify(findChild(findChild(controls, "sound"), "rows").visible, "the rows stay in place");
    }

    function test_the_input_select_lists_the_inputs() {
        const sound = giveSound(controls);
        showLevel("sound");
        const select = inSound("inputDevice");
        mouseClick(findChild(select, "box"));
        const options = optionRows(select);
        compare(options.map(row => row.text), ["Microphone", "Headset Microphone"]);
        waitForRendering(side);
        mouseClick(options[1]);
        compare(chosenDevices, [sound.headset]);
    }

    function test_from_the_keyboard_its_list_opens_a_device_is_chosen_and_the_focus_stays() {
        const sound = giveSound(controls);
        showLevel("sound");
        const select = inSound("outputDevice");
        verify(select.activeFocus, "the first control of ton");
        keyClick(Qt.Key_Return);
        verify(select.expanded);
        const options = optionRows(select);
        verify(options[0].activeFocus, "the keys start on the default");
        keyClick(Qt.Key_Down);
        verify(options[1].activeFocus);
        keyClick(Qt.Key_Down);
        verify(options[0].activeFocus, "↓ goes around the list rather than on in the panel");
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Return);
        compare(chosenDevices, [sound.headphones], "Enter chooses");
        verify(!select.expanded);
        verify(select.activeFocus, "the focus stays on the select");
        verify(side.open);
    }

    function test_closed_the_arrows_on_the_select_ask_for_another_device_without_opening_it() {
        const sound = giveSound(controls);
        showLevel("sound");
        const select = inSound("outputDevice");
        verify(select.activeFocus);
        keyClick(Qt.Key_Down);
        compare(chosenDevices, [sound.headphones]);
        verify(!select.expanded);
        verify(select.activeFocus, "the focus stays on the select");
        controls.output = sound.headphones;
        keyClick(Qt.Key_Down);
        verify(select.activeFocus, "↓ on the last device stays on the select rather than walking on in the panel");
        compare(chosenDevices, [sound.headphones]);
        keyClick(Qt.Key_Up);
        compare(chosenDevices, [sound.headphones, sound.speakers]);
        controls.output = sound.speakers;
        keyClick(Qt.Key_Up);
        verify(select.activeFocus, "↑ on the first device stays on the select");
        compare(chosenDevices, [sound.headphones, sound.speakers]);
    }

    function test_escape_closes_the_list_and_leaves_the_level_and_the_panel_open() {
        giveSound(controls);
        showLevel("sound");
        const select = inSound("outputDevice");
        keyClick(Qt.Key_Return);
        verify(select.expanded);
        keyClick(Qt.Key_Escape);
        verify(!select.expanded);
        verify(side.open, "the panel stays");
        verify(select.activeFocus);
        compare(chosenDevices, []);
        keyClick(Qt.Key_Escape);
        verify(!findChild(controls, "sound").open, "the next leaves the level");
        verify(control("soundTile").activeFocus);
        keyClick(Qt.Key_Escape);
        verify(!side.open, "and the one after closes the panel");
    }

    function test_escape_closes_a_list_a_pointer_opened_then_the_level_and_only_then_the_panel() {
        giveSound(controls);
        showLevel("sound");
        const select = inSound("inputDevice");
        mouseClick(findChild(select, "box"));
        verify(select.expanded);
        verify(!select.activeFocus, "a press gives no focus");
        keyClick(Qt.Key_Escape);
        verify(!select.expanded, "Escape folds the list first");
        verify(side.open, "the panel stays");
        keyClick(Qt.Key_Escape);
        verify(!findChild(controls, "sound").open, "a second leaves the level");
        verify(side.open);
        keyClick(Qt.Key_Escape);
        verify(!side.open, "a third, on its tile, closes the panel");
    }

    // A branch unfolded as a pointer's press on its opener does: the focus stays where it was, outside it.
    function unfoldByPointer(): var {
        const branch = control("quietBranch");
        branch.expand();
        verify(branch.expanded);
        return branch;
    }

    function test_escape_folds_a_branch_a_pointer_unfolded_without_focus_and_only_a_second_escape_closes_the_panel() {
        showSettled(0);
        const branch = unfoldByPointer();
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

    function test_escape_in_another_window_leaves_an_open_branch_open() {
        showSettled(0);
        const branch = unfoldByPointer();
        const elsewhere = createTemporaryObject(windowedComponent, testCase).first;
        verify(!branch.foldOnEscape({ key: Qt.Key_Escape }, elsewhere));
        verify(branch.expanded);
    }

    function test_another_key_or_a_sheet_over_it_leaves_an_open_branch_open() {
        showSettled(0);
        const branch = unfoldByPointer();
        const focused = side.Window.activeFocusItem;
        verify(!branch.foldOnEscape({ key: Qt.Key_Down }, focused), "only Escape");
        KeyLayers.opened(side.sheets);
        verify(!branch.foldOnEscape({ key: Qt.Key_Escape }, focused), "a sheet over it is nearer");
        KeyLayers.closed(side.sheets);
        verify(branch.expanded);
    }

    function test_the_selects_list_closes_with_the_panel() {
        giveSound(controls);
        showLevel("sound");
        keyClick(Qt.Key_Return);
        verify(inSound("outputDevice").expanded);
        side.close();
        verify(!side.open);
        verify(!inSound("outputDevice").expanded);
        side.show(0);
        verify(!inSound("outputDevice").expanded, "and stays collapsed when it comes back");
    }

    function test_the_selects_list_floats_in_the_panels_window_over_the_panel_and_follows_its_scroller() {
        giveSound(controls);
        scene.height = 300;
        const scroller = showLevel("sound");
        const select = inSound("inputDevice");
        select.forceActiveFocus();
        keyClick(Qt.Key_Return);
        const list = findChild(select, "list");
        const floats = findChild(side, "floats");
        compare(list.parent, floats, "in the panel");
        const holder = floats.parent.children;
        verify(Array.from(holder).indexOf(named("tip")) > Array.from(holder).indexOf(floats) && named("tip").z >= floats.z, "under its tip");
        verify(Array.from(holder).indexOf(floats) > Array.from(holder).indexOf(findChild(side, "sheets")), "over its sheets");
        const panel = side.mapToItem(null, 0, 0, side.width, side.height);
        const at = list.mapToItem(null, 0, 0, list.width, list.height);
        verify(at.x >= panel.x && at.x + at.width <= panel.x + panel.width, "within the panel's width");
        verify(at.y >= 0 && at.y + at.height <= side.Window.window.height, "within the window's height");
        const box = findChild(select, "box");
        // space-xs between the field and the list, on whichever side it floats; Placement rounds.
        const gap = () => {
            const field = box.mapToItem(null, 0, 0, box.width, box.height);
            const top = list.mapToItem(null, 0, 0).y;
            return list.side === "below" ? top - field.y - field.height : field.y - top - list.height;
        };
        fuzzyCompare(gap(), Tokens.spaceXs, 1, "space-xs from its field");
        verify(scroller.contentY > 0, "the focus scrolled the level");
        const before = list.y;
        scroller.contentY = 0;
        verify(list.y !== before, "the list moves with the view");
        fuzzyCompare(gap(), Tokens.spaceXs, 1, "and keeps to its field");
        verify(select.expanded);
    }

    function atTopOfView(item: var, scroller: var): bool {
        return Math.abs(item.mapToItem(scroller, 0, 0).y) < 0.5 || scroller.contentY + scroller.height >= scroller.contentHeight - 0.5;
    }

    function test_revealing_a_place_from_a_closed_panel_scrolls_to_it_once_the_facet_has_laid_out() {
        giveSound(controls);
        scene.height = 360;
        const row = controls.places.battery;
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
        side.reveal(controls.places.battery);
        tryVerify(() => scroller.contentY > 0);
        side.reveal(null);
        compare(scroller.contentY, 0);
        side.reveal(controls.places.battery);
        mouseWheel(scroller, 10, 10, 0, 120);
        verify(side.revealed === null, "the wheel takes the view");
    }

    function test_a_word_leads_to_its_place_in_the_controls() {
        giveNetworks(controls);
        compare(controls.places.sound, findChild(side, "sound"));
        compare(controls.places.connections, findChild(side, "network"), "offline to the level of netz");
        compare(controls.places.doNotDisturb, control("doNotDisturb"), "nicht stören is its button");
        compare(controls.places.battery, findChild(side, "session"), "without a battery the group of the session");
        giveBattery(controls);
        compare(controls.places.battery, findChild(side, "battery"), "with one its level");
    }

    function test_revealing_a_place_after_a_pointer_open_shows_no_ring_on_its_control_until_a_key() {
        const place = controls.places.doNotDisturb;
        side.show(0, true);
        side.reveal(place);
        verify(place.activeFocus, "the focus is on the place's control all the same");
        compare(ringsShowing(place), 0, "no ring and so no tip");
        keyClick(Qt.Key_Tab);
        compare(ringsShowing(scene), 1, "the keyboard brings the ring");
    }

    function test_revealing_a_place_after_a_keyboard_open_shows_the_ring_on_its_control_at_once() {
        const place = controls.places.doNotDisturb;
        side.show(0, false);
        side.reveal(place);
        verify(place.activeFocus);
        compare(ringsShowing(place), 1);
    }

    function test_a_second_pointer_open_of_a_place_after_closing_shows_no_ring_either() {
        const place = controls.places.doNotDisturb;
        side.show(0, true);
        side.reveal(place);
        side.close();
        tryVerify(() => !side.open);
        side.show(0, true);
        side.reveal(place);
        compare(ringsShowing(place), 0);
    }

    function test_revealing_a_place_puts_the_focus_on_its_first_control() {
        giveSound(controls);
        giveNetworks(controls);
        scene.height = 360;
        side.show(0);
        side.reveal(controls.places.connections);
        verify(control("wifiSwitch").activeFocus, "the level of netz, on its switch");
        side.reveal(controls.places.sound);
        verify(inSound("outputDevice").activeFocus, "the level of ton, on its output");
    }

    function test_revealing_nicht_stoeren_puts_the_focus_on_its_button_at_the_top_of_the_view() {
        giveSound(controls);
        scene.height = 360;
        side.show(0);
        const scroller = findChild(side, "scroller");
        side.reveal(controls.places.doNotDisturb);
        const button = control("doNotDisturb");
        verify(button.activeFocus, "the button itself");
        compare(side.revealed, button, "held in view");
        tryVerify(() => atTopOfView(button, scroller));
        verify(scroller.contentY > 0);
    }

    function test_the_place_is_let_go_once_the_facet_has_laid_out() {
        giveSound(controls);
        scene.height = 360;
        side.show(0);
        side.reveal(controls.places.battery);
        verify(side.revealed !== null);
        tryVerify(() => side.revealed === null);
    }

    function test_a_branch_unfolding_after_a_jump_scrolls_itself_whole_into_view() {
        giveSound(controls);
        scene.height = 360;
        side.show(0);
        side.reveal(controls.places.battery);
        tryVerify(() => side.revealed === null);
        const scroller = findChild(side, "scroller");
        verify(scroller.contentY > 0, "the jump scrolled the view past the toggle buttons");
        const branch = control("quietBranch");
        branch.expand();
        const top = () => branch.mapToItem(scroller, 0, 0).y;
        const bottom = () => top() + branch.height;
        tryVerify(() => branch.unfolded === 1 && top() >= -0.5 && bottom() <= scroller.height + 0.5, 3000, `the lengths from ${top()} to ${bottom()} in a view ${scroller.height} high`);
    }

    function test_a_later_change_of_the_content_does_not_pull_the_view_back_to_the_place() {
        giveSound(controls);
        scene.height = 360;
        side.show(0);
        side.reveal(controls.places.battery);
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
        verify(findChild(optionRows(select)[0], "label").truncated, "in its row");
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
        compare(rows[0].isBack, true);
        compare(rows.slice(1).map(row => row.kind), ["radio", "radio"]);
        compare(rows.slice(1).map(row => row.checked), [true, false], "the current one is marked as a chosen menu option");
        waitForRendering(panel);
        mouseClick(rows[2]);
        compare(chosenOptions, [1], "a click chooses");
        verify(!level.open, "and goes back");
        verify(findChild(group, "rows").visible);
    }

    function test_the_back_row_of_a_level_has_a_chevron_back_and_a_hairline_and_the_options_start_at_the_edge() {
        const panel = showLevelPanel();
        const level = findChild(panel, "level");
        mouseClick(findChild(panel, "chooseNetwork"));
        waitForRendering(panel);
        const rows = levelRows(level);
        verify(findChild(rows[0], "chevron").visible, "a chevron pointing back");
        compare(findChild(rows[0], "chevron").rotation, Geometry.chevronBackTurn);
        verify(!findChild(rows[0], "glyph").visible, "in place of the icon");
        verify(findChild(rows[0], "hairline").visible, "a hairline below");
        compare(findChild(rows[0], "label").font.weight, Tokens.fontWeightSemibold);
        const stand = findChild(rows[1], "label").x;
        compare(stand, rows[1].inset + rows[1].checkSpace, "the options do not make room for an icon");
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

    function test_a_cut_network_name_in_netz_shows_whole_in_a_tip_under_the_pointer_and_for_keyboard_focus() {
        const long = "the guest network of the house by the lake, second floor, room two";
        const networks = giveNetworks(controls);
        networks.office.name = long;
        showLevel("network");
        verify(control("wifiSwitch").activeFocus);
        const office = findChild(rowsOf("networkRows")[1], "label");
        verify(office.truncated);
        compare(tipOver(office), long, "a resting pointer");
        compare(tipOver(findChild(rowsOf("networkRows")[0], "label")), "", "Home fits");
        mouseMove(scene, 1, 1);
        Tips.hide();
        keyClick(Qt.Key_Down);
        compare(Tips.target, null);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        verify(rowsOf("networkRows")[1].activeFocus);
        compare(Tips.target, office, "keyboard focus shows it at once");
        compare(Tips.text, long);
    }

    function test_a_cut_device_name_shows_whole_in_a_tip_over_the_select_and_over_its_option_and_scrolling_hides_it() {
        const long = "Navi 21/23 HDMI/DP Audio Controller Digital Stereo (HDMI 3) of the monitor on the left";
        giveSound(controls).speakers.description = long;
        const level = showLevel("sound");
        const select = inSound("outputDevice");
        const chosen = findChild(select, "chosen");
        compare(tipOver(chosen), long, "over the select");
        compare(findChild(named("tip"), "words").text, long, "drawn in the panel");
        level.contentY = 1;
        compare(Tips.target, null, "scrolling hides it");
        level.contentY = 0;
        mouseClick(findChild(select, "box"));
        waitForRendering(side);
        const options = optionRows(select);
        compare(tipOver(findChild(options[0], "label")), long, "over its option");
        compare(tipOver(findChild(options[1], "label")), "", "Headphones fits");
        compare(tipOver(chosen), "", "none over the box while its list is open");
    }

    function test_keyboard_focus_on_a_select_shows_its_cut_choice_at_once_and_its_options_and_pointer_focus_show_none() {
        const long = "Navi 21/23 HDMI/DP Audio Controller Digital Stereo (HDMI 3) of the monitor on the left";
        giveSound(controls).speakers.description = long;
        showLevel("sound");
        const select = inSound("outputDevice");
        verify(select.activeFocus, "the first control, from the keyboard");
        compare(Tips.target, findChild(select, "chosen"));
        compare(Tips.text, long);
        inSound("back").forceActiveFocus();
        compare(Tips.target, null, "the focus leaving takes it away");
        select.forceActiveFocus();
        compare(Tips.target, findChild(select, "chosen"), "and coming back by keyboard brings it again");
        keyClick(Qt.Key_Return);
        verify(select.expanded);
        const cut = findChild(optionRows(select)[0], "label");
        compare(Tips.target, cut, "open, the focused option shows its cut words");
        keyClick(Qt.Key_Down);
        compare(Tips.target, null, "Headphones fits");
        keyClick(Qt.Key_Escape);
        side.close();
        tryVerify(() => !side.open);
        side.show(0, true);
        side.reveal(findChild(controls, "sound"));
        verify(select.activeFocus);
        compare(Tips.target, null, "focus a pointer gave shows none");
    }

    function test_the_cut_word_or_state_of_a_quick_setting_shows_whole_in_a_tip_and_keyboard_focus_shows_neither() {
        const long = "until the end of the meeting in the room by the lake, second floor";
        showSettled(0);
        const quiet = control("doNotDisturb");
        quiet.value = long;
        compare(tipOver(findChild(quiet, "state")), long, "its state");
        compare(tipOver(findChild(quiet, "word")), "", "nicht stören fits");
        quiet.text = "do not disturb, not even with the quiet ones";
        compare(tipOver(findChild(quiet, "word")), "do not disturb, not even with the quiet ones", "its word");
        mouseMove(scene, 1, 1);
        Tips.hide();
        quiet.forceActiveFocus();
        compare(Tips.target, null);
    }

    function test_the_cut_words_of_a_row_show_whole_in_a_tip_and_keyboard_focus_on_its_control_shows_none() {
        const long = "the density of every surface of the shell, from comfortable to compact";
        showLevel("display");
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

    // bluetooth (states.md:237–242): with an adapter, its tile says how Bluetooth stands.
    function test_the_bluetooth_tile_stands_with_an_adapter_and_says_funk_gesperrt_aus_the_device_n_verbunden_or_an() {
        showSettled(0);
        const tile = control("bluetoothTile");
        verify(!tile.visible, "without an adapter");
        const bluetooth = giveBluetooth(controls);
        verify(tile.visible);
        compare(tile.name, "bluetooth");
        compare(tile.glyph, "bluetooth");
        compare(stateOf("bluetoothTile"), "Headphones", "the one device connected");
        compare(tile.Accessible.name, "bluetooth, Headphones");
        bluetooth.speaker.connected = true;
        compare(stateOf("bluetoothTile"), "2 verbunden", "how many, with more than one");
        bluetooth.speaker.connected = false;
        bluetooth.headphones.connected = false;
        compare(stateOf("bluetoothTile"), "an", "on, with none connected");
        bluetooth.headphones.connected = true;
        bluetooth.adapter.enabled = false;
        compare(stateOf("bluetoothTile"), "aus", "off, before the devices");
        bluetooth.adapter.state = Controls.Blocked;
        compare(stateOf("bluetoothTile"), "funk gesperrt", "blocked, before off");
        compare(tile.Accessible.name, "bluetooth, funk gesperrt");
        controls.bluetooth = null;
        verify(!tile.visible, "the adapter gone");
    }

    // The level of bluetooth (states.md:231–233, :260–271): the back row, then its switch, which takes the focus.
    function test_the_bluetooth_level_starts_with_its_switch_which_takes_the_focus_and_switches_the_adapter() {
        const bluetooth = giveBluetooth(controls);
        showSettled(0);
        control("bluetoothTile").forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Return);
        const level = findChild(controls, "bluetooth");
        verify(level.open);
        const back = findChild(level, "back");
        compare(back.text, "zurück · bluetooth");
        const toggle = control("bluetoothSwitch");
        verify(toggle instanceof Toggle, "a toggle switch, which acts at once");
        verify(toggle.activeFocus, "the focus on it at once");
        compare(toggle.label, "bluetooth");
        verify(toggle.checked, "on, as the adapter is");
        waitForFrame(side);
        compare(toggle.mapToItem(level, 0, 0).y, back.mapToItem(level, 0, 0).y + back.height + Tokens.spaceM, "first after the back row");
        keyClick(Qt.Key_Space);
        compare(bluetoothSwitches, [false]);
        verify(!bluetooth.adapter.enabled);
        verify(!toggle.checked);
        verify(!control("deviceRows").visible, "off, no devices");
        bluetooth.adapter.enabled = true;
        verify(toggle.checked, "a change from elsewhere shows");
        verify(control("deviceRows").visible);
        bluetoothTakes = false;
        keyClick(Qt.Key_Space);
        compare(bluetoothSwitches, [false, false]);
        verify(toggle.checked, "a switch the system did not take springs back");
    }

    function test_a_blocked_adapter_greys_the_bluetooth_switch_which_says_why() {
        const bluetooth = giveBluetooth(controls);
        bluetooth.adapter.enabled = false;
        bluetooth.adapter.state = Controls.Blocked;
        showLevel("bluetooth");
        const toggle = control("bluetoothSwitch");
        verify(toggle.disabled);
        verify(findChild(toggle, "why").visible);
        compare(findChild(toggle, "why").text, "funk gesperrt");
        toggle.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(bluetoothSwitches, []);
        verify(!toggle.checked);
    }

    function test_while_bluetooth_is_on_the_paired_devices_stand_right_below_its_switch_with_their_state_and_battery() {
        const bluetooth = giveBluetooth(controls);
        const level = showLevel("bluetooth");
        const toggle = control("bluetoothSwitch");
        const list = control("deviceRows");
        compare(list.mapToItem(level, 0, 0).y, toggle.mapToItem(level, 0, 0).y + toggle.height + Tokens.spaceM, "directly below the switch, without a heading");
        const rows = rowsOf("deviceRows");
        compare(rows.map(row => row.text), ["Headphones", "Speaker", "Mouse", "neues gerät koppeln"]);
        compare(rows.map(row => row.kind), ["item", "item", "item", "item"], "no option to choose one of");
        const states = rows.slice(0, 3).map(row => findChild(row, "state"));
        compare(states.map(tag => tag.word), ["verbunden", "getrennt", "getrennt"]);
        compare(states.map(tag => tag.status), ["info", "", ""]);
        compare(rows[0].Accessible.name, "Headphones, verbunden, akku 80%");
        const battery = findChild(rows[0], "battery");
        verify(battery.visible);
        compare(battery.text, "80%");
        compare(battery.font.features, { "tnum": 1 }, "in tabular figures");
        compare(battery.font.weight, Tokens.fontWeightMedium, "a number to read as data");
        verify(!findChild(rows[1], "battery").visible, "where the device tells none");
        const end = findChild(rows[0], "end");
        compare(end.x + end.width, rows[0].width, "state and battery at the row's end");
        bluetooth.adapter.enabled = false;
        verify(!list.visible, "off, the devices are gone");
    }

    function test_with_more_than_five_devices_five_stand_connected_first_and_alle_geräte_opens_all_in_place() {
        giveBluetooth(controls);
        givePairedDevices(controls, 7);
        const level = showLevel("bluetooth");
        compare(rowsOf("deviceRows").map(row => row.text), ["Headphones", "Device 7", "Speaker", "Mouse", "Device 4", "alle geräte …", "neues gerät koppeln"]);
        verify(control("allDevices").opensLevel, "its chevron says it goes on");
        verify(!control("bluetoothDevices").open, "no list of all yet");
        mouseClick(control("allDevices"));
        const all = control("bluetoothDevices");
        verify(all.open);
        compare(rowsOf("bluetoothDevices").map(row => row.text), ["zurück · geräte", "Headphones", "Speaker", "Mouse", "Device 4", "Device 5", "Device 6", "Device 7", "neues gerät koppeln"]);
        verify(!control("deviceRows").visible && !control("bluetoothSwitch").visible, "in place of the level's rows");
        verify(findChild(level, "back").visible, "under the level's own back row");
        verify(rowsOf("bluetoothDevices")[1].activeFocus, "the focus on the first device");
        keyClick(Qt.Key_Escape);
        verify(!all.open);
        verify(control("allDevices").activeFocus, "back on the row that opened it");
        verify(level.open);
    }

    // `.rk-rows` and `.rk-in-back` have no room before or after (rekta.css:77–78, :1131–1135): the rows, the switch, the
    // back rows and the list of all start at the content's edge, and the rows end at it.
    function test_the_rows_of_netz_and_bluetooth_and_their_lists_of_all_stand_at_the_contents_edges_data() {
        return [
            { tag: "netz", level: "network", toggle: "wifiSwitch", list: "networkRows", opener: "allNetworks", all: "networks" },
            { tag: "bluetooth", level: "bluetooth", toggle: "bluetoothSwitch", list: "deviceRows", opener: "allDevices", all: "bluetoothDevices" }
        ];
    }

    function test_the_rows_of_netz_and_bluetooth_and_their_lists_of_all_stand_at_the_contents_edges(data) {
        giveNetworks(controls);
        giveBluetooth(controls);
        givePairedDevices(controls, 7);
        const level = showLevel(data.level);
        const ground = findChild(side, "ground");
        const left = item => item.mapToItem(ground, 0, 0).x;
        const right = item => item.mapToItem(ground, item.width, 0).x;
        const contentRight = Tokens.spaceM + side.contentWidth;
        const back = findChild(level, "back");
        compare(left(back), Tokens.spaceM);
        compare(left(control(data.toggle)), Tokens.spaceM, "the switch");
        for (const row of rowsOf(data.list)) {
            compare(left(findChild(row, "label")), Tokens.spaceM, `${row.text}: its words at the edge`);
            compare(right(row), contentRight, `${row.text}: to the edge`);
        }
        mouseClick(control(data.opener));
        waitForFrame(side);
        const [allBack, ...allRows] = rowsOf(data.all);
        compare(left(findChild(allBack, "chevron")), left(findChild(back, "chevron")), "the back row of the list of all, its chevron under the level's");
        for (const row of allRows)
            compare(left(findChild(row, "label")), Tokens.spaceM, `${row.text} in the list of all: its words at the edge`);
    }

    function test_up_to_five_devices_have_no_alle_geräte_row() {
        giveBluetooth(controls);
        givePairedDevices(controls, 5);
        showLevel("bluetooth");
        compare(rowsOf("deviceRows").length, 6, "five devices and neues gerät koppeln");
        verify(!control("allDevices").visible);
    }

    // A connection that fails shows the state from before, as Quickshell reports no cause.
    function test_a_press_connects_or_disconnects_and_a_device_on_its_way_takes_no_press() {
        const bluetooth = giveBluetooth(controls);
        showLevel("bluetooth");
        const row = index => rowsOf("deviceRows")[index];
        const tagOf = index => findChild(row(index), "state");
        mouseClick(row(1));
        compare(bluetooth.speaker.calls, ["connect"]);
        verify(findChild(controls, "bluetooth").open, "the level stays");
        compare(tagOf(1).word, "wartet");
        compare(tagOf(1).status, "warning");
        mouseClick(row(1));
        compare(bluetooth.speaker.calls, ["connect"], "one on its way waits for the answer");
        bluetooth.speaker.connected = true;
        bluetooth.speaker.state = Controls.Connected;
        compare(tagOf(1).word, "verbunden");
        compare(tagOf(1).status, "info");
        compare(stateOf("bluetoothTile"), "2 verbunden", "the tile follows");
        waitForFrame(side);
        mouseClick(row(0));
        compare(bluetooth.headphones.calls, ["disconnect"]);
        compare(tagOf(0).word, "wartet");
        bluetooth.headphones.state = Controls.Connected;
        compare(tagOf(0).word, "verbunden", "a disconnection that fails shows the state from before");
        mouseClick(row(2));
        compare(bluetooth.mouse.calls, ["connect"]);
        bluetooth.mouse.state = Controls.Disconnected;
        compare(tagOf(2).word, "getrennt", "so does a connection that fails");
        bluetooth.mouse.pairing = true;
        compare(tagOf(2).word, "wartet", "pairing waits too");
        mouseClick(row(2));
        compare(bluetooth.mouse.calls, ["connect"], "and takes no press either");
    }

    // The host closes the panel and opens System Settings on pairingAsked: the shell has no BlueZ agent.
    function test_neues_gerät_koppeln_stands_last_and_asks_for_system_settings_to_pair_a_device() {
        giveBluetooth(controls);
        givePairedDevices(controls, 7);
        showLevel("bluetooth");
        const pair = control("pairDevice");
        compare(rowsOf("deviceRows").slice(-1)[0], pair, "the last row, after alle geräte …");
        mouseClick(pair);
        compare(pairingAsked, 1);
        mouseClick(control("allDevices"));
        waitForFrame(side);
        const inAll = control("pairDeviceInAll");
        compare(rowsOf("bluetoothDevices").slice(-1)[0], inAll, "and last in the list of all");
        mouseClick(inAll);
        compare(pairingAsked, 2);
    }

    function test_bluetooth_works_from_the_keyboard() {
        const bluetooth = giveBluetooth(controls);
        showSettled(0);
        control("bluetoothTile").forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Return);
        verify(control("bluetoothSwitch").activeFocus);
        keyClick(Qt.Key_Down);
        verify(rowsOf("deviceRows")[0].activeFocus, "↓ from the switch to the first device");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(bluetooth.speaker.calls, ["connect"], "Enter connects");
        verify(rowsOf("deviceRows")[1].activeFocus, "the focus stays");
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Space);
        compare(bluetooth.headphones.calls, ["disconnect"], "Space too");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Tab);
        verify(control("pairDevice").activeFocus, "Tab to neues gerät koppeln");
        keyClick(Qt.Key_Return);
        compare(pairingAsked, 1);
        keyClick(Qt.Key_Left);
        verify(!findChild(controls, "bluetooth").open, "← goes back");
        verify(control("bluetoothTile").activeFocus, "to the tile");
        verify(side.open);
    }

    // Qt leaves the focus on a hidden item: a row that hides while it holds the focus hands it on.
    function test_bluetooth_off_from_elsewhere_closes_the_list_of_all_devices_and_hands_the_focus_to_the_switch() {
        giveBluetooth(controls);
        givePairedDevices(controls, 7);
        showLevel("bluetooth");
        mouseClick(control("allDevices"));
        const all = control("bluetoothDevices");
        verify(rowsOf("bluetoothDevices")[1].activeFocus);
        controls.bluetooth.enabled = false;
        verify(!all.open, "the list of all closes");
        tryVerify(() => control("bluetoothSwitch").activeFocus, 1000, "the focus on the switch, not on a hidden row");
        verify(findChild(controls, "bluetooth").open, "the level stays");
    }

    // The devices are built anew when one connects, the connected first; the focus on one goes back into the level.
    function test_a_focused_device_row_that_is_built_anew_leaves_the_focus_in_the_level() {
        const bluetooth = giveBluetooth(controls);
        const level = showLevel("bluetooth");
        rowsOf("deviceRows")[2].forceActiveFocus(Qt.TabFocusReason);
        bluetooth.mouse.connected = true;
        compare(rowsOf("deviceRows").map(row => row.text).slice(0, 3), ["Headphones", "Mouse", "Speaker"], "connected first");
        tryVerify(() => level.isMine(side.Window.activeFocusItem) && side.Window.activeFocusItem.visible, 1000, "the focus in the level");
        keyClick(Qt.Key_Escape);
        verify(!level.open, "so Escape leaves the level");
        verify(side.open, "and not the panel");
    }

    function test_without_an_adapter_the_bluetooth_tile_and_its_switch_are_gone() {
        giveBluetooth(controls);
        showLevel("bluetooth");
        verify(control("bluetoothSwitch").visible);
        controls.bluetooth = null;
        controls.bluetoothDevices = [];
        verify(!control("bluetoothTile").visible, "no tile");
        verify(!control("bluetoothSwitch").visible, "and no switch that would act on nothing");
    }

    function test_a_long_device_name_is_cut_before_its_state() {
        const bluetooth = giveBluetooth(controls);
        bluetooth.headphones.name = "Navi 21/23 HDMI/DP Audio Controller Digital Stereo Headphones of the guest room";
        showLevel("bluetooth");
        const row = rowsOf("deviceRows")[0];
        const label = findChild(row, "label");
        verify(label.truncated);
        compare(label.x + label.width, findChild(row, "end").x - Tokens.spaceS);
    }

    // netz (states.md:237–242): with a wireless or a wired device, its tile says how the network stands.
    function test_the_netz_tile_stands_with_a_wireless_or_a_wired_device_and_is_gone_without_both() {
        showSettled(0);
        const tile = control("networkTile");
        verify(!tile.visible, "without a network device");
        controls.wiredDevice = createTemporaryObject(wiredDeviceComponent, testCase);
        verify(tile.visible, "with a cable alone");
        controls.wiredDevice = null;
        verify(!tile.visible);
        giveNetworks(controls);
        verify(tile.visible, "with wireless alone");
        compare(tile.name, "netz");
        compare(tile.glyph, "wireless");
    }

    function test_the_netz_tile_says_wartet_the_joined_network_kabel_aus_or_getrennt() {
        const networks = giveNetworks(controls);
        controls.wiredDevice = createTemporaryObject(wiredDeviceComponent, testCase);
        showSettled(0);
        const tile = control("networkTile");
        compare(stateOf("networkTile"), "Home", "the joined network, before the cable");
        compare(tile.Accessible.name, "netz, Home");
        networks.office.stateChanging = true;
        compare(stateOf("networkTile"), "wartet", "on its way, before all else");
        networks.office.stateChanging = false;
        networks.home.connected = false;
        compare(stateOf("networkTile"), "kabel", "without a joined network, the cable");
        controls.networking.wifiEnabled = false;
        compare(stateOf("networkTile"), "kabel", "the cable, before wireless off");
        controls.wiredDevice.connected = false;
        compare(stateOf("networkTile"), "aus", "wireless off");
        compare(tile.Accessible.name, "netz, aus");
        controls.networking.wifiEnabled = true;
        compare(stateOf("networkTile"), "getrennt", "on, with nothing joined");
        controls.networking.wifiEnabled = false;
        controls.wifiDevice = null;
        compare(stateOf("networkTile"), "getrennt", "aus speaks of the wireless switch: with a cable alone it is getrennt");
    }

    // The level of netz (states.md:231–233, :260–271): the back row, then the wlan switch, which takes the focus.
    function test_the_netz_level_starts_with_the_wlan_switch_which_takes_the_focus_and_switches_wireless() {
        giveNetworks(controls);
        showSettled(0);
        control("networkTile").forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Return);
        const level = findChild(controls, "network");
        verify(level.open);
        const back = findChild(level, "back");
        compare(back.text, "zurück · netz");
        const toggle = control("wifiSwitch");
        verify(toggle instanceof Toggle, "a toggle switch, which acts at once");
        verify(toggle.activeFocus, "the focus on it at once");
        compare(toggle.label, "wlan");
        verify(toggle.checked);
        waitForFrame(side);
        compare(toggle.mapToItem(level, 0, 0).y, back.mapToItem(level, 0, 0).y + back.height + Tokens.spaceM, "first after the back row");
        mouseClick(toggle);
        compare(wifiSwitches, [false]);
        verify(!toggle.checked);
        verify(!control("networkRows").visible, "without wireless there are no networks");
        wifiTakes = false;
        mouseClick(toggle);
        compare(wifiSwitches, [false, true]);
        verify(!toggle.checked, "a switch the system did not take springs back");
        controls.networking.wifiEnabled = true;
        verify(toggle.checked, "a change from elsewhere shows");
        verify(control("networkRows").visible);
    }

    function test_a_blocked_radio_greys_the_wlan_switch_which_says_why() {
        giveNetworks(controls);
        controls.networking.wifiHardwareEnabled = false;
        showLevel("network");
        const toggle = control("wifiSwitch");
        verify(toggle.disabled);
        compare(toggle.disabledReason, "funk gesperrt");
        verify(findChild(toggle, "why").visible);
        mouseClick(toggle);
        compare(wifiSwitches, []);
    }

    // Up to five networks stand right below the switch; all of them are a list chosen in place (states.md:203–214).
    function test_with_eight_networks_the_five_strongest_stand_below_the_switch_and_alle_netze_opens_all_in_place() {
        giveNetworks(controls);
        const level = showLevel("network");
        const toggle = control("wifiSwitch");
        const list = control("networkRows");
        compare(list.mapToItem(level, 0, 0).y, toggle.mapToItem(level, 0, 0).y + toggle.height + Tokens.spaceM, "directly below the switch, without a heading");
        compare(rowsOf("networkRows").map(row => row.text), ["Home", "Office", "Guest", "Neighbour", "Library", "alle netze …"]);
        verify(control("allNetworks").opensLevel, "its chevron says it goes on");
        verify(!control("networks").open, "no list of all yet");
        mouseClick(control("allNetworks"));
        const all = control("networks");
        verify(all.open);
        compare(rowsOf("networks").map(row => row.text), ["zurück · netze", "Home", "Office", "Guest", "Neighbour", "Library", "Cafe", "Shop", "Hotel"]);
        verify(!list.visible && !toggle.visible, "in place of the level's rows");
        const back = findChild(level, "back");
        verify(back.visible, "under the level's own back row");
        waitForFrame(side);
        compare(all.mapToItem(level, 0, 0).y, back.mapToItem(level, 0, 0).y + back.height + Tokens.spaceM, "where the switch stood");
        verify(rowsOf("networks")[1].activeFocus, "the focus on the first network");
        keyClick(Qt.Key_Escape);
        verify(!all.open);
        verify(control("allNetworks").activeFocus, "back on the row that opened it");
        verify(level.open);
    }

    function test_up_to_five_networks_have_no_alle_netze_row() {
        const networks = giveNetworks(controls);
        networks.device.networks.values = [networks.home, networks.office, networks.guest, networks.neighbour, networks.library];
        showLevel("network");
        compare(rowsOf("networkRows").length, 5);
        verify(!control("allNetworks").visible);
    }

    function test_the_list_of_all_networks_is_closed_when_the_level_opens_again() {
        giveNetworks(controls);
        const level = showLevel("network");
        mouseClick(control("allNetworks"));
        verify(control("networks").open);
        level.leave();
        side.reveal(level);
        verify(!control("networks").open, "the level opens on its own rows");
        verify(control("wifiSwitch").activeFocus);
    }

    function test_a_network_row_tells_what_it_is_and_its_signal_in_percent() {
        giveNetworks(controls);
        showLevel("network");
        const rows = rowsOf("networkRows");
        compare(findChild(rows[0], "signal").text, "90%");
        verify(findChild(rows[0], "leave").visible, "the joined one can be left");
        verify(!findChild(rows[0], "kinds").visible, "the joined one needs no more words");
        compare(findChild(rows[1], "kinds").text, "gesichert · bekannt");
        compare(findChild(rows[2], "kinds").text, "");
        compare(findChild(rows[3], "kinds").text, "gesichert");
        verify(!findChild(rows[1], "leave").visible);
        compare(rows[1].Accessible.name, "Office, gesichert · bekannt, signal 70%");
    }

    // scanWanted: the system scans only while the networks show, the level of netz standing with wireless on.
    function test_the_scan_runs_only_while_the_level_of_netz_stands_with_wireless_on() {
        giveNetworks(controls);
        showSettled(0);
        compare(scans, [], "not for the tile alone");
        const tile = control("networkTile");
        tile.forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Return);
        compare(scans, [true], "the level opens with wireless on");
        waitForFrame(side);
        mouseClick(control("allNetworks"));
        verify(control("networks").open);
        compare(scans, [true], "the list of all goes on with the same scan");
        keyClick(Qt.Key_Escape);
        keyClick(Qt.Key_Escape);
        verify(tile.activeFocus);
        compare(scans, [true, false], "closing the level stops it");
        keyClick(Qt.Key_Return);
        compare(scans, [true, false, true]);
        controls.networking.wifiEnabled = false;
        compare(scans, [true, false, true, false], "wlan off stops it");
        controls.networking.wifiEnabled = true;
        compare(scans, [true, false, true, false, true], "wlan on starts it again while the level stands");
        const device = controls.wifiDevice;
        controls.wifiDevice = null;
        compare(scans, [true, false, true, false, true, false], "the wireless device gone stops it");
        controls.wifiDevice = device;
        compare(scans.length, 7);
        side.close();
        tryVerify(() => !side.visible);
        compare(scans, [true, false, true, false, true, false, true, false], "closing the panel stops it");
        controls.networking.wifiEnabled = false;
        showLevel("network");
        compare(scans.length, 8, "a level opened with wireless off scans for nothing");
    }

    function test_the_networks_keep_their_order_while_the_list_shows_though_the_signal_moves() {
        const networks = giveNetworks(controls);
        const level = showLevel("network");
        networks.shop.signalStrength = 0.95;
        compare(rowsOf("networkRows").map(row => row.text).slice(0, 2), ["Home", "Office"]);
        compare(findChild(rowsOf("networkRows")[0], "signal").text, "90%");
        level.leave();
        side.reveal(level);
        compare(rowsOf("networkRows")[0].text, "Shop", "closed and opened again it is ranked anew");
    }

    function test_a_known_or_open_network_joins_at_once() {
        const networks = giveNetworks(controls);
        showLevel("network");
        const rows = rowsOf("networkRows");
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
        showLevel("network");
        mouseClick(rowsOf("networkRows")[3]);
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
        verify(rowsOf("networkRows")[3].activeFocus, "the focus goes back to the row");
    }

    function test_the_tip_of_the_password_sheets_close_button_is_drawn_over_the_sheet() {
        giveNetworks(controls);
        showLevel("network");
        mouseClick(rowsOf("networkRows")[3]);
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
        showLevel("network");
        mouseClick(rowsOf("networkRows")[3]);
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
        verify(findChild(controls, "network").open, "and the level");
        compare(networks.neighbour.calls, []);
        compare(passwordsSent, []);
    }

    function test_an_untouched_password_sheet_leaves_without_asking() {
        giveNetworks(controls);
        showLevel("network");
        mouseClick(rowsOf("networkRows")[3]);
        keyClick(Qt.Key_Escape);
        verify(!sheet().open);
        verify(side.open);
        verify(findChild(controls, "network").open);
    }

    function test_the_sheet_closes_when_its_network_goes() {
        const networks = giveNetworks(controls);
        showLevel("network");
        mouseClick(rowsOf("networkRows")[3]);
        typeText("pw");
        networks.device.networks.values = networks.device.networks.values.filter(network => network !== networks.neighbour);
        tryVerify(() => !sheet().open);
        compare(passwordsSent, []);
    }

    function test_the_sheet_goes_with_the_panel() {
        giveNetworks(controls);
        showLevel("network");
        mouseClick(rowsOf("networkRows")[3]);
        verify(sheet().open);
        side.close();
        tryVerify(() => !side.visible);
        tryVerify(() => !sheet().open);
    }

    // Qt hands the pointer handlers under a sheet's shading the press all the same.
    function test_a_press_on_the_password_sheet_or_its_shading_reaches_nothing_of_the_level_under_it() {
        const networks = giveNetworks(controls);
        const level = showLevel("network");
        for (const name of ["back row", "Office"]) {
            if (!sheet().open)
                mouseClick(rowsOf("networkRows")[3]);
            verify(sheet().open, name);
            const under = name === "Office" ? rowsOf("networkRows")[1] : findChild(level, "back");
            const at = under.mapToItem(scene, Tokens.spaceL, under.height / 2);
            mouseClick(scene, at.x, at.y);
            verify(level.open, `${name}: the level stays`);
        }
        compare(networks.office.calls, [], "Office was not pressed");
        compare(joined, []);
    }

    // A list built anew, as when a network comes, drops the rows it had; the focus on one goes back into the level.
    function test_a_focused_network_row_that_is_built_anew_leaves_the_focus_in_the_level() {
        const networks = giveNetworks(controls);
        const level = showLevel("network");
        rowsOf("networkRows")[1].forceActiveFocus(Qt.TabFocusReason);
        const near = createTemporaryObject(networkComponent, testCase, { name: "Near", signalStrength: 0.8, security: 3 });
        networks.device.networks.values = [...networks.device.networks.values, near];
        tryVerify(() => level.isMine(side.Window.activeFocusItem) && side.Window.activeFocusItem.visible, 1000, "the focus in the level");
        keyClick(Qt.Key_Escape);
        verify(!level.open, "so Escape leaves the level");
        verify(side.open, "and not the panel");
    }

    function test_a_failed_connection_says_why_in_its_row_until_the_next_attempt() {
        const networks = giveNetworks(controls);
        showLevel("network");
        mouseClick(rowsOf("networkRows")[1]);
        networks.office.stateChanging = false;
        networks.office.connectionFailed(Controls.WifiAuthTimeout);
        const failure = findChild(rowsOf("networkRows")[1], "failure");
        verify(failure.visible);
        compare(failure.word, "zeitüberschreitung");
        compare(failure.status, "error");
        verify(!findChild(rowsOf("networkRows")[1], "kinds").visible, "the cause takes the words' place");
        compare(rowsOf("networkRows")[1].Accessible.name, "Office, zeitüberschreitung, gesichert · bekannt, signal 70%");
        mouseClick(rowsOf("networkRows")[1]);
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
        showLevel("network");
        const home = rowsOf("networkRows")[0];
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
        showSettled(0);
        control("networkTile").forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Return);
        verify(control("wifiSwitch").activeFocus);
        keyClick(Qt.Key_Down);
        verify(rowsOf("networkRows")[0].activeFocus, "↓ from the switch to the first network");
        keyClick(Qt.Key_Down);
        verify(findChild(rowsOf("networkRows")[0], "leave").activeFocus, "the joined network's button comes before the next row");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(networks.office.calls, ["connect"], "Enter joins a known network");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        verify(rowsOf("networkRows")[4].activeFocus);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        verify(control("networks").open, "alle netze … opens the list of all");
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
        verify(control("allNetworks").activeFocus, "back where it began");
    }

    function test_after_trennen_the_row_does_not_say_it_is_connecting_and_bluetooth_says_the_same_word() {
        const networks = giveNetworks(controls);
        const bluetooth = giveBluetooth(controls);
        showLevel("network");
        mouseClick(findChild(rowsOf("networkRows")[0], "leave"));
        compare(networks.home.calls, ["disconnect"]);
        compare(stateOf("networkTile"), "wartet");
        compare(findChild(rowsOf("networkRows")[0], "joining").word, "wartet");
        showLevel("bluetooth");
        bluetooth.speaker.connect();
        compare(findChild(rowsOf("deviceRows")[1], "state").word, "wartet");
    }

    function test_the_cause_for_a_lost_connection_is_not_the_word_for_an_idle_network() {
        const networks = giveNetworks(controls);
        showLevel("network");
        networks.home.connected = false;
        networks.home.connectionFailed(Controls.WifiClientDisconnected);
        compare(stateOf("networkTile"), "getrennt");
        const cause = findChild(rowsOf("networkRows").find(row => row.text === "Home"), "failure");
        compare(cause.word, "verbindung abgebrochen");
        verify(cause.word !== stateOf("networkTile"));
    }

    function test_an_empty_list_says_what_is_empty_while_the_scan_runs() {
        const networks = giveNetworks(controls);
        networks.device.networks.values = [];
        showLevel("network");
        const hint = control("noNetworks");
        verify(hint.visible);
        compare(hint.text, "keine netze gefunden, die suche läuft");
        verify(findChild(hint, "line").visible, "on Rekta's empty hairline");
        verify(control("networkRows").height > 0, "the list is not empty");
        compare(scans, [true]);
        networks.device.networks.values = [networks.home];
        waitForRendering(side);
        verify(!hint.visible, "the first network takes its place");
    }

    function test_networks_that_come_or_go_while_the_list_shows_leave_the_others_in_their_place() {
        const networks = giveNetworks(controls);
        showLevel("network");
        networks.shop.signalStrength = 0.95;
        const faraway = createTemporaryObject(networkComponent, testCase, { name: "Faraway", signalStrength: 0.05, security: 3 });
        const near = createTemporaryObject(networkComponent, testCase, { name: "Near", signalStrength: 0.8, security: 3 });
        networks.device.networks.values = [...networks.device.networks.values, faraway, near];
        compare(controls.ranked.map(network => network.name), ["Home", "Office", "Guest", "Neighbour", "Library", "Cafe", "Shop", "Hotel", "Near", "Faraway"]);
        networks.device.networks.values = networks.device.networks.values.filter(network => network !== networks.office);
        compare(controls.ranked.map(network => network.name).slice(0, 3), ["Home", "Guest", "Neighbour"], "a gone network drops out in place");
    }

    // Qt leaves the focus on a hidden item: a row that hides while it holds the focus hands it on.
    function test_wlan_off_from_elsewhere_closes_the_list_of_all_networks_and_hands_the_focus_to_the_switch() {
        giveNetworks(controls);
        controls.wiredDevice = createTemporaryObject(wiredDeviceComponent, testCase);
        const level = showLevel("network");
        mouseClick(control("allNetworks"));
        const all = control("networks");
        verify(rowsOf("networks")[1].activeFocus);
        controls.networking.wifiEnabled = false;
        verify(!all.open, "the list of all closes");
        verify(!control("networkRows").visible, "the networks are gone");
        tryVerify(() => control("wifiSwitch").activeFocus, 1000, "the focus on the switch, not on a hidden row");
        verify(level.open, "the level stays");
        findChild(level, "back").forceActiveFocus(Qt.TabFocusReason);
        controls.networking.wifiEnabled = true;
        controls.networking.wifiEnabled = false;
        settleLater();
        verify(findChild(level, "back").activeFocus, "a focus that still shows stays");
        const opener = named("opener");
        opener.forceActiveFocus(Qt.TabFocusReason);
        opener.visible = false;
        controls.networking.wifiEnabled = true;
        controls.networking.wifiEnabled = false;
        settleLater();
        verify(opener.activeFocus, "a hidden focus outside the level is not the level's to move");
        opener.visible = true;
        controls.networking.wifiEnabled = true;
        rowsOf("networkRows")[1].forceActiveFocus(Qt.TabFocusReason);
        controls.wifiDevice = null;
        verify(!control("networkRows").visible && !control("wifiSwitch").visible, "the wireless device gone: no switch, no networks");
        tryVerify(() => findChild(level, "back").activeFocus, 1000, "the focus on the back row, the level's first control left");
    }

    // Another facet closed the level and left the focus where it was.
    function test_wlan_off_while_the_level_of_netz_is_closed_draws_no_focus_into_it() {
        giveNetworks(controls);
        const level = showLevel("network");
        rowsOf("networkRows")[1].forceActiveFocus(Qt.TabFocusReason);
        findChild(side, "pivot").select(1);
        verify(!level.open);
        controls.networking.wifiEnabled = false;
        settleLater();
        verify(!findChild(level, "back").activeFocus && !control("wifiSwitch").activeFocus, "the closed level takes no focus");
    }

    function test_kabel_stands_last_in_the_level_of_netz_with_its_state_as_a_status_word() {
        giveNetworks(controls);
        controls.wiredDevice = createTemporaryObject(wiredDeviceComponent, testCase);
        const level = showLevel("network");
        const state = control("wiredState");
        const row = rowOf(state);
        const list = control("networkRows");
        compare(findChild(row, "words").text, "kabel");
        compare(row.mapToItem(level, 0, 0).y, list.mapToItem(level, 0, list.height).y + Tokens.spaceM, "below the networks");
        compare(state.word, "verbunden");
        compare(state.status, "info");
        controls.wiredDevice.connected = false;
        compare(state.word, "getrennt");
        controls.wiredDevice = null;
        verify(!row.visible, "without a wired device the row is gone");
    }

    function test_without_networkmanager_netz_has_no_tile_and_a_cable_alone_no_wlan_switch() {
        showSettled(0);
        verify(!control("networkTile").visible);
        controls.wiredDevice = createTemporaryObject(wiredDeviceComponent, testCase);
        const level = showLevel("network");
        verify(!control("wifiSwitch").visible, "no wireless device, no switch");
        verify(!control("networkRows").visible);
        verify(findChild(level, "back").activeFocus, "the focus on the back row then");
    }

    // Each step up takes its key (rekta.js:1987–1992): none reaches what lies behind the panel; Escape on the tile
    // closes the panel, ← on it stays in the grid.
    function test_escape_left_and_the_back_rows_go_from_the_list_of_all_up_to_the_level_and_then_to_the_tile_data() {
        const areas = [
            { tag: "netz", tile: "networkTile", level: "network", opener: "allNetworks", all: "networks" },
            { tag: "bluetooth", tile: "bluetoothTile", level: "bluetooth", opener: "allDevices", all: "bluetoothDevices" }
        ];
        return areas.reduce((ways, area) => ways.concat(["Escape", "Left", "back"].map(way => Object.assign({}, area, { tag: `${area.tag} by ${way}`, way }))), []);
    }

    function test_escape_left_and_the_back_rows_go_from_the_list_of_all_up_to_the_level_and_then_to_the_tile(data) {
        giveNetworks(controls);
        giveBluetooth(controls);
        givePairedDevices(controls, 7);
        showSettled(0);
        const tile = control(data.tile);
        const level = findChild(controls, data.level);
        const all = control(data.all);
        tile.forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Return);
        control(data.opener).forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Return);
        verify(all.open && level.open);
        const up = list => {
            if (data.way !== "back") {
                keyClick(data.way === "Escape" ? Qt.Key_Escape : Qt.Key_Left);
                return;
            }
            waitForFrame(side);
            mouseClick(findChild(list, "back"));
        };
        up(all);
        verify(!all.open, "first the list of all");
        verify(level.open, "the level stays");
        verify(control(data.opener).activeFocus, "the focus on the row that opened the list");
        up(level);
        verify(!level.open, "then the level");
        verify(tile.activeFocus, "the focus on its tile");
        compare(keysPast, [], "each key was taken on its way up");
        keyClick(data.way === "Left" ? Qt.Key_Left : Qt.Key_Escape);
        compare(keysPast, [], "and on the tile");
        if (data.way === "Left")
            verify(side.open && side.within(control("areas"), side.Window.activeFocusItem), "← on the tile is the grid's: the focus stays among the tiles");
        else
            verify(!side.open, "Escape on the tile closes the panel");
    }

    // "offline" leads to the level of netz, as the host's openAt does for the word and the banner's remedy.
    function test_offline_opens_the_level_of_netz_with_the_focus_on_wlan_and_without_a_network_device_the_top() {
        giveSound(controls);
        giveNetworks(controls);
        const level = findChild(controls, "network");
        compare(controls.places.connections, level);
        side.show(0, false);
        side.reveal(controls.places.connections);
        verify(level.open, "the level of netz stands");
        verify(control("wifiSwitch").activeFocus, "the focus on wlan");
        showLevel("sound");
        side.reveal(controls.places.connections);
        verify(!findChild(controls, "sound").open, "another level gives way first");
        verify(level.open);
        verify(control("wifiSwitch").activeFocus);
        controls.wifiDevice = null;
        compare(controls.places.connections, null, "without a network device there is no netz to open");
        side.reveal(controls.places.connections);
        verify(!level.open);
        compare(named("scroller").contentY, 0, "the facet at its top");
    }

    // Above the grid, from the top (states.md:252–259): the output's volume, each display's brightness, the toggle buttons,
    // then the group that has no tile; at the foot the tiles in their fixed order, ton, netz, bluetooth, anzeige
    // (states.md:246–251).
    function test_above_the_grid_stand_volume_brightness_toggle_buttons_and_sitzung_in_order_and_the_tiles_go_ton_netz_bluetooth_anzeige() {
        giveSound(controls);
        giveDisplays(controls);
        giveNetworks(controls);
        giveBluetooth(controls);
        showSettled(0);
        const parts = [rowOf(control("outputVolume")), rowOf(control("display0Brightness")), rowOf(control("display1Brightness")), control("toggles"), findChild(controls, "session")];
        const tops = parts.map(part => part.mapToItem(controls, 0, 0).y);
        for (let k = 1; k < parts.length; k++)
            verify(tops[k] > tops[k - 1], `part ${k} below part ${k - 1}`);
        verify(side.within(control("quick"), parts[0]) && side.within(control("quick"), parts[2]), "volume and brightness above the grid, out of their groups");
        compare(findChild(findChild(controls, "session"), "heading").text, "sitzung");
        const grid = control("areas");
        const session = findChild(controls, "session");
        verify(grid.mapToItem(controls, 0, 0).y >= session.mapToItem(controls, 0, session.height).y + Tokens.spaceM, "the grid last");
        const tiles = ["soundTile", "networkTile", "bluetoothTile", "displayTile"].map(name => control(name));
        compare(grid.shownTiles(), tiles, "ton, netz, bluetooth, anzeige");
        compare(tiles.map(tile => [tile.x, tile.y]), [[0, 0], [tiles[0].width + Tokens.spaceS, 0], [0, Tokens.tileUnit + Tokens.spaceS], [tiles[0].width + Tokens.spaceS, Tokens.tileUnit + Tokens.spaceS]], "two to a row, in reading order");
    }

    function test_an_area_without_its_devices_has_no_tile() {
        side.show(0);
        verify(findChild(controls, "session").visible);
        verify(!control("soundTile").visible, "ton without audio devices");
        verify(!control("networkTile").visible, "netz without a network device");
        verify(!control("bluetoothTile").visible, "bluetooth without an adapter");
        compare(control("areas").shownTiles(), [control("displayTile")]);
    }

    // Its rows are a form's controls, not a list (forms.md); groups stand apart by their headings and space.
    function test_the_rows_of_a_group_and_of_a_level_stand_space_m_apart_on_no_hairline() {
        giveSound(controls);
        showLevel("sound");
        const session = findChild(controls, "session");
        verify(session.visible);
        compare(hairlinesIn(session).length, 0);
        const device = rowOf(inSound("outputDevice"));
        const volume = rowOf(inSound("outputVolume"));
        compare(volume.y - (device.y + device.height), Tokens.spaceM, "a level's parts are space-m apart");
    }

    function test_a_group_whose_rows_are_all_absent_falls_away() {
        const group = createTemporaryObject(absentGroupComponent, testCase);
        verify(!group.visible);
        group.rows[0].present = true;
        verify(group.visible);
    }

    function test_a_group_takes_space_xl_above_and_below_and_its_heading_stands_space_l_above_its_rows() {
        side.show(0);
        const group = findChild(controls, "session");
        const heading = findChild(group, "heading");
        const rows = findChild(group, "rows");
        waitForRendering(side);
        compare(heading.mapToItem(group, 0, 0).y, Tokens.spaceXl);
        compare(rows.mapToItem(group, 0, 0).y, Tokens.spaceXl + heading.height + Tokens.spaceL);
        compare(group.height, Tokens.spaceXl + heading.height + Tokens.spaceL + rows.height + Tokens.spaceXl);
    }

    function test_a_row_has_its_words_at_the_start_and_its_control_at_the_end() {
        controls.wiredDevice = createTemporaryObject(wiredDeviceComponent, testCase);
        showLevel("network");
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
        showLevel("network");
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
    function test_the_toggle_buttons_nicht_stoeren_and_dunkel_stand_in_two_columns_above_the_grid_in_the_scroll_without_a_heading() {
        giveNetworks(controls);
        giveBluetooth(controls);
        showSettled(0);
        const toggles = control("toggles");
        const ground = findChild(side, "ground");
        const buttons = ["doNotDisturb", "dark"].map(name => control(name));
        const cell = (side.contentWidth - Tokens.spaceS) / 2;
        const at = button => button.mapToItem(ground, 0, 0);
        for (const button of buttons) {
            verify(button instanceof ToggleButton);
            verify(side.within(toggles, button), `${button.objectName} among the toggle buttons`);
            compare(button.width, cell, `${button.objectName}: half the width, space-s between`);
        }
        compare(buttons.map(button => button.text), ["nicht stören", "dunkel"]);
        compare(buttons.map(button => button.icon), ["bell", "theme"]);
        compare(at(buttons[0]).x, Tokens.spaceM);
        compare(at(buttons[1]).x, Tokens.spaceM + cell + Tokens.spaceS);
        compare(at(buttons[1]).y, at(buttons[0]).y);
        compare(control("quickSettings").height, buttons[0].height, "one line");
        verify(at(buttons[1]).y + buttons[1].height < at(control("areas")).y, "above the grid");
        verify(!findChild(control("quick"), "heading"), "no heading over them");
        verify(side.within(findChild(side, "scroller"), buttons[0]), "in the scroll");
    }

    // wlan and bluetooth are switched in their levels, the switch first (states.md:231–233, :252–259): above the grid
    // stands neither a group verbindungen nor a toggle button of theirs.
    function test_above_the_grid_stand_no_group_verbindungen_and_no_toggle_button_wlan_or_bluetooth() {
        giveSound(controls);
        giveNetworks(controls);
        giveBluetooth(controls);
        controls.wiredDevice = createTemporaryObject(wiredDeviceComponent, testCase);
        showSettled(0);
        const all = (item, type) => (item instanceof type ? [item] : []).concat(...Array.from(item.children).map(child => all(child, type)));
        const above = control("above");
        compare(all(above, PanelGroup).filter(group => group.visible).map(group => group.title), ["sitzung"], "the one group without a tile");
        compare(all(above, ToggleButton).filter(button => button.visible).map(button => button.text), ["nicht stören", "dunkel"]);
        compare(all(above, Toggle).length, 0, "no toggle switch either");
        verify(side.within(findChild(controls, "network"), control("wifiSwitch")), "wlan in the level of netz");
        verify(side.within(findChild(controls, "bluetooth"), control("bluetoothSwitch")), "bluetooth in its level");
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

    // The rows show only once the branch does, a frame after it starts to unfold.
    function test_unfolding_with_motion_the_focus_goes_to_the_first_row_once_it_shows() {
        Prefs.motion = "on";
        showSettled(0);
        mouseClick(control("doNotDisturb"), 10, 10, Qt.RightButton);
        tryVerify(() => control("quietBranch").visible && control("quietLength").activeFocus, 4 * Tokens.durationShort);
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
        const buttons = control("quickSettings");
        tryVerify(() => Math.abs(control("quietBranch").mapToItem(control("toggles"), 0, 0).y - buttons.height - Tokens.spaceS) < 0.01, 1000, "below the buttons, space-s apart");
        waitForFrame(side);
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

    // The grid of opener tiles at the foot of steuerung and the levels its tiles open (states.md:224–275).

    function arrow(code: int): var {
        return { key: code, text: "", modifiers: Qt.NoModifier };
    }

    function stateOf(name: string): string {
        return findChild(control(name), "state").text;
    }

    function test_the_grid_is_the_last_part_its_foot_space_l_above_the_floor_and_the_free_space_above_it() {
        giveSound(controls);
        scene.height = 1000;
        showSettled(0);
        const ground = findChild(side, "ground");
        const grid = control("areas");
        const above = control("above");
        verify(!named("scroller").interactive, "it all fits");
        compare(grid.mapToItem(ground, 0, grid.height).y, ground.height - Tokens.spaceL, "on the sheet's padding at its foot");
        compare(controls.height, grid.y + grid.height, "nothing below it");
        const free = grid.mapToItem(ground, 0, 0).y - above.mapToItem(ground, 0, above.height).y;
        verify(free > Tokens.spaceM, "the free space lies between what stands above and the grid");
        compare(above.y, 0, "what stands above it from the top");
    }

    function test_a_panel_taller_than_its_room_scrolls_as_one_with_the_grid_last_space_m_after_what_stands_above() {
        giveSound(controls);
        giveDisplays(controls);
        giveBluetooth(controls);
        scene.height = 400;
        showSettled(0);
        const scroller = named("scroller");
        const grid = control("areas");
        verify(scroller.interactive, "one scroll for all");
        compare(grid.y, control("above").height + Tokens.spaceM, "space-m after what stands above it");
        verify(side.within(scroller, grid) && side.within(scroller, control("toggles")), "the toggle buttons and the grid scroll along");
        compare(grid.mapToItem(scroller.contentItem, 0, grid.height).y + Tokens.spaceL, scroller.contentHeight, "the grid last, then the sheet's padding");
    }

    function test_the_grid_has_two_columns_of_half_the_content_width_space_s_apart_and_rows_a_tile_unit_high() {
        giveSound(controls);
        showSettled(0);
        const grid = control("areas");
        const ton = control("soundTile");
        const display = control("displayTile");
        const half = (side.contentWidth - Tokens.spaceS) / 2;
        compare(grid.width, side.contentWidth);
        compare(grid.mapToItem(findChild(side, "ground"), 0, 0).x, Tokens.spaceM, "at the content's edge");
        for (const tile of [ton, display]) {
            compare(tile.width, half, `${tile.name}: half the content`);
            compare(tile.height, Tokens.tileUnit, `${tile.name}: a tile unit high`);
        }
        compare(ton.x, 0);
        compare(display.x, half + Tokens.spaceS, "space-s apart");
        compare(display.y, ton.y, "on one row");
    }

    function test_the_grid_is_one_tab_stop_its_arrows_go_to_the_next_tile_and_stay_at_its_edge_and_home_and_end_go_to_its_ends() {
        giveSound(controls);
        showSettled(0);
        const grid = control("areas");
        const ton = control("soundTile");
        const display = control("displayTile");
        control("sessionActions").forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Tab);
        verify(ton.activeFocus, "Tab reaches the first tile");
        verify(grid.handleKey(arrow(Qt.Key_Right)), "→ is the grid's");
        verify(display.activeFocus, "the next tile that way");
        verify(grid.handleKey(arrow(Qt.Key_Right)), "at the edge the grid still takes it");
        verify(display.activeFocus, "and the focus stays");
        verify(grid.handleKey(arrow(Qt.Key_Down)));
        verify(grid.handleKey(arrow(Qt.Key_Up)));
        verify(display.activeFocus, "no row above or below: ↑ and ↓ stay");
        verify(grid.handleKey(arrow(Qt.Key_Home)));
        verify(ton.activeFocus, "Home: the first tile");
        verify(grid.handleKey(arrow(Qt.Key_End)));
        verify(display.activeFocus, "End: the last");
        keyClick(Qt.Key_Tab);
        verify(findChild(side, "close").activeFocus, "the next Tab leaves the grid");
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        verify(display.activeFocus, "Shift+Tab comes back to the tile last focused");
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        verify(control("sessionActions").activeFocus, "and the next leaves it the other way");
        ton.forceActiveFocus();
        keyClick(Qt.Key_Up);
        verify(ton.activeFocus, "a real ↑ on the first row stays in the grid");
        keyClick(Qt.Key_Left);
        verify(ton.activeFocus);
        verify(side.open);
    }

    function test_the_ton_tile_names_the_output_says_stumm_while_it_is_muted_and_without_an_output_the_input() {
        const sound = giveSound(controls);
        showSettled(0);
        const ton = control("soundTile");
        compare(ton.name, "ton");
        compare(ton.glyph, "speaker");
        compare(stateOf("soundTile"), "Speakers");
        compare(ton.Accessible.name, "ton, Speakers");
        sound.speakers.audio.muted = true;
        compare(stateOf("soundTile"), "stumm", "the output muted");
        compare(ton.Accessible.name, "ton, stumm");
        sound.speakers.audio.muted = false;
        controls.output = sound.headphones;
        compare(stateOf("soundTile"), "Headphones", "another output");
        controls.output = null;
        compare(stateOf("soundTile"), "Microphone", "without an output, the input");
    }

    function test_the_anzeige_tile_says_the_density() {
        showSettled(0);
        const display = control("displayTile");
        compare(display.name, "anzeige");
        compare(display.glyph, "window");
        compare(stateOf("displayTile"), "dichte automatisch");
        controls.density = "comfortable";
        compare(stateOf("displayTile"), "dichte bequem");
        controls.density = "compact";
        compare(stateOf("displayTile"), "dichte kompakt");
        compare(display.Accessible.name, "anzeige, dichte kompakt");
    }

    function test_a_press_on_a_tile_opens_its_level_over_the_panel_below_its_head_on_the_ground_data() {
        const ways = ["click", "Enter", "Space", "finger"];
        const areas = [["soundTile", "sound", "ton"], ["displayTile", "display", "anzeige"]];
        return areas.reduce((all, [tile, level, name]) => all.concat(ways.map(way => ({ tag: `${name} by ${way}`, tile, level, name, way }))), []);
    }

    function pressTile(tile: var, way: string) {
        const scroller = named("scroller");
        scroller.contentY = Math.max(0, scroller.contentHeight - scroller.height);
        waitForFrame(side);
        if (way === "click") {
            mouseClick(tile);
        } else if (way === "finger") {
            const at = tile.mapToItem(scene, tile.width / 2, tile.height / 2);
            const touch = touchEvent(scene);
            touch.press(0, scene, at.x, at.y).commit();
            touch.release(0, scene, at.x, at.y).commit();
        } else {
            tile.forceActiveFocus(Qt.TabFocusReason);
            keyClick(way === "Enter" ? Qt.Key_Return : Qt.Key_Space);
        }
    }

    function test_a_press_on_a_tile_opens_its_level_over_the_panel_below_its_head_on_the_ground(data) {
        giveSound(controls);
        giveDisplays(controls);
        showSettled(0);
        const level = findChild(controls, data.level);
        verify(!level.open);
        pressTile(control(data.tile), data.way);
        verify(level.open, "it opens");
        verify(level.visible);
        waitForFrame(side);
        const ground = findChild(side, "ground");
        const levels = findChild(side, "levels");
        const under = findChild(side, "underPivot");
        compare(levels.mapToItem(ground, 0, 0).y, under.y + Geometry.hairline, "from the hairline under the pivot");
        compare(levels.mapToItem(ground, 0, levels.height).y, ground.height, "to the floor");
        compare(levels.x, 0);
        compare(levels.width, ground.width, "across the ground");
        compare(levels.color, Tokens.color.bg, "on the panel's ground");
        compare(level.mapToItem(levels, 0, 0), Qt.point(0, 0));
        compare(level.height, levels.height);
        const back = findChild(level, "back");
        compare(back.text, `zurück · ${data.name}`);
        verify(back.isBack);
        compare(back.mapToItem(ground, 0, 0).x, Tokens.spaceM, "at the content's edge");
        compare(back.mapToItem(levels, 0, 0).y, Tokens.spaceM, "space-m below the head");
        verify(!findChild(level, "heading"), "the rows without their group's heading");
        const rows = shownRows(level);
        verify(rows.length > 0);
        compare(rows[0].mapToItem(level, 0, 0).y, back.mapToItem(level, 0, 0).y + back.height + Tokens.spaceM, "the rows space-m after the back row");
        verify(findChild(side, "pivot").visible && findChild(side, "close").visible, "pivot and close button stay");
        const children = Array.from(ground.children);
        verify(children.indexOf(findChild(side, "close")) > children.indexOf(levels), "the close button over the level");
    }

    function test_the_level_takes_the_focus_at_once_and_its_back_row_escape_and_left_give_it_back_to_the_tile() {
        giveSound(controls);
        showSettled(0);
        const ton = control("soundTile");
        const level = findChild(controls, "sound");
        for (const way of ["back", "Escape", "Left"]) {
            ton.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Return);
            verify(inSound("outputDevice").activeFocus, `${way}: at once on the output select`);
            if (way === "back") {
                waitForFrame(side);
                mouseClick(inSound("back"));
            } else {
                keyClick(way === "Escape" ? Qt.Key_Escape : Qt.Key_Left);
            }
            verify(!level.open, `${way} closes it`);
            verify(ton.activeFocus, `${way}: the focus back on the tile`);
            verify(side.open, `${way}: the panel stays`);
        }
        keyClick(Qt.Key_Return);
        inSound("back").forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Space);
        verify(!level.open, "Space on the back row");
        verify(ton.activeFocus);
        keyClick(Qt.Key_Escape);
        verify(!side.open, "Escape on the tile closes the panel");
    }

    function test_tab_and_the_arrows_stay_in_the_head_and_the_level() {
        giveSound(controls);
        giveBluetooth(controls);
        const level = showLevel("sound");
        const stops = [findChild(side, "pivot"), inSound("back"), inSound("outputDevice"), inSound("outputMute"), inSound("outputVolume"), inSound("inputDevice"), inSound("inputMute"), inSound("inputVolume"), findChild(side, "close")];
        stops[0].forceActiveFocus(Qt.TabFocusReason);
        for (let k = 1; k < stops.length; k++) {
            keyClick(Qt.Key_Tab);
            verify(stops[k].activeFocus, `Tab to ${stops[k].objectName}`);
        }
        for (let k = stops.length - 2; k >= 0; k--) {
            keyClick(Qt.Key_Tab, Qt.ShiftModifier);
            verify(stops[k].activeFocus, `Shift+Tab to ${stops[k].objectName}`);
        }
        inSound("inputMute").forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Down);
        verify(inSound("inputVolume").activeFocus, "↓ to the next in the level");
        inSound("back").forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Up);
        verify(findChild(side, "pivot").activeFocus, "↑ from the back row to the head");
        verify(level.open);
    }

    function test_what_the_level_covers_is_out_of_reach_and_keeps_its_place_and_its_scroll() {
        giveSound(controls);
        giveBluetooth(controls);
        scene.height = 400;
        showSettled(0);
        const scroller = named("scroller");
        const branch = control("quietBranch");
        control("doNotDisturb").forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Menu);
        verify(branch.expanded, "the lengths of nicht stören unfolded");
        tryVerify(() => !branch.revealing, 1000, "and scrolled into view");
        const dark = control("dark");
        const ton = control("soundTile");
        ton.forceActiveFocus(Qt.TabFocusReason);
        verify(scroller.contentY > 0, "scrolled to the tile");
        const contentY = scroller.contentY;
        const tonAt = ton.mapToItem(scene, 0, 0);
        const darkAt = dark.mapToItem(scene, 0, 0);
        keyClick(Qt.Key_Return);
        const level = findChild(controls, "sound");
        verify(level.open);
        waitForFrame(side);
        verify(!scroller.enabled, "the facet under it takes no focus, press, hover or wheel");
        for (const covered of [dark, control("quietLength"), ton, control("lock")])
            verify(!covered.enabled, `${covered.objectName}: unavailable, to a screen reader too`);
        mouseClick(dark, dark.width / 2, dark.height / 2);
        compare(commands, [], "a press where dunkel lies does not reach it");
        mouseMove(ton, ton.width / 2, ton.height / 2);
        verify(!ton.hovered, "nor does the pointer's hover");
        mouseWheel(scroller, 10, 10, 0, -120);
        compare(scroller.contentY, contentY, "nor the wheel");
        inSound("inputVolume").forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Tab);
        verify(findChild(side, "close").activeFocus, "Tab passes over it");
        keyClick(Qt.Key_Down);
        verify(!side.within(scroller, side.Window.activeFocusItem), "and so do the arrows");
        inSound("back").forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Escape);
        verify(ton.activeFocus);
        fuzzyCompare(scroller.contentY, contentY, 0.01, "the same scroll afterwards");
        const near = (point, other) => Math.abs(point.x - other.x) < 0.01 && Math.abs(point.y - other.y) < 0.01;
        verify(near(ton.mapToItem(scene, 0, 0), tonAt), "the same place");
        verify(near(dark.mapToItem(scene, 0, 0), darkAt));
        verify(scroller.enabled && dark.enabled);
        verify(branch.expanded, "and what it covered as it was: the lengths still unfolded");
    }

    function test_a_level_longer_than_its_room_scrolls() {
        giveSound(controls);
        controls.ownProcessId = 1000;
        controls.streams = Array.from({ length: 7 }, (_, k) => stream(70 + k, { "application.name": `Player ${k + 1}` }, 0.5));
        const level = showLevel("sound");
        compare(streamRows().length, 7);
        verify(level.contentHeight > level.height, "seven streams outgrow the room");
        verify(level.interactive, "so the level scrolls");
        inSound("inputVolume").forceActiveFocus(Qt.TabFocusReason);
        verify(level.contentY > 0, "the focus brings its control into view");
        verify(shownWhole(inSound("inputVolume"), level));
        compare(named("scroller").contentY, 0, "the facet under it stays");
    }

    function test_the_panel_going_or_another_facet_closes_the_level_at_once() {
        giveSound(controls);
        const level = showLevel("sound");
        Prefs.motion = "on";
        side.close();
        verify(findChild(side, "goingOut").running, "the panel goes");
        tryVerify(() => !side.open, Tokens.durationModerate * 4);
        verify(!level.open, "the level is gone with it");
        Prefs.motion = "off";
        showLevel("sound");
        findChild(side, "pivot").select(1);
        verify(!level.open, "another facet closes it at once");
        verify(findChild(side, "scroller").enabled);
        findChild(side, "pivot").select(0);
        verify(!level.open, "and it does not come back with steuerung");
    }

    // As the host's openAt does for the bar's "stumm" and "mikrofon an".
    function test_stumm_from_the_bar_opens_the_panel_with_the_level_of_ton_standing_or_opens_it_in_the_open_panel() {
        giveSound(controls);
        Prefs.motion = "on";
        const level = findChild(controls, "sound");
        side.show(0, true);
        side.reveal(controls.places.sound);
        verify(findChild(side, "comingIn").running, "the panel comes in");
        verify(level.open, "with the level standing");
        verify(inSound("outputDevice").activeFocus);
        tryVerify(() => !findChild(side, "comingIn").running, Tokens.durationModerate * 4);
        side.reveal(findChild(controls, "display"));
        level.leave();
        verify(!level.open);
        side.show(0, true);
        side.reveal(controls.places.sound);
        verify(level.open, "the open panel opens it");
        verify(!findChild(controls, "display").open, "in place of another level");
        verify(inSound("outputDevice").activeFocus);
    }

    // As the host's openAt does for "nicht stören", "offline" or a banner's remedy while a level stands.
    function test_a_word_that_leads_to_a_place_of_the_facet_while_a_level_stands_closes_the_level_and_puts_the_focus_on_the_place() {
        giveSound(controls);
        scene.height = 500;
        const level = showLevel("sound");
        const scroller = named("scroller");
        side.show(0, true);
        side.reveal(controls.places.doNotDisturb);
        verify(!level.open, "the level gives way");
        verify(scroller.enabled, "the facet is in reach again");
        verify(control("doNotDisturb").activeFocus, "the place takes the focus");
        verify(shownWhole(control("doNotDisturb")), "whole in view, ring included");
        verify(scroller.contentY > 0, "the view went to it");
        showLevel("sound");
        side.reveal(null);
        verify(!level.open, "revealing nothing closes it too");
        compare(scroller.contentY, 0, "the view at the top");
        verify(side.holds(side.Window.activeFocusItem), "the focus stays in the panel");
        verify(control("outputMute").activeFocus, "on its first control");
    }

    // As the host's openAt does without a place: a focus that was not in a level stays where it is.
    function test_revealing_nothing_leaves_a_focus_that_was_not_in_a_level_where_it_is() {
        giveSound(controls);
        showSettled(0);
        const dark = control("dark");
        dark.forceActiveFocus(Qt.TabFocusReason);
        side.reveal(null);
        verify(dark.activeFocus, "a focus in the facet stays");
        const level = showLevel("sound");
        const pivot = findChild(side, "pivot");
        pivot.forceActiveFocus(Qt.TabFocusReason);
        side.reveal(null);
        verify(!level.open, "the level gives way");
        verify(pivot.activeFocus, "a focus in the head stays while a level stood");
    }

    // Rekta's levels take Escape only from inside them (rekta.js:1990–1991); in the head it is the panel's.
    function test_escape_in_the_panels_head_while_a_level_stands_closes_the_panel() {
        giveSound(controls);
        for (const name of ["pivot", "close"]) {
            const level = showLevel("sound");
            findChild(side, name).forceActiveFocus(Qt.TabFocusReason);
            Tips.hide();
            keyClick(Qt.Key_Escape);
            verify(!side.open, `Escape on the ${name} closes the panel`);
            verify(!level.open, `${name}: and the level with it`);
        }
    }

    // The dense case of ton: its level with three streams between the output and the input, so the eye finds where the input
    // begins.
    function test_contact_sheet_of_ton_with_three_streams_in_both_themes() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const contact = createTemporaryObject(contactComponent, testCase);
            contact.height = 800;
            const panel = findChild(contact, "panel");
            giveSound(panel.controls);
            giveStreams(panel.controls);
            panel.show(0, true);
            panel.reveal(findChild(panel.controls, "sound"));
            waitForRendering(contact);
            tryVerify(() => shownRows(findChild(contact, "sound")).filter(row => row.objectName === "stream").length === 3);
            grabImage(contact).save(`panel-sound-sheet-${theme}.png`);
            verify(findChild(contact, "inputDeviceLabel").mapToItem(contact, 0, 0).y + findChild(contact, "inputDeviceLabel").height <= contact.height, theme);
            contact.destroy();
        }
    }

    // The panel follows the one current theme and density, so the contact sheet is drawn once per pair. On a screen 1440
    // px high it holds all it has without scrolling: the grid at its foot, the free space above it; then the level of ton
    // stands over it, its output select open, and the level of anzeige; the level of netz with the joined network, one
    // that failed, one on its way and the cable, then all networks chosen in place and the password sheet over them; the
    // level of bluetooth with devices connected, on their way and not, then all devices chosen in place.
    function test_contact_sheet_of_the_panel_in_both_themes_and_densities() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        testCase.height = 1440;
        for (const theme of ContactSheets.colourSets) {
            for (const density of ["compact", "comfortable"]) {
                useColours(theme);
                Prefs.density = density;
                const contact = createTemporaryObject(contactComponent, testCase, { height: 1440 - Tokens.appbarHeight });
                const panel = findChild(contact, "panel");
                panel.controls.hasPerformanceProfile = true;
                const sound = giveSound(panel.controls);
                sound.speakers.audio.volume = 0.62;
                sound.microphone.audio.muted = true;
                giveDisplays(panel.controls);
                const networks = giveNetworks(panel.controls);
                panel.controls.wiredDevice = createTemporaryObject(wiredDeviceComponent, testCase);
                giveBluetooth(panel.controls).speaker.state = Controls.Connecting;
                givePairedDevices(panel.controls, 7);
                panel.show(0, true);
                waitForRendering(contact);
                verify(!findChild(panel, "scroller").interactive, `${theme} ${density}: no scroll`);
                grabImage(contact).save(`panel-sheet-${theme}-${density}.png`);
                findChild(contact, "soundTile").forceActiveFocus();
                keyClick(Qt.Key_Return);
                waitForRendering(contact);
                verify(findChild(contact, "outputDevice").activeFocus);
                grabImage(contact).save(`panel-level-sheet-${theme}-${density}.png`);
                keyClick(Qt.Key_Return);
                waitForRendering(contact);
                grabImage(contact).save(`panel-select-sheet-${theme}-${density}.png`);
                verify(findChild(contact, "outputDevice").expanded);
                keyClick(Qt.Key_Escape);
                keyClick(Qt.Key_Escape);
                verify(findChild(contact, "soundTile").activeFocus);
                keyClick(Qt.Key_End);
                keyClick(Qt.Key_Return);
                waitForRendering(contact);
                grabImage(contact).save(`panel-display-sheet-${theme}-${density}.png`);
                verify(findChild(contact, "display").open);
                keyClick(Qt.Key_Escape);
                findChild(contact, "networkTile").forceActiveFocus();
                keyClick(Qt.Key_Return);
                verify(findChild(contact, "wifiSwitch").activeFocus);
                networks.office.connect();
                networks.office.stateChanging = false;
                networks.office.connectionFailed(Controls.WifiAuthTimeout);
                networks.guest.stateChanging = true;
                waitForRendering(contact);
                grabImage(contact).save(`panel-wifi-level-sheet-${theme}-${density}.png`);
                findChild(contact, "allNetworks").forceActiveFocus();
                keyClick(Qt.Key_Return);
                waitForRendering(contact);
                grabImage(contact).save(`panel-networks-sheet-${theme}-${density}.png`);
                verify(findChild(contact, "networks").open);
                keyClick(Qt.Key_Down);
                keyClick(Qt.Key_Down);
                keyClick(Qt.Key_Down);
                keyClick(Qt.Key_Down);
                keyClick(Qt.Key_Return);
                typeText("pass");
                waitForRendering(contact);
                grabImage(contact).save(`panel-wifi-password-sheet-${theme}-${density}.png`);
                const passwordSheet = findChild(panel, "passwordSheet");
                verify(passwordSheet.open, `${theme} ${density}`);
                passwordSheet.close("cancel");
                keyClick(Qt.Key_Escape);
                keyClick(Qt.Key_Escape);
                verify(findChild(contact, "networkTile").activeFocus, `${theme} ${density}`);
                findChild(contact, "bluetoothTile").forceActiveFocus();
                keyClick(Qt.Key_Return);
                waitForRendering(contact);
                grabImage(contact).save(`panel-bluetooth-level-sheet-${theme}-${density}.png`);
                verify(findChild(contact, "bluetoothSwitch").activeFocus);
                findChild(contact, "allDevices").forceActiveFocus();
                keyClick(Qt.Key_Return);
                waitForRendering(contact);
                grabImage(contact).save(`panel-devices-sheet-${theme}-${density}.png`);
                verify(findChild(contact, "bluetoothDevices").open);
                verify(panel.open, `${theme} ${density}`);
                contact.destroy();
            }
        }
        testCase.height = 720;
    }
}
