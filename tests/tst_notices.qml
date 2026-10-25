pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Notices
import Rekta

TestCase {
    id: testCase

    name: "Notices"
    visible: true
    when: windowShown
    width: 900
    height: 640

    // A 40px app icon: a blue rounded square with a white dot.
    readonly property string picture: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAMAAAC7IEhfAAAAHlBMVEX///86dvBEffF4ofW5zvrs8v7///9Be/GcuvdVifLlkWmGAAAAAXRSTlMAQObYZgAAAI1JREFUOMu11UkOgCAQRFGaocH7X9iFMaKW5DvV+sWANEUIS+wyoY8NA9lGzaCk0AxKCg3mOYwpFy85xTGszde0OoCT95ku4d7tZQ+rH1M1bCfYJIx+TlQwCZgUzAJmBYuARUFXefVFvEa8a/wf8cnws8bTw+eRTzi/M39c17dVcaekvu9HXs287NHzMQN/Vg0WT30WoAAAAABJRU5ErkJggg=="
    // A pink 20px square, the icon the theme has for "konsole".
    readonly property string konsoleIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAGklEQVR4nGN4aTWLbMQwqnlU86jmUc0DqxkAreu3b+7dCC4AAAAASUVORK5CYII="
    // The wall clock the toasts run against, in ms.
    property double time: 0
    // What the fake notifications were asked to do and told, oldest first.
    property var calls: []
    property Item scene
    property Toaster toaster
    property NoticeBoard board
    property SignalSpy wanted
    property SignalSpy sounding

    Component {
        id: sceneComponent

        Rectangle {
            width: 900
            height: 640
            color: Tokens.color.bg

            Toaster {
                id: region

                objectName: "toaster"
                width: parent.width
                clock: () => testCase.time
            }

            NoticeBoard {
                id: noticeBoard

                objectName: "board"
                toaster: region
                iconUrl: name => name === "konsole" ? testCase.konsoleIcon : ""
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
        time = 0;
        calls = [];
        scene = createTemporaryObject(sceneComponent, testCase);
        toaster = findChild(scene, "toaster");
        board = findChild(scene, "board");
        wanted = createTemporaryObject(spyComponent, testCase, { target: board, signalName: "appWanted" });
        sounding = createTemporaryObject(spyComponent, testCase, { target: board, signalName: "sounding" });
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    // A signal as a notification has them, to connect() to; the test emit()s it.
    function signal() {
        const handlers = [];
        return {
            connect: handler => handlers.push(handler),
            emit: (...args) => handlers.forEach(handler => handler(...args))
        };
    }

    // A notification arrives as the server hands it over: plain JS, as QML reserves "transient". `actions` are
    // [identifier, text] pairs; invoking one tells the app and closes the notification, as the server does for one that
    // is not resident. The server closes a notification once; a second close is a mistake the calls show.
    function notify(properties, actions) {
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
            closedWith: 0,
            closed: signal(),
            summaryChanged: signal(),
            bodyChanged: signal()
        }, properties);
        fake.close = reason => {
            testCase.calls = [...testCase.calls, `${fake.summary} closed ${fake.closedWith ? "again " : ""}${reason}`];
            if (fake.closedWith)
                return;
            fake.closedWith = reason;
            fake.closed.emit(reason);
        };
        fake.expire = () => fake.close(NoticeBoard.Expired);
        fake.dismiss = () => fake.close(NoticeBoard.Dismissed);
        fake.actions = (actions ?? []).map(([identifier, text]) => ({
            identifier,
            text,
            invoke: () => {
                testCase.calls = [...testCase.calls, `${fake.summary} invoked ${identifier}`];
                fake.dismiss();
            }
        }));
        board.arrive(fake);
        return fake;
    }

    // The clock reaches the end of the open toast's window, as its timer would.
    function runOut() {
        const toast = toaster.open;
        time += toast.remaining;
        toast.step();
    }

    function shownTitles() {
        return toaster.open ? `${toaster.open.title}: ${toaster.open.text}` : "none";
    }

    function rowNames() {
        return board.rows.map(row => row.summary);
    }

    function test_one_toast_shows_at_a_time_and_the_next_comes_once_the_one_before_has_gone() {
        notify({ summary: "anna", body: "lunch?" });
        notify({ summary: "ben", body: "call me" });
        compare(shownTitles(), "anna: lunch?");
        runOut();
        compare(shownTitles(), "ben: call me");
        runOut();
        compare(toaster.open, null);
    }

    function test_a_toast_waits_while_the_one_before_slides_away() {
        Prefs.motion = "on";
        notify({ summary: "anna" });
        const first = toaster.open;
        notify({ summary: "ben" });
        compare(toaster.open, first, "the second waits in the queue, not in the toaster");
        tryCompare(first, "entry", 1, 1000);
        runOut();
        verify(toaster.open.waiting, "it comes once the first has gone");
        compare(toaster.open.title, "ben");
        tryVerify(() => !toaster.open.waiting, 1000);
    }

    function test_twenty_notifications_in_a_burst_toast_one_after_another_and_all_stand_in_the_list() {
        for (let i = 0; i < 20; i++)
            notify({ summary: `message ${i}` });
        const shown = [];
        while (toaster.open) {
            shown.push(toaster.open.title);
            runOut();
        }
        compare(shown, Array.from({ length: 20 }, (_, i) => `message ${i}`));
        compare(board.rows.length, 20);
        compare(board.rows[0].summary, "message 19", "newest first");
    }

    function test_a_summary_stands_over_the_body_and_either_alone_is_the_toast_s_one_sentence() {
        notify({ summary: "anna", body: "lunch at noon?" });
        compare(toaster.open.title, "anna");
        compare(toaster.open.text, "lunch at noon?");
        runOut();
        notify({ summary: "backup finished", body: "" });
        compare(toaster.open.title, "");
        compare(toaster.open.text, "backup finished");
        runOut();
        notify({ summary: "", body: "disk almost full" });
        compare(toaster.open.text, "disk almost full");
        compare(board.rows[0].summary, "disk almost full", "the list row says it too");
    }

    function test_the_image_takes_the_place_of_the_app_icon() {
        notify({ image: testCase.picture, appIcon: "konsole" });
        compare(toaster.open.icon, testCase.picture);
        runOut();
        notify({ appIcon: "konsole" });
        compare(toaster.open.icon, testCase.konsoleIcon, "without an image, the app's icon from the theme");
    }

    function test_a_normal_toast_runs_duration_toast_then_expires_and_stays_in_the_list_unseen() {
        const fake = notify({}, [["default", "open"]]);
        compare(toaster.open.total, Tokens.durationToast);
        time = Tokens.durationToast - 1;
        toaster.open.step();
        verify(toaster.open, "still within its window");
        runOut();
        compare(calls, ["anna closed 1"]);
        compare(fake.closedWith, NoticeBoard.Expired);
        compare(board.rows.length, 1, "the list keeps it, as Plasma's history does");
        verify(board.rows[0].unseen);
        compare(board.unseen, 1);
        compare(board.rows[0].notification, null, "an expired notification has no actions left");
    }

    function test_a_critical_toast_stays_until_it_is_pressed_and_later_ones_wait() {
        notify({ summary: "battery low", urgency: NoticeBoard.Critical });
        notify({ summary: "anna" });
        const critical = toaster.open;
        verify(critical.stays);
        compare(critical.status, "", "no status fill: the failure is not the shell's own");
        time = 100 * Tokens.durationToast;
        critical.step();
        compare(toaster.open, critical);
        critical.pressText();
        compare(toaster.open.title, "anna");
    }

    function test_an_app_s_timeout_of_zero_keeps_its_toast_standing() {
        notify({ expireTimeout: 0 });
        verify(toaster.open.stays);
        notify({ summary: "ben", expireTimeout: 2000 });
        time = 100 * Tokens.durationToast;
        toaster.open.step();
        verify(toaster.open.stays, "it has no window to run out");
        toaster.dismiss();
        verify(!toaster.open.stays, "any other timeout of the app runs duration-toast");
        compare(toaster.open.total, Tokens.durationToast);
    }

    function test_low_and_transient_notifications_toast_but_stay_out_of_the_list_and_the_count() {
        notify({ summary: "low", urgency: NoticeBoard.Low });
        compare(shownTitles(), "low: lunch at noon?");
        runOut();
        notify({ summary: "transient", transient: true });
        compare(toaster.open.title, "transient");
        runOut();
        compare(calls, ["low closed 1", "transient closed 1"]);
        compare(board.rows.length, 0);
        compare(board.unseen, 0);
    }

    function test_in_full_screen_normal_ones_collect_quietly_in_the_list_and_critical_ones_still_show() {
        board.quiet = true;
        notify({ summary: "anna" }, [["default", "open"]]);
        compare(toaster.open, null, "no toast");
        compare(sounding.count, 0, "no sound");
        compare(rowNames(), ["anna"]);
        compare(board.unseen, 1);
        verify(board.actionOf(board.rows[0].notification, true), "it is still open, so its default action still runs");
        notify({ summary: "low", urgency: NoticeBoard.Low });
        compare(toaster.open, null);
        compare(calls, ["low closed 1"], "a low one nobody sees has expired");
        notify({ summary: "battery low", urgency: NoticeBoard.Critical });
        compare(toaster.open.title, "battery low");
        compare(sounding.count, 1);
    }

    function test_once_full_screen_ends_nothing_collected_follows_as_a_toast() {
        board.quiet = true;
        notify({ summary: "anna" });
        board.quiet = false;
        compare(toaster.open, null);
        notify({ summary: "ben" });
        compare(toaster.open.title, "ben", "what comes after toasts again");
        compare(board.unseen, 1);
    }

    function test_pressing_the_text_runs_the_default_action_and_the_toast_ends() {
        notify({}, [["default", "open"], ["reply", "reply"]]);
        const toast = toaster.open;
        mouseClick(findChild(toast, "open"));
        mouseMove(testCase, 0, testCase.height - 1);
        compare(calls, ["anna invoked default", "anna closed 2"]);
        verify(toast.done);
        compare(wanted.count, 0);
        compare(board.rows.length, 0);
    }

    function test_without_a_default_action_pressing_the_text_brings_the_app_forward_and_dismisses_it() {
        const fake = notify({}, [["reply", "reply"]]);
        const toast = toaster.open;
        toast.pressText();
        compare(wanted.count, 1);
        compare(Array.from(wanted.signalArguments[0]), [fake.desktopEntry, fake.appName]);
        compare(calls, ["anna closed 2"]);
        verify(toast.done, "it ends as any action does");
        compare(board.rows.length, 0);
    }

    function test_act_is_the_first_action_other_than_default_with_its_text() {
        notify({}, [["default", "open"], ["reply", "Reply"], ["mark", "Mark read"]]);
        const toast = toaster.open;
        compare(toast.actionLabel, "Reply");
        toast.press();
        compare(calls, ["anna invoked reply", "anna closed 2"]);
        notify({ summary: "ben" }, [["default", "open"]]);
        compare(toaster.open.actionLabel, "", "only default: no act");
    }

    function test_escape_or_a_dismissed_toast_dismisses_its_notification() {
        const fake = notify({});
        toaster.dismiss();
        compare(fake.closedWith, NoticeBoard.Dismissed);
        compare(board.rows.length, 0);
    }

    function test_a_notification_its_app_closes_leaves_the_toast_the_queue_and_the_list() {
        const first = notify({ summary: "anna" });
        const second = notify({ summary: "ben" });
        const third = notify({ summary: "cleo" });
        second.close(NoticeBoard.CloseRequested);
        compare(rowNames(), ["cleo", "anna"]);
        const toast = toaster.open;
        first.close(NoticeBoard.CloseRequested);
        verify(toast.done, "its toast goes");
        compare(rowNames(), ["cleo"]);
        compare(toaster.open.title, "cleo", "the one taken from the queue never shows");
        compare(calls, ["ben closed 3", "anna closed 3"], "nothing closes them a second time");
        verify(third.closedWith === 0);
    }

    function test_replacing_a_notification_updates_its_open_toast_and_its_row() {
        const fake = notify({ summary: "anna", body: "lunch?" });
        fake.summary = "anna (2)";
        fake.body = "lunch at noon?";
        fake.summaryChanged.emit();
        fake.bodyChanged.emit();
        compare(toaster.open.title, "anna (2)");
        compare(toaster.open.text, "lunch at noon?");
        compare(rowNames(), ["anna (2)"]);
    }

    function test_a_toast_sounds_as_it_begins() {
        const first = notify({ summary: "anna" });
        notify({ summary: "ben" });
        compare(sounding.count, 1, "the waiting one sounds when its toast comes");
        compare(sounding.signalArguments[0][0].summary, first.summary);
        runOut();
        compare(sounding.count, 2);
    }

    function test_notifications_carried_over_a_reload_go_into_the_list_without_a_toast() {
        notify({ lastGeneration: true });
        compare(toaster.open, null);
        compare(rowNames(), ["anna"]);
        compare(board.unseen, 0);
    }

    function test_the_count_shows_only_unseen_ones_and_seeing_the_list_sets_it_to_zero() {
        notify({ summary: "anna" });
        compare(board.unseen, 0, "a toast on screen is seen");
        runOut();
        compare(board.unseen, 1, "its toast ran out unseen");
        board.quiet = true;
        notify({ summary: "ben" });
        compare(board.unseen, 2);
        board.seen();
        compare(board.unseen, 0);
        compare(board.rows.length, 2, "seen, they stay in the list");
    }

    function test_a_row_shows_the_summary_one_line_of_the_body_and_the_picture_or_the_app_s_icon() {
        board.quiet = true;
        notify({ summary: "anna", body: "lunch at noon?", appIcon: "konsole" });
        notify({ summary: "", body: "disk almost full", image: testCase.picture });
        compare(board.rows.map(row => [row.summary, row.body, row.icon]), [["disk almost full", "", testCase.picture], ["anna", "lunch at noon?", testCase.konsoleIcon]]);
    }

    function test_removed_rows_leave_the_list_at_once_and_their_notifications_close_only_once_the_undo_window_has_run_out() {
        board.quiet = true;
        const anna = notify({ summary: "anna" });
        notify({ summary: "ben" });
        board.remove([board.rows[1]]);
        compare(rowNames(), ["ben"]);
        compare(toaster.open.text, "meldung entfernt");
        compare(toaster.open.actionLabel, "undo");
        compare(toaster.open.total, toaster.undoWindow, "the undo window: duration-toast in whole seconds");
        time = toaster.undoWindow - 1;
        toaster.open.step();
        compare(calls, [], "nothing is closed while undo is possible");
        runOut();
        compare(calls, ["anna closed 2"]);
        compare(anna.closedWith, NoticeBoard.Dismissed);
    }

    function test_undo_puts_the_rows_back_where_they_were_and_closes_nothing() {
        board.quiet = true;
        notify({ summary: "anna" });
        notify({ summary: "ben" });
        notify({ summary: "cleo" });
        board.remove([board.rows[1]]);
        notify({ summary: "dora" });
        toaster.open.undo();
        compare(rowNames(), ["dora", "cleo", "ben", "anna"]);
        compare(calls, []);
        compare(toaster.open, null);
    }

    function test_a_second_removal_joins_the_open_undo_toast_and_undo_brings_both_back() {
        board.quiet = true;
        notify({ summary: "anna" });
        notify({ summary: "ben" });
        notify({ summary: "cleo" });
        board.remove([board.rows[0]]);
        const toast = toaster.open;
        time = 3000;
        board.remove([board.rows[1]]);
        compare(toaster.open, toast, "the same toast");
        compare(toast.text, "2 meldungen entfernt");
        compare(toast.remaining, toaster.undoWindow, "its window starts again");
        compare(rowNames(), ["ben"]);
        toast.undo();
        compare(rowNames(), ["cleo", "ben", "anna"]);
        compare(calls, []);
    }

    function test_removing_them_all_closes_them_all_once_the_window_has_run_out() {
        notify({ summary: "anna" });
        runOut();
        board.quiet = true;
        notify({ summary: "ben" });
        notify({ summary: "low", urgency: NoticeBoard.Low });
        board.remove(board.rows);
        compare(board.rows.length, 0);
        compare(toaster.open.text, "2 meldungen entfernt");
        runOut();
        compare(calls, ["anna closed 1", "low closed 1", "ben closed 2"], "the expired one only leaves the list; ben is dismissed");
    }

    function test_a_removed_notification_its_app_closes_or_replaces_in_the_window_is_gone_without_undo() {
        board.quiet = true;
        const anna = notify({ summary: "anna" });
        const ben = notify({ summary: "ben" });
        notify({ summary: "cleo" });
        board.remove([board.rows[1], board.rows[2]]);
        anna.close(NoticeBoard.CloseRequested);
        compare(toaster.open.text, "meldung entfernt", "one is left to undo");
        ben.summary = "ben (2)";
        ben.summaryChanged.emit();
        compare(calls, ["anna closed 3", "ben (2) closed 2"], "replaced, it is removed for good");
        verify(!toaster.open || toaster.open.done, "nothing is left to undo");
        compare(rowNames(), ["cleo"]);
    }

    function test_the_undo_toast_takes_the_place_of_a_notification_s_toast_and_the_queue_waits_for_it() {
        notify({ summary: "anna" });
        notify({ summary: "ben" });
        notify({ summary: "low", urgency: NoticeBoard.Low });
        compare(toaster.open.title, "anna");
        board.remove([board.rows[0]]);
        compare(toaster.open.text, "meldung entfernt", "in place of anna's toast");
        compare(calls, [], "anna stays open in the list");
        runOut();
        compare(calls, ["ben closed 2"]);
        compare(toaster.open.title, "low", "then the queue goes on, without ben");
        compare(rowNames(), ["anna"]);
    }

    function test_pressing_a_row_does_what_pressing_its_toast_does_and_a_row_that_ran_out_brings_its_app_forward() {
        board.quiet = true;
        notify({ summary: "anna" }, [["default", "open"]]);
        const ben = notify({ summary: "ben" });
        board.press(board.rows[1]);
        compare(calls, ["anna invoked default", "anna closed 2"]);
        board.press(board.rows[0]);
        compare(Array.from(wanted.signalArguments[0]), [ben.desktopEntry, ben.appName]);
        compare(calls.slice(2), ["ben closed 2"]);
        board.quiet = false;
        const cleo = notify({ summary: "cleo", appName: "mail", desktopEntry: "org.example.mail" });
        runOut();
        board.press(board.rows[0]);
        compare(Array.from(wanted.signalArguments[1]), [cleo.desktopEntry, "mail"]);
        compare(board.rows.length, 0, "the row goes as its toast would");
    }

    function test_the_sound_plays_the_hint_in_the_theme_kdeglobals_names_unless_suppressed() {
        compare(Sound.theme(""), "ocean", "Plasma's default");
        compare(Sound.theme("[General]\nTheme=breeze\n[Sounds]\nEnable=true\nTheme[$i]=freedesktop\n"), "freedesktop");
        compare(Sound.command({ "sound-name": "message-new-instant" }, "ocean"), ["canberra-gtk-play", "--property=canberra.xdg-theme.name=ocean", "--cache-control=volatile", "--id=message-new-instant"]);
        compare(Sound.command({ "sound-file": "/sounds/ding.oga" }, "freedesktop"), ["canberra-gtk-play", "--property=canberra.xdg-theme.name=freedesktop", "--cache-control=volatile", "--file=/sounds/ding.oga"]);
        compare(Sound.command({ "sound-name": "message-new-instant", "suppress-sound": true }, "ocean"), []);
        compare(Sound.command({}, "ocean"), [], "no hint, no sound");
    }

    // Both themes: a toast with a picture, a title and two lines.
    function test_contact_sheet_of_a_notification_toast_in_both_themes() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            init();
            notify({ summary: "Mia", body: "Can we move the call to Thursday afternoon? I have the whole morning booked, so any time after lunch works.", image: testCase.picture }, [["default", "open"], ["reply", "reply"]]);
            tryCompare(findChild(toaster.open, "appIcon"), "status", Image.Ready);
            waitForRendering(scene);
            grabImage(scene).save(`notices-sheet-${theme}.png`);
        }
    }
}
