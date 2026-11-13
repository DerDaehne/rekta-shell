pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Notices
import Rekta
import "ContactSheets.js" as ContactSheets

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
    property alias calls: fakes.calls
    property Item scene
    property Toaster toaster
    property NoticeBoard board
    property SignalSpy wanted
    property SignalSpy sounding

    FakeNotifications {
        id: fakes
    }

    Component {
        id: sceneComponent

        // A host: it routes the keys nobody took to the key layers, as the shell does from its root.
        Rectangle {
            width: 900
            height: 640
            color: Tokens.color.bg
            Keys.onPressed: event => KeyLayers.dispatch(event, Window.activeFocusItem)

            Toaster {
                id: region

                objectName: "toaster"
                undoWord: "rückgängig"
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

    // A notification arrives as the server hands it over.
    function notify(properties, actions) {
        const fake = fakes.make(properties, actions);
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

    function test_a_notification_s_toast_takes_the_place_of_the_open_one_at_once_and_none_follows_once_it_has_gone() {
        notify({ summary: "anna", body: "lunch?" });
        notify({ summary: "ben", body: "call me" });
        compare(shownTitles(), "ben: call me");
        runOut();
        compare(toaster.open, null, "anna's does not come back");
        compare(rowNames(), ["ben", "anna"]);
    }

    function test_a_notification_s_toast_rises_from_its_count_and_the_undo_toast_of_a_removal_does_not() {
        notify({ summary: "anna" });
        verify(toaster.open.notification, "its count gives way to it");
        runOut();
        board.remove([board.rows[0]]);
        verify(!toaster.open.notification, "the count stays for the shell's own toast");
    }

    function test_a_shell_toast_that_takes_the_place_of_a_notification_s_toast_rises_and_stands_its_time_with_meldungen_back() {
        Prefs.motion = "on";
        toaster.countInSight = true;
        // A banner's state that ends, and a failure of the shell's own.
        for (const options of [{ key: "state" }, { status: "error" }]) {
            notify({ summary: "anna" });
            tryCompare(toaster.open, "entry", 1, 1000);
            const shell = toaster.show("akku wieder ok", options);
            tryCompare(shell, "entry", 1, 1000, "it rises, announced as it begins");
            tryVerify(() => !toaster.countAway, 1000, "meldungen is back while it stands");
            verify(toaster.open === shell, "nothing takes its place");
            compare(sounding.count, 1, "nothing toasts after anna");
            runOut();
            verify(shell.done, "it went when its window ran out");
            tryCompare(toaster, "leaving", 0, 1000);
            compare(toaster.open, null);
            sounding.clear();
        }
    }

    function test_twenty_notifications_in_a_burst_leave_the_last_as_the_toast_and_all_in_the_list_with_the_nineteen_replaced_unseen() {
        for (let i = 0; i < 20; i++)
            notify({ summary: `message ${i}` });
        compare(toaster.open.title, "message 19");
        compare(sounding.count, 20, "each sounded with its toast");
        compare(board.rows.length, 20);
        compare(board.rows[0].summary, "message 19", "newest first");
        compare(board.unseen, 19);
        verify(!board.rows[0].unseen, "the one on screen is seen");
        runOut();
        compare(toaster.open, null, "none follows");
        compare(board.unseen, 20);
    }

    function test_a_notification_whose_toast_another_or_a_shell_toast_replaced_stays_open_in_the_list_unseen_unless_the_list_is_in_sight() {
        const anna = notify({ summary: "anna" }, [["default", "open"], ["reply", "antworten"]]);
        notify({ summary: "ben" });
        toaster.show("akku wieder ok", { key: "state" });
        compare(calls, [], "neither has closed");
        compare(board.rows.map(row => [row.summary, row.unseen]), [["ben", true], ["anna", true]]);
        compare(board.rows[1].notification, anna, "anna is still open");
        compare(board.actionsOf(board.rows[1]), [{ identifier: "reply", text: "antworten" }]);
        board.listInSight = true;
        notify({ summary: "cleo" });
        notify({ summary: "dora" });
        verify(!board.rows[1].unseen, "replaced while the list is in sight, cleo is seen");
        board.listInSight = false;
        notify({ summary: "transient", transient: true });
        notify({ summary: "emil" });
        compare(calls, ["transient closed 1"], "a transient one nobody sees any more has expired");
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

    function test_the_toast_keeps_the_words_the_app_sends_and_does_not_add_the_app_s_name() {
        notify({ appName: "Browser", summary: "Download finished", body: "report.pdf" });
        compare(toaster.open.title, "Download finished");
        compare(toaster.open.text, "report.pdf");
        compare(toaster.open.spoken, "Download finished. report.pdf");
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

    function test_a_critical_toast_stays_until_it_is_pressed() {
        notify({ summary: "battery low", urgency: NoticeBoard.Critical });
        const critical = toaster.open;
        verify(critical.stays);
        compare(critical.status, "", "no status fill: the failure is not the shell's own");
        time = 100 * Tokens.durationToast;
        critical.step();
        compare(toaster.open, critical);
        critical.pressText();
        verify(critical.done);
    }

    function test_behind_a_critical_toast_every_later_notification_goes_to_the_list_only_unseen_without_toast_or_sound_even_after_the_press() {
        for (const quiet of [false, true]) {
            init();
            board.quiet = quiet;
            notify({ summary: "battery low", urgency: NoticeBoard.Critical });
            const critical = toaster.open;
            const anna = notify({ summary: "anna" });
            notify({ summary: "disk failing", urgency: NoticeBoard.Critical });
            notify({ summary: "transient", transient: true });
            verify(toaster.open === critical, `quiet ${quiet}: it keeps its place`);
            compare(sounding.count, 1, `quiet ${quiet}: only the critical one sounded`);
            compare(rowNames(), ["disk failing", "anna", "battery low"], `quiet ${quiet}`);
            compare(board.unseen, 2, `quiet ${quiet}: they count`);
            compare(calls, ["transient closed 1"], `quiet ${quiet}: a transient one nobody sees has expired, the others are open`);
            critical.pressText();
            compare(toaster.open, null, `quiet ${quiet}: none follows the press`);
            compare(sounding.count, 1, `quiet ${quiet}`);
            verify(anna.closedWith === 0, `quiet ${quiet}`);
        }
    }

    function test_a_critical_toast_says_dringend_in_a_neutral_tag_before_its_action_and_first_to_a_reader() {
        notify({ summary: "backup", body: "the disk is full", urgency: NoticeBoard.Critical }, [["retry", "wiederholen"]]);
        const toast = toaster.open;
        const tag = findChild(toast, "tag");
        compare(toast.tag, "dringend");
        verify(tag.visible);
        compare(tag.status, "", "neutral: urgency is not a status");
        compare(toast.status, "", "the surface stays ink");
        compare(toast.actionLabel, "wiederholen");
        verify(tag.mapToItem(toast, 0, 0).x + tag.width <= findChild(toast, "action").x, "the action stays last");
        compare(toast.Accessible.name, "dringend. backup. the disk is full");
    }

    function test_normal_toasts_carry_no_tag_whatever_timeout_their_app_gives() {
        for (const [summary, expireTimeout] of [["normal", -1], ["no timeout", 0]]) {
            notify({ summary, expireTimeout });
            compare(toaster.open.title, summary);
            tryCompare(toaster.open, "waiting", false);
            compare(toaster.open.tag, "", summary);
            verify(!findChild(toaster.open, "tag").visible, summary);
            compare(toaster.open.Accessible.name, `${summary}. lunch at noon?`);
            toaster.dismiss();
        }
    }

    function test_a_toast_runs_duration_toast_and_goes_whatever_timeout_its_app_gives_even_none() {
        for (const [summary, expireTimeout] of [["none", 0], ["short", 2000], ["long", 20000]]) {
            notify({ summary, expireTimeout });
            verify(!toaster.open.stays, summary);
            compare(toaster.open.total, Tokens.durationToast, summary);
            time += Tokens.durationToast - 1;
            toaster.open.step();
            compare(toaster.open?.title, summary, `${summary}: still within its window`);
            runOut();
            compare(toaster.open, null, `${summary}: then it goes`);
        }
        compare(calls, ["short closed 1", "long closed 1"], "only no timeout at all keeps its notification open");
    }

    function test_a_notification_its_app_gives_no_timeout_does_not_expire_with_its_toast_but_stays_open_and_unseen_in_the_list() {
        const fake = notify({ expireTimeout: 0 }, [["default", "open"], ["accept", "annehmen"]]);
        runOut();
        compare(calls, [], "no expire(): the app hears nothing");
        compare(board.rows[0].notification, fake, "it is still open");
        compare(board.actionsOf(board.rows[0]), [{ identifier: "accept", text: "annehmen" }]);
        verify(board.rows[0].unseen);
        compare(board.unseen, 1);
        compare(board.unseenByApp, { "org.example.chat": 1 });
        board.invokeAction(board.rows[0], "accept");
        compare(calls, ["anna invoked accept", "anna closed 2"]);
    }

    function test_a_transient_notification_its_app_gives_no_timeout_expires_once_its_toast_has_gone() {
        notify({ summary: "transient", transient: true, expireTimeout: 0 });
        verify(!toaster.open.stays);
        runOut();
        compare(calls, ["transient closed 1"]);
        compare(board.rows.length, 0);
    }

    function test_transient_notifications_toast_but_stay_out_of_the_list_and_the_count() {
        notify({ summary: "transient", transient: true });
        compare(shownTitles(), "transient: lunch at noon?");
        runOut();
        compare(calls, ["transient closed 1"]);
        compare(board.rows.length, 0);
        compare(board.unseen, 0);
    }

    function test_a_low_transient_notification_has_neither_toast_nor_row_and_expires_at_once() {
        notify({ summary: "lt", urgency: NoticeBoard.Low, transient: true });
        compare(toaster.open, null);
        compare(board.rows.length, 0);
        compare(calls, ["lt closed 1"]);
    }

    function test_a_low_notification_shows_no_toast_and_no_sound_and_stands_open_at_the_top_of_the_list() {
        notify({ summary: "anna" });
        const low = notify({ summary: "update ready", urgency: NoticeBoard.Low }, [["default", "open"], ["install", "install"]]);
        compare(rowNames(), ["update ready", "anna"]);
        runOut();
        compare(toaster.open, null, "no toast follows anna's");
        compare(sounding.count, 1, "only anna's toast sounded");
        compare(board.rows[0].notification, low, "it has not expired");
        compare(board.actionsOf(board.rows[0]), [{ identifier: "install", text: "install" }]);
        board.press(board.rows[0]);
        compare(calls, ["anna closed 1", "update ready invoked default", "update ready closed 2"]);
    }

    function test_a_low_notification_counts_neither_in_meldungen_nor_for_its_app_even_while_toasts_are_quiet() {
        for (const quiet of [false, true]) {
            board.quiet = quiet;
            notify({ summary: `quiet ${quiet}`, urgency: NoticeBoard.Low });
            compare(board.unseen, 0, `quiet: ${quiet}`);
            compare(Object.keys(board.unseenByApp), [], `quiet: ${quiet}`);
        }
        compare(rowNames(), ["quiet true", "quiet false"]);
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
        compare(rowNames(), ["low", "anna"], "a low one stands in the list, as it does outside full screen");
        compare(board.unseen, 1, "it does not count");
        notify({ summary: "transient", transient: true });
        compare(toaster.open, null);
        compare(calls, ["transient closed 1"], "a transient one nobody sees has expired; the low one stays open");
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

    function test_escape_or_a_dismissed_toast_dismisses_its_notification_whatever_timeout_its_app_gives() {
        for (const expireTimeout of [-1, 0]) {
            const fake = notify({ expireTimeout });
            toaster.dismiss();
            compare(fake.closedWith, NoticeBoard.Dismissed, `timeout ${expireTimeout}`);
            compare(board.rows.length, 0, `timeout ${expireTimeout}`);
        }
    }

    function test_a_notification_its_app_closes_leaves_its_toast_and_the_list() {
        const anna = notify({ summary: "anna" });
        const ben = notify({ summary: "ben" });
        anna.close(NoticeBoard.CloseRequested);
        compare(rowNames(), ["ben"]);
        compare(toaster.open.title, "ben", "ben's toast stays");
        const toast = toaster.open;
        ben.close(NoticeBoard.CloseRequested);
        verify(toast.done, "its toast goes");
        compare(rowNames(), []);
        compare(calls, ["anna closed 3", "ben closed 3"], "nothing closes them a second time");
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

    function test_each_toast_sounds_as_it_takes_the_place_of_the_one_before() {
        notify({ summary: "anna" });
        notify({ summary: "ben" });
        compare(sounding.count, 2);
        compare(sounding.signalArguments.map(args => args[0].summary), ["anna", "ben"]);
    }

    function test_notifications_carried_over_a_reload_go_into_the_list_without_a_toast() {
        notify({ lastGeneration: true });
        compare(toaster.open, null);
        compare(rowNames(), ["anna"]);
        compare(board.unseen, 0);
    }

    function test_a_transient_notification_carried_over_a_reload_has_neither_toast_nor_row_and_expires_at_once() {
        notify({ summary: "carried", transient: true, lastGeneration: true });
        compare(toaster.open, null);
        compare(board.rows.length, 0);
        compare(calls, ["carried closed 1"]);
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

    function test_while_the_list_is_in_sight_what_comes_into_it_is_seen_there() {
        board.quiet = true;
        notify({ summary: "anna" });
        board.listInSight = true;
        compare(board.unseen, 0, "in sight, it has seen them all");
        notify({ summary: "ben" });
        compare(board.unseen, 0, "collected quietly");
        board.quiet = false;
        notify({ summary: "cleo" });
        runOut();
        compare(board.unseen, 0, "its toast ran out");
        board.listInSight = false;
        notify({ summary: "dora" });
        runOut();
        compare(board.unseen, 1, "out of sight it counts again");
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
        compare(toaster.open.actionLabel, "rückgängig");
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
        compare(toaster.open.text, "3 meldungen entfernt");
        runOut();
        compare(calls, ["anna closed 1", "low closed 2", "ben closed 2"], "the expired one only leaves the list; the open ones are dismissed");
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

    // anna, ben and cleo stand in the list; ben is removed at 0, and at 2000 dora's toast takes the place of the undo
    // toast, whose figure then showed 3 of its 5 seconds.
    function removeBenAndLetDoraTakeTheUndoToastsPlace() {
        board.quiet = true;
        notify({ summary: "anna" });
        notify({ summary: "ben" });
        notify({ summary: "cleo" });
        board.quiet = false;
        board.remove([board.rows[1]]);
        time = 2000;
        toaster.open.step();
        notify({ summary: "dora" });
        compare(toaster.open.title, "dora");
        compare(calls, [], "nothing closes yet");
        scene.forceActiveFocus();
    }

    function test_after_a_notification_took_the_undo_toasts_place_ctrl_z_brings_the_rows_back_until_their_window_ends_and_closes_nothing() {
        removeBenAndLetDoraTakeTheUndoToastsPlace();
        time = toaster.undoWindow - 1;
        board.undoLeft.triggered();
        compare(calls, [], "an early timer: the window is still open");
        const below = [];
        const removeBelow = KeyLayers.on(3, event => {
            below.push(event.key);
            return false;
        });
        keyClick(Qt.Key_Escape);
        keyClick(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier);
        compare(rowNames(), ["dora", "cleo", "anna"], "neither Escape nor Ctrl+Shift+Z brings ben back");
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(rowNames(), ["dora", "cleo", "ben", "anna"], "Ctrl+Z brings ben back in his place");
        compare(calls, []);
        compare(toaster.open.title, "dora", "dora's toast stays");
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        removeBelow();
        compare(below.filter(key => key === Qt.Key_Escape || key === Qt.Key_Z), [Qt.Key_Escape, Qt.Key_Z, Qt.Key_Z], "Escape, Ctrl+Shift+Z and a Ctrl+Z with nothing left to bring back go on to the layers below");
    }

    function test_after_a_notification_took_the_undo_toasts_place_the_removed_notifications_close_once_their_window_has_run_out() {
        removeBenAndLetDoraTakeTheUndoToastsPlace();
        verify(board.undoLeft.running, "the rest of the window runs");
        compare(board.undoLeft.interval, toaster.undoWindow - 2000, "what the figure showed");
        time = toaster.undoWindow;
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(rowNames(), ["dora", "cleo", "anna"], "a late timer: the window has run out all the same");
        board.undoLeft.triggered();
        compare(calls, ["ben closed 2"]);
        compare(toaster.open.title, "dora");
    }

    function test_removed_notifications_their_app_closes_after_another_toast_took_the_undo_toasts_place_leave_that_toast_alone() {
        board.quiet = true;
        const anna = notify({ summary: "anna" });
        const ben = notify({ summary: "ben" });
        board.quiet = false;
        board.remove(board.rows);
        notify({ summary: "cleo", body: "call me" });
        const toast = toaster.open;
        ben.close(NoticeBoard.CloseRequested);
        anna.close(NoticeBoard.CloseRequested);
        verify(!toast.done);
        compare(shownTitles(), "cleo: call me");
        compare(calls, ["ben closed 3", "anna closed 3"]);
        scene.forceActiveFocus();
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(rowNames(), ["cleo"], "nothing is left to bring back");
    }

    function test_a_removal_while_a_replaced_undo_toasts_window_runs_takes_its_rows_into_the_new_undo_toast_with_a_new_window() {
        removeBenAndLetDoraTakeTheUndoToastsPlace();
        time = 3000;
        board.remove([board.rows[2]]);
        compare(toaster.open.text, "2 meldungen entfernt");
        compare(toaster.open.total, toaster.undoWindow);
        time = toaster.undoWindow;
        board.undoLeft.triggered();
        compare(calls, [], "ben's first window has run out, but the new toast holds him");
        toaster.open.undo();
        compare(rowNames(), ["dora", "cleo", "ben", "anna"]);
        compare(calls, []);
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
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            init();
            notify({ summary: "Mia", body: "Can we move the call to Thursday afternoon? I have the whole morning booked, so any time after lunch works.", image: testCase.picture }, [["default", "open"], ["reply", "reply"]]);
            tryCompare(findChild(toaster.open, "appIcon"), "status", Image.Ready);
            grabImage(scene).save(`notices-sheet-${theme}.png`);
        }
    }

    readonly property var freeSpaceHints: ({ "x-kde-appname": "freespacenotifier", "x-kde-eventId": "freespacenotif" })

    function test_freespacenotifiers_notice_is_neither_toast_nor_row_and_turns_the_storage_state_on() {
        notify({ summary: "Low Disk Space", body: "Root is running out of space.", hints: freeSpaceHints });
        compare(toaster.open, null);
        compare(board.rows.length, 0);
        verify(board.storageFull);
        compare(board.storageText, "Root is running out of space.");
    }

    function test_the_storage_state_follows_the_words_the_program_rewrites() {
        const notice = notify({ summary: "Low Disk Space", body: "5 MiB free", hints: freeSpaceHints });
        notice.body = "4 MiB free";
        notice.bodyChanged.emit();
        compare(board.storageText, "4 MiB free");
    }

    function test_closing_freespacenotifiers_notice_leaves_the_storage_state_on() {
        const notice = notify({ hints: freeSpaceHints });
        notice.close(NoticeBoard.CloseRequested);
        verify(board.storageFull);
    }

    function test_the_storage_state_ends_when_the_notice_has_gone_and_the_shells_own_check_finds_enough_free() {
        const notice = notify({ hints: freeSpaceHints });
        notice.close(NoticeBoard.CloseRequested);
        board.storageChecked(false);
        verify(board.storageFull, "still too little");
        board.storageChecked(true);
        verify(!board.storageFull);
    }

    function test_an_open_notice_keeps_the_storage_state_on_although_the_root_and_home_have_room() {
        const notice = notify({ hints: freeSpaceHints });
        board.storageChecked(true);
        verify(board.storageFull, "the notice may mean another disk");
        notice.close(NoticeBoard.CloseRequested);
        board.storageChecked(true);
        verify(!board.storageFull);
    }

    function test_the_storage_remedy_invokes_the_first_action_of_the_notice_and_leaves_the_state_on() {
        notify({ hints: freeSpaceHints }, [["default", "open"], ["filelight", "Open in Filelight"]]);
        board.cleanUp();
        compare(calls, ["anna invoked filelight", "anna closed 2"]);
        verify(board.storageFull, "the server closed the notice after the action; nothing was freed");
    }

    function test_the_storage_remedy_opens_the_program_and_never_configure_warning() {
        notify({ hints: freeSpaceHints }, [["default", "open"], ["0", "Open in File Manager"], ["1", "Configure Warning…"]]);
        board.cleanUp();
        compare(calls, ["anna invoked 0", "anna closed 2"]);
    }

    function test_the_storage_remedy_is_there_only_while_the_notice_stands() {
        const notice = notify({ hints: freeSpaceHints }, [["default", "open"], ["0", "Open in Filelight"]]);
        verify(board.storageNotice !== null);
        notice.close(NoticeBoard.CloseRequested);
        compare(board.storageNotice, null);
        board.cleanUp();
        compare(calls.filter(call => call.includes("invoked")), []);
    }

    function test_powerdevils_low_battery_notice_is_neither_toast_nor_row() {
        notify({ summary: "Battery Low", hints: { "x-kde-appname": "powerdevil", "x-kde-eventId": "lowbattery" } });
        compare(toaster.open, null);
        compare(board.rows.length, 0);
    }

    function test_powerdevils_critical_battery_notice_stays_a_toast() {
        notify({ summary: "Battery Critical", urgency: NoticeBoard.Critical, hints: { "x-kde-appname": "powerdevil", "x-kde-eventId": "criticalbattery" } });
        compare(shownTitles(), "Battery Critical: lunch at noon?");
        compare(board.rows.length, 1);
    }
}
