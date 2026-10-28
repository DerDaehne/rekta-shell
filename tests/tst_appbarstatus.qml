pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "AppBarStatus"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1200
    height: 300

    readonly property var keys: ["microphone", "battery", "offline", "muted", "doNotDisturb", "more"]
    readonly property var microphone: ({ key: "microphone", word: "mikrofon an", status: "error", opens: "sound", name: "mikrofon an, öffnet ton" })
    readonly property var battery: ({ key: "battery", word: "akku 12 %", status: "error", opens: "power", name: "akku 12 %, öffnet energie" })
    readonly property var offline: ({ key: "offline", word: "offline", status: "error", opens: "connections", name: "offline, öffnet verbindungen" })
    readonly property var muted: ({ key: "muted", word: "stumm", status: "", opens: "sound", name: "stumm, öffnet ton" })
    readonly property var more: ({ key: "more", word: "+2", status: "", opens: "", name: "+2, öffnet steuerung" })

    // A bar like the shell's: a centre, then on the trailing side a messages control, the status words and controls.
    Component {
        id: sceneComponent

        Item {
            id: scene

            property alias bar: appBar
            property alias status: words
            property real barWidth: 1200
            property var shown: []

            width: 1200
            height: 300

            AppBar {
                id: appBar

                objectName: "bar"
                y: scene.height - height
                width: scene.barWidth
                area: Qt.size(scene.barWidth, scene.height)
                centre: slot

                Item { id: slot; implicitWidth: 80; width: implicitWidth; height: 48 }
                AppBarButton { objectName: "messages"; icon: "bell"; text: "meldungen"; priority: 2 }
                AppBarStatus {
                    id: words

                    objectName: "words"
                    keys: testCase.keys
                    words: scene.shown
                }
                AppBarButton { objectName: "controls"; icon: "tune"; text: "steuerung"; priority: 1 }
            }
        }
    }

    Component {
        id: pressSpy

        SignalSpy {
            signalName: "activated"
        }
    }

    property var scene

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
    }

    function cleanup() {
        Prefs.theme = "system";
        Prefs.motion = "system";
    }

    function makeScene(properties) {
        scene = createTemporaryObject(sceneComponent, testCase, properties);
        return scene;
    }

    function word(key: string): var {
        return findChild(scene, `status-${key}`);
    }

    function standing(): var {
        return testCase.keys.filter(key => word(key).visible);
    }

    function test_without_a_deviation_no_word_and_no_room_stands() {
        makeScene({});
        compare(scene.status.present, false);
        compare(scene.status.visible, false);
        compare(standing(), []);
        const gapBetween = findChild(scene, "controls").x - (findChild(scene, "messages").x + findChild(scene, "messages").width);
        compare(gapBetween, scene.bar.gap, "the neighbours stand a gap apart, as with nothing between them");
    }

    function test_a_word_is_a_square_and_the_word_with_its_status_colour() {
        makeScene({ shown: [microphone, muted] });
        const tag = word("microphone").face;
        compare(tag.word, "mikrofon an");
        compare(tag.mark, Tokens.color.statusErrorFull);
        compare(word("muted").face.mark, Tokens.color.textContrastMedium);
        compare(word("muted").face.word, "stumm");
    }

    function test_each_word_is_named_with_where_it_leads() {
        makeScene({ shown: [muted] });
        compare(word("muted").Accessible.name, "stumm, öffnet ton");
    }

    function test_the_words_stand_in_the_order_of_the_keys_before_steuerung() {
        makeScene({ shown: [muted, microphone, offline] });
        tryVerify(() => standing().length === 3);
        verify(word("microphone").mapToItem(scene, 0, 0).x < word("offline").mapToItem(scene, 0, 0).x);
        verify(word("offline").mapToItem(scene, 0, 0).x < word("muted").mapToItem(scene, 0, 0).x);
        tryVerify(() => scene.status.x + scene.status.width <= findChild(scene, "controls").x);
        verify(findChild(scene, "messages").x + findChild(scene, "messages").width <= scene.status.x);
    }

    function test_a_press_names_the_word() {
        makeScene({ shown: [offline, more] });
        const spy = createTemporaryObject(pressSpy, testCase, { target: scene.status });
        mouseClick(word("offline"), 10, 10);
        compare(spy.count, 1);
        compare(spy.signalArguments[0][0].opens, "connections");
        mouseClick(word("more"), 10, 10);
        compare(spy.signalArguments[1][0].opens, "");
    }

    function test_a_word_fades_in_and_the_bar_makes_room() {
        makeScene({});
        const before = findChild(scene, "controls").x;
        scene.shown = [muted];
        compare(word("muted").visible, true);
        verify(word("muted").opacity < 1, "it comes with a fade");
        tryCompare(word("muted"), "opacity", 1);
        tryVerify(() => findChild(scene, "controls").x === before);
        verify(findChild(scene, "messages").x < scene.bar.width);
    }

    function test_a_word_fades_out_and_then_leaves_no_room() {
        makeScene({ shown: [muted] });
        const messages = findChild(scene, "messages");
        const controls = findChild(scene, "controls");
        const sideWidth = () => controls.x + controls.width - messages.x;
        // The trailing side is packed to the end: messages, the word and controls, a gap apart.
        tryVerify(() => sideWidth() === messages.width + word("muted").width + controls.width + 2 * scene.bar.gap);
        scene.shown = [];
        verify(word("muted").visible, "it stays while it fades");
        tryCompare(word("muted"), "visible", false);
        compare(scene.status.present, false);
        tryVerify(() => sideWidth() === messages.width + controls.width + scene.bar.gap);
    }

    function test_under_reduced_motion_a_word_stands_and_goes_at_once() {
        Prefs.motion = "off";
        makeScene({});
        scene.shown = [muted];
        compare(word("muted").opacity, 1);
        scene.shown = [];
        tryCompare(word("muted"), "visible", false);
    }

    function test_the_status_words_never_move_into_more() {
        makeScene({ shown: [microphone, offline], barWidth: 330 });
        tryVerify(() => scene.bar.plan.more);
        verify(!scene.bar.plan.moved.includes(scene.status), "not as a unit");
        compare(standing().length, 2);
        verify(word("microphone").visible && word("offline").visible);
        verify(scene.bar.plan.moved.length > 0, "the other controls gave way");
    }

    function test_contact_sheet() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const sheet = createTemporaryObject(sheetComponent, testCase);
            waitForRendering(sheet);
            wait(Tokens.durationShort + 100);
            grabImage(sheet).save(`appbarstatus-sheet-${theme}.png`);
        }
    }

    // Two words and "+1" on a bar, then one neutral word, then one error.
    Component {
        id: sheetComponent

        Rectangle {
            width: 1200
            height: 300
            color: Tokens.color.bg

            component Bar: AppBar {
                property alias words: status

                width: 1200
                area: Qt.size(width, 300)

                AppBarButton { icon: "bell"; text: "meldungen"; count: 2; priority: 2 }
                AppBarStatus { id: status; keys: testCase.keys }
                AppBarButton { icon: "tune"; text: "steuerung"; priority: 1 }
            }

            Bar { y: 20; Component.onCompleted: words.words = [testCase.microphone, testCase.offline, { key: "more", word: "+1", status: "", opens: "", name: "+1" }] }
            Bar { y: 110; Component.onCompleted: words.words = [testCase.muted] }
            Bar { y: 200; Component.onCompleted: words.words = [testCase.battery] }
        }
    }
}
