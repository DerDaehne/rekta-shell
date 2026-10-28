pragma ComponentBehavior: Bound

import QtQuick
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
    property var chosenProfiles: []
    property var chosenDensities: []
    property var chosenDevices: []
    // The options chosen in a level, by index.
    property var chosenOptions: []
    // How often "sitzung …" asked for the session banner.
    property int sessionAsked: 0
    // The Bluetooth switches asked for, whether the adapter takes them, and how often pairing was asked for.
    property var bluetoothSwitches: []
    property bool bluetoothTakes: true
    property int pairingAsked: 0
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
            onDensityChosen: density => testCase.chosenDensities = [...testCase.chosenDensities, density]
            onPowerProfileChosen: profile => testCase.chosenProfiles = [...testCase.chosenProfiles, profile]
            onDeviceChosen: node => testCase.chosenDevices = [...testCase.chosenDevices, node]
            onSessionAsked: testCase.sessionAsked += 1
            // As the host and Quickshell have it: the adapter switches at once, a device goes on its way.
            onBluetoothChosen: on => {
                testCase.bluetoothSwitches = [...testCase.bluetoothSwitches, on];
                if (testCase.bluetoothTakes)
                    controlsFacet.bluetooth.enabled = on;
            }
            onConnectionChosen: (device, connect) => connect ? device.connect() : device.disconnect()
            onPairingAsked: testCase.pairingAsked += 1
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

    // A branch below the fold of a scroller.
    Component {
        id: scrolledBranchComponent

        Flickable {
            property alias branch: lowBranch

            width: 300
            height: 200
            contentHeight: column.height

            Column {
                id: column

                width: parent.width

                Item {
                    width: parent.width
                    height: 400
                }

                PanelBranch {
                    id: lowBranch

                    MenuItem { text: "one" }
                    MenuItem { text: "two" }
                    MenuItem { text: "three" }
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
        chosenProfiles = [];
        chosenDensities = [];
        chosenDevices = [];
        chosenOptions = [];
        sessionAsked = 0;
        bluetoothSwitches = [];
        bluetoothTakes = true;
        pairingAsked = 0;
        scene = createTemporaryObject(sceneComponent, testCase);
        side = findChild(scene, "panel");
        controls = side.controls;
        board = findChild(scene, "board");
        toaster = findChild(scene, "toaster");
        named("opener").forceActiveFocus();
    }

    function cleanup() {
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
        compare(scroller.y + scroller.height, 640 - Tokens.spaceL, "and at the bottom");
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
        tryCompare(side, "entry", 1, Tokens.durationModerate * 4);
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
        side.show(0);
        waitForRendering(side);
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
        verify(control("dark").activeFocus, "the first control in steuerung");
        side.close();
        side.show(1);
        verify(findChild(side, "pivot").activeFocus, "meldungen has none yet");
    }

    function test_tab_and_the_arrows_reach_every_control_in_order() {
        side.show(0);
        const order = [control("dark"), control("doNotDisturb"), control("density"), control("powerProfile"), control("lock"), control("sessionActions")];
        for (let k = 1; k < order.length; k++) {
            keyClick(Qt.Key_Tab);
            verify(order[k].activeFocus, `Tab to ${order[k].objectName}`);
        }
        for (let k = order.length - 2; k >= 0; k--) {
            keyClick(Qt.Key_Tab, Qt.ShiftModifier);
            verify(order[k].activeFocus, `Shift+Tab to ${order[k].objectName}`);
        }
        keyClick(Qt.Key_Down);
        verify(order[1].activeFocus, "↓ to the next");
        keyClick(Qt.Key_Up);
        verify(order[0].activeFocus, "↑ to the one before");
        keyClick(Qt.Key_Up);
        verify(findChild(side, "pivot").activeFocus, "↑ from the first to the pivot");
        keyClick(Qt.Key_Down);
        verify(order[0].activeFocus, "↓ from the pivot to the first");
        order[5].forceActiveFocus();
        keyClick(Qt.Key_Down);
        verify(order[5].activeFocus, "the arrows never leave the panel");
    }

    function test_every_row_works_from_the_keyboard() {
        controls.hasPerformanceProfile = true;
        controls.kdeglobals = "";
        side.show(0);
        keyClick(Qt.Key_Space);
        compare(commands, [["plasma-apply-lookandfeel", "--apply", "org.kde.breezedark.desktop"]], "dunkel");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Space);
        verify(controls.doNotDisturb, "nicht stören");
        keyClick(Qt.Key_Down);
        verify(control("density").activeFocus);
        keyClick(Qt.Key_Right);
        compare(chosenDensities, ["comfortable"], "dichte, where the arrows choose");
        keyClick(Qt.Key_Tab);
        verify(control("powerProfile").activeFocus);
        keyClick(Qt.Key_Right);
        compare(chosenProfiles, [2], "energieprofil, where the arrows choose");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        compare(commands[1], ["loginctl", "lock-session"], "sperren");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        compare(sessionAsked, 1, "sitzung …");
    }

    function test_dunkel_applies_the_dark_theme_of_plasmas_pair_and_the_light_one_back() {
        controls.kdeglobals = "[General]\nColorScheme=RektaLight\n\n[KDE]\nDefaultDarkLookAndFeel=org.example.night\nDefaultLightLookAndFeel=org.example.day\nLookAndFeelPackage=org.example.day\n";
        side.show(0);
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
        side.show(0);
        Prefs.theme = "dark";
        verify(control("dark").checked);
        compare(findChild(control("dark"), "word").text, "an");
        mouseClick(control("dark"));
        verify(!control("dark").checked, "the choice shows at once");
        Prefs.theme = "light";
        Prefs.theme = "dark";
        verify(control("dark").checked, "and the system's next change too");
        Prefs.theme = "light";
        verify(!control("dark").checked);
        compare(findChild(control("dark"), "word").text, "aus");
    }

    function test_with_nicht_stoeren_only_critical_notifications_toast_and_the_others_go_quietly_into_the_list() {
        side.show(0);
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
        side.show(0);
        waitForRendering(side);
        mouseClick(control("lock"));
        compare(commands, [["loginctl", "lock-session"]]);
    }

    function test_sitzung_asks_for_the_session_banner_below_sperren() {
        side.show(0);
        waitForRendering(side);
        const sessionActions = control("sessionActions");
        compare(sessionActions.text, "sitzung …");
        verify(rowOf(sessionActions).y > rowOf(control("lock")).y, "in the group sitzung, below sperren");
        mouseClick(sessionActions);
        compare(sessionAsked, 1);
        compare(commands, [], "it runs nothing itself");
    }

    function test_ton_shows_the_default_output_and_input_with_their_volume_and_stumm() {
        const sound = giveSound(controls);
        sound.speakers.audio.volume = 0.62;
        sound.microphone.audio.muted = true;
        side.show(0);
        const group = findChild(controls, "sound");
        verify(group.visible);
        compare(findChild(group, "heading").text, "ton");
        tryCompare(group, "y", 0, 1000, "the first group");
        compare(findChild(rowOf(control("outputDevice")), "words").text, "ausgang");
        compare(control("outputDevice").currentText, "Speakers");
        compare(findChild(rowOf(control("inputDevice")), "words").text, "eingang");
        compare(control("inputDevice").currentText, "Microphone");
        compare(control("outputVolume").value, 0.62);
        compare(findChild(control("outputVolume"), "output").text, "62%", "in tabular figures");
        compare(findChild(control("outputVolume"), "output").font.features, { "tnum": 1 });
        compare(control("inputVolume").value, 0.5);
        verify(!control("outputMuted").checked);
        verify(control("inputMuted").checked);
        compare(findChild(rowOf(control("outputMuted")), "words").text, "stumm");
        compare(control("outputDevice").Accessible.name, "ausgang Speakers");
        compare(control("outputVolume").Accessible.name, "lautstärke ausgang");
        compare(control("inputMuted").Accessible.name, "stumm eingang");
    }

    function test_the_device_select_and_the_volume_slider_stand_below_their_words_as_wide_as_the_row() {
        giveSound(controls);
        side.show(0);
        waitForRendering(side);
        for (const name of ["outputDevice", "outputVolume"]) {
            const row = rowOf(control(name));
            compare(control(name).width, row.width, name);
            compare(findChild(row, "holder").x, 0, name);
            compare(findChild(row, "holder").y, findChild(row, "words").height + Tokens.spaceXs, `${name} space-xs below, as a field's control below its label`);
        }
        compare(findChild(rowOf(control("outputVolume")), "words").text, "lautstärke");
    }

    function test_the_slider_and_stumm_set_the_device_and_follow_changes_from_elsewhere() {
        const sound = giveSound(controls);
        side.show(0);
        const slider = control("outputVolume");
        slider.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(sound.speakers.audio.volume, 0.51, "a step up sets the device's volume");
        sound.speakers.audio.volume = 0.8;
        compare(slider.value, 0.8, "a key or an app moves the slider");
        compare(findChild(slider, "output").text, "80%");
        sound.speakers.audio.volume = 1.4;
        compare(slider.value, 1, "a raised volume shows as the end of the scale");
        mouseClick(control("outputMuted"));
        verify(sound.speakers.audio.muted, "stumm mutes the device");
        sound.speakers.audio.muted = false;
        verify(!control("outputMuted").checked, "and follows it");
        control("inputVolume").forceActiveFocus();
        keyClick(Qt.Key_Left);
        compare(sound.microphone.audio.volume, 0.49, "the microphone the same");
        mouseClick(control("inputMuted"));
        verify(sound.microphone.audio.muted);
    }

    function test_rows_follow_another_default_device() {
        const sound = giveSound(controls);
        side.show(0);
        sound.headphones.audio.volume = 0.3;
        controls.output = sound.headphones;
        compare(control("outputDevice").currentText, "Headphones");
        compare(control("outputVolume").value, 0.3);
    }

    function test_without_audio_devices_ton_falls_away_and_without_an_input_only_its_rows_go() {
        const sound = giveSound(controls);
        side.show(0);
        controls.input = null;
        verify(findChild(controls, "sound").visible);
        verify(!rowOf(control("inputDevice")).visible);
        verify(!rowOf(control("inputVolume")).visible);
        verify(!rowOf(control("inputMuted")).visible);
        controls.output = null;
        verify(!findChild(controls, "sound").visible);
    }

    function test_the_output_select_expands_in_place_pushes_the_rows_below_down_and_a_click_asks_for_another_default() {
        const sound = giveSound(controls);
        side.show(0);
        waitForRendering(side);
        const select = control("outputDevice");
        const volumeRow = rowOf(control("outputVolume"));
        const before = volumeRow.mapToItem(controls, 0, 0).y;
        mouseClick(findChild(select, "box"));
        verify(select.expanded);
        const options = optionRows(select);
        compare(options.map(row => findChild(row, "label").text), ["Speakers", "Headphones"]);
        compare(options.map(row => findChild(row, "fill").visible), [true, false], "the default in the accent");
        const growth = findChild(select, "box").height - Tokens.controlHeight;
        tryVerify(() => volumeRow.mapToItem(controls, 0, 0).y === before + growth, 1000, "lautstärke moves down by what the select grows");
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
        side.show(0);
        waitForRendering(side);
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

    function test_a_long_device_name_is_cut_in_its_select_and_in_its_row() {
        const sound = giveSound(controls);
        sound.speakers.description = "Navi 21/23 HDMI/DP Audio Controller Digital Stereo (HDMI 3)".repeat(Math.ceil(Tokens.tileUnit / 40));
        side.show(0);
        waitForRendering(side);
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

    function test_the_bluetooth_toggle_switches_the_adapter_and_shows_what_the_adapter_has() {
        const bluetooth = giveBluetooth(controls);
        side.show(0);
        const toggle = control("bluetooth");
        compare(findChild(rowOf(toggle), "words").text, "bluetooth");
        verify(findChild(controls, "connections").visible, "in verbindungen");
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

    function test_a_blocked_adapter_greys_the_toggle_which_says_why() {
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
        side.show(0);
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
        side.show(0);
        waitForRendering(side);
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
        side.show(0);
        waitForRendering(side);
        mouseClick(control("chooseBluetoothDevice"));
        waitForRendering(side);
        compare(branchRows().length, 6, "five devices and neues gerät koppeln");
        verify(!control("allDevices").visible);
    }

    function test_the_unfolded_devices_connect_and_pair_like_those_of_the_level() {
        const bluetooth = giveBluetooth(controls);
        side.show(0);
        waitForRendering(side);
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
        side.show(0);
        waitForRendering(side);
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
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(branch.unfolded, 1);
        keyClick(Qt.Key_Escape);
        compare(branch.unfolded, 0);
    }

    function test_geräte_unfolds_from_the_keyboard_and_escape_folds_it() {
        const bluetooth = giveBluetooth(controls);
        side.show(0);
        keyClick(Qt.Key_Down);
        const opener = control("chooseBluetoothDevice");
        verify(opener.activeFocus);
        const branch = control("bluetoothBranch");
        keyClick(Qt.Key_Escape);
        verify(!side.open, "folded, Escape leaves the panel");
        side.show(0);
        keyClick(Qt.Key_Down);
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

    function test_the_devices_come_back_folded_after_the_panel_was_away() {
        giveBluetooth(controls);
        side.show(0);
        waitForRendering(side);
        mouseClick(control("chooseBluetoothDevice"));
        side.close();
        tryVerify(() => !side.visible);
        side.show(0);
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
        verify(!rowOf(control("bluetooth")).visible);
        verify(!rowOf(control("chooseBluetoothDevice")).visible);
        verify(!findChild(controls, "connections").visible, "with no other row the group falls away");
    }

    function test_bluetooth_works_from_the_keyboard() {
        const bluetooth = giveBluetooth(controls);
        side.show(0);
        verify(control("bluetooth").activeFocus, "the first control without sound");
        keyClick(Qt.Key_Space);
        compare(bluetoothSwitches, [false]);
        keyClick(Qt.Key_Down);
        const opener = control("chooseBluetoothDevice");
        verify(opener.activeFocus);
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
        const dark = rowOf(control("dark"));
        const doNotDisturb = rowOf(control("doNotDisturb"));
        compare(doNotDisturb.y - (dark.y + dark.height), Tokens.spaceM, "a section's parts are space-m apart");
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
        side.show(0);
        const toggle = control("dark");
        const row = rowOf(toggle);
        waitForRendering(side);
        const words = findChild(row, "words");
        compare(words.text, "dunkel");
        compare(words.x, 0);
        compare(findChild(row, "holder").x, row.width - toggle.implicitWidth, "the control at the end");
        compare(row.height, Math.max(words.height, toggle.implicitHeight), "the height of its line");
        compare(findChild(rowOf(control("lock")), "holder").x, 0, "a row without words has its control at the start");
    }

    function test_a_row_whose_words_and_control_do_not_fit_puts_the_control_below_and_cuts_long_words() {
        side.show(0);
        const toggle = control("dark");
        const row = rowOf(toggle);
        row.label = "a long word for the dark look that cannot share its line with the toggle";
        waitForRendering(side);
        const words = findChild(row, "words");
        compare(findChild(row, "holder").x, 0);
        compare(findChild(row, "holder").y, words.height + Tokens.spaceXs, "space-xs below the words");
        compare(row.height, words.height + Tokens.spaceXs + toggle.implicitHeight);
        compare(words.width, row.width);
        verify(words.truncated, "the words are cut, not wrapped");
        compare(words.lineCount, 1);
    }

    function test_the_toggles_are_named_by_their_rows() {
        compare(control("dark").Accessible.name, "dunkel");
        compare(control("doNotDisturb").Accessible.name, "nicht stören");
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
                giveSound(panel.controls).speakers.audio.volume = 0.62;
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
                grabImage(contact).save(`panel-bluetooth-collapsed-sheet-${theme}-${density}.png`);
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
