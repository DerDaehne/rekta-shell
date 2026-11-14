pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import DBusCounterpart
import Rekta
import "../lockscreen/contents/lockscreen"
import "ContactSheets.js" as ContactSheets

TestCase {
    id: testCase

    name: "LockScreen"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1920
    height: 1080

    // kscreenlocker 6.8.0's authenticator as the lock screen sees it. Like its PamAuthenticator, it signals a question
    // before the question can take an answer, so an answer given inside that signal's handler finds no question and is
    // lost, as is any answer without one. It never signals `inPasswordDelay`: a stand-in keeps the value it was made
    // with. `calls` records the calls in order: "start", "stop", ["respond", text], or ["lost", text].
    Component {
        id: authenticatorComponent

        QtObject {
            property bool unlocked: false
            property bool inPasswordDelay: false
            property string prompt
            property string promptForSecret
            property string errorMessage
            property string infoMessage
            property bool waiting: false
            property var calls: []
            property bool announced: false

            signal failed(int kind)
            signal succeeded

            // Like PamAuthenticators, which queues this in its constructor: once the event loop runs, after the lock
            // screen has loaded, both questions are signalled, still without words.
            Component.onCompleted: Qt.callLater(announce)

            function announce() {
                promptChanged();
                promptForSecretChanged();
                announced = true;
            }

            // The signal comes each time, with the same words or not, and only then does the question wait.
            function ask(question: string) {
                if (promptForSecret === question)
                    promptForSecretChanged();
                else
                    promptForSecret = question;
                waiting = true;
            }

            function succeed() {
                unlocked = true;
                succeeded();
            }

            function startAuthenticating() {
                calls.push("start");
            }

            function stopAuthenticating() {
                calls.push("stop");
            }

            function respond(text: string) {
                if (!waiting) {
                    console.warn("Received prompt response, but no pending prompt was found!");
                    calls.push(["lost", text]);
                    return;
                }
                waiting = false;
                calls.push(["respond", text]);
            }
        }
    }

    // Plasma 6.8.0's MultiplexerModel as the lock screen sees it: no row without a player, else one row for the player
    // it follows, with its title, artist and status in the values of Mpris.PlaybackStatus (playercontainer.h).
    readonly property var playback: ({ stopped: 1, playing: 2, paused: 3 })

    ListModel {
        id: players
    }

    NowPlaying {
        id: nowPlaying

        model: players
        playingStatus: testCase.playback.playing
    }

    // What LockScreen.qml takes the player from.
    Component {
        id: playingComponent

        Playing {}
    }

    // The rekta shell's end of the count of new notifications. Made at run time: a second run of these tests goes without
    // RektaShell.DBus, and then the component stands in error.
    readonly property Component shellComponent: Qt.createComponent(Qt.resolvedUrl("../shell/services/NoticeCount.qml"))
    readonly property bool hasDBus: shellComponent.status === Component.Ready

    // What LockScreen.qml takes the count from.
    Component {
        id: unseenComponent

        Unseen {}
    }

    Component {
        id: countComponent

        UnseenCount {}
    }

    Counterpart {
        id: counterpart
    }

    function play(track: string, artist: string, status: int) {
        players.clear();
        players.append({ track: track, artist: artist, playbackStatus: status });
    }

    // The lock screen of one monitor, wired to the shared flow and the player as LockScreen.qml wires it.
    Component {
        id: faceComponent

        LockFace {
            id: lockFace

            width: 1920
            height: 1080
            locale: Qt.locale("de_DE")
            now: new Date(2026, 9, 29, 14, 32)
            userName: "rekta"
            checking: Unlock.checking
            error: Unlock.error
            info: Unlock.info
            playingTitle: nowPlaying.title
            playingArtist: nowPlaying.artist
            onSubmitted: secret => Unlock.submit(secret, lockFace.capsLock)
        }
    }

    SignalSpy {
        id: unlockedSpy

        target: Unlock
        signalName: "unlocked"
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var pam
    property var face

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop|no pending prompt/);
        Prefs.motion = "off";
        unlockedSpy.clear();
        pam = createTemporaryObject(authenticatorComponent, testCase);
        Unlock.authenticator = pam;
        face = createTemporaryObject(faceComponent, testCase);
        waitForRendering(face);
    }

    // The stand-ins go when the test ends; the real authenticator lives as long as the greeter.
    function cleanup() {
        players.clear();
        counterpart.releaseName("rekta.Shell");
        counterpart.releaseName("org.example.Other");
        Unlock.shown = false;
        Unlock.authenticator = null;
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function part(name: string): var {
        return findChild(face, name);
    }

    function input(): var {
        return findChild(part("password"), "input");
    }

    function ask() {
        pam.ask("Password: ");
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
        const heartbeat = findChild(Unlock, "heartbeat");
        verify(!heartbeat.running, "not before the greeter shows the screen");
        Unlock.shown = true;
        verify(heartbeat.running);
        tryVerify(() => pam.calls[0] === "start", 100, "at once");
        compare(heartbeat.interval, 1000);
        verify(heartbeat.repeat);
        pam.unlocked = true;
        verify(!heartbeat.running, "and no more once unlocked");
    }

    function test_the_password_goes_to_pam_only_on_sending_never_when_pam_asks() {
        ask();
        type("geheim");
        compare(responses(), []);
        keyClick(Qt.Key_Return);
        compare(responses(), [["respond", "geheim"]]);
        ask();
        wait(10);
        compare(responses().length, 1, "a new question is no answer");
    }

    function test_the_unlock_button_sends_the_password_too() {
        ask();
        type("geheim");
        mouseClick(part("unlock"));
        compare(responses(), [["respond", "geheim"]]);
    }

    function test_a_password_sent_before_pam_asks_reaches_pam_once_it_asks() {
        verify(pam.announced, "after the questions without words");
        type("geheim");
        keyClick(Qt.Key_Return);
        compare(responses(), []);
        verify(Unlock.checking);
        ask();
        tryVerify(() => responses().length > 0);
        compare(responses(), [["respond", "geheim"]]);
    }

    function test_a_question_asked_before_the_lock_screen_loaded_is_answered() {
        const early = createTemporaryObject(authenticatorComponent, testCase);
        early.ask("Password: ");
        Unlock.authenticator = early;
        Unlock.submit("geheim", false);
        compare(early.calls, [["respond", "geheim"]]);
    }

    function test_a_password_sent_while_pam_still_reports_its_delay_reaches_pam_when_it_asks() {
        const delayed = createTemporaryObject(authenticatorComponent, testCase, {
            inPasswordDelay: true
        });
        Unlock.authenticator = delayed;
        Unlock.submit("geheim", false);
        delayed.ask("Password: ");
        tryVerify(() => delayed.calls.length > 0);
        compare(delayed.calls, [["respond", "geheim"]]);
    }

    // Ends the pause after a failure at once instead of waiting it out; its interval is held to two seconds below.
    function runOutPause() {
        const pause = findChild(Unlock, "pause");
        verify(pause.running, "the pause after a failure runs");
        pause.stop();
        pause.triggered();
    }

    function test_after_a_failure_pam_gets_the_next_answer_no_sooner_than_two_seconds_later() {
        ask();
        Unlock.submit("falsch", false);
        pam.failed(0);
        const pause = findChild(Unlock, "pause");
        verify(pause.running);
        compare(pause.interval, 2000);
        Unlock.submit("geheim", false);
        ask();
        // The answer to a question comes after its handler, a moment later.
        wait(50);
        compare(responses(), [["respond", "falsch"]], "not yet");
        runOutPause();
        compare(responses().length, 2);
        compare(responses()[1], ["respond", "geheim"]);
    }

    function test_a_second_question_during_a_check_opens_the_field_and_says_it() {
        ask();
        type("geheim");
        keyClick(Qt.Key_Return);
        pam.ask("Bestätigungscode: ");
        verify(!Unlock.checking, "the check ends");
        verify(!input().readOnly);
        compare(part("password").hint, "Bestätigungscode: ");
        compare(input().selectedText, "geheim", "typing replaces what was sent");
        type("123456");
        keyClick(Qt.Key_Return);
        compare(responses(), [["respond", "geheim"], ["respond", "123456"]]);
    }

    function test_sending_again_during_a_check_reaches_no_question_of_pam() {
        ask();
        type("geheim");
        keyClick(Qt.Key_Return);
        mouseClick(part("unlock"));
        pam.ask("Bestätigungscode: ");
        verify(!Unlock.checking, "the second question ends the check");
        wait(10);
        compare(responses(), [["respond", "geheim"]], "the code is not answered with the password");
    }

    function test_a_check_without_word_from_pam_ends_after_a_while_and_the_field_takes_input_again() {
        ask();
        type("geheim");
        keyClick(Qt.Key_Return);
        const watchdog = findChild(Unlock, "watchdog");
        verify(watchdog.running);
        compare(watchdog.interval, 10000);
        watchdog.triggered();
        verify(!Unlock.checking);
        verify(!input().readOnly);
        verify(!part("dots").running);
        compare(part("password").error, "Das Passwort wurde nicht geprüft – bitte noch einmal eingeben.");
        compare(input().selectedText, "geheim");
        verify(Unlock.asked, "the next answer goes straight to a question PAM may still hold");
        pam.failed(0);
        verify(!Unlock.asked, "unless the answer that was out fails late: then PAM holds no question");
    }

    function test_all_monitors_share_one_check() {
        ask();
        type("geheim");
        keyClick(Qt.Key_Return);
        const other = createTemporaryObject(faceComponent, testCase);
        verify(findChild(other, "dots").running, "the other monitor shows the check");
        verify(findChild(findChild(other, "password"), "input").readOnly);
        other.submitted("anders");
        compare(responses(), [["respond", "geheim"]], "and sends nothing meanwhile");
        pam.failed(0);
        compare(findChild(other, "password").error, "Das Passwort stimmt nicht – bitte noch einmal eingeben.");
        compare(part("password").error, findChild(other, "password").error);
        other.submitted("anders");
        ask();
        runOutPause();
        compare(responses().length, 2);
        compare(responses()[1], ["respond", "anders"], "the other monitor's password reaches PAM");
    }

    function test_a_wrong_password_says_cause_and_remedy_and_stays_all_selected() {
        ask();
        type("geheim");
        keyClick(Qt.Key_Return);
        pam.failed(0);
        verify(!Unlock.checking);
        compare(part("password").error, "Das Passwort stimmt nicht – bitte noch einmal eingeben.");
        compare(input().text, "geheim", "the input stays");
        compare(input().selectedText, "geheim", "all of it selected");
        verify(input().activeFocus);
        compare(pam.calls[pam.calls.length - 1], "start", "PAM asks again");
        keyClick(Qt.Key_X);
        compare(input().text, "x", "typing replaces it");
    }

    function test_with_caps_lock_on_a_wrong_password_names_it() {
        face.capsLock = true;
        compare(part("password").hint, "Die Feststelltaste ist an.");
        ask();
        face.submitted("GEHEIM");
        pam.failed(0);
        compare(part("password").error, "Das Passwort stimmt nicht – die Feststelltaste ist an.");
    }

    function test_pam_says_its_own_errors_and_information_at_the_field() {
        pam.infoMessage = "Noch 3 Versuche.";
        compare(part("password").hint, "Noch 3 Versuche.");
        pam.errorMessage = "Das Konto ist gesperrt.";
        compare(part("password").error, "Das Konto ist gesperrt.", "as it comes, outside a check");
        ask();
        Unlock.submit("geheim", false);
        compare(part("password").error, "", "a check starts without the old error");
        pam.errorMessage = "Das Konto ist abgelaufen.";
        pam.failed(0);
        compare(part("password").error, "Das Konto ist abgelaufen.", "PAM's words over the shell's");
    }

    function test_a_failing_fingerprint_reader_shows_nothing() {
        ask();
        Unlock.submit("geheim", false);
        pam.failed(1);
        verify(Unlock.checking);
        compare(part("password").error, "");
    }

    function test_success_stops_asking_and_quits() {
        ask();
        Unlock.submit("geheim", false);
        pam.succeed();
        compare(pam.calls[pam.calls.length - 1], "stop");
        compare(unlockedSpy.count, 1);
        verify(!findChild(Unlock, "watchdog").running);
    }

    function test_while_checking_field_and_button_take_nothing() {
        ask();
        type("geheim");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_X);
        compare(input().text, "geheim", "the field takes no typing");
        keyClick(Qt.Key_Return);
        mouseClick(part("unlock"));
        compare(responses().length, 1, "Enter and the button send nothing more");
    }

    function test_the_dots_run_under_the_field_as_wide_as_it_and_above_the_button_only_while_checking() {
        Prefs.motion = "on";
        waitForRendering(face);
        const field = part("password"), dots = part("dots"), button = part("unlock");
        const flying = () => Array.from(dots.children).filter(child => child.position !== undefined).length;
        verify(!dots.running);
        compare(flying(), 0, "resting, no dot exists");
        Unlock.submit("geheim", false);
        waitForRendering(face);
        verify(dots.running);
        compare(flying(), Geometry.dotCount);
        compare(dots.height, Geometry.dotSize);
        compare(dots.width, field.width);
        compare(dots.width, 2 * Tokens.tileUnit + Tokens.spaceS);
        const fieldBottom = field.mapToItem(face, 0, field.height).y;
        const dotsTop = dots.mapToItem(face, 0, 0).y;
        compare(dotsTop - fieldBottom, Tokens.spaceS);
        compare(button.mapToItem(face, 0, 0).y - (dotsTop + dots.height), Tokens.spaceS);
        compare(dots.mapToItem(face, 0, 0).x, field.mapToItem(face, 0, 0).x);
    }

    function test_field_and_button_stay_where_they_are_when_the_check_starts() {
        Prefs.motion = "on";
        waitForRendering(face);
        const field = part("password"), button = part("unlock");
        const fieldAt = field.mapToItem(face, 0, 0), buttonAt = button.mapToItem(face, 0, 0);
        Unlock.submit("geheim", false);
        waitForRendering(face);
        compare(field.mapToItem(face, 0, 0), fieldAt);
        compare(button.mapToItem(face, 0, 0), buttonAt);
    }

    function test_under_reduced_motion_the_dots_stand_with_words_and_every_end_state_is_reached() {
        face.active = false;
        compare(part("rest").opacity, 0, "the rest is gone at once");
        compare(part("clock").shrink, part("clock").ratio);
        face.active = true;
        compare(part("clock").shrink, 1, "the clock is whole at once");
        compare(part("rest").opacity, 1);
        Unlock.submit("geheim", false);
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
        compare(clock.lineHeightFactor, Tokens.lineHeightTitle);
        compare(clock.color, Tokens.color.textPrimary);
        compare(date.text, "donnerstag, 29. oktober");
        compare(date.x, Tokens.spaceXl);
        compare(date.y, clock.y + clock.height);
        compare(Calendar.longDateWords(new Date(2026, 9, 29), Qt.locale("en_US")), "thursday, october 29");
    }

    function test_another_monitor_shows_the_clock_alone_as_the_inactive_title_which_grows_when_it_becomes_active() {
        Prefs.motion = "on";
        waitForRendering(face);
        const clock = part("clock"), rest = part("rest");
        face.active = false;
        tryCompare(rest, "opacity", 0);
        verify(!rest.enabled, "the hidden parts take nothing");
        const ratio = Tokens.fluid(Tokens.fontSizePivotInactive, 1920) / Tokens.fluid(Tokens.fontSizeDisplay, 1920);
        tryCompare(clock, "shrink", ratio);
        tryCompare(clock, "color", Tokens.color.textContrastHigh, 1000, "it fades to the inactive title's colour");
        fuzzyCompare(clock.font.pixelSize * clock.shrink, Tokens.fluid(Tokens.fontSizePivotInactive, 1920), 0.5, "as large as pivot-inactive");
        face.active = true;
        tryVerify(() => clock.shrink > clock.ratio && clock.shrink < 1, 1000, "it grows, not jumps");
        tryCompare(clock, "shrink", 1);
        tryCompare(clock, "color", Tokens.color.textPrimary);
        tryCompare(rest, "opacity", 1);
        verify(input().activeFocus, "the field takes the keyboard");
    }

    function test_the_name_and_field_stand_bottom_left_and_the_status_bottom_right() {
        const name = part("name"), signIn = part("signIn"), corner = part("corner");
        compare(name.text, "rekta");
        compare(name.font.weight, Tokens.fontWeightSemibold);
        compare(name.font.pixelSize, Tokens.fluid(Tokens.fontSizeTitle, 1920));
        compare(name.lineHeightFactor, Tokens.lineHeightTitle);
        compare(name.color, Tokens.color.textPrimary);
        compare(signIn.x, Tokens.spaceXl);
        compare(signIn.y + signIn.height, face.height - Tokens.spaceXl);
        compare(part("password").label, "passwort");
        compare(input().echoMode, TextInput.Password);
        compare(part("unlock").variant, "primary");
        compare(corner.x + corner.width, face.width - Tokens.spaceXl);
        compare(corner.y + corner.height, face.height - Tokens.spaceXl);
        verify(!part("status").visible, "the empty status area takes no room");
        compare(corner.height, 0);
        compare(findChild(corner, "switchUser"), null, "no control in the corner");
    }

    function test_switch_user_is_a_quiet_button_in_the_row_of_unlock_space_s_behind_it() {
        const unlock = part("unlock"), switchUser = part("switchUser"), field = part("password"), dots = part("dots");
        compare(switchUser.variant, "quiet");
        compare(switchUser.text, "benutzer wechseln");
        compare(switchUser.mapToItem(face, 0, 0).y, unlock.mapToItem(face, 0, 0).y, "one row");
        compare(switchUser.mapToItem(face, 0, switchUser.height).y, face.height - Tokens.spaceXl, "at the bottom of the sign-in");
        compare(switchUser.mapToItem(face, 0, 0).x, unlock.mapToItem(face, unlock.width, 0).x + Tokens.spaceS);
        compare(unlock.mapToItem(face, 0, 0).x, field.mapToItem(face, 0, 0).x, "flush with the field's leading edge");
        compare(unlock.mapToItem(face, 0, 0).y - dots.mapToItem(face, 0, dots.height).y, Tokens.spaceS, "below the dots");
        let switched = 0;
        face.switchUser.connect(() => switched++);
        mouseClick(switchUser);
        compare(switched, 1);
    }

    function test_without_switching_users_unlock_stands_alone_where_it_stood() {
        const unlock = part("unlock"), at = unlock.mapToItem(face, 0, 0);
        face.canSwitchUser = false;
        verify(!part("switchUser").visible);
        compare(unlock.mapToItem(face, 0, 0), at);
        compare(part("signIn").y + part("signIn").height, face.height - Tokens.spaceXl);
    }

    function test_tab_goes_from_the_field_through_the_layouts_to_unlock_and_then_switch_user() {
        face.layouts = ["de", "us"];
        let switched = 0;
        face.switchUser.connect(() => switched++);
        tryVerify(() => input().activeFocus);
        keyClick(Qt.Key_Tab);
        verify(part("layouts").activeFocus, "the layouts");
        keyClick(Qt.Key_Tab);
        verify(part("unlock").activeFocus, "unlock");
        keyClick(Qt.Key_Tab);
        verify(part("switchUser").activeFocus, "switch user");
        keyClick(Qt.Key_Return);
        compare(switched, 1, "Enter presses it");
    }

    function test_the_layouts_stand_beside_the_field_level_with_its_input_only_when_there_are_several() {
        const layouts = part("layouts"), field = part("password");
        face.layouts = ["de"];
        verify(!layouts.visible);
        face.layouts = ["de", "us"];
        face.layoutIndex = 1;
        verify(layouts.visible);
        compare(layouts.currentIndex, 1);
        compare(layouts.x, field.width + Tokens.spaceM);
        compare(layouts.mapToItem(face, 0, 0).y, findChild(field, "box").mapToItem(face, 0, 0).y);
        let chosen = -1;
        face.layoutChosen.connect(index => chosen = index);
        layouts.choose(0);
        compare(chosen, 0);
    }

    function test_while_a_player_plays_its_title_stands_as_a_figure_over_the_music_icon_and_its_artist() {
        play("Nachtfahrt", "Kolibri", playback.playing);
        const status = part("status"), playing = part("playing"), corner = part("corner");
        waitForRendering(face);
        verify(status.visible);
        compare(findChild(playing, "number").text, "Nachtfahrt");
        compare(findChild(playing, "number").font.pixelSize, Tokens.fluid(Tokens.fontSizeXxl, playing.placeWidth));
        const words = findChild(playing, "words"), icon = findChild(playing, "wordsIcon");
        compare(words.text, "läuft · Kolibri");
        compare(words.color, Tokens.color.textContrastHigh);
        compare(icon.name, "music");
        compare(icon.color, words.color, "the icon in the colour of its words");
        compare(words.leftPadding, Geometry.iconSize + Tokens.spaceS, "space-s between icon and words");
        compare(status.mapToItem(face, status.width, 0).x, face.width - Tokens.spaceXl, "right-aligned");
        compare(corner.y + corner.height, face.height - Tokens.spaceXl);
        compare(playing.Accessible.name, "Nachtfahrt läuft · Kolibri");
        players.setProperty(0, "track", "Morgengrau");
        compare(findChild(playing, "number").text, "Morgengrau", "a new title follows");
        players.setProperty(0, "artist", "");
        compare(words.text, "läuft", "without an artist only the title");
    }

    function test_the_music_icon_stands_centred_on_the_first_line_of_its_words() {
        play("Nachtfahrt", "Kolibri", playback.playing);
        waitForRendering(face);
        const playing = part("playing"), words = findChild(playing, "words"), icon = findChild(playing, "wordsIcon");
        compare(icon.mapToItem(words, 0, icon.height / 2).y, words.lineHeight / 2, "on the centre of the first line box");
    }

    function test_a_short_title_still_stands_at_the_right_edge() {
        play("Ja", "Kolibri", playback.playing);
        const status = part("status");
        waitForRendering(face);
        compare(status.mapToItem(face, status.width, 0).x, face.width - Tokens.spaceXl);
    }

    function test_a_long_artist_wraps_its_words_and_keeps_space_l_from_the_sign_in() {
        play("Nachtfahrt", "Kolibri und das Orchester der langen Nächte, mit Chor und allen Gästen des Abends".repeat(3), playback.playing);
        const status = part("status"), signIn = part("signIn"), words = findChild(part("playing"), "words");
        waitForRendering(face);
        verify(words.lineCount > 1, "the words wrap");
        compare(status.mapToItem(face, 0, 0).x, signIn.x + signIn.width + Tokens.spaceL, "space-l from the sign-in");
        compare(status.mapToItem(face, status.width, 0).x, face.width - Tokens.spaceXl);
    }

    // Plasma's modules are not on the test path, so Plasma's player cannot load here, as when it is missing or changed.
    function test_without_plasmas_player_module_nothing_shows_and_the_password_still_reaches_pam() {
        ignoreWarning(/org\.kde\.plasma\.private\.mpris/);
        const playing = createTemporaryObject(playingComponent, testCase);
        tryCompare(playing, "status", Loader.Error);
        face = createTemporaryObject(faceComponent, testCase, {
            playingTitle: Qt.binding(() => playing.title),
            playingArtist: Qt.binding(() => playing.artist)
        });
        waitForRendering(face);
        compare(playing.title, "");
        compare(playing.artist, "");
        verify(!part("status").visible);
        ask();
        type("rekta");
        keyClick(Qt.Key_Return);
        tryVerify(() => responses().length === 1);
        compare(responses()[0], ["respond", "rekta"]);
    }

    function test_with_media_switched_off_in_the_lock_screen_settings_plasmas_player_is_not_even_loaded() {
        const playing = createTemporaryObject(playingComponent, testCase, { shown: false });
        compare(playing.status, Loader.Null);
        compare(playing.title, "");
        compare(playing.artist, "");
        ignoreWarning(/org\.kde\.plasma\.private\.mpris/);
        playing.shown = true;
        tryCompare(playing, "status", Loader.Error, 5000, "switched on, it is loaded");
    }

    function test_a_paused_or_stopped_player_or_one_without_a_title_shows_nothing_and_takes_no_room() {
        const corner = part("corner");
        const height = corner.height;
        for (const [track, status] of [["Nachtfahrt", playback.paused], ["Nachtfahrt", playback.stopped], ["", playback.playing]]) {
            play(track, "Kolibri", status);
            verify(!part("status").visible, `${track || "no title"} ${status}`);
            compare(corner.height, height, "no room taken");
        }
        play("Nachtfahrt", "Kolibri", playback.playing);
        verify(part("status").visible);
        players.setProperty(0, "playbackStatus", playback.paused);
        verify(!part("status").visible, "pausing takes it away");
        compare(corner.y + corner.height, face.height - Tokens.spaceXl);
    }

    function test_without_a_player_nothing_shows() {
        play("Nachtfahrt", "Kolibri", playback.playing);
        players.clear();
        verify(!part("status").visible);
        compare(nowPlaying.title, "");
    }

    function test_a_long_title_ends_on_one_line_in_an_ellipsis_beside_the_sign_in() {
        play("Eine sehr lange Nachtfahrt durch die Stadt, bis der Morgen graut und alle Lichter ausgehen".repeat(2), "Kolibri", playback.playing);
        const status = part("status"), signIn = part("signIn");
        const number = findChild(part("playing"), "number");
        waitForItemPolished(status);
        verify(number.truncated);
        compare(number.lineCount, 1);
        compare(status.mapToItem(face, 0, 0).x, signIn.x + signIn.width + Tokens.spaceL, "space-l from the sign-in");
        compare(status.mapToItem(face, status.width, 0).x, face.width - Tokens.spaceXl);
        compare(part("playing").Accessible.name, `${players.get(0).track} läuft · Kolibri`, "read out whole");
    }

    function test_another_monitor_shows_nothing_of_what_is_playing() {
        play("Nachtfahrt", "Kolibri", playback.playing);
        face.active = false;
        tryCompare(part("rest"), "opacity", 0);
        verify(!part("rest").enabled);
    }

    function test_new_notifications_stand_as_a_figure_with_the_bell_before_what_is_playing() {
        face.unseen = 3;
        play("Nachtfahrt", "Kolibri", playback.playing);
        waitForRendering(face);
        const status = part("status"), notices = part("notices"), playing = part("playing");
        verify(status.visible);
        verify(notices.visible);
        compare(findChild(notices, "number").text, "3");
        compare(findChild(notices, "words").text, "neue meldungen");
        compare(findChild(notices, "wordsIcon").name, "bell");
        compare(findChild(notices, "wordsIcon").color, findChild(notices, "words").color, "the bell in the colour of its words");
        compare(notices.Accessible.name, "3 neue meldungen");
        compare(playing.x, notices.width + Tokens.spaceM, "before what is playing, a figure's gap apart");
        compare(playing.y, notices.y, "in one row");
        compare(status.mapToItem(face, status.width, 0).x, face.width - Tokens.spaceXl, "right-aligned");
    }

    function test_one_new_notification_is_said_in_the_singular() {
        face.unseen = 1;
        compare(findChild(part("notices"), "number").text, "1");
        compare(findChild(part("notices"), "words").text, "neue meldung");
        face.unseen = 2;
        compare(findChild(part("notices"), "words").text, "neue meldungen");
    }

    function test_without_new_notifications_nothing_of_them_shows_and_takes_no_room() {
        const corner = part("corner");
        const height = corner.height;
        face.unseen = 0;
        verify(!part("status").visible, "alone it shows nothing");
        face.unseen = 1;
        verify(part("status").visible, "a single one shows");
        face.unseen = 0;
        verify(!part("status").visible);
        compare(corner.height, height, "no room taken");
        play("Nachtfahrt", "Kolibri", playback.playing);
        waitForRendering(face);
        verify(!part("notices").visible);
        compare(part("playing").x, 0, "what is playing stands first");
    }

    function test_new_notifications_and_a_long_title_still_keep_space_l_from_the_sign_in() {
        face.unseen = 12;
        play("Eine sehr lange Nachtfahrt durch die Stadt, bis der Morgen graut und alle Lichter ausgehen".repeat(2), "Kolibri", playback.playing);
        const status = part("status"), signIn = part("signIn");
        waitForItemPolished(status);
        verify(findChild(part("playing"), "number").truncated);
        compare(part("playing").y, part("notices").y, "in one row");
        compare(status.mapToItem(face, 0, 0).x, signIn.x + signIn.width + Tokens.spaceL, "space-l from the sign-in");
        compare(status.mapToItem(face, status.width, 0).x, face.width - Tokens.spaceXl);
    }

    function test_another_monitor_shows_nothing_of_new_notifications() {
        face.unseen = 3;
        face.active = false;
        tryCompare(part("rest"), "opacity", 0);
        verify(!part("rest").enabled);
    }

    function test_only_a_whole_number_from_zero_up_counts() {
        const count = createTemporaryObject(countComponent, testCase);
        for (const value of [-1, 1.5, "3", null, undefined, NaN, Infinity, 2 ** 31, [3]]) {
            count.take(4);
            count.take(value);
            compare(count.count, 0, `${value}`);
        }
        count.take(0);
        compare(count.count, 0);
        count.take(2 ** 31 - 1);
        compare(count.count, 2 ** 31 - 1);
    }

    // The lock screen's count from the shell over the test's private bus, wired as LockScreen.qml wires it.
    function lockFaceCountingFromTheShell(): var {
        const unseen = createTemporaryObject(unseenComponent, testCase);
        tryCompare(unseen, "status", Loader.Ready);
        face = createTemporaryObject(faceComponent, testCase, {
            unseen: Qt.binding(() => unseen.count)
        });
        return unseen;
    }

    // The counterpart gives the name up, and a shell of an earlier test may hold it until its deferred destruction has
    // run.
    function freeShellName() {
        counterpart.releaseName("rekta.Shell");
        tryVerify(() => counterpart.nameOwner("rekta.Shell") === "");
    }

    function shell(count: int): var {
        freeShellName();
        const created = createTemporaryObject(shellComponent, testCase, {
            sessionDesktop: "rekta",
            count
        });
        tryVerify(() => counterpart.nameOwner("rekta.Shell") !== "");
        return created;
    }

    function shownCount(): string {
        return part("notices").visible ? findChild(part("notices"), "number").text : "";
    }

    function test_the_count_shows_what_the_shell_holds_and_follows_it_while_locked() {
        if (!hasDBus)
            skip("this run goes without RektaShell.DBus");
        const exporter = shell(3);
        lockFaceCountingFromTheShell();
        tryVerify(() => shownCount() === "3");
        exporter.count = 1;
        tryVerify(() => shownCount() === "1");
        compare(findChild(part("notices"), "words").text, "neue meldung");
        exporter.count = 0;
        tryVerify(() => !part("status").visible);
        exporter.count = 5;
        tryVerify(() => shownCount() === "5");
    }

    function test_a_shell_that_starts_after_the_lock_screen_is_asked_and_one_that_ends_takes_the_count_along() {
        if (!hasDBus)
            skip("this run goes without RektaShell.DBus");
        freeShellName();
        const unseen = lockFaceCountingFromTheShell();
        compare(unseen.count, 0, "no shell, no count");
        const exporter = shell(2);
        tryVerify(() => shownCount() === "2");
        exporter.destroy();
        tryVerify(() => !part("status").visible);
        compare(unseen.count, 0);
    }

    function test_no_other_program_on_the_bus_can_speak_for_the_shell() {
        if (!hasDBus)
            skip("this run goes without RektaShell.DBus");
        shell(2);
        const unseen = lockFaceCountingFromTheShell();
        tryVerify(() => unseen.count === 2);
        counterpart.emitSignal("/rekta/Shell", "rekta.Shell.Notices", "UnseenCountChanged", [9]);
        counterpart.nameOwner("org.freedesktop.DBus");
        wait(100);
        compare(unseen.count, 2);
    }

    // The counterpart, as another program on the bus, says the count or sends a signal from the shell's place.
    function sayCount(values: var) {
        counterpart.emitSignal("/rekta/Shell", "rekta.Shell.Notices", "UnseenCountChanged", values);
    }

    // What arrives on the lock screen's own connection cannot be awaited from the counterpart's; a moment must do.
    function settle() {
        counterpart.nameOwner("org.freedesktop.DBus");
        wait(200);
    }

    readonly property var notCounts: [["9"], [-3], [2.5], [], [[1, 2]], [true], [{ a: 1 }], [4294967295]]

    function test_whoever_takes_the_shells_name_is_heard_and_the_shell_again_once_it_has_the_name_back() {
        if (!hasDBus)
            skip("this run goes without RektaShell.DBus");
        const exporter = shell(2);
        const unseen = lockFaceCountingFromTheShell();
        tryVerify(() => unseen.count === 2);
        counterpart.answerAt("/rekta/Shell", [7]);
        verify(counterpart.takeName("rekta.Shell"));
        compare(counterpart.nameOwner("rekta.Shell"), counterpart.uniqueName());
        tryVerify(() => unseen.count === 7, 5000, "the new owner is asked");
        sayCount([8]);
        tryVerify(() => unseen.count === 8, 5000, "and heard");
        exporter.count = 4;
        settle();
        compare(unseen.count, 8, "the shell, waiting for its name, is not heard");
        counterpart.releaseName("rekta.Shell");
        tryVerify(() => unseen.count === 4, 5000, "the shell is asked once it has the name back");
        sayCount([9]);
        settle();
        compare(unseen.count, 4, "the former owner is not heard any more");
        exporter.count = 6;
        tryVerify(() => unseen.count === 6);
    }

    function test_a_signal_of_the_owner_with_anything_but_a_count_counts_as_none() {
        if (!hasDBus)
            skip("this run goes without RektaShell.DBus");
        freeShellName();
        const unseen = lockFaceCountingFromTheShell();
        counterpart.answerAt("/rekta/Shell", [5]);
        verify(counterpart.takeName("rekta.Shell"));
        // The answer to the question the new owner is asked lands first, so it cannot overwrite a later signal.
        tryVerify(() => unseen.count === 5);
        for (const values of notCounts) {
            sayCount([5]);
            tryVerify(() => unseen.count === 5);
            sayCount(values);
            tryVerify(() => unseen.count === 0, 5000, JSON.stringify(values));
            verify(!part("status").visible);
        }
    }

    function test_an_answer_of_the_owner_with_anything_but_a_count_counts_as_none() {
        if (!hasDBus)
            skip("this run goes without RektaShell.DBus");
        shell(5);
        const unseen = lockFaceCountingFromTheShell();
        tryVerify(() => unseen.count === 5);
        for (const values of notCounts) {
            counterpart.answerAt("/rekta/Shell", values);
            verify(counterpart.takeName("rekta.Shell"));
            tryVerify(() => unseen.count === 0, 5000, JSON.stringify(values));
            counterpart.releaseName("rekta.Shell");
            tryVerify(() => unseen.count === 5, 5000, "the shell has the name back");
        }
    }

    function test_another_program_coming_to_and_leaving_the_bus_leaves_the_count_alone() {
        if (!hasDBus)
            skip("this run goes without RektaShell.DBus");
        shell(3);
        const unseen = lockFaceCountingFromTheShell();
        tryVerify(() => unseen.count === 3);
        verify(counterpart.takeName("org.example.Other"));
        settle();
        counterpart.releaseName("org.example.Other");
        settle();
        compare(unseen.count, 3);
    }

    function test_an_owner_that_never_answers_and_floods_the_bus_leaves_the_way_to_pam_free() {
        if (!hasDBus)
            skip("this run goes without RektaShell.DBus");
        freeShellName();
        counterpart.ignoreAt("/rekta/Shell");
        verify(counterpart.takeName("rekta.Shell"));
        const unseen = lockFaceCountingFromTheShell();
        counterpart.flood("/rekta/Shell", "rekta.Shell.Notices", "UnseenCountChanged", 20000);
        ask();
        type("rekta");
        keyClick(Qt.Key_Return);
        tryVerify(() => responses().length === 1, 10000);
        compare(responses()[0], ["respond", "rekta"]);
        tryVerify(() => unseen.count === 20000, 20000);
        freeShellName();
        tryVerify(() => unseen.count === 0);
    }

    // The test path holds RektaShell.DBus in the first run of these tests only.
    function test_without_the_shells_dbus_module_nothing_shows_and_the_password_still_reaches_pam() {
        if (hasDBus)
            skip("only the run without RektaShell.DBus misses it");
        ignoreWarning(/RektaShell\.DBus/);
        const unseen = createTemporaryObject(unseenComponent, testCase);
        tryCompare(unseen, "status", Loader.Error);
        compare(unseen.count, 0);
        face = createTemporaryObject(faceComponent, testCase, {
            unseen: Qt.binding(() => unseen.count)
        });
        waitForRendering(face);
        verify(!part("status").visible);
        ask();
        type("rekta");
        keyClick(Qt.Key_Return);
        tryVerify(() => responses().length === 1);
        compare(responses()[0], ["respond", "rekta"]);
    }

    // Each theme on a fresh lock screen: resting with two layouts, new notifications and a player, the notifications
    // alone, a long title, a refused password, and another monitor.
    function test_contact_sheet_in_both_themes() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            pam = createTemporaryObject(authenticatorComponent, testCase);
            Unlock.authenticator = pam;
            face = createTemporaryObject(faceComponent, testCase);
            face.layouts = ["de", "us"];
            play("Nachtfahrt", "Kolibri", playback.playing);
            waitForRendering(face);
            grabImage(face).save(`lockscreen-sheet-${theme}.png`);
            face.unseen = 3;
            waitForRendering(face);
            grabImage(face).save(`lockscreen-sheet-${theme}-notices.png`);
            players.clear();
            waitForRendering(face);
            grabImage(face).save(`lockscreen-sheet-${theme}-notices-alone.png`);
            face.unseen = 0;
            play("Nachtfahrt", "Kolibri", playback.playing);
            players.setProperty(0, "track", "Eine sehr lange Nachtfahrt durch die Stadt, bis der Morgen graut und alle Lichter ausgehen");
            waitForRendering(face);
            grabImage(face).save(`lockscreen-sheet-${theme}-long-title.png`);
            ask();
            type("geheim");
            keyClick(Qt.Key_Return);
            pam.failed(0);
            waitForRendering(face);
            grabImage(face).save(`lockscreen-sheet-${theme}-error.png`);
            face.active = false;
            waitForRendering(face);
            grabImage(face).save(`lockscreen-sheet-${theme}-other-monitor.png`);
            verify(face.height > 0, theme);
        }
    }
}
