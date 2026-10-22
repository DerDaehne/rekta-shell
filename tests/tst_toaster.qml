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
    height: 600

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
        compare(toast.height, Math.max(Tokens.controlHeight + Tokens.spaceXs, findChild(toast, "message").height));
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
        compare(message.x + message.leftPadding, Tokens.spaceM + 20 + Tokens.spaceS);
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
            findChild(sheet, "neutral").set("offline", true, { since: false });
            const fiveAfterTwo = new Date();
            fiveAfterTwo.setHours(14, 5, 0, 0);
            findChild(sheet, "warning").set("paused", true, { since: fiveAfterTwo });
            findChild(sheet, "alert").set("halted", true, { since: false });
            tryCompare(findChild(plain, "appIcon"), "status", Image.Ready);
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
            height: 600
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
