pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import State
import "ContactSheets.js" as ContactSheets

TestCase {
    id: testCase

    name: "AppBarStatus"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1800
    height: 300

    readonly property var keys: ["microphone", "screen", "battery", "offline", "muted", "doNotDisturb", "more"]
    readonly property var microphone: ({ key: "microphone", word: "mikrofon an", status: "error", opens: "sound", name: "mikrofon an, öffnet ton" })
    readonly property var screen: ({ key: "screen", word: "bildschirm geteilt", status: "error", opens: "background", name: "bildschirm geteilt, öffnet im hintergrund" })
    readonly property var battery: ({ key: "battery", word: "akku 12 %", status: "error", opens: "power", name: "akku 12 %, öffnet energieprofil" })
    readonly property var offline: ({ key: "offline", word: "offline", status: "error", opens: "connections", name: "offline, öffnet verbindungen" })
    readonly property var muted: ({ key: "muted", word: "stumm", status: "", opens: "sound", name: "stumm, öffnet ton" })
    readonly property var quiet: ({ key: "doNotDisturb", word: "nicht stören", status: "", opens: "doNotDisturb", name: "nicht stören, öffnet steuerung" })
    readonly property var everything: [microphone, battery, offline, muted, quiet]
    // The clock text is the widest on "mo 16. märz" and the narrowest on "fr 3. juli" (tabular figures keep the time as wide as any).
    readonly property date widestClock: new Date(2026, 2, 16, 20, 8)
    readonly property date narrowestClock: new Date(2026, 6, 3, 20, 8)

    Component {
        id: stateComponent

        StatusWords {}
    }

    // A bar as the shell's: the status words and the middle, the clock in the centre, then on the trailing side the
    // background apps, messages and controls.
    Component {
        id: sceneComponent

        Item {
            id: scene

            property alias bar: appBar
            property alias status: words
            property real barWidth: 1600
            property var shown: []
            property date clockNow: testCase.widestClock
            property real reserve: Tokens.tileUnit

            width: 1800
            height: 300

            AppBar {
                id: appBar

                objectName: "bar"
                y: scene.height - height
                width: scene.barWidth
                area: Qt.size(scene.barWidth, scene.height)
                centre: clock
                centreReserve: scene.reserve

                AppBarStatus {
                    id: words

                    objectName: "words"
                    keys: testCase.keys
                    words: scene.shown
                    more: stateModel.more
                }

                AppBarMiddle { objectName: "middle"; parts: ["konsole", "~/projects: build the shell and its tests"] }
                AppBarClock { id: clock; objectName: "clock"; area: appBar.area; locale: Qt.locale("de_DE"); now: scene.clockNow }
                AppBarButton { objectName: "background"; icon: "window"; text: "im hintergrund"; priority: 0 }
                AppBarButton { objectName: "messages"; icon: "bell"; text: "meldungen"; count: 2; priority: 2 }
                AppBarButton { objectName: "controls"; icon: "tune"; text: "steuerung"; priority: 1 }
            }

            StatusWords { id: stateModel }
        }
    }

    // The shell's bar as it was when the review found "stumm" over "meldungen 4": the words after "meldungen".
    Component {
        id: beside

        Item {
            id: besideScene

            property alias bar: besideBar
            property var shown: []

            width: 1800
            height: 300

            AppBar {
                id: besideBar

                y: besideScene.height - height
                width: 1600
                area: Qt.size(width, besideScene.height)
                centre: besideClock
                centreReserve: Tokens.tileUnit

                AppBarMiddle { objectName: "middle"; parts: ["konsole", "~/projects"] }
                AppBarClock { id: besideClock; objectName: "clock"; area: besideBar.area; locale: Qt.locale("de_DE"); now: testCase.widestClock }
                AppBarButton { objectName: "background"; icon: "window"; text: "im hintergrund"; priority: 0 }
                AppBarButton { objectName: "messages"; icon: "bell"; text: "meldungen"; count: 4; priority: 2 }
                AppBarStatus { keys: testCase.keys; words: besideScene.shown; more: besideModel.more }
                AppBarButton { objectName: "controls"; icon: "tune"; text: "steuerung"; priority: 1 }
            }

            StatusWords { id: besideModel }
        }
    }

    Component {
        id: pressSpy

        SignalSpy {
            signalName: "activated"
        }
    }

    property var scene
    readonly property easingCurve easeBase: ({ type: Easing.Bezier, bezierCurve: Tokens.easeBase })

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

    // Where an item shows along the bar.
    function drawnX(item: Item): real {
        return item.mapToItem(scene.bar, 0, 0).x;
    }

    // Until the bar has laid itself out after a change: a word that goes has faded and nothing glides any more.
    function settle() {
        wait(Geometry.leaveShare * Tokens.durationShort + 50);
        tryVerify(() => !scene.bar.settling && !scene.bar.gliding);
    }

    // Holds the glide of the bar that has begun.
    function holdGlide() {
        tryVerify(() => scene.bar.gliding, 1000, "it glides");
        scene.bar.reflow.run.pause();
    }

    // Makes `change` and checks that nothing that shows overlaps the clock or another item while what goes fades out, and at
    // every tenth of the glide that follows. What comes waits unseen where it rests all along the glide and shows once the
    // glide has ended.
    function checkClearAllAlong(what: string, change: var) {
        const all = ["middle", "clock", "background", "messages", "controls"].map(name => findChild(scene, name)).concat(testCase.keys.map(word), [scene.bar.more]);
        const before = all.filter(item => item.visible);
        change();
        checkClear(`${what}, as it changes`, all);
        holdGlide();
        const coming = all.filter(item => (item as AppBarButton)?.wanted && !before.includes(item));
        const resting = coming.map(drawnX);
        for (let step = 0; step <= 10; step++) {
            scene.bar.reflow.progress = step / 10;
            checkClear(`${what} at ${step / 10}`, all);
            coming.forEach((item, i) => {
                verify(!item.visible, `${what} at ${step / 10}: ${item.objectName} waits unseen`);
                compare(drawnX(item), resting[i], `${what} at ${step / 10}: ${item.objectName} waits where it rests`);
            });
        }
        scene.bar.reflow.run.complete();
        coming.forEach(item => verify(item.visible, `${what}: ${item.objectName} shows once the others have made room`));
        checkClear(`${what}, at rest`, all);
    }

    function checkClear(what: string, items: var) {
        const shown = items.filter(item => item.visible).map(item => ({ name: item.objectName, left: drawnX(item), right: drawnX(item) + item.width })).sort((a, b) => a.left - b.left);
        verify(shown.length > 1, `${what}: ${shown.map(item => item.name)}`);
        for (let i = 1; i < shown.length; i++)
            verify(shown[i - 1].right <= shown[i].left + 0.5, `${what}: ${shown[i - 1].name} runs into ${shown[i].name}`);
    }

    function middle(): var {
        return findChild(scene, "middle");
    }

    function endOf(item: Item): real {
        return drawnX(item) + item.width;
    }

    // The width of a bar whose sides have `room` each beside the clock and its reserve.
    function barWidthFor(room: real): real {
        return 2 * (room + scene.bar.gap + scene.bar.padding) + Math.max(findChild(scene, "clock").implicitWidth, scene.reserve);
    }

    function test_without_a_deviation_no_word_and_no_room_stands() {
        makeScene({});
        compare(scene.status.present, false);
        compare(scene.status.visible, false);
        compare(standing(), []);
        compare(middle().x, scene.bar.padding, "the middle starts the bar, as with nothing before it");
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

    function test_the_words_stand_at_the_start_of_the_bar_in_the_order_of_the_keys_before_the_middle() {
        makeScene({ shown: [microphone, offline] });
        tryVerify(() => standing().length === 2);
        compare(drawnX(word("microphone")), scene.bar.padding, "the first word starts the bar");
        verify(endOf(word("microphone")) <= drawnX(word("offline")));
        tryCompare(middle(), "x", scene.status.x + scene.status.width + scene.bar.gap);
        verify(endOf(word("offline")) <= middle().x - scene.bar.gap + 0.5);
        verify(endOf(middle()) <= findChild(scene, "clock").x - scene.bar.gap + 0.5, "the middle ends before the clock");
    }

    function test_more_than_two_deviations_show_two_words_and_a_count_of_the_rest() {
        makeScene({ shown: everything });
        tryCompare(scene.status, "limit", 2);
        compare(scene.status.shown.map(word => word.word), ["mikrofon an", "akku 12 %", "+3"]);
        tryVerify(() => standing().length === 3);
        compare(word("more").face.word, "+3");
    }

    function test_a_press_names_the_group_the_word_opens_and_leaves_the_words_as_they_are() {
        makeScene({ shown: [offline, muted, quiet] });
        const spy = createTemporaryObject(pressSpy, testCase, { target: scene.status });
        tryVerify(() => standing().length === 3);
        mouseClick(word("offline"), 10, 10);
        compare(spy.count, 1);
        compare(spy.signalArguments[0][0].opens, "connections");
        mouseClick(word("more"), 10, 10);
        compare(spy.signalArguments[1][0].opens, "");
        compare(standing(), ["offline", "muted", "more"], "a press switches nothing");
    }

    function test_a_pointer_press_on_a_word_says_a_pointer_did_it_and_enter_on_the_focused_word_says_the_keyboard_did() {
        makeScene({ shown: [offline, muted, quiet] });
        const spy = createTemporaryObject(pressSpy, testCase, { target: scene.status });
        tryVerify(() => standing().length === 3);
        mouseClick(word("offline"), 10, 10);
        compare(spy.signalArguments[0][1], true);
        word("muted").forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Return);
        compare(spy.count, 2);
        compare(spy.signalArguments[1][0].key, "muted");
        compare(spy.signalArguments[1][1], false);
    }

    function test_the_screen_word_stands_in_the_error_colour_and_its_press_names_the_background_menu() {
        makeScene({ shown: [screen, muted] });
        const spy = createTemporaryObject(pressSpy, testCase, { target: scene.status });
        tryVerify(() => standing().length === 2);
        compare(word("screen").face.mark, Tokens.color.statusErrorFull);
        compare(word("screen").Accessible.name, "bildschirm geteilt, öffnet im hintergrund");
        mouseClick(word("screen"), 10, 10);
        compare(spy.signalArguments[0][0].opens, "background");
    }

    function test_a_word_fades_in_and_the_middle_makes_room() {
        makeScene({});
        const controls = findChild(scene, "controls");
        const before = controls.x;
        scene.shown = [muted];
        tryCompare(word("muted"), "visible", true);
        verify(word("muted").opacity < 1, "it comes with a fade");
        tryCompare(word("muted"), "opacity", 1);
        tryCompare(middle(), "x", scene.status.x + scene.status.width + scene.bar.gap);
        compare(controls.x, before, "the trailing side stays where it stood");
    }

    function test_a_word_fades_out_and_then_leaves_no_room() {
        makeScene({ shown: [muted] });
        tryCompare(middle(), "x", scene.bar.padding + scene.status.widthAt(2) + scene.bar.gap);
        scene.shown = [];
        verify(word("muted").visible, "it stays while it fades");
        tryCompare(word("muted"), "visible", false);
        compare(scene.status.present, false);
        tryCompare(middle(), "x", scene.bar.padding);
    }

    function test_while_a_word_fades_out_the_words_stay_clear_of_the_middle_and_the_bar_lays_out_after_it() {
        makeScene({ shown: [muted, quiet] });
        tryVerify(() => standing().length === 2);
        settle();
        const right = () => endOf(word("doNotDisturb"));
        scene.shown = [muted];
        verify(word("doNotDisturb").visible, "it still stands");
        verify(right() <= middle().x - scene.bar.gap + 0.5, `${right()} against ${middle().x}`);
        wait(Tokens.durationShort / 2);
        verify(right() <= middle().x - scene.bar.gap + 0.5, `half way: ${right()} against ${middle().x}`);
        tryCompare(word("doNotDisturb"), "visible", false);
        tryVerify(() => scene.status.width === scene.status.widthAt(2));
    }

    function test_a_word_that_comes_waits_unseen_where_it_rests_while_the_middle_glides_aside_then_fades_in() {
        Prefs.motion = "on";
        makeScene({ shown: [muted] });
        settle();
        const from = middle().x;
        scene.shown = [microphone, muted];
        holdGlide();
        const microphoneWord = word("microphone");
        verify(!microphoneWord.visible, "unseen as the glide begins");
        scene.bar.reflow.progress = 0;
        const at = drawnX(microphoneWord);
        compare(middle().x, from, "the middle starts where it stood");
        scene.bar.reflow.progress = easeBase.valueForProgress(0.5);
        const half = middle().x;
        verify(!microphoneWord.visible, "unseen halfway");
        scene.bar.reflow.run.complete();
        verify(microphoneWord.visible, "it comes once the glide has ended");
        compare(microphoneWord.opacity, 0, "from nothing");
        verify(findChild(microphoneWord, "fadeRun").running, "fading in");
        compare(drawnX(microphoneWord), at, "where it waited");
        verify(middle().x > from, "the middle made room");
        verify(Math.abs(half - (from + (middle().x - from) * easeBase.valueForProgress(0.5))) <= 1, `halfway at ${half}`);
        tryCompare(microphoneWord, "opacity", 1);
    }

    function test_two_words_that_come_at_once_both_wait_for_the_glide_and_then_fade_in_together() {
        Prefs.motion = "on";
        makeScene({ shown: [muted] });
        settle();
        scene.shown = [microphone, battery, muted];
        holdGlide();
        const coming = [word("microphone"), word("battery")];
        verify(coming.every(item => !item.visible), "both unseen while the others glide");
        scene.bar.reflow.run.complete();
        verify(coming.every(item => item.visible && item.opacity === 0), "both come from nothing");
        verify(coming.every(item => findChild(item, "fadeRun").running), "together");
    }

    function test_a_word_that_comes_goes_and_comes_again_waits_for_the_glide_each_time() {
        Prefs.motion = "on";
        makeScene({ shown: [muted] });
        settle();
        const microphoneWord = word("microphone");
        for (const round of [1, 2]) {
            scene.shown = [microphone, muted];
            holdGlide();
            verify(!microphoneWord.visible, `round ${round}: it waits unseen`);
            scene.bar.reflow.run.complete();
            verify(microphoneWord.visible && microphoneWord.opacity < 1, `round ${round}: then fades in`);
            tryCompare(microphoneWord, "opacity", 1);
            scene.shown = [muted];
            verify(microphoneWord.fading, `round ${round}: it fades out`);
            settle();
            verify(!microphoneWord.visible);
        }
    }

    // The bar of the review that found "stumm" over "meldungen 4": the words on the trailing side, right after it.
    function test_a_word_that_comes_beside_messages_never_lies_over_it() {
        Prefs.motion = "on";
        scene = createTemporaryObject(beside, testCase);
        settle();
        const messages = findChild(scene, "messages");
        compare(messages.words, "meldungen 4");
        checkClearAllAlong("stumm beside meldungen 4", () => (scene.shown = [muted]));
        verify(endOf(messages) + scene.bar.gap <= drawnX(word("muted")) + 0.5, "it rests after meldungen");
    }

    function test_the_first_word_to_come_fades_in_at_the_start_of_the_bar_where_it_rests() {
        Prefs.motion = "on";
        makeScene({});
        settle();
        const quietWord = word("doNotDisturb");
        scene.shown = [quiet];
        tryVerify(() => quietWord.visible, 1000, "it comes");
        const at = drawnX(quietWord);
        compare(at, scene.bar.padding);
        settle();
        compare(drawnX(quietWord), at, "it stood where it rests from the start");
        compare(middle().x, scene.status.x + scene.status.width + scene.bar.gap, "the middle follows it");
        verify(endOf(quietWord) + scene.bar.gap <= middle().x + 0.5);
    }

    function test_a_word_that_goes_fades_out_where_it_stands_and_then_the_others_close_the_gap() {
        Prefs.motion = "on";
        makeScene({ shown: [microphone, muted] });
        settle();
        const microphoneWord = word("microphone");
        const at = drawnX(microphoneWord);
        const from = middle().x;
        const started = Date.now();
        scene.shown = [muted];
        verify(microphoneWord.visible, "it stays while it fades");
        holdGlide();
        verify(Date.now() - started >= Geometry.leaveShare * Tokens.durationShort - 2, "after 0.6 × duration-short");
        verify(!microphoneWord.visible, "it has gone before the others move");
        scene.bar.reflow.progress = 0;
        compare(drawnX(microphoneWord), at, "it faded where it stood");
        compare(middle().x, from, "they start where they stood");
        scene.bar.reflow.run.complete();
        verify(middle().x < from, "and close the gap");
        compare(drawnX(word("muted")), scene.bar.padding);
    }

    function test_a_word_that_comes_while_another_goes_waits_until_that_one_has_gone() {
        Prefs.motion = "on";
        makeScene({ shown: [microphone, muted] });
        settle();
        scene.shown = [muted, quiet];
        const leaving = findChild(word("microphone"), "fadeRun");
        verify(leaving.running, "the one that goes fades out");
        leaving.pause();
        wait(Geometry.leaveShare * Tokens.durationShort);
        verify(!word("doNotDisturb").visible, "the one that comes waits out of sight");
        leaving.resume();
        holdGlide();
        verify(!word("microphone").visible);
        verify(!word("doNotDisturb").visible, "and still while the others glide");
        scene.bar.reflow.run.complete();
        verify(word("doNotDisturb").visible, "it comes once they have made room");
    }

    function test_after_a_change_of_the_bar_s_width_a_word_that_goes_fades_out_again() {
        Prefs.motion = "on";
        makeScene({ shown: [microphone, muted] });
        settle();
        scene.barWidth = 1500;
        settle();
        scene.shown = [muted];
        verify(word("microphone").visible && word("microphone").fading, "it fades out where it stands");
    }

    // Without a reserve the clock's width sets the room of the sides, as on every screen but the primary one.
    function test_on_a_bar_without_a_reserve_after_the_clock_changes_width_a_word_that_goes_fades_out_again() {
        Prefs.motion = "on";
        makeScene({ shown: [microphone, muted], reserve: 0 });
        settle();
        const clock = findChild(scene, "clock");
        const clockWidth = clock.implicitWidth;
        scene.clockNow = testCase.narrowestClock;
        verify(clock.implicitWidth !== clockWidth, "the clock changed width");
        settle();
        scene.shown = [muted];
        verify(word("microphone").visible && word("microphone").fading, "it fades out where it stands");
    }

    function test_a_word_that_gives_its_place_to_the_count_fades_out_as_a_control_moving_into_more_does() {
        Prefs.motion = "on";
        makeScene({ shown: [muted] });
        settle();
        scene.shown = everything;
        verify(word("muted").visible && word("muted").fading, "it fades out where it stands");
        verify(!word("more").visible, "the count waits out of sight");
        holdGlide();
        verify(!word("muted").visible);
        verify(!word("more").visible, "and still while the others glide");
        scene.bar.reflow.run.complete();
        verify(word("more").visible, "it comes once they have made room");
    }

    function test_while_words_come_and_go_nothing_runs_into_the_clock_or_another_control() {
        Prefs.motion = "on";
        for (const barWidth of [1600, 1200]) {
            makeScene({ shown: [muted], barWidth });
            settle();
            checkClearAllAlong(`${barWidth}, coming`, () => (scene.shown = [microphone, muted]));
            settle();
            checkClearAllAlong(`${barWidth}, going`, () => (scene.shown = [muted]));
            settle();
            checkClearAllAlong(`${barWidth}, coming with +N`, () => (scene.shown = everything));
            settle();
            checkClearAllAlong(`${barWidth}, coming and going at once`, () => (scene.shown = [battery, muted]));
        }
    }

    function test_under_reduced_motion_the_middle_makes_room_at_once() {
        Prefs.motion = "off";
        makeScene({ shown: [muted] });
        tryVerify(() => scene.status.slots.length === 1);
        const from = middle().x;
        scene.shown = [microphone, muted];
        tryVerify(() => middle().x > from);
        verify(!scene.bar.gliding);
        verify(word("microphone").visible);
        compare(word("microphone").opacity, 1);
        compare(scene.status.x + scene.status.width + scene.bar.gap, middle().x);
    }

    function test_under_reduced_motion_a_word_stands_and_goes_at_once() {
        Prefs.motion = "off";
        makeScene({});
        scene.shown = [muted];
        tryVerify(() => word("muted").visible);
        compare(word("muted").opacity, 1, "it stands without a fade");
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

    // The status words stand on the leading side, from the bar's padding to a gap before the clock and its reserve.
    function checkWordsOnTheirSide(barWidth: real) {
        const clock = findChild(scene, "clock");
        const to = barWidth / 2 - Math.max(clock.implicitWidth, scene.reserve) / 2 - scene.bar.gap;
        const words = standing().map(key => word(key));
        verify(words.length > 0, `${barWidth}: a word stands`);
        for (const control of words) {
            const key = control.objectName;
            verify(drawnX(control) >= scene.bar.padding - 0.5, `${barWidth} ${key} runs out of the bar at ${drawnX(control)}`);
            verify(endOf(control) <= to + 0.5, `${barWidth} ${key}: ${endOf(control)} runs into the clock at ${to}`);
        }
        for (let i = 1; i < words.length; i++)
            verify(drawnX(words[i]) >= endOf(words[i - 1]), `${barWidth}: words overlap`);
    }

    function test_at_800_px_and_narrower_the_words_never_move_into_more_and_never_cover_the_clock() {
        const cases = [];
        for (const width of [800, 700, 600, 520, 400])
            cases.push([width, widestClock], [width, narrowestClock]);
        for (const [barWidth, clockNow] of cases) {
            makeScene({ shown: everything, barWidth, clockNow });
            tryVerify(() => standing().length === scene.status.shown.length, 1000, `${barWidth}`);
            verify(!scene.bar.plan.moved.includes(scene.status), `${barWidth}`);
            verify(scene.status.visible, `${barWidth}`);
            tryVerify(() => scene.status.width === scene.status.widthAt(scene.status.limit));
            // A word that has left no longer holds its place in the row once the row has laid itself out again.
            tryVerify(() => standing().every(key => endOf(word(key)) <= scene.status.x + scene.status.width + 0.5), 1000, `${barWidth}: row settled`);
            checkWordsOnTheirSide(barWidth);
        }
    }

    function test_the_middle_cuts_its_words_first_and_the_words_keep_theirs() {
        makeScene({ shown: [microphone, muted] });
        findChild(scene, "background").present = false;
        tryVerify(() => standing().length === 2);
        const full = middle().implicitWidth;
        scene.barWidth = barWidthFor(scene.status.widthAt(2) + scene.bar.gap + full / 2);
        settle();
        compare(scene.status.limit, 2, "both words stand");
        verify(!scene.bar.more.visible);
        verify(middle().visible);
        verify(Math.abs(middle().width - full / 2) <= 1, `the middle is cut to the room left: ${middle().width} of ${full}`);
        compare(middle().x, scene.status.x + scene.status.width + scene.bar.gap);
    }

    function test_when_the_middle_has_given_its_room_the_words_give_up_places_and_the_other_side_keeps_its_controls() {
        makeScene({ shown: everything });
        findChild(scene, "background").present = false;
        settle();
        const trailing = ["messages", "controls"].map(name => findChild(scene, name));
        const room = trailing[0].width + scene.bar.gap + trailing[1].width;
        verify(scene.status.widthAt(2) > room, "two words and the count need more than the trailing side");
        scene.barWidth = barWidthFor(room);
        settle();
        verify(scene.status.limit < 2, "the words give up places");
        verify(scene.status.widthAt(scene.status.limit) <= room && scene.status.widthAt(scene.status.limit + 1) > room, `only as many as their side needs: ${scene.status.limit}`);
        compare(scene.status.shown.length, scene.status.limit + 1, "the rest are counted");
        verify(!scene.bar.more.visible, "the words never call up more");
        verify(trailing.every(control => control.visible && !control.overflowed), "the other side keeps its controls");
        checkWordsOnTheirSide(scene.barWidth);
        verify(!middle().visible || endOf(middle()) <= findChild(scene, "clock").x - scene.bar.gap + 0.5, "the middle ends before the clock");
    }

    function test_the_remaining_time_of_do_not_disturb_stands_in_the_middle_after_the_words() {
        makeScene({ shown: [muted, quiet] });
        middle().parts = ["nicht stören", "noch 42 min"];
        tryVerify(() => standing().length === 2);
        settle();
        verify(middle().visible);
        verify(middle().width >= middle().implicitWidth, "it has room for its words");
        verify(!findChild(middle(), "part 1").truncated, "the time is not cut");
        compare(middle().x, scene.status.x + scene.status.width + scene.bar.gap);
        verify(endOf(word("doNotDisturb")) + scene.bar.gap <= middle().x + 0.5);
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
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const sheet = createTemporaryObject(sheetComponent, testCase);
            waitForRendering(sheet);
            wait(Tokens.durationShort + 100);
            grabImage(sheet).save(`appbarstatus-sheet-${theme}.png`);
        }
    }

    // The bar before, a quarter and half the way through and after "mikrofon an" comes while "meldungen" counts from 9 to
    // 10: the word waits unseen where it rests while the count peeks and the others glide aside, then fades in.
    function test_reflow_contact_sheet() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            Prefs.motion = "on";
            const sheet = createTemporaryObject(reflowSheetComponent, testCase);
            const bars = ["before", "quarter", "half", "after"].map(name => findChild(sheet, name));
            wait(Tokens.durationShort + 100);
            for (const bar of bars.slice(1)) {
                bar.deviations = [microphone, muted];
                bar.messages.count = 10;
            }
            bars.slice(1, 3).forEach((bar, i) => holdAt(bar, (i + 1) / 4));
            tryVerify(() => !bars[3].gliding && !bars[3].settling);
            wait(Tokens.durationModerate);
            grabImage(sheet).save(`appbar-reflow-sheet-${theme}.png`);
        }
    }

    // Holds a bar that has begun to glide at `share` of the glide's time, its count as it is then.
    function holdAt(bar: var, share: real) {
        tryVerify(() => bar.gliding);
        bar.reflow.run.pause();
        bar.reflow.progress = easeBase.valueForProgress(share);
        findChild(bar.messages, "peekRun").pause();
        findChild(bar.messages, "peek").phase = share;
    }

    Component {
        id: reflowSheetComponent

        Rectangle {
            width: 1200
            height: 300
            color: Tokens.color.bg

            component ReflowBar: AppBar {
                id: reflowBar
                property alias messages: bell
                property var deviations: [testCase.muted]

                width: 1200
                area: Qt.size(width, 300)
                centre: slot
                centreReserve: Tokens.tileUnit

                AppBarStatus { keys: testCase.keys; words: reflowBar.deviations; more: model.more }
                AppBarMiddle { parts: ["konsole", "~/projects: build the shell"] }
                AppBarClock { id: slot; locale: Qt.locale("de_DE"); now: testCase.widestClock }
                AppBarButton { icon: "window"; text: "im hintergrund"; priority: 0 }
                AppBarButton { id: bell; icon: "bell"; text: "meldungen"; count: 9; priority: 2 }
                AppBarButton { icon: "tune"; text: "steuerung"; priority: 1 }

                StatusWords { id: model }
            }

            ReflowBar { objectName: "before"; y: 8 }
            ReflowBar { objectName: "quarter"; y: 80 }
            ReflowBar { objectName: "half"; y: 152 }
            ReflowBar { objectName: "after"; y: 224 }
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

                AppBarStatus { id: status; keys: testCase.keys; words: sheetBar.deviations; more: model.more }
                AppBarMiddle { parts: ["konsole", "~/projects: build the shell"] }
                AppBarClock { id: slot; locale: Qt.locale("de_DE"); now: testCase.widestClock }
                AppBarButton { icon: "window"; text: "im hintergrund"; priority: 0 }
                AppBarButton { icon: "bell"; text: "meldungen"; count: 2; priority: 2 }
                AppBarButton { icon: "tune"; text: "steuerung"; priority: 1 }

                StatusWords { id: model }
            }

            Bar { y: 10; deviations: testCase.everything }
            Bar { y: 110; width: 800; deviations: testCase.everything }
            Bar { y: 210; deviations: [testCase.screen, testCase.muted] }
        }
    }
}
