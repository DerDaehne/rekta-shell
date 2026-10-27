pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "Toaster"
    visible: true
    when: windowShown
    width: 800
    height: 760

    // A 40px app icon: a blue rounded square with a white dot.
    readonly property string appIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAMAAAC7IEhfAAAAHlBMVEX///86dvBEffF4ofW5zvrs8v7///9Be/GcuvdVifLlkWmGAAAAAXRSTlMAQObYZgAAAI1JREFUOMu11UkOgCAQRFGaocH7X9iFMaKW5DvV+sWANEUIS+wyoY8NA9lGzaCk0AxKCg3mOYwpFy85xTGszde0OoCT95ku4d7tZQ+rH1M1bCfYJIx+TlQwCZgUzAJmBYuARUFXefVFvEa8a/wf8cnws8bTw+eRTzi/M39c17dVcaekvu9HXs287NHzMQN/Vg0WT30WoAAAAABJRU5ErkJggg=="
    // The wall clock the toasts run against, in ms.
    property double time: 0
    property var ends: []
    property var undone: []
    property Item scene
    property Toaster toaster

    Component {
        id: sceneComponent

        // A host: it routes the keys nobody took to the key layers, as the shell does from its root.
        Item {
            width: 800
            height: 600
            Keys.onPressed: event => KeyLayers.dispatch(event, Window.activeFocusItem)

            Toaster {
                objectName: "toaster"
                width: parent.width
                clock: () => testCase.time
            }

            Button {
                objectName: "trigger"
                y: 400
                text: "archive"
            }

            TextInput {
                objectName: "input"
                y: 500
                width: 200
                text: "name"
            }
        }
    }

    Component {
        id: sheetSceneComponent

        // A sheet stands in the modal layer above everything (platforms.md, "Layer").
        Item {
            width: 800
            height: 600

            Toaster {
                objectName: "toaster"
                width: parent.width
            }

            Rectangle {
                objectName: "sheet"
                anchors.fill: parent
                z: Tokens.layerFloat + 1
                color: Tokens.color.shading
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "off";
        time = 0;
        ends = [];
        undone = [];
        scene = createTemporaryObject(sceneComponent, testCase);
        toaster = findChild(scene, "toaster");
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function ending(label) {
        return reason => {
            testCase.ends = [...testCase.ends, `${label} ${reason}`];
        };
    }

    function undoing(label) {
        return () => {
            testCase.undone = [...testCase.undone, label];
        };
    }

    // The clock moves on and the toast takes its next step, as its timer would.
    function at(ms, toast) {
        time = ms;
        toast.step();
    }

    function test_a_toast_hangs_from_the_top_centre_12px_below_the_edge() {
        const toast = toaster.show("3 messages archived", {});
        compare(toast.y, toaster.rest);
        compare(toaster.rest, 12);
        compare(toast.x, (toaster.width - toast.width) / 2);
        compare(toast.height, Math.max(Tokens.controlHeight + Tokens.spaceXs, findChild(toast, "words").height));
        compare(toaster.implicitHeight, 12 + toast.height, "the host's window holds it");
        toast.text = "a very long sentence that says what happened in many words, and then some more words, so it wraps";
        compare(toast.width, Geometry.toastMaxWidth, "at most 32rem");
    }

    function test_a_success_is_the_plain_ink_strip_without_a_status() {
        Prefs.theme = "dark";
        const toast = toaster.show("schedule saved", {});
        compare(findChild(toast, "fill").color, Tokens.color.textPrimary);
        compare(findChild(toast, "message").color, Tokens.color.bg);
        compare(toast.Accessible.role, Accessible.Notification);
    }

    function test_an_error_toast_takes_the_error_fill_and_is_an_alert() {
        const toast = toaster.show("could not save the schedule: the server is offline", { status: "error", act: { label: "retry", run: () => {} } });
        compare(findChild(toast, "fill").color, Tokens.color.statusErrorTile);
        compare(findChild(toast, "message").color, Tokens.color.textPrimary);
        compare(toast.Accessible.role, Accessible.AlertMessage);
        compare(toaster.show("syncing paused", { status: "warning" }).Accessible.role, Accessible.Notification, "only an error is an alert");
    }

    function test_a_new_toast_replaces_the_open_one_and_comes_in_once_that_one_has_gone() {
        Prefs.motion = "on";
        const first = toaster.show("message archived", { onEnd: ending("first") });
        const second = toaster.show("message moved", { onEnd: ending("second") });
        compare(testCase.ends, ["first replaced"]);
        compare(toaster.open, second);
        verify(second.waiting, "it waits while the first leaves");
        verify(!second.visible);
        verify(first.visible, "the first is on its way out");
        tryVerify(() => second.visible, 1000);
        compare(toaster.leaving, 0);
        tryCompare(second, "y", toaster.rest, 1000);
    }

    function test_a_toast_dismissed_before_it_came_in_never_shows() {
        Prefs.motion = "on";
        toaster.show("message archived", {});
        const second = toaster.show("message moved", { onEnd: ending("second") });
        const third = toaster.show("message deleted", {});
        compare(testCase.ends, ["second replaced"]);
        tryVerify(() => third.visible, 1000);
        compare(toaster.open, third);
    }

    function test_the_same_key_with_undo_joins_the_open_toast_and_restarts_its_window() {
        const toast = toaster.show("1 message archived", { key: "archive", undo: undoing("first"), onEnd: ending("first") });
        at(3000, toast);
        compare(toast.seconds, 2);
        const joined = toaster.show("2 messages archived", { key: "archive", undo: undoing("both"), onEnd: ending("both") });
        compare(joined, toast);
        compare(toast.text, "2 messages archived");
        compare(testCase.ends, ["first merged"]);
        compare(toast.seconds, 5, "the window starts again");
        toast.undo();
        compare(testCase.undone, ["both"]);
        compare(testCase.ends, ["first merged", "both undone"]);
    }

    function test_the_same_key_without_undo_replaces_the_open_toast() {
        const toast = toaster.show("message archived", { key: "archive", undo: undoing("archive"), onEnd: ending("first") });
        verify(toaster.show("message archived", { key: "archive" }) !== toast);
        compare(testCase.ends, ["first replaced"]);
    }

    function test_a_plain_toast_goes_when_its_window_runs_out() {
        const toast = toaster.show("message archived", { onEnd: ending("toast") });
        compare(findChild(toast, "tick").interval, Tokens.durationToast, "no steps on the way");
        at(Tokens.durationToast - 1, toast);
        compare(toaster.open, toast);
        at(Tokens.durationToast, toast);
        compare(testCase.ends, ["toast expired"]);
        compare(toaster.open, null);
    }

    function test_an_undo_window_counts_down_once_a_second() {
        const toast = toaster.show("3 messages deleted", { undo: undoing("delete") });
        const tick = findChild(toast, "tick");
        const line = findChild(toast, "line");
        compare(toast.seconds, 5);
        compare(findChild(toast, "count").text, "5");
        compare(tick.interval, 1000);
        at(1300, toast);
        compare(toast.seconds, 4);
        compare(tick.interval, 700, "the next step falls on a whole second");
        compare(line.transform[0].xScale, 3700 / 5000);
        at(2000, toast);
        compare(findChild(toast, "count").text, "3");
        compare(line.transform[0].xScale, 3000 / 5000);
    }

    function test_the_window_runs_on_the_wall_clock_and_a_late_step_catches_up_at_once() {
        const toast = toaster.show("3 messages deleted", { undo: undoing("delete"), onEnd: ending("toast") });
        at(7000, toast);
        compare(testCase.ends, ["toast expired"]);
        compare(testCase.undone, []);
    }

    function test_hover_holds_the_window_and_letting_go_runs_out_what_was_left() {
        const toast = toaster.show("3 messages deleted", { undo: undoing("delete"), onEnd: ending("toast") });
        at(2000, toast);
        mouseMove(toast, 10, 10);
        verify(toast.held);
        compare(toast.remaining, 3000);
        at(60000, toast);
        compare(toaster.open, toast, "held, the window does not run");
        compare(toast.seconds, 3);
        mouseMove(scene, 400, 300);
        verify(!toast.held);
        at(62999, toast);
        compare(toaster.open, toast);
        at(63000, toast);
        compare(testCase.ends, ["toast expired"]);
    }

    function test_a_toast_joined_while_it_is_held_stays_held_with_a_new_window() {
        const toast = toaster.show("1 message archived", { key: "archive", undo: undoing("first") });
        at(1000, toast);
        mouseMove(toast, 10, 10);
        verify(toast.held);
        toaster.show("2 messages archived", { key: "archive", undo: undoing("both") });
        compare(toast.remaining, 5000);
        at(30000, toast);
        compare(toaster.open, toast);
        compare(toast.seconds, 5);
    }

    function test_focus_holds_the_window() {
        const toast = toaster.show("3 messages deleted", { undo: undoing("delete") });
        at(1000, toast);
        findChild(toast, "action").forceActiveFocus();
        verify(toast.held);
        at(30000, toast);
        compare(toaster.open, toast);
        findChild(scene, "trigger").forceActiveFocus();
        verify(!toast.held);
        compare(toast.deadline, 30000 + 4000);
    }

    function test_the_undo_word_is_the_hosts_and_ctrl_z_follows_it() {
        toaster.undoWord = "rückgängig";
        const toast = toaster.show("3 messages deleted", { undo: undoing("delete") });
        compare(toast.actionLabel, "rückgängig");
        compare(findChild(toast, "action").Accessible.name, "rückgängig");
        findChild(scene, "trigger").forceActiveFocus();
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(testCase.undone, ["delete"]);
    }

    function test_the_action_undoes_and_ends_the_toast_as_undone() {
        const toast = toaster.show("3 messages deleted", { undo: undoing("delete"), onEnd: ending("toast") });
        mouseClick(findChild(toast, "action"));
        compare(testCase.undone, ["delete"]);
        compare(testCase.ends, ["toast undone"]);
        compare(toaster.open, null);
    }

    function test_ctrl_z_undoes_while_the_window_is_open_except_in_a_text_field() {
        toaster.show("3 messages deleted", { undo: undoing("delete") });
        findChild(scene, "input").forceActiveFocus();
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(testCase.undone, [], "a field's own undo wins");
        findChild(scene, "trigger").forceActiveFocus();
        keyClick(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier);
        compare(testCase.undone, [], "Ctrl+Shift+Z is redo");
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(testCase.undone, ["delete"]);
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(testCase.undone, ["delete"], "the window has closed");
    }

    function test_ctrl_z_leaves_a_redo_toast_and_another_action_alone() {
        toaster.show("3 messages restored", { undo: undoing("redo"), action: "redo" });
        findChild(scene, "trigger").forceActiveFocus();
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(testCase.undone, []);
    }

    function test_escape_in_a_toast_dismisses_it_and_focus_returns_to_where_it_came_from() {
        const trigger = findChild(scene, "trigger");
        const toast = toaster.show("3 messages deleted", { undo: undoing("delete"), from: trigger, onEnd: ending("toast") });
        findChild(toast, "action").forceActiveFocus();
        keyClick(Qt.Key_Escape);
        compare(testCase.ends, ["toast dismissed"]);
        compare(testCase.undone, []);
        verify(trigger.activeFocus);
    }

    function test_escape_outside_the_toast_leaves_it_alone() {
        const toast = toaster.show("3 messages deleted", { undo: undoing("delete") });
        findChild(scene, "trigger").forceActiveFocus();
        keyClick(Qt.Key_Escape);
        compare(toaster.open, toast);
    }

    function test_a_toast_on_its_way_out_takes_no_click() {
        Prefs.motion = "on";
        let runs = 0;
        const toast = toaster.show("could not load the jobs", { act: { label: "reload", run: () => { runs++; } }, onEnd: ending("toast") });
        tryCompare(toast, "y", toaster.rest, 1000);
        toaster.dismiss();
        verify(findChild(toast, "slidingOut").running);
        mouseClick(findChild(toast, "action"));
        compare(runs, 0);
        compare(testCase.ends, ["toast dismissed"]);
    }

    function test_a_replaced_toast_that_keeps_focus_takes_no_key() {
        Prefs.motion = "on";
        let runs = 0;
        const toast = toaster.show("could not load the jobs", { act: { label: "reload", run: () => { runs++; } } });
        tryCompare(toast, "y", toaster.rest, 1000);
        findChild(toast, "action").forceActiveFocus();
        toaster.show("message archived", {});
        verify(findChild(toast, "action").activeFocus, "no `from` to return focus to");
        keyClick(Qt.Key_Return);
        compare(runs, 0);
    }

    function test_a_plain_action_runs_without_a_countdown_and_ends_the_toast_as_acted() {
        let reloaded = false;
        const toast = toaster.show("could not load the jobs", { status: "error", act: { label: "reload", run: () => { reloaded = true; } }, onEnd: ending("toast") });
        verify(!findChild(toast, "count").visible);
        verify(!findChild(toast, "line").visible);
        compare(findChild(toast, "tick").interval, Tokens.durationToast, "it stays its usual time");
        findChild(toast, "action").forceActiveFocus();
        keyClick(Qt.Key_Return);
        verify(reloaded);
        compare(testCase.ends, ["toast acted"]);
    }

    function test_the_undo_line_runs_along_the_foot_and_shrinks_toward_the_action() {
        const toast = toaster.show("3 messages deleted", { undo: undoing("delete") });
        const line = findChild(toast, "line");
        compare(line.height, 2);
        compare(line.x, Tokens.spaceXs);
        compare(line.y + line.height, toast.height - Tokens.spaceXs);
        compare(line.width, toast.width - 2 * Tokens.spaceXs);
        compare(line.transform[0].origin.x, line.width, "its trailing end stays");
        compare(line.color, findChild(toast, "message").color);
    }

    function test_an_app_icon_stands_at_the_front_of_the_strip() {
        const plain = toaster.show("message archived", {});
        verify(!findChild(plain, "appIcon").visible);
        compare(findChild(plain, "message").leftPadding, Tokens.spaceM);
        const toast = toaster.show("see you soon", { icon: testCase.appIcon });
        const icon = findChild(toast, "appIcon");
        const message = findChild(toast, "message");
        verify(icon.visible);
        compare(icon.width, 20);
        compare(icon.mapToItem(toast, 0, 0).x, Tokens.spaceM);
        fuzzyCompare(icon.mapToItem(toast, 0, 0).y, (toast.height - 20) / 2, 0.5, "centred on the strip");
        compare(message.mapToItem(toast, 0, 0).x + message.leftPadding, Tokens.spaceM + 20 + Tokens.spaceS);
    }

    // A 40 × 20 picture: red, blue and green stripes of 10, 20 and 10px. A square crop from its middle is all blue.
    readonly property string widePicture: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAUCAIAAABwJOjsAAAALUlEQVR4nGO4aW+PB1mVfSAb2W+IwoMYRi0etXjU4lGLRy0etXjU4lGLR47FADgIlz0RQ3NbAAAAAElFTkSuQmCC"

    function test_a_toast_with_a_title_has_it_in_semibold_above_a_text_of_two_lines_that_ends_in_an_ellipsis() {
        const long = "a long message body that says what happened in many words, and then some more words, so that it needs a third line to be said, and a fourth line besides, because a message may run on and on and on until nobody reads it to the end";
        const toast = toaster.show(long, { title: "Mia", icon: testCase.appIcon });
        const heading = findChild(toast, "title");
        const message = findChild(toast, "message");
        verify(heading.visible);
        compare(heading.text, "Mia");
        compare(heading.font.weight, Tokens.fontWeightSemibold);
        compare(message.font.weight, Tokens.fontWeightRegular);
        verify(message.mapToItem(toast, 0, 0).y >= heading.mapToItem(toast, 0, 0).y + heading.height, "the text is below the title");
        compare(message.lineCount, 2);
        verify(message.truncated, "the third line ends in an ellipsis");
        compare(message.elide, Text.ElideRight);
        compare(toast.height, findChild(toast, "words").height);
    }

    function test_the_whole_text_is_announced_and_named_even_where_it_is_cut() {
        const long = "a long message body that says what happened in many words, and then some more words, so that it needs a third line to be said, and a fourth line besides, because a message may run on and on and on until nobody reads it to the end";
        const toast = toaster.show(long, { title: "Mia" });
        compare(toast.announcement, `Mia. ${long}`);
        compare(toast.Accessible.name, `Mia. ${long}`);
        compare(toast.spoken, toast.Accessible.name);
        compare(findChild(toast, "message").text, long);
    }

    // Qt's wrapped implicitWidth would follow the toast's width, which follows the words' width: the words measure
    // single-line copies instead.
    function test_the_words_are_measured_on_single_line_copies_not_on_the_wrapped_text() {
        const toast = toaster.show("a long message body that says what happened in many words, and then some more", { title: "Mia" });
        const words = findChild(toast, "words");
        const message = findChild(toast, "message");
        const copy = findChild(toast, "messageLine");
        copy.text = "a copy of another length";
        compare(words.implicitWidth, copy.implicitWidth + message.leftPadding + message.rightPadding);
        copy.text = message.text;
        const natural = words.implicitWidth;
        toaster.width = 300;
        compare(words.implicitWidth, natural, "the toaster's width does not reach it");
        compare(message.lineCount, 2);
    }

    function test_without_a_title_the_text_has_no_limit_and_no_heading() {
        const long = "a long message body that says what happened in many words, and then some more words, so that it needs a third line to be said, and a fourth line besides, because a message may run on and on and on until nobody reads it to the end";
        const toast = toaster.show(long, {});
        verify(!findChild(toast, "title").visible);
        verify(findChild(toast, "message").lineCount > 2);
        verify(!findChild(toast, "message").truncated);
        compare(toast.Accessible.name, long);
    }

    function test_an_undo_toast_announces_its_window_after_the_whole_text() {
        const toast = toaster.show("3 messages deleted", { title: "Mail", undo: undoing("delete") });
        compare(toast.announcement, "Mail. 3 messages deleted, 5 seconds to undo");
    }

    function test_a_held_key_presses_the_text_once() {
        let presses = 0;
        const toast = toaster.show("see you soon", { open: { run: () => {} } });
        for (const isAutoRepeat of [false, true, true])
            toast.activateOnKey({ key: Qt.Key_Return, isAutoRepeat }, () => { presses++; });
        compare(presses, 1);
    }

    function test_a_text_without_open_is_plain_text_and_cannot_take_focus() {
        const toast = toaster.show("see you soon", { act: { label: "reply", run: () => {} } });
        const text = findChild(toast, "open");
        verify(!text.visible);
        verify(!text.activeFocusOnTab);
    }

    function test_a_press_on_the_text_runs_open_once_and_ends_the_toast_as_acted() {
        let runs = 0;
        const toast = toaster.show("see you soon", { title: "Mia", open: { run: () => { runs++; } }, onEnd: ending("toast") });
        mouseClick(findChild(toast, "open"));
        compare(runs, 1);
        compare(testCase.ends, ["toast acted"]);
    }

    function test_enter_and_space_on_the_text_run_open_once_each() {
        for (const key of [Qt.Key_Return, Qt.Key_Space])
            pressTextWith(key);
    }

    function pressTextWith(key) {
        let runs = 0;
        const toast = toaster.show("see you soon", { open: { run: () => { runs++; } }, onEnd: ending(`key ${key}`) });
        findChild(toast, "open").forceActiveFocus();
        verify(findChild(toast, "open").activeFocus);
        keyClick(key);
        compare(runs, 1);
        keyClick(key);
        compare(runs, 1, "the toast is going and takes no second press");
        toaster.leaving = 0;
    }

    function test_a_text_that_is_going_takes_no_press() {
        Prefs.motion = "on";
        let runs = 0;
        const toast = toaster.show("see you soon", { open: { run: () => { runs++; } }, onEnd: ending("toast") });
        tryCompare(toast, "y", toaster.rest, 1000);
        toaster.dismiss();
        verify(findChild(toast, "slidingOut").running);
        mouseClick(findChild(toast, "open"));
        compare(runs, 0);
        compare(testCase.ends, ["toast dismissed"]);
    }

    function test_the_text_control_tints_with_hover_and_carries_the_acts_focus_ring() {
        const toast = toaster.show("see you soon", { open: { run: () => {} } });
        const text = findChild(toast, "open");
        const tint = findChild(text, "press");
        compare(tint.opacity, 0);
        compare(tint.color, Tokens.color.hover);
        mouseMove(text, 20, 10);
        tryCompare(tint, "opacity", 1);
        text.forceActiveFocus(Qt.TabFocusReason);
        const ring = Array.from(text.children).find(child => child instanceof FocusRing);
        verify(ring.visible);
        compare(ring.offset, -Geometry.toastFocusInset);
        compare(ring.ink, findChild(toast, "message").color);
    }

    function test_the_text_comes_before_the_action_in_the_tab_order() {
        const toast = toaster.show("see you soon", { open: { run: () => {} }, act: { label: "reply", run: () => {} } });
        findChild(toast, "open").forceActiveFocus();
        verify(findChild(toast, "open").nextItemInFocusChain(true) === findChild(toast, "action"));
    }

    function test_a_toast_that_stays_does_not_run_out_and_has_no_countdown_line() {
        const toast = toaster.show("battery low", { stays: true, undo: undoing("x"), onEnd: ending("toast") });
        verify(!findChild(toast, "tick").running);
        verify(!findChild(toast, "line").visible);
        at(Tokens.durationToast * 10, toast);
        compare(toaster.open, toast);
        compare(testCase.ends, []);
    }

    function test_a_toast_that_stays_ends_by_escape_as_dismissed() {
        const toast = toaster.show("battery low", { stays: true, open: { run: () => {} }, onEnd: ending("toast") });
        findChild(toast, "open").forceActiveFocus();
        keyClick(Qt.Key_Escape);
        compare(testCase.ends, ["toast dismissed"]);
    }

    function test_a_toast_that_stays_ends_by_dismiss_and_by_its_action() {
        let toast = toaster.show("battery low", { stays: true, onEnd: ending("first") });
        toaster.dismiss();
        compare(testCase.ends, ["first dismissed"]);
        toaster.leaving = 0;
        toast = toaster.show("battery low", { stays: true, act: { label: "close", run: () => {} }, onEnd: ending("second") });
        mouseClick(findChild(toast, "action"));
        compare(testCase.ends, ["first dismissed", "second acted"]);
    }

    function test_a_new_toast_replaces_one_that_stays() {
        const first = toaster.show("battery low", { stays: true, onEnd: ending("first") });
        toaster.show("saved", {});
        compare(testCase.ends, ["first replaced"]);
    }

    // A toast at a fraction of a pixel is drawn blurred; pixel tests put it on the grid.
    function onWholePixels(toast) {
        toaster.width = toast.width + 200;
        compare(toast.x, 100);
    }

    function test_a_picture_in_the_icon_field_is_cropped_to_a_square_not_squeezed() {
        const toast = toaster.show("see you soon", { icon: testCase.widePicture });
        const picture = findChild(toast, "appIcon");
        tryCompare(picture, "status", Image.Ready);
        onWholePixels(toast);
        compare(picture.fillMode, Image.PreserveAspectCrop);
        compare(picture.width, 20);
        compare(picture.height, 20);
        waitForRendering(picture);
        const shot = grabImage(scene);
        const origin = picture.mapToItem(scene, 0, 0);
        for (const [x, y] of [[1, 1], [10, 10], [18, 18]])
            compare(shot.pixel(origin.x + x, origin.y + y), Qt.color("#3a76f0"), `pixel ${x},${y} is from the middle stripe`);
    }

    function test_the_picture_has_the_tile_s_corners_in_the_strip_s_own_ground() {
        const toast = toaster.show("see you soon", { icon: testCase.widePicture });
        const picture = findChild(toast, "appIcon");
        tryCompare(picture, "status", Image.Ready);
        onWholePixels(toast);
        compare(Tokens.radiusTile, 2);
        waitForRendering(picture);
        const shot = grabImage(scene);
        const origin = picture.mapToItem(scene, 0, 0);
        for (const [x, y] of [[0, 0], [19, 0], [0, 19], [19, 19]])
            verify(shot.pixel(origin.x + x, origin.y + y).g < 0.25, `corner ${x},${y} is cut to the ground, not the picture`);
        for (const [x, y] of [[2, 2], [17, 2], [2, 17], [17, 17], [10, 0], [0, 10]])
            compare(shot.pixel(origin.x + x, origin.y + y), Qt.color("#3a76f0"), `pixel ${x},${y} is picture`);
    }

    function test_a_toast_slides_in_whole_from_the_top_edge_without_a_fade_and_leaves_back_up() {
        Prefs.motion = "on";
        const toast = toaster.show("message archived", {});
        const slidingIn = findChild(toast, "slidingIn");
        compare(slidingIn.duration, 300);
        compare(slidingIn.easing.bezierCurve, Tokens.easePivotGlide);
        wait(slidingIn.duration / 2);
        verify(toast.y > -toast.height && toast.y < toaster.rest, `on its way: ${toast.y}`);
        compare(toast.opacity, 1, "no fade");
        tryCompare(toast, "y", toaster.rest, 1000);
        const slidingOut = findChild(toast, "slidingOut");
        compare(slidingOut.duration, 0.6 * 300);
        compare(slidingOut.easing.bezierCurve, Tokens.easeOut);
        toaster.dismiss();
        verify(slidingOut.running);
        tryVerify(() => toast.y <= -toast.height + 1 || toaster.leaving === 0, 1000, "whole above the edge");
        tryCompare(toaster, "leaving", 0, 1000);
    }

    function test_a_toast_starts_whole_above_the_top_edge() {
        Prefs.motion = "on";
        const toast = toaster.show("message archived", {});
        compare(toast.entry, 0);
        compare(toast.y, -toast.height);
    }

    function test_under_reduced_motion_toasts_come_and_go_at_once_and_the_window_still_runs() {
        const first = toaster.show("message archived", { undo: undoing("archive") });
        compare(first.y, toaster.rest);
        compare(findChild(first, "tick").interval, 1000, "the wall clock keeps running");
        compare(first.total, 5000);
        const second = toaster.show("message moved", {});
        verify(!second.waiting, "the first has gone at once");
        compare(second.y, toaster.rest);
        compare(toaster.leaving, 0);
    }

    function test_toasts_stay_on_their_layer_below_floating_surfaces_and_sheets() {
        compare(toaster.z, Tokens.layerToast);
        verify(toaster.z < Tokens.layerFloat);
        const sheetScene = createTemporaryObject(sheetSceneComponent, testCase);
        const below = findChild(sheetScene, "toaster");
        const toast = below.show("message archived", {});
        compare(toast.parent.parent, below, "it never moves to another layer");
        compare(sheetScene.childAt(toast.x + toast.width / 2, toast.y + toast.height / 2), findChild(sheetScene, "sheet"));
    }

    // The toasts follow the one current theme, so the sheet is drawn once per theme.
    function test_contact_sheet_of_toasts_and_banners_in_both_themes() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            testCase.time = 0;
            const sheet = createTemporaryObject(contactSheetComponent, testCase);
            const plain = findChild(sheet, "plain").show("see you soon", { icon: testCase.appIcon, act: { label: "reply", run: () => {} } });
            const undo = findChild(sheet, "undo").show("3 messages deleted", { undo: () => {} });
            testCase.time = 2000;
            undo.step();
            findChild(sheet, "error").show("could not save the schedule: the server is offline", { status: "error", act: { label: "retry", run: () => {} } });
            findChild(sheet, "focused").show("message archived", { undo: () => {} });
            findChild(findChild(sheet, "focused").open, "action").forceActiveFocus();
            const titled = findChild(sheet, "titled").show("Can we move the call to Thursday afternoon? I have the whole morning booked and the afternoon is free, so any time after lunch works.", { title: "Mia", icon: testCase.widePicture, open: { run: () => {} }, stays: true });
            findChild(sheet, "pressable").show("Backup finished", { title: "Backups", icon: testCase.appIcon, open: { run: () => {} }, act: { label: "show", run: () => {} } });
            findChild(findChild(sheet, "pressable").open, "open").forceActiveFocus(Qt.TabFocusReason);
            findChild(sheet, "neutral").set("offline", true, { since: false });
            const fiveAfterTwo = new Date();
            fiveAfterTwo.setHours(14, 5, 0, 0);
            findChild(sheet, "warning").set("paused", true, { since: fiveAfterTwo });
            findChild(sheet, "alert").set("halted", true, { since: false });
            tryCompare(findChild(plain, "appIcon"), "status", Image.Ready);
            tryCompare(findChild(titled, "appIcon"), "status", Image.Ready);
            waitForRendering(sheet);
            grabImage(sheet).save(`toast-sheet-${theme}.png`);
            compare(plain.y, 12, theme);
            sheet.destroy();
        }
    }

    Component {
        id: contactSheetComponent

        Rectangle {
            width: 800
            height: 760
            color: Tokens.color.bg

            Column {
                width: parent.width
                spacing: Tokens.spaceS

                Toaster {
                    objectName: "plain"
                    width: parent.width
                    clock: () => testCase.time
                }

                Toaster {
                    objectName: "undo"
                    width: parent.width
                    clock: () => testCase.time
                }

                Toaster {
                    objectName: "error"
                    width: parent.width
                    clock: () => testCase.time
                }

                Toaster {
                    objectName: "focused"
                    width: parent.width
                    clock: () => testCase.time
                }

                Toaster {
                    objectName: "titled"
                    width: parent.width
                    clock: () => testCase.time
                }

                Toaster {
                    objectName: "pressable"
                    width: parent.width
                    clock: () => testCase.time
                }

                Banner {
                    objectName: "neutral"
                    width: parent.width
                    bannerStates: ({ offline: { word: "offline", text: "Changes are kept on this device and sent when the connection is back." } })
                }

                Banner {
                    objectName: "warning"
                    width: parent.width
                    bannerStates: ({ paused: { word: "paused", status: "warning", text: "Runs wait until you resume them.", action: "resume" } })
                }

                Banner {
                    objectName: "alert"
                    width: parent.width
                    bannerStates: ({ halted: { word: "halted", status: "error", alert: true, text: "Every run has stopped: the job server does not answer.", action: "retry now" } })
                }
            }
        }
    }
}
