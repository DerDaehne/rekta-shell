pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import "../lockscreen/contents/lockscreen"

TestCase {
    id: testCase

    name: "LockScreen"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1920
    height: 1080

    // kscreenlocker's authenticator as the lock screen sees it: its properties, signals and calls. `calls` records the
    // calls in order: "start", "stop" or ["respond", text].
    Component {
        id: authenticatorComponent

        QtObject {
            property bool unlocked: false
            property bool inPasswordDelay: false
            property string prompt
            property string promptForSecret
            property string errorMessage
            property string infoMessage
            property var calls: []

            signal failed(int kind)
            signal succeeded

            function startAuthenticating() {
                calls.push("start");
            }

            function stopAuthenticating() {
                calls.push("stop");
            }

            function respond(text: string) {
                calls.push(["respond", text]);
            }
        }
    }

    // The lock screen of one monitor, wired as LockScreen.qml wires it to the greeter.
    Component {
        id: sceneComponent

        Item {
            id: scene

            property alias unlock: unlockFlow
            property alias face: lockFace
            property bool quit: false
            required property var authenticator

            width: 1920
            height: 1080

            Unlock {
                id: unlockFlow

                authenticator: scene.authenticator
                capsLock: lockFace.capsLock
                onRejected: lockFace.reject()
                onUnlocked: scene.quit = true
            }

            LockFace {
                id: lockFace

                anchors.fill: parent
                locale: Qt.locale("de_DE")
                now: new Date(2026, 9, 29, 14, 32)
                userName: "rekta"
                checking: unlockFlow.checking
                error: unlockFlow.error
                info: unlockFlow.info
                onSubmitted: secret => unlockFlow.submit(secret)
            }
        }
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var pam
    property var scene

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "off";
        pam = createTemporaryObject(authenticatorComponent, testCase);
        scene = createTemporaryObject(sceneComponent, testCase, {
            authenticator: pam
        });
        waitForRendering(scene);
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function part(name: string): var {
        return findChild(scene, name);
    }

    function input(): var {
        return findChild(part("password"), "input");
    }

    // PAM asks for the password, as its signal says each time.
    function ask() {
        pam.promptForSecret = "";
        pam.promptForSecret = "Password: ";
    }

    function type(text: string) {
        input().forceActiveFocus();
        for (const character of text)
            keyClick(character);
    }

    function responses(): var {
        return pam.calls.filter(call => Array.isArray(call));
    }

    function test_the_heartbeat_keeps_pam_asking_only_while_the_screen_shows() {
        const heartbeat = findChild(scene.unlock, "heartbeat");
        verify(!heartbeat.running, "not before the greeter shows the screen");
        scene.unlock.viewVisible = true;
        verify(heartbeat.running);
        tryVerify(() => pam.calls[0] === "start", 100, "at once");
        compare(heartbeat.interval, 1000);
        verify(heartbeat.repeat);
        pam.unlocked = true;
        verify(!heartbeat.running, "and no more once unlocked");
        // The stand-in goes first when the test ends; the real one lives as long as the greeter.
        scene.unlock.viewVisible = false;
    }

    function test_the_password_goes_to_pam_only_on_sending_never_when_pam_asks() {
        ask();
        type("geheim");
        compare(responses(), []);
        keyClick(Qt.Key_Return);
        compare(responses(), [["respond", "geheim"]]);
        ask();
        compare(responses().length, 1, "a new question is no answer");
    }

    function test_the_unlock_button_sends_the_password_too() {
        ask();
        type("geheim");
        mouseClick(part("unlock"));
        compare(responses(), [["respond", "geheim"]]);
    }

    function test_a_password_sent_before_pam_asks_waits_for_the_question() {
        type("geheim");
        keyClick(Qt.Key_Return);
        compare(responses(), []);
        verify(scene.unlock.checking);
        ask();
        compare(responses(), [["respond", "geheim"]]);
    }

    function test_a_question_asked_before_the_lock_screen_loaded_is_answered() {
        pam.promptForSecret = "Password: ";
        const later = createTemporaryObject(sceneComponent, testCase, {
            authenticator: pam
        });
        later.unlock.submit("geheim");
        compare(responses(), [["respond", "geheim"]]);
    }

    function test_a_password_sent_in_the_delay_after_a_failure_waits_for_its_end() {
        ask();
        pam.inPasswordDelay = true;
        scene.unlock.submit("geheim");
        compare(responses(), []);
        verify(scene.unlock.checking);
        pam.inPasswordDelay = false;
        compare(responses(), [["respond", "geheim"]]);
    }

    function test_a_wrong_password_says_cause_and_remedy_and_stays_all_selected() {
        ask();
        type("geheim");
        keyClick(Qt.Key_Return);
        pam.failed(0);
        verify(!scene.unlock.checking);
        compare(part("password").error, "Das Passwort stimmt nicht – bitte noch einmal eingeben.");
        compare(input().text, "geheim", "the input stays");
        compare(input().selectedText, "geheim", "all of it selected");
        verify(input().activeFocus);
        compare(pam.calls[pam.calls.length - 1], "start", "PAM asks again");
        keyClick(Qt.Key_X);
        compare(input().text, "x", "typing replaces it");
    }

    function test_with_caps_lock_on_a_wrong_password_names_it() {
        scene.face.capsLock = true;
        compare(part("password").hint, "Die Feststelltaste ist an.");
        ask();
        scene.unlock.submit("GEHEIM");
        pam.failed(0);
        compare(part("password").error, "Das Passwort stimmt nicht – die Feststelltaste ist an.");
    }

    function test_pam_says_its_own_errors_and_information_at_the_field() {
        pam.infoMessage = "Noch 3 Versuche.";
        compare(part("password").hint, "Noch 3 Versuche.");
        pam.errorMessage = "Das Konto ist gesperrt.";
        compare(part("password").error, "Das Konto ist gesperrt.", "as it comes, outside a check");
        ask();
        scene.unlock.submit("geheim");
        compare(part("password").error, "", "a check starts without the old error");
        pam.errorMessage = "Das Konto ist abgelaufen.";
        pam.failed(0);
        compare(part("password").error, "Das Konto ist abgelaufen.", "PAM's words over the shell's");
    }

    function test_a_failing_fingerprint_reader_shows_nothing() {
        ask();
        scene.unlock.submit("geheim");
        pam.failed(1);
        verify(scene.unlock.checking);
        compare(part("password").error, "");
    }

    function test_success_stops_asking_and_quits() {
        ask();
        scene.unlock.submit("geheim");
        pam.succeeded();
        compare(pam.calls[pam.calls.length - 1], "stop");
        verify(scene.quit);
    }

    function test_while_checking_field_and_button_take_nothing() {
        ask();
        type("geheim");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_X);
        compare(input().text, "geheim", "the field takes no typing");
        mouseClick(part("unlock"));
        ask();
        compare(responses().length, 1, "the button sends nothing more");
    }

    function test_the_dots_run_under_the_field_as_wide_as_it_and_above_the_button_only_while_checking() {
        Prefs.motion = "on";
        waitForRendering(scene);
        const field = part("password"), dots = part("dots"), button = part("unlock");
        const flying = () => Array.from(dots.children).filter(child => child.position !== undefined).length;
        verify(!dots.running);
        compare(flying(), 0, "resting, no dot exists");
        scene.unlock.submit("geheim");
        waitForRendering(scene);
        verify(dots.running);
        compare(flying(), Geometry.dotCount);
        compare(dots.height, Geometry.dotSize);
        compare(dots.width, field.width);
        compare(dots.width, 2 * Tokens.tileUnit + Tokens.spaceS);
        const fieldBottom = field.mapToItem(scene, 0, field.height).y;
        const dotsTop = dots.mapToItem(scene, 0, 0).y;
        compare(dotsTop - fieldBottom, Tokens.spaceS);
        compare(button.mapToItem(scene, 0, 0).y - (dotsTop + dots.height), Tokens.spaceS);
        compare(dots.mapToItem(scene, 0, 0).x, field.mapToItem(scene, 0, 0).x);
    }

    function test_field_and_button_stay_where_they_are_when_the_check_starts() {
        Prefs.motion = "on";
        waitForRendering(scene);
        const field = part("password"), button = part("unlock");
        const fieldAt = field.mapToItem(scene, 0, 0), buttonAt = button.mapToItem(scene, 0, 0);
        scene.unlock.submit("geheim");
        waitForRendering(scene);
        compare(field.mapToItem(scene, 0, 0), fieldAt);
        compare(button.mapToItem(scene, 0, 0), buttonAt);
    }

    function test_under_reduced_motion_the_dots_stand_with_words_and_every_end_state_is_reached() {
        scene.face.active = false;
        compare(findChild(scene.face, "rest").opacity, 0, "the rest is gone at once");
        compare(part("clock").shrink, part("clock").ratio);
        scene.face.active = true;
        compare(part("clock").shrink, 1, "the clock is whole at once");
        compare(findChild(scene.face, "rest").opacity, 1);
        scene.unlock.submit("geheim");
        const dots = part("dots");
        const words = Array.from(dots.children).find(child => child.text === "wird geprüft …");
        verify(words.visible, "the dots say what happens");
        const standing = Array.from(dots.children).filter(child => child.position !== undefined);
        compare(standing.length, Geometry.dotCount);
        for (const dot of standing)
            compare(dot.x, dots.width / 2 - Geometry.dotRestOffset + dot.index * Geometry.dotRestSpacing, "middle");
    }

    function test_the_clock_stands_top_left_twice_as_large_as_a_navigation_title_with_the_long_date_below() {
        const clock = part("clock"), date = part("date");
        compare(clock.text, "14:32");
        compare(clock.x, Tokens.spaceXl);
        compare(clock.y, Tokens.spaceXl);
        compare(clock.font.pixelSize, Math.floor(2 * Tokens.fluid(Tokens.fontSizeNavActive, 1920)));
        compare(clock.font.pixelSize, 144, "at 1920 px");
        compare(clock.font.weight, Tokens.fontWeightLight);
        compare(date.text, "donnerstag, 29. oktober");
        compare(date.x, Tokens.spaceXl);
        compare(date.y, clock.y + clock.height);
        compare(Calendar.longDateWords(new Date(2026, 9, 29), Qt.locale("en_US")), "thursday, october 29");
    }

    function test_another_monitor_shows_the_clock_alone_as_the_inactive_title_which_grows_when_it_becomes_active() {
        Prefs.motion = "on";
        waitForRendering(scene);
        const clock = part("clock"), rest = findChild(scene.face, "rest");
        scene.face.active = false;
        tryCompare(rest, "opacity", 0);
        verify(!rest.enabled, "the hidden parts take nothing");
        const ratio = Tokens.fluid(Tokens.fontSizeNavInactive, 1920) / Tokens.fluid(Tokens.fontSizeNavActive, 1920);
        tryCompare(clock, "shrink", ratio);
        compare(clock.color, Tokens.color.textContrastMedium);
        scene.face.active = true;
        wait(Tokens.durationPivotSize / 2);
        verify(clock.shrink > clock.ratio && clock.shrink < 1, "it grows, not jumps");
        tryCompare(clock, "shrink", 1);
        tryCompare(rest, "opacity", 1);
        verify(input().activeFocus, "the field takes the keyboard");
    }

    function test_the_name_and_field_stand_bottom_left_and_switch_user_bottom_right() {
        const name = part("name"), signIn = part("signIn"), corner = part("corner");
        compare(name.text, "rekta");
        compare(name.font.weight, Tokens.fontWeightLight);
        compare(signIn.x, Tokens.spaceXl);
        compare(signIn.y + signIn.height, scene.height - Tokens.spaceXl);
        compare(part("password").label, "passwort");
        compare(input().echoMode, TextInput.Password);
        compare(part("unlock").variant, "primary");
        compare(corner.x + corner.width, scene.width - Tokens.spaceXl);
        compare(corner.y + corner.height, scene.height - Tokens.spaceXl);
        const switchUser = part("switchUser");
        compare(switchUser.variant, "quiet");
        compare(switchUser.text, "benutzer wechseln");
        const bottomRight = Qt.point(scene.width - Tokens.spaceXl, scene.height - Tokens.spaceXl);
        compare(switchUser.mapToItem(scene, switchUser.width, switchUser.height), bottomRight);
        verify(!part("status").visible, "the empty status area takes no room");
        scene.face.canSwitchUser = false;
        verify(!switchUser.visible);
    }

    function test_the_layouts_stand_beside_the_field_level_with_its_input_only_when_there_are_several() {
        const layouts = part("layouts"), field = part("password");
        scene.face.layouts = ["de"];
        verify(!layouts.visible);
        scene.face.layouts = ["de", "us"];
        scene.face.layoutIndex = 1;
        verify(layouts.visible);
        compare(layouts.currentIndex, 1);
        compare(layouts.x, field.width + Tokens.spaceM);
        compare(layouts.mapToItem(scene, 0, 0).y, findChild(field, "box").mapToItem(scene, 0, 0).y);
        let chosen = -1;
        scene.face.layoutChosen.connect(index => chosen = index);
        layouts.choose(0);
        compare(chosen, 0);
    }

    // Each theme on a fresh lock screen: resting with two layouts, a refused password, and another monitor.
    function test_contact_sheet_in_both_themes() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            pam = createTemporaryObject(authenticatorComponent, testCase);
            scene = createTemporaryObject(sceneComponent, testCase, {
                authenticator: pam
            });
            scene.face.layouts = ["de", "us"];
            waitForRendering(scene);
            grabImage(scene).save(`lockscreen-sheet-${theme}.png`);
            ask();
            type("geheim");
            keyClick(Qt.Key_Return);
            pam.failed(0);
            waitForRendering(scene);
            grabImage(scene).save(`lockscreen-sheet-${theme}-error.png`);
            scene.face.active = false;
            waitForRendering(scene);
            grabImage(scene).save(`lockscreen-sheet-${theme}-other-monitor.png`);
            verify(scene.height > 0, theme);
        }
    }
}
