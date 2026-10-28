pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import State

TestCase {
    id: testCase

    name: "AppBarStatus"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1800
    height: 300

    readonly property var keys: ["microphone", "battery", "offline", "muted", "doNotDisturb", "more"]
    readonly property var microphone: ({ key: "microphone", word: "mikrofon an", status: "error", opens: "sound", name: "mikrofon an, öffnet ton" })
    readonly property var battery: ({ key: "battery", word: "akku 12 %", status: "error", opens: "power", name: "akku 12 %, öffnet energieprofil" })
    readonly property var offline: ({ key: "offline", word: "offline", status: "error", opens: "connections", name: "offline, öffnet verbindungen" })
    readonly property var muted: ({ key: "muted", word: "stumm", status: "", opens: "sound", name: "stumm, öffnet ton" })
    readonly property var quiet: ({ key: "doNotDisturb", word: "nicht stören", status: "", opens: "doNotDisturb", name: "nicht stören, öffnet anzeige" })
    readonly property var everything: [microphone, battery, offline, muted, quiet]

    Component {
        id: stateComponent

        StatusWords {}
    }

    // A bar as the shell's: the middle, the clock in the centre, then on the trailing side the background apps, messages,
    // the status words and controls.
    Component {
        id: sceneComponent

        Item {
            id: scene

            property alias bar: appBar
            property alias status: words
            property real barWidth: 1600
            property var shown: []

            width: 1800
            height: 300

            AppBar {
                id: appBar

                objectName: "bar"
                y: scene.height - height
                width: scene.barWidth
                area: Qt.size(scene.barWidth, scene.height)
                centre: clock
                centreReserve: Tokens.tileUnit

                AppBarMiddle { objectName: "middle"; parts: ["konsole", "~/projects: build the shell and its tests"] }
                AppBarClock { id: clock; objectName: "clock"; area: appBar.area }
                AppBarButton { objectName: "background"; icon: "window"; text: "im hintergrund"; priority: 0 }
                AppBarButton { objectName: "messages"; icon: "bell"; text: "meldungen"; count: 2; priority: 2 }
                AppBarStatus {
                    id: words

                    objectName: "words"
                    keys: testCase.keys
                    words: scene.shown
                    more: stateModel.more
                }
                AppBarButton { objectName: "controls"; icon: "tune"; text: "steuerung"; priority: 1 }
            }

            StatusWords { id: stateModel }
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
        return testCase.keys.filter(key => word(key).visible && word(key).opacity > 0);
    }

    function test_without_a_deviation_no_word_and_no_room_stands() {
        makeScene({});
        compare(scene.status.present, false);
        compare(scene.status.visible, false);
        compare(standing(), []);
        const messages = findChild(scene, "messages");
        compare(findChild(scene, "controls").x - (messages.x + messages.width), scene.bar.gap, "the neighbours stand a gap apart, as with nothing between them");
    }

    function test_a_word_is_a_square_and_the_word_with_its_status_colour() {
        makeScene({ shown: [microphone, muted] });
        compare(word("microphone").face.word, "mikrofon an");
        compare(word("microphone").face.mark, Tokens.color.statusErrorFull);
        compare(word("muted").face.mark, Tokens.color.textContrastMedium);
        compare(word("muted").face.word, "stumm");
    }

    function test_each_word_is_named_with_where_it_leads() {
        makeScene({ shown: [muted] });
        compare(word("muted").Accessible.name, "stumm, öffnet ton");
    }

    function test_the_words_stand_in_the_order_of_the_keys_before_steuerung() {
        makeScene({ shown: [microphone, offline] });
        tryVerify(() => standing().length === 2);
        verify(word("microphone").mapToItem(scene, 0, 0).x < word("offline").mapToItem(scene, 0, 0).x);
        tryVerify(() => scene.status.x + scene.status.width <= findChild(scene, "controls").x);
        verify(findChild(scene, "messages").x + findChild(scene, "messages").width <= scene.status.x);
    }

    function test_more_than_two_deviations_show_two_words_and_a_count_of_the_rest() {
        makeScene({ shown: everything });
        tryCompare(scene.status, "limit", 2);
        compare(scene.status.shown.map(word => word.word), ["mikrofon an", "akku 12 %", "+3"]);
        tryVerify(() => standing().length === 3);
        compare(word("more").face.word, "+3");
    }

    function test_a_press_names_the_word() {
        makeScene({ shown: [offline, muted, quiet] });
        const spy = createTemporaryObject(pressSpy, testCase, { target: scene.status });
        tryVerify(() => standing().length === 3);
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
        const sideWidth = () => controls.x + controls.width - findChild(scene, "background").x;
        const background = findChild(scene, "background");
        tryVerify(() => sideWidth() === background.width + messages.width + scene.status.width + controls.width + 3 * scene.bar.gap);
        scene.shown = [];
        verify(word("muted").visible, "it stays while it fades");
        tryCompare(word("muted"), "visible", false);
        compare(scene.status.present, false);
        tryVerify(() => sideWidth() === background.width + messages.width + controls.width + 2 * scene.bar.gap);
    }

    function test_while_a_word_fades_out_the_words_stay_clear_of_steuerung_and_the_bar_lays_out_after_it() {
        makeScene({ shown: [muted, quiet] });
        const controls = findChild(scene, "controls");
        tryVerify(() => standing().length === 2);
        const right = () => word("doNotDisturb").mapToItem(scene, word("doNotDisturb").width, 0).x;
        scene.shown = [muted];
        verify(word("doNotDisturb").visible, "it still stands");
        verify(right() <= controls.x - scene.bar.gap + 0.5, `${right()} against ${controls.x}`);
        wait(Tokens.durationShort / 2);
        verify(right() <= controls.x - scene.bar.gap + 0.5, `half way: ${right()} against ${controls.x}`);
        tryCompare(word("doNotDisturb"), "visible", false);
        tryVerify(() => scene.status.width === scene.status.widthAt(2));
    }

    function test_under_reduced_motion_a_word_stands_and_goes_at_once() {
        Prefs.motion = "off";
        makeScene({});
        scene.shown = [muted];
        compare(word("muted").opacity, 1);
        scene.shown = [];
        tryCompare(word("muted"), "visible", false);
    }

    function test_the_reserved_width_holds_the_words_and_is_not_much_more() {
        makeScene({ shown: everything });
        tryVerify(() => standing().length === 3);
        const first = word("microphone").mapToItem(scene, 0, 0).x;
        const last = word("more").mapToItem(scene, word("more").width, 0).x;
        const reserved = scene.status.widthAt(2);
        verify(last - first <= reserved, `${last - first} in ${reserved}`);
        verify(reserved - (last - first) <= 5 * 3, `${last - first} in ${reserved}`);
    }

    // The status words stand on the trailing side, right of the centre and its reserve, left of "more", inside the bar.
    function checkWordsOnTheirSide(barWidth: real) {
        const clock = findChild(scene, "clock");
        const more = scene.bar.more;
        const from = barWidth / 2 + Math.max(clock.implicitWidth, Tokens.tileUnit) / 2 + scene.bar.gap;
        const words = standing().map(key => word(key));
        verify(words.length > 0, `${barWidth}: a word stands`);
        for (const control of words) {
            const left = control.mapToItem(scene, 0, 0).x;
            const key = control.objectName;
            verify(left >= from - 0.5, `${barWidth} ${key}: ${left} is left of ${from}`);
            verify(left + control.width <= barWidth - scene.bar.padding + 0.5, `${barWidth} ${key} runs out of the bar: left ${left} width ${control.width} status ${scene.status.x} ${scene.status.width} limit ${scene.status.limit} plan ${scene.bar.plan.statusLimit} more ${more.x} ${more.width}`);
            if (more.visible)
                verify(left + control.width <= more.x - scene.bar.gap + 0.5, `${barWidth} ${key} runs into "more"`);
        }
        for (let i = 1; i < words.length; i++)
            verify(words[i].mapToItem(scene, 0, 0).x >= words[i - 1].mapToItem(scene, words[i - 1].width, 0).x, `${barWidth}: words overlap`);
    }

    function test_at_800_px_and_narrower_the_words_never_move_into_more_and_never_cover_the_clock() {
        for (const barWidth of [800, 700, 600, 520]) {
            makeScene({ shown: everything, barWidth });
            tryVerify(() => scene.bar.plan.more, 1000, `${barWidth}: more shows`);
            tryVerify(() => standing().length === scene.status.shown.length, 1000, `${barWidth}`);
            verify(!scene.bar.plan.moved.includes(scene.status), `${barWidth}`);
            verify(scene.status.visible, `${barWidth}`);
            tryVerify(() => scene.status.width === scene.status.widthAt(scene.status.limit));
            tryVerify(() => scene.status.x + scene.status.width <= barWidth - scene.bar.padding + 0.5, 1000, `${barWidth}: placed`);
            checkWordsOnTheirSide(barWidth);
        }
    }

    function test_the_controls_go_into_more_first_and_the_words_give_up_places_only_after_them() {
        makeScene({ shown: everything, barWidth: 800 });
        tryVerify(() => scene.bar.plan.more);
        compare(scene.bar.plan.moved.length, 3, "background, messages and controls have gone");
        verify(scene.status.limit < 2, "the room left holds fewer than two words");
        compare(scene.status.shown.length, scene.status.limit + 1, "the rest are counted");
    }

    function test_the_limit_is_two_while_there_is_room() {
        makeScene({ shown: everything });
        tryCompare(scene.status, "limit", 2);
        compare(scene.bar.plan.moved.length, 0);
    }

    function test_the_count_has_the_error_square_when_a_hidden_word_is_an_error() {
        makeScene({ shown: everything, barWidth: 400 });
        tryCompare(scene.status, "limit", 0);
        compare(scene.status.shown.length, 1);
        tryCompare(word("more").face, "mark", Tokens.color.statusErrorFull);
        makeScene({ shown: [muted, quiet], barWidth: 330 });
        tryCompare(scene.status, "limit", 0);
        tryCompare(word("more").face, "mark", Tokens.color.textContrastMedium);
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

    // The bar at 1200 px with two words and a count, at 800 px with the controls gone and the words reduced, and with
    // one neutral word and one error.
    Component {
        id: sheetComponent

        Rectangle {
            width: 1800
            height: 300
            color: Tokens.color.bg

            component Bar: AppBar {
                id: sheetBar
                property alias words: status
                property var deviations: []

                width: 1200
                area: Qt.size(width, 300)
                centre: slot
                centreReserve: Tokens.tileUnit

                AppBarMiddle { parts: ["konsole", "~/projects: build the shell"] }
                AppBarClock { id: slot }
                AppBarButton { icon: "window"; text: "im hintergrund"; priority: 0 }
                AppBarButton { icon: "bell"; text: "meldungen"; count: 2; priority: 2 }
                AppBarStatus { id: status; keys: testCase.keys; words: sheetBar.deviations; more: model.more }
                AppBarButton { icon: "tune"; text: "steuerung"; priority: 1 }

                StatusWords { id: model }
            }

            Bar { y: 10; deviations: testCase.everything }
            Bar { y: 110; width: 800; deviations: testCase.everything }
            Bar { y: 210; deviations: [testCase.muted, testCase.battery] }
        }
    }
}
