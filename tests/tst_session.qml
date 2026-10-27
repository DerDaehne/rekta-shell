pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Session

TestCase {
    id: testCase

    name: "Session"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 640

    readonly property string seat: "/org/freedesktop/DisplayManager/Seat0"
    // What the actions asked the launcher for, oldest first: ["run", command], ["launch", id] or
    // ["call", bus, service, path, interface, method].
    property var asked: []
    // The replies to a lock and to the question whether the session is locked, which the launcher holds back until the
    // test gives them: reply(error, values).
    property var lockReply: null
    property var activeReply: null
    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var scene
    property var sessionBanner

    // Records what it is asked for instead of acting; a lock and the question whether it holds wait for their replies.
    component Recorder: QtObject {
        function run(command) {
            testCase.asked = [...testCase.asked, ["run", command]];
        }

        function launch(entry) {
            testCase.asked = [...testCase.asked, ["launch", entry.id]];
        }

        function call(onSystemBus, service, path, iface, method, done) {
            testCase.asked = [...testCase.asked, ["call", onSystemBus ? "system" : "session", service, path, iface, method]];
            if (method === "Lock")
                testCase.lockReply = done;
            else if (method === "GetActive")
                testCase.activeReply = done;
            else
                done?.(null, []);
        }
    }

    Component {
        id: sceneComponent

        // The banner over a place with the control that opened it.
        Item {
            property alias seatPath: sessionActions.seatPath
            property alias systemMonitor: sessionActions.systemMonitor

            width: 900
            height: 600

            Rectangle {
                anchors.fill: parent
                color: Tokens.color.bg

                Title {
                    x: Tokens.spaceL
                    y: 2 * Tokens.spaceXl
                    text: "nightly builds"
                }

                Button {
                    objectName: "opener"
                    x: Tokens.spaceL
                    y: 300
                    text: "steuerung"
                }
            }

            Recorder {
                id: recorder
            }

            Toaster {
                id: toastRegion

                objectName: "toaster"
                width: parent.width
            }

            SessionActions {
                id: sessionActions

                objectName: "sessionActions"

                launcher: recorder
                toaster: toastRegion
                seatPath: testCase.seat
                systemMonitor: ({
                        id: "org.kde.plasma-systemmonitor"
                    })
            }

            SessionBanner {
                objectName: "sessionBanner"
                anchors.fill: parent
                actions: sessionActions.actions
            }
        }
    }

    Component {
        id: spyComponent

        SignalSpy {}
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "off";
        asked = [];
        lockReply = null;
        activeReply = null;
        scene = createTemporaryObject(sceneComponent, testCase);
        sessionBanner = findChild(scene, "sessionBanner");
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

    function button(name: string): var {
        return findChild(sessionBanner, name);
    }

    function part(name: string): var {
        return findChild(sessionBanner, name);
    }

    readonly property var actionNames: ["lock", "switchUser", "logout", "reboot", "shutdown", "systemMonitor"]

    // The call each action makes, as the recorder writes it down.
    function callOf(service, path, iface, method, bus) {
        return ["call", bus ?? "session", service, path, iface, method];
    }

    readonly property var lockCall: callOf("org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", "Lock")
    readonly property var activeCall: callOf("org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", "GetActive")
    readonly property var greeterCall: callOf("org.freedesktop.DisplayManager", seat, "org.freedesktop.DisplayManager.Seat", "SwitchToGreeter", "system")

    function test_it_shows_the_word_sitzung_and_the_six_actions_with_sperren_primary_and_holding_the_focus() {
        sessionBanner.show("");
        compare(part("word").text, "sitzung");
        compare(actionNames.map(name => button(name).text), ["sperren", "benutzer wechseln", "abmelden", "neu starten", "ausschalten", "systemmonitor"]);
        compare(button("lock").variant, "primary");
        for (const name of actionNames.slice(1))
            compare(button(name).variant, "quiet", name);
        verify(button("lock").activeFocus);
        compare(part("banner").Accessible.role, Accessible.Dialog);
        compare(part("banner").Accessible.name, "sitzung");
    }

    function test_it_spans_the_top_on_surface_in_a_banners_geometry_with_a_hairline_below() {
        sessionBanner.show("");
        waitForRendering(sessionBanner);
        const banner = part("banner");
        const word = part("word");
        const actions = part("actions");
        compare(banner.x, 0);
        compare(banner.y, 0);
        compare(banner.width, 900, "full bleed");
        compare(banner.color, Tokens.color.surface);
        compare(word.x, Tokens.spaceXl, "space-xl at the sides of a sideways screen (rekta.css:1105)");
        compare(word.font.pixelSize, Math.floor(Tokens.fluid(Tokens.fontSizeL, 900)));
        compare(word.font.weight, Tokens.fontWeightLight);
        compare(actions.x, Tokens.spaceXl + Math.max(Tokens.tileUnit, word.implicitWidth) + Tokens.spaceS, "the actions from tile column 2");
        compare(actions.width, 900 - actions.x - Tokens.spaceXl);
        const lock = button("lock");
        compare(word.y + word.baselineOffset, actions.y + lock.mapToItem(actions, 0, 0).y + lock.baselineOffset, "word and buttons share a baseline");
        const top = Math.min(word.y, actions.y);
        compare(top, Tokens.spaceM, "space-m above");
        const hairline = part("hairline");
        compare(hairline.color, Tokens.color.textContrastLow);
        compare(hairline.height, Geometry.hairline);
        compare(hairline.y, banner.height - Geometry.hairline, "at the bottom edge");
        compare(banner.height, Math.max(word.y + word.height, actions.y + actions.height) + Tokens.spaceM + Geometry.hairline, "space-m below");
    }

    function test_the_rest_of_the_screen_lies_under_the_shading() {
        sessionBanner.show("");
        const shading = part("shading");
        compare(shading.color, Tokens.color.shading);
        compare(shading.width, 900);
        compare(shading.height, 600);
        compare(shading.opacity, 1);
    }

    function test_too_narrow_for_one_line_the_actions_wrap_below_one_another() {
        scene.width = 640;
        sessionBanner.show("");
        waitForRendering(sessionBanner);
        const actions = part("actions");
        verify(button("systemMonitor").y > button("lock").y, "the last button on a line of its own");
        verify(button("systemMonitor").x + button("systemMonitor").width <= actions.width);
        compare(part("banner").height, actions.y + actions.height + Tokens.spaceM + Geometry.hairline, "the banner grows with them");
    }

    function test_it_comes_in_once_8px_with_a_fade_over_duration_short_and_the_shading_fades_in_alongside() {
        Prefs.motion = "on";
        const comingIn = part("comingIn");
        compare(comingIn.duration, Tokens.durationShort);
        compare(comingIn.easing.type, Easing.Bezier);
        compare(comingIn.easing.bezierCurve, Tokens.easeIn);
        compare(part("shadingIn").duration, Tokens.durationShort);
        sessionBanner.show("");
        compare(sessionBanner.entry, 0, "the banner starts away");
        compare(sessionBanner.shade, 0, "and the shading clear");
        sessionBanner.entry = 0.5;
        sessionBanner.shade = 0.5;
        const banner = part("banner");
        compare(banner.opacity, 0.5);
        compare(banner.mapToItem(sessionBanner, 0, 0).y, -Geometry.bannerShift / 2, "from 8px above");
        compare(part("shading").opacity, 0.5);
        tryCompare(sessionBanner, "entry", 1, Tokens.durationShort * 4);
        tryCompare(sessionBanner, "shade", 1, Tokens.durationShort * 4);
        compare(banner.mapToItem(sessionBanner, 0, 0).y, 0);
    }

    function test_it_leaves_the_way_it_came_in_0_8_duration_short_with_ease_out_and_is_closed_once_gone() {
        Prefs.motion = "on";
        const goingUp = part("goingUp");
        compare(goingUp.duration, 0.8 * Tokens.durationShort);
        compare(goingUp.easing.type, Easing.Bezier);
        compare(goingUp.easing.bezierCurve, Tokens.easeOut);
        compare(part("shadingOut").duration, 0.8 * Tokens.durationShort);
        const closed = createTemporaryObject(spyComponent, testCase, {
            target: sessionBanner,
            signalName: "closed"
        });
        sessionBanner.show("");
        tryCompare(sessionBanner, "entry", 1, Tokens.durationShort * 4);
        sessionBanner.close();
        verify(sessionBanner.open, "it is open while it leaves");
        tryVerify(() => part("banner").mapToItem(sessionBanner, 0, 0).y < 0, Tokens.durationShort * 4, "back up");
        tryCompare(closed, "count", 1, Tokens.durationShort * 4);
        verify(!sessionBanner.open);
        verify(!sessionBanner.visible);
        compare(sessionBanner.entry, 0);
        compare(sessionBanner.shade, 0);
    }

    function test_shown_again_while_it_leaves_it_comes_back() {
        Prefs.motion = "on";
        sessionBanner.show("");
        tryCompare(sessionBanner, "entry", 1, Tokens.durationShort * 4);
        sessionBanner.close();
        sessionBanner.show("logout");
        tryCompare(sessionBanner, "entry", 1, Tokens.durationShort * 4);
        wait(Tokens.durationShort);
        verify(sessionBanner.open, "it stays");
        verify(button("logout").activeFocus);
    }

    function test_under_reduced_motion_banner_and_shading_stand_at_once_and_go_at_once() {
        Prefs.motion = "off";
        sessionBanner.show("");
        compare(sessionBanner.entry, 1, "in at once");
        compare(part("banner").opacity, 1);
        compare(part("banner").mapToItem(sessionBanner, 0, 0).y, 0);
        compare(part("shading").opacity, 1);
        sessionBanner.close();
        verify(!sessionBanner.open, "gone at once, never skipped");
        verify(!sessionBanner.visible);
    }

    function test_shown_for_an_action_the_focus_starts_on_it_and_for_any_other_name_on_sperren() {
        for (const name of actionNames) {
            sessionBanner.show(name);
            verify(button(name).activeFocus, name);
            sessionBanner.close();
        }
        sessionBanner.show("all");
        verify(button("lock").activeFocus, "all");
    }

    function test_escape_closes_it_and_the_focus_goes_back_to_where_it_was() {
        sessionBanner.show("");
        verify(!named("opener").activeFocus, "the banner holds the focus");
        keyClick(Qt.Key_Escape);
        verify(!sessionBanner.open);
        verify(named("opener").activeFocus, "and gives it back");
        compare(asked, [], "nothing acted");
    }

    function test_back_closes_it_by_key_and_by_the_pointers_back_button() {
        sessionBanner.show("");
        keyClick(Qt.Key_Back);
        verify(!sessionBanner.open, "the Back key");
        verify(named("opener").activeFocus);
        sessionBanner.show("");
        mouseClick(part("banner"), 10, 10, Qt.BackButton);
        verify(!sessionBanner.open, "the back button, also over the banner");
        verify(named("opener").activeFocus);
    }

    function test_a_press_on_the_shading_closes_it_and_one_on_the_banner_does_not() {
        const opener = named("opener");
        const clicked = createTemporaryObject(spyComponent, testCase, {
            target: opener,
            signalName: "clicked"
        });
        sessionBanner.show("");
        waitForRendering(sessionBanner);
        const banner = part("banner");
        mouseClick(banner, banner.width - 4, banner.height - 4);
        verify(sessionBanner.open, "a press on the banner beside the buttons");
        mouseClick(sessionBanner, opener.x + opener.width / 2, opener.y + opener.height / 2);
        verify(!sessionBanner.open, "a press on the shading");
        compare(clicked.count, 0, "nothing behind it reacts");
        verify(opener.activeFocus, "the focus goes back");
        compare(asked, []);
    }

    function test_the_arrows_and_tab_go_round_the_buttons() {
        sessionBanner.show("");
        for (let k = 1; k <= actionNames.length; k++) {
            keyClick(Qt.Key_Right);
            verify(button(actionNames[k % actionNames.length]).activeFocus, `→ to ${actionNames[k % actionNames.length]}`);
        }
        keyClick(Qt.Key_Left);
        verify(button("systemMonitor").activeFocus, "← from the first to the last");
        keyClick(Qt.Key_Left);
        verify(button("shutdown").activeFocus, "← to the one before");
        sessionBanner.close();
        sessionBanner.show("");
        for (let k = 1; k < actionNames.length; k++) {
            keyClick(Qt.Key_Tab);
            verify(button(actionNames[k]).activeFocus, `Tab to ${actionNames[k]}`);
        }
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        verify(button("shutdown").activeFocus, "Shift+Tab back");
        verify(sessionBanner.open, "and it stays open");
    }

    function test_every_action_acts_from_the_keyboard_and_the_banner_goes() {
        for (let k = 0; k < actionNames.length; k++) {
            sessionBanner.show("");
            for (let step = 0; step < k; step++)
                keyClick(Qt.Key_Right);
            keyClick(k % 2 === 0 ? Qt.Key_Return : Qt.Key_Space);
            verify(!sessionBanner.open, actionNames[k]);
        }
        lockReply(null);
        activeReply(null, [true]);
        compare(asked, [["run", ["loginctl", "lock-session"]], lockCall, callOf("org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logout"), callOf("org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logoutAndReboot"), callOf("org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logoutAndShutdown"), ["launch", "org.kde.plasma-systemmonitor"], activeCall, greeterCall]);
    }

    function test_a_click_acts_and_the_banner_goes() {
        sessionBanner.show("");
        waitForRendering(sessionBanner);
        mouseClick(button("logout"));
        verify(!sessionBanner.open);
        compare(asked, [callOf("org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logout")]);
    }

    function test_each_action_calls_exactly_its_command_or_method() {
        const expected = {
            lock: [["run", ["loginctl", "lock-session"]]],
            logout: [callOf("org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logout")],
            reboot: [callOf("org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logoutAndReboot")],
            shutdown: [callOf("org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logoutAndShutdown")],
            systemMonitor: [["launch", "org.kde.plasma-systemmonitor"]]
        };
        for (const name of Object.keys(expected)) {
            asked = [];
            button(name).click();
            compare(asked, expected[name], name);
        }
    }

    function test_starting_the_system_monitor_says_an_app_has_started() {
        const launched = createTemporaryObject(spyComponent, testCase, {
            target: findChild(scene, "sessionActions"),
            signalName: "launched"
        });
        button("lock").click();
        compare(launched.count, 0, "a lock starts no app");
        button("systemMonitor").click();
        compare(launched.count, 1);
    }

    function sessionActions(): var {
        return named("sessionActions");
    }

    function toastSays(): string {
        const toast = named("toaster").open;
        return toast ? `${toast.status}: ${toast.text}` : "none";
    }

    function test_choosing_benutzer_wechseln_takes_the_shading_away_at_once_and_the_banner_leaves_as_a_sheet_does() {
        Prefs.motion = "on";
        sessionBanner.show("");
        tryCompare(sessionBanner, "entry", 1, Tokens.durationShort * 4);
        button("switchUser").click();
        verify(!sessionBanner.shaded, "the host's blur goes with it");
        verify(!part("shading").visible, "in the same frame, without a fade");
        verify(sessionBanner.open, "the banner is still on its way up");
        tryVerify(() => part("banner").mapToItem(sessionBanner, 0, 0).y < 0, Tokens.durationShort * 4, "back up, as a sheet leaves");
        tryVerify(() => !sessionBanner.open, Tokens.durationShort * 4);
        sessionBanner.show("");
        verify(sessionBanner.shaded && part("shading").visible, "shown again, it is shaded again");
    }

    function test_the_other_actions_leave_the_shading_to_fade_with_the_banner() {
        Prefs.motion = "on";
        for (const name of ["lock", "logout", "reboot", "shutdown", "systemMonitor"]) {
            sessionBanner.show("");
            tryCompare(sessionBanner, "entry", 1, Tokens.durationShort * 4);
            button(name).click();
            verify(part("shading").visible && sessionBanner.shaded, name);
            tryVerify(() => !sessionBanner.open, Tokens.durationShort * 4);
        }
    }

    function test_the_windows_step_back_at_rektas_pace_while_the_session_is_still_open_and_only_then_it_locks() {
        Prefs.motion = "on";
        button("switchUser").click();
        verify(sessionActions().leaving, "the host shows its clear surface");
        verify(sessionActions().windowsBack, "holding the keyboard, so the windows step back");
        wait(0.8 * Tokens.durationModerate);
        compare(asked, [], "nothing is locked while they step back, in a whole duration-moderate");
        tryCompare(testCase, "asked", [lockCall], Tokens.durationModerate);
        verify(sessionActions().windowsBack, "they stand back while it locks");
    }

    function test_it_locks_then_asks_whether_the_session_is_locked_and_only_then_asks_for_the_greeter_of_its_seat() {
        button("switchUser").click();
        compare(asked, [lockCall], "the lock alone, until it is done");
        lockReply(null, []);
        compare(asked, [lockCall, activeCall], "then whether it holds, until that is answered");
        activeReply(null, [true]);
        compare(asked, [lockCall, activeCall, greeterCall], "then the greeter, on the system bus, at the seat's path");
        verify(!sessionActions().leaving, "the surface goes under the lock");
        verify(!sessionActions().windowsBack, "and the windows stand in front again for whoever comes back");
        compare(toastSays(), "none");
    }

    function test_when_the_session_does_not_lock_it_stays_the_windows_come_forward_and_a_toast_says_why() {
        Prefs.motion = "on";
        const failures = {
            "the lock fails": [["org.freedesktop.DBus.Error.ServiceUnknown: no screen locker"]],
            "the lock does not hold": [[null, []], [null, [false]]],
            "the question fails": [[null, []], ["org.freedesktop.DBus.Error.NoReply: no answer", []]]
        };
        for (const [failure, replies] of Object.entries(failures)) {
            asked = [];
            named("toaster").dismiss();
            button("switchUser").click();
            tryCompare(testCase, "asked", [lockCall], Tokens.durationModerate * 3, failure);
            lockReply(...replies[0]);
            if (replies.length > 1)
                activeReply(...replies[1]);
            verify(!asked.some(call => call[5] === "SwitchToGreeter"), `${failure}: no greeter`);
            verify(!sessionActions().windowsBack, `${failure}: the surface hands the keyboard over`);
            verify(sessionActions().leaving, `${failure}: and stays while the windows come forward`);
            compare(toastSays(), "error: nicht gewechselt: die sitzung ließ sich nicht sperren.", failure);
            tryCompare(sessionActions(), "leaving", false, Tokens.durationModerate * 3, failure);
        }
    }

    function test_under_reduced_motion_nothing_moves_and_the_lock_follows_at_once() {
        Prefs.motion = "off";
        button("switchUser").click();
        verify(sessionActions().windowsBack, "the windows stand back at once");
        compare(asked, [lockCall], "and the lock follows at once");
        lockReply("org.freedesktop.DBus.Error.ServiceUnknown: no screen locker");
        verify(!sessionActions().leaving, "failed, the windows stand in front at once");
        compare(toastSays(), "error: nicht gewechselt: die sitzung ließ sich nicht sperren.");
        asked = [];
        button("switchUser").click();
        lockReply(null, []);
        activeReply(null, [true]);
        compare(asked, [lockCall, activeCall, greeterCall]);
        verify(!sessionActions().leaving);
    }

    function test_without_a_seat_benutzer_wechseln_cannot_act_and_says_why() {
        scene.seatPath = "";
        sessionBanner.show("switchUser");
        const switchUser = button("switchUser");
        compare(switchUser.disabledReason, "Der Anmeldemanager bietet keinen Wechsel an.");
        verify(switchUser.activeFocus, "it stays focusable");
        keyClick(Qt.Key_Return);
        switchUser.click();
        compare(asked, [], "it does nothing");
        verify(sessionBanner.open, "and the banner stays");
        const why = part("why");
        verify(why.visible);
        compare(why.text, "Der Anmeldemanager bietet keinen Wechsel an.");
        waitForRendering(sessionBanner);
        const last = button("systemMonitor");
        compare(why.x, last.x + last.width + Tokens.spaceS, "after the last button, never over them");
    }

    function test_without_the_system_monitor_its_button_cannot_act_and_says_why() {
        scene.systemMonitor = null;
        sessionBanner.show("systemMonitor");
        compare(button("systemMonitor").disabledReason, "Der Systemmonitor ist nicht installiert.");
        keyClick(Qt.Key_Space);
        compare(asked, []);
        verify(sessionBanner.open);
        compare(part("why").text, "Der Systemmonitor ist nicht installiert.");
    }

    function test_contact_sheet_of_the_banner_in_both_themes() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            Prefs.density = "compact";
            sessionBanner.show("");
            waitForRendering(scene);
            grabImage(scene).save(`session-sheet-${theme}.png`);
            scene.seatPath = "";
            scene.systemMonitor = null;
            waitForRendering(scene);
            grabImage(scene).save(`session-sheet-${theme}-unavailable.png`);
            scene.seatPath = seat;
            scene.systemMonitor = {
                id: "org.kde.plasma-systemmonitor"
            };
            sessionBanner.close();
            verify(!sessionBanner.open, theme);
        }
    }
}
