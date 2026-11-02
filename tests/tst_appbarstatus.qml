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

    readonly property var keys: ["microphone", "screen", "battery", "offline", "muted", "doNotDisturb", "more"]
    readonly property var microphone: ({ key: "microphone", word: "mikrofon an", status: "error", opens: "sound", name: "mikrofon an, öffnet ton" })
    readonly property var screen: ({ key: "screen", word: "bildschirm geteilt", status: "error", opens: "background", name: "bildschirm geteilt, öffnet im hintergrund" })
    readonly property var battery: ({ key: "battery", word: "akku 12 %", status: "error", opens: "power", name: "akku 12 %, öffnet energieprofil" })
    readonly property var offline: ({ key: "offline", word: "offline", status: "error", opens: "connections", name: "offline, öffnet verbindungen" })
    readonly property var muted: ({ key: "muted", word: "stumm", status: "", opens: "sound", name: "stumm, öffnet ton" })
    readonly property var quiet: ({ key: "doNotDisturb", word: "nicht stören", status: "", opens: "doNotDisturb", name: "nicht stören, öffnet anzeige" })
    readonly property var everything: [microphone, battery, offline, muted, quiet]
    // The clock text is the widest on "mo 16. märz" and the narrowest on "fr 3. juli" (tabular figures keep the time as wide as any).
    readonly property date widestClock: new Date(2026, 2, 16, 20, 8)
    readonly property date narrowestClock: new Date(2026, 6, 3, 20, 8)

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

                AppBarMiddle { objectName: "middle"; parts: ["konsole", "~/projects: build the shell and its tests"] }
                AppBarClock { id: clock; objectName: "clock"; area: appBar.area; locale: Qt.locale("de_DE"); now: scene.clockNow }
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
    readonly property easingCurve easeBase: ({ type: Easing.Bezier, bezierCurve: Tokens.easeBase })
    readonly property easingCurve easeIn: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })

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
    // every tenth of the glide that follows. What comes stands where it rests from the start, so the others may still be
    // leaving its place; once they have, nothing overlaps at all.
    function checkClearAllAlong(what: string, change: var) {
        const all = ["middle", "clock", "background", "messages", "controls"].map(name => findChild(scene, name)).concat(testCase.keys.map(word), [scene.bar.more]);
        const before = all.filter(item => item.visible);
        change();
        checkClear(`${what}, as it changes`, all);
        holdGlide();
        const coming = all.filter(item => item.visible && !before.includes(item));
        const resting = coming.map(drawnX);
        for (let step = 0; step <= 10; step++) {
            scene.bar.reflow.progress = step / 10;
            checkClear(`${what} at ${step / 10}`, all.filter(item => step === 10 || !coming.includes(item)));
            coming.forEach((item, i) => compare(drawnX(item), resting[i], `${what} at ${step / 10}: ${item.objectName} stands where it rests`));
        }
        scene.bar.reflow.run.complete();
    }

    function checkClear(what: string, items: var) {
        const shown = items.filter(item => item.visible).map(item => ({ name: item.objectName, left: drawnX(item), right: drawnX(item) + item.width })).sort((a, b) => a.left - b.left);
        verify(shown.length > 1, `${what}: ${shown.map(item => item.name)}`);
        for (let i = 1; i < shown.length; i++)
            verify(shown[i - 1].right <= shown[i].left + 0.5, `${what}: ${shown[i - 1].name} runs into ${shown[i].name}`);
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

    function test_the_screen_word_stands_in_the_error_colour_and_its_press_names_the_background_menu() {
        makeScene({ shown: [screen, muted] });
        const spy = createTemporaryObject(pressSpy, testCase, { target: scene.status });
        tryVerify(() => standing().length === 2);
        compare(word("screen").face.mark, Tokens.color.statusErrorFull);
        compare(word("screen").Accessible.name, "bildschirm geteilt, öffnet im hintergrund");
        mouseClick(word("screen"), 10, 10);
        compare(spy.signalArguments[0][0].opens, "background");
    }

    function test_a_word_fades_in_and_the_bar_makes_room() {
        makeScene({});
        const before = findChild(scene, "controls").x;
        scene.shown = [muted];
        tryCompare(word("muted"), "visible", true);
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

    function test_a_word_that_comes_fades_in_where_it_rests_while_the_others_glide_aside() {
        Prefs.motion = "on";
        makeScene({ shown: [muted] });
        settle();
        const messages = findChild(scene, "messages");
        const from = messages.x;
        scene.shown = [microphone, muted];
        tryVerify(() => word("microphone").visible && word("microphone").opacity < 1, 1000, "it fades in");
        holdGlide();
        scene.bar.reflow.progress = 0;
        const at = drawnX(word("microphone"));
        compare(messages.x, from, "the others start where they stood");
        scene.bar.reflow.progress = easeBase.valueForProgress(0.5);
        const half = messages.x;
        scene.bar.reflow.run.complete();
        compare(drawnX(word("microphone")), at, "it stood where it rests from the start");
        verify(messages.x < from, "the others made room");
        verify(Math.abs(half - (from + (messages.x - from) * easeBase.valueForProgress(0.5))) <= 1, `halfway at ${half}`);
    }

    function test_the_first_word_to_come_fades_in_where_it_rests_clear_of_the_control_after_it() {
        Prefs.motion = "on";
        makeScene({});
        settle();
        const quietWord = word("doNotDisturb");
        const controls = findChild(scene, "controls");
        scene.shown = [quiet];
        tryVerify(() => quietWord.visible, 1000, "it comes");
        const at = drawnX(quietWord);
        verify(at + quietWord.width <= drawnX(controls) + 0.5, `it stands clear of the control after it: ${at + quietWord.width} > ${drawnX(controls)}`);
        settle();
        compare(drawnX(quietWord), at, "it stood where it rests from the start");
    }

    function test_a_word_that_goes_fades_out_where_it_stands_and_then_the_others_close_the_gap() {
        Prefs.motion = "on";
        makeScene({ shown: [microphone, muted] });
        settle();
        const microphoneWord = word("microphone");
        const messages = findChild(scene, "messages");
        const at = drawnX(microphoneWord);
        const from = messages.x;
        const started = Date.now();
        scene.shown = [muted];
        verify(microphoneWord.visible, "it stays while it fades");
        holdGlide();
        verify(Date.now() - started >= Geometry.leaveShare * Tokens.durationShort - 2, "after 0.6 × duration-short");
        verify(!microphoneWord.visible, "it has gone before the others move");
        scene.bar.reflow.progress = 0;
        compare(drawnX(microphoneWord), at, "it faded where it stood");
        compare(messages.x, from, "they start where they stood");
        scene.bar.reflow.run.complete();
        verify(messages.x > from, "and close the gap");
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
        verify(word("doNotDisturb").visible, "and comes as the others glide");
        scene.bar.reflow.run.complete();
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
        verify(word("more").visible, "and comes as the others glide");
        scene.bar.reflow.run.complete();
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

    function test_under_reduced_motion_the_others_make_room_at_once() {
        Prefs.motion = "off";
        makeScene({ shown: [muted] });
        const messages = findChild(scene, "messages");
        tryVerify(() => scene.status.slots.length === 1);
        const from = messages.x;
        scene.shown = [microphone, muted];
        tryVerify(() => messages.x < from);
        verify(!scene.bar.gliding);
        compare(word("microphone").opacity, 1);
        compare(messages.x + messages.width + scene.bar.gap, scene.status.x);
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
        const cases = [];
        for (const width of [800, 700, 600, 520])
            cases.push([width, widestClock], [width, narrowestClock]);
        for (const [barWidth, clockNow] of cases) {
            makeScene({ shown: everything, barWidth, clockNow });
            tryVerify(() => scene.bar.plan.more, 1000, `${barWidth}: more shows`);
            tryVerify(() => standing().length === scene.status.shown.length, 1000, `${barWidth}`);
            verify(!scene.bar.plan.moved.includes(scene.status), `${barWidth}`);
            verify(scene.status.visible, `${barWidth}`);
            tryVerify(() => scene.status.width === scene.status.widthAt(scene.status.limit));
            tryVerify(() => scene.status.x + scene.status.width <= barWidth - scene.bar.padding + 0.5, 1000, `${barWidth}: placed`);
            // A word that has left no longer holds its place in the row once the row has laid itself out again.
            tryVerify(() => standing().every(key => word(key).mapToItem(scene, word(key).width, 0).x <= scene.status.x + scene.status.width + 0.5), 1000, `${barWidth}: row settled`);
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

    // The bar before, a quarter and half the way through and after "mikrofon an" comes while "meldungen" counts from 9 to
    // 10: the word fades in where it rests, the count peeks, the others glide aside.
    function test_reflow_contact_sheet() {
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
            waitForRendering(sheet);
            grabImage(sheet).save(`appbar-reflow-sheet-${theme}.png`);
        }
    }

    // Holds a bar that has begun to glide at `share` of the glide's time, its new word and count as they are then.
    function holdAt(bar: var, share: real) {
        tryVerify(() => bar.gliding);
        bar.reflow.run.pause();
        bar.reflow.progress = easeBase.valueForProgress(share);
        const coming = findChild(bar, "status-microphone");
        coming.animated = false;
        coming.opacity = easeIn.valueForProgress(Math.min(1, share * Tokens.durationModerate / Tokens.durationShort));
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

                AppBarMiddle { parts: ["konsole", "~/projects: build the shell"] }
                AppBarClock { id: slot; locale: Qt.locale("de_DE"); now: testCase.widestClock }
                AppBarButton { icon: "window"; text: "im hintergrund"; priority: 0 }
                AppBarButton { id: bell; icon: "bell"; text: "meldungen"; count: 9; priority: 2 }
                AppBarStatus { keys: testCase.keys; words: reflowBar.deviations; more: model.more }
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

                AppBarMiddle { parts: ["konsole", "~/projects: build the shell"] }
                AppBarClock { id: slot; locale: Qt.locale("de_DE"); now: testCase.widestClock }
                AppBarButton { icon: "window"; text: "im hintergrund"; priority: 0 }
                AppBarButton { icon: "bell"; text: "meldungen"; count: 2; priority: 2 }
                AppBarStatus { id: status; keys: testCase.keys; words: sheetBar.deviations; more: model.more }
                AppBarButton { icon: "tune"; text: "steuerung"; priority: 1 }

                StatusWords { id: model }
            }

            Bar { y: 10; deviations: testCase.everything }
            Bar { y: 110; width: 800; deviations: testCase.everything }
            Bar { y: 210; deviations: [testCase.screen, testCase.muted] }
        }
    }
}
