pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Notices
import Panel
import Rekta

TestCase {
    id: testCase

    name: "Messages"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 720

    // A 40px app icon: a blue rounded square with a white dot.
    readonly property string picture: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAMAAAC7IEhfAAAAHlBMVEX///86dvBEffF4ofW5zvrs8v7///9Be/GcuvdVifLlkWmGAAAAAXRSTlMAQObYZgAAAI1JREFUOMu11UkOgCAQRFGaocH7X9iFMaKW5DvV+sWANEUIS+wyoY8NA9lGzaCk0AxKCg3mOYwpFy85xTGszde0OoCT95ku4d7tZQ+rH1M1bCfYJIx+TlQwCZgUzAJmBYuARUFXefVFvEa8a/wf8cnws8bTw+eRTzi/M39c17dVcaekvu9HXs287NHzMQN/Vg0WT30WoAAAAABJRU5ErkJggg=="
    // The wall clock the toasts run against, in ms.
    property double time: 0
    // What the fake notifications were asked to do and told, oldest first.
    property var calls: []
    property Item scene
    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var side
    property var messages
    property var opener
    property NoticeBoard board
    property Toaster toaster
    property SignalSpy wanted

    // As the shell has it: "meldungen N" in the bar opens the panel on its facet, and a pressed row closes it.
    component ShellPanel: SidePanel {
        id: panel

        required property NoticeBoard board

        titles: ["steuerung", "meldungen"]

        Item {
            objectName: "controls"
        }

        Messages {
            objectName: "messages"
            board: panel.board
            onActed: panel.close()
        }
    }

    Component {
        id: sceneComponent

        Rectangle {
            width: 900
            height: 640
            color: Tokens.color.bg

            AppBarButton {
                objectName: "opener"
                x: Tokens.spaceL
                y: parent.height - height
                icon: "bell"
                text: "meldungen"
                count: noticeBoard.unseen
                onClicked: scenePanel.toggle(1)
            }

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
                quiet: true
            }

            ShellPanel {
                id: scenePanel

                objectName: "panel"
                anchors.fill: parent
                board: noticeBoard
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
        side = findChild(scene, "panel");
        messages = findChild(scene, "messages");
        opener = findChild(scene, "opener");
        board = findChild(scene, "board");
        toaster = findChild(scene, "toaster");
        wanted = createTemporaryObject(spyComponent, testCase, { target: board, signalName: "appWanted" });
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

    // A notification as the server hands it over, in plain JS as QML reserves "transient"; `actions` are [identifier,
    // text] pairs. Invoking one tells the app and closes the notification, as the server does for one not resident.
    function notify(properties, actions) {
        const fake = Object.assign({
            lastGeneration: false,
            appName: "chat",
            appIcon: "",
            summary: "anna",
            body: "",
            urgency: NoticeBoard.Normal,
            expireTimeout: -1,
            transient: false,
            desktopEntry: "org.example.chat",
            image: testCase.picture,
            hints: {},
            closed: signal(),
            summaryChanged: signal(),
            bodyChanged: signal()
        }, properties);
        fake.close = reason => {
            testCase.calls = [...testCase.calls, `${fake.summary} closed ${reason}`];
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

    // Three quietly collected notifications, the newest first: cleo, ben, anna.
    function three() {
        notify({ summary: "anna" }, [["default", "open"]]);
        notify({ summary: "ben" });
        notify({ summary: "cleo" });
    }

    // The rows in the list, from the top.
    function rows(): var {
        return Array.from(findChild(messages, "rows").children).filter(child => child instanceof MessageRow);
    }

    function summaries(): var {
        return rows().map(row => row.summary);
    }

    function openOnMessages() {
        side.show(1);
        tryCompare(side, "entry", 1, Tokens.durationModerate * 4);
        waitForRendering(scene);
    }

    function named(name: string): var {
        return findChild(messages, name);
    }

    // Pulls a row towards the trailing edge by a share of its width; `release` lets it go.
    function pull(row, share, release) {
        const y = row.height / 2;
        mousePress(row, 10, y);
        mouseMove(row, 30, y);
        mouseMove(row, 10 + share * row.width, y);
        if (release)
            mouseRelease(row, 10 + share * row.width, y);
    }

    function test_the_list_stands_newest_first_with_icon_summary_time_and_one_line_of_body() {
        notify({ summary: "anna", body: "lunch at noon?" });
        notify({ summary: "invoice 2026-10", body: "Your invoice for October is ready. It lists every build minute and every gigabyte of storage you used." });
        openOnMessages();
        compare(summaries(), ["invoice 2026-10", "anna"]);
        const first = rows()[0];
        compare(findChild(first, "icon").source.toString(), testCase.picture);
        compare(findChild(first, "icon").width, Geometry.iconSize);
        compare(findChild(first, "summary").font.weight, Tokens.fontWeightSemibold);
        compare(findChild(first, "time").text, "gerade eben");
        compare(findChild(first, "time").font.features.tnum, 1, "tabular figures");
        const body = findChild(first, "body");
        compare(body.lineCount, 1, "one line of the body");
        verify(body.truncated, "cut");
        verify(findChild(first, "time").x + findChild(first, "time").width <= first.width, "the time at the end");
    }

    function test_rows_stand_on_hairlines_and_the_list_ends_with_one() {
        three();
        openOnMessages();
        const list = rows();
        compare(list[1].y, list[0].y + list[0].height, "each row on the hairline of its top");
        verify(list.every(row => row.implicitHeight > Geometry.hairline + 2 * Tokens.spaceS));
    }

    function test_without_notifications_it_says_keine_meldungen_and_offers_nothing_to_remove() {
        openOnMessages();
        verify(named("empty").visible);
        compare(rows().length, 0);
        verify(!named("head").visible);
        verify(findChild(side, "pivot").activeFocus, "nothing to focus in the list");
    }

    function test_the_bar_control_opens_the_panel_on_meldungen_and_that_sees_them_all() {
        three();
        compare(opener.words, "meldungen 3");
        mouseClick(opener);
        verify(side.open);
        compare(side.currentIndex, 1);
        compare(board.unseen, 0);
        compare(opener.words, "meldungen");
        compare(board.rows.length, 3, "seen, they stay");
        mouseClick(opener);
        tryVerify(() => !side.open, 1000, "pressed again, it closes");
    }

    function test_turning_to_meldungen_sees_them_too() {
        three();
        side.show(0);
        compare(board.unseen, 3);
        findChild(side, "pivot").select(1);
        compare(board.unseen, 0);
    }

    function test_what_comes_while_the_list_is_in_sight_is_seen_there_and_only_there() {
        openOnMessages();
        three();
        compare(board.unseen, 0);
        compare(opener.words, "meldungen");
        findChild(side, "pivot").select(0);
        notify({ summary: "dora" });
        compare(board.unseen, 1, "on the other facet it counts");
    }

    function test_focus_starts_at_the_newest_row_and_up_down_home_end_move_through_the_rows() {
        three();
        openOnMessages();
        const list = rows();
        verify(list[0].activeFocus);
        keyClick(Qt.Key_Down);
        verify(list[1].activeFocus);
        keyClick(Qt.Key_End);
        verify(list[2].activeFocus);
        keyClick(Qt.Key_Down);
        verify(named("clear").activeFocus, "after the rows, alle entfernen");
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Home);
        verify(list[0].activeFocus);
        keyClick(Qt.Key_Escape);
        verify(!side.open, "Escape closes the panel");
    }

    function test_a_row_follows_the_pointer_pulled_towards_the_trailing_edge() {
        three();
        openOnMessages();
        const row = rows()[1];
        pull(row, 0.3, false);
        fuzzyCompare(findChild(row, "content").x, 0.3 * row.width, 1, "it follows");
        mouseMove(row, -40, row.height / 2);
        compare(findChild(row, "content").x, 0, "never towards the leading edge");
        mouseRelease(row, -40, row.height / 2);
    }

    function test_let_go_past_half_its_width_a_row_is_removed_and_short_of_it_it_stays_in_its_place() {
        three();
        openOnMessages();
        pull(rows()[1], 0.45, true);
        compare(summaries(), ["cleo", "ben", "anna"]);
        compare(findChild(rows()[1], "content").x, 0, "back in its place");
        compare(toaster.open, null, "nothing removed");
        pull(rows()[1], 0.55, true);
        compare(summaries(), ["cleo", "anna"]);
        compare(board.rows.map(row => row.summary), ["cleo", "anna"]);
        compare(toaster.open.text, "meldung entfernt");
        compare(calls, [], "it closes only once the undo window has run out");
    }

    function test_a_pulled_row_is_not_pressed() {
        three();
        openOnMessages();
        pull(rows()[2], 0.3, true);
        compare(calls, []);
        verify(side.open);
    }

    function test_delete_removes_the_focused_row_and_the_focus_goes_to_the_next() {
        three();
        openOnMessages();
        keyClick(Qt.Key_Delete);
        compare(summaries(), ["ben", "anna"]);
        verify(rows()[0].activeFocus, "ben");
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_Delete);
        compare(summaries(), ["ben"]);
        verify(rows()[0].activeFocus, "the last gone, the one before");
        keyClick(Qt.Key_Delete);
        compare(summaries(), []);
        verify(findChild(side, "pivot").activeFocus, "none left, the pivot");
        compare(toaster.open.text, "3 meldungen entfernt");
    }

    function test_undo_restores_the_row_in_its_place_and_dismiss_comes_only_once_the_window_has_run_out() {
        three();
        openOnMessages();
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Delete);
        compare(summaries(), ["cleo", "anna"]);
        time = toaster.undoWindow - 1;
        toaster.open.step();
        toaster.open.press();
        compare(summaries(), ["cleo", "ben", "anna"], "back in its place");
        compare(calls, []);
        keyClick(Qt.Key_Delete);
        compare(calls, [], "removed again");
        time += toaster.undoWindow - 1;
        toaster.open.step();
        compare(calls, []);
        time += 1;
        toaster.open.step();
        compare(calls, ["anna closed 2"], "the window has run out");
        compare(toaster.open, null);
    }

    function test_ctrl_z_in_the_panel_undoes_while_the_window_is_open() {
        three();
        openOnMessages();
        keyClick(Qt.Key_Delete);
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(summaries(), ["cleo", "ben", "anna"]);
        verify(side.open);
    }

    function test_alle_entfernen_removes_them_all_and_undo_brings_them_all_back() {
        three();
        openOnMessages();
        mouseClick(named("clear"));
        compare(summaries(), []);
        verify(named("empty").visible);
        compare(toaster.open.text, "3 meldungen entfernt");
        toaster.open.press();
        compare(summaries(), ["cleo", "ben", "anna"]);
        mouseClick(named("clear"));
        time = toaster.undoWindow;
        toaster.open.step();
        compare(calls, ["cleo closed 2", "ben closed 2", "anna closed 2"]);
    }

    // The first row arrived at the given date; the clock tells the given date.
    function tellTime(arrived: date, now: date): string {
        board.rows[0].time = arrived;
        board.rows = board.rows.slice();
        messages.clock = () => now;
        messages.renewNow();
        return findChild(rows()[0], "time").text;
    }

    function test_a_row_tells_how_long_ago_in_rektas_words() {
        notify({ summary: "anna" });
        openOnMessages();
        const arrived = new Date(2026, 9, 28, 10, 0, 20);
        compare(tellTime(arrived, new Date(2026, 9, 28, 10, 0, 50)), "gerade eben");
        compare(tellTime(arrived, new Date(2026, 9, 28, 10, 4, 30)), "vor 4 min");
        compare(tellTime(arrived, new Date(2026, 9, 28, 10, 59, 30)), "vor 59 min");
        compare(tellTime(arrived, new Date(2026, 9, 28, 12, 0, 30)), `um ${Calendar.timeWords(arrived, Qt.locale())}`);
        compare(tellTime(arrived, new Date(2026, 9, 29, 9, 0, 0)), `${Calendar.dateWords(arrived, Qt.locale())} um ${Calendar.timeWords(arrived, Qt.locale())}`);
        compare(tellTime(arrived, new Date(2026, 9, 28, 9, 0, 0)), "gerade eben", "a clock that runs behind does not count backwards");
    }

    function test_the_times_are_renewed_by_one_tick_a_minute_while_the_list_is_in_sight_and_by_none_otherwise() {
        notify({ summary: "anna" });
        const tick = named("tick");
        verify(!tick.running, "the panel is closed");
        openOnMessages();
        verify(tick.running && tick.repeat);
        compare(tick.interval, Calendar.untilNextMinute(messages.now), "it wakes when the minute changes");
        verify(tick.interval <= 60000);
        side.close();
        verify(!tick.running, "closed again");
    }

    function test_the_remove_button_shows_with_the_pointer_or_the_focus_and_removes_with_undo() {
        three();
        openOnMessages();
        const [cleo, ben] = rows();
        const remove = findChild(ben, "remove");
        mouseMove(scene, 1, 1);
        tryVerify(() => !remove.visible, 1000, "not on a row at rest");
        verify(findChild(ben, "time").visible);
        mouseMove(ben, 40, 10);
        verify(remove.visible, "on a row under the pointer");
        verify(!findChild(ben, "time").visible, "in the place of the time");
        compare(remove.label, "entfernen");
        compare(remove.icon, "close");
        verify(!findChild(cleo, "remove").visible || cleo.activeFocus, "only on that row");
        mouseMove(scene, 1, 1);
        verify(!remove.visible);
        ben.forceActiveFocus(Qt.TabFocusReason);
        verify(remove.visible, "on a row with the focus");
        mouseClick(remove);
        compare(summaries(), ["cleo", "anna"]);
        compare(toaster.open.text, "meldung entfernt");
        compare(calls, [], "it closes only once the undo window has run out");
        toaster.open.press();
        compare(summaries(), ["cleo", "ben", "anna"], "undo brings it back");
    }

    function test_the_focus_reaches_the_remove_button_and_the_actions_with_tab_and_enter_presses_them() {
        notify({ summary: "ben" });
        notify({ summary: "anna" }, [["reply", "antworten"], ["later", "später"]]);
        openOnMessages();
        const [row] = rows();
        verify(row.activeFocus);
        keyClick(Qt.Key_Tab);
        verify(findChild(row, "remove").activeFocus, "the remove button");
        keyClick(Qt.Key_Tab);
        verify(offers(row)[0].activeFocus, "antworten");
        keyClick(Qt.Key_Tab);
        verify(offers(row)[1].activeFocus, "später");
        keyClick(Qt.Key_Tab);
        verify(rows()[1].activeFocus, "then the next row");
        keyClick(Qt.Key_Backtab);
        keyClick(Qt.Key_Backtab);
        keyClick(Qt.Key_Backtab);
        verify(findChild(row, "remove").activeFocus);
        keyClick(Qt.Key_Return);
        compare(summaries(), ["ben"], "Enter on the remove button removes it");
        verify(rows()[0].activeFocus, "and the focus goes to the next row");
        compare(toaster.open.text, "meldung entfernt");
    }

    function test_delete_on_a_button_of_the_row_removes_the_row() {
        notify({ summary: "anna" }, [["reply", "antworten"]]);
        openOnMessages();
        offers(rows()[0])[0].forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Delete);
        compare(summaries(), []);
    }

    function offers(row): var {
        return Array.from(findChild(row, "offers").children).filter(child => child instanceof Button);
    }

    function test_up_to_two_actions_stand_under_the_text_and_a_press_runs_the_action_and_not_the_default() {
        notify({ summary: "anna", body: "lunch at noon?" }, [["default", "open"], ["reply", "antworten"], ["later", "später"], ["mute", "stumm"]]);
        notify({ summary: "ben" });
        openOnMessages();
        const [ben, anna] = rows();
        verify(!findChild(ben, "offers").visible, "none without actions");
        const buttons = offers(anna);
        compare(buttons.map(button => button.text), ["antworten", "später"], "two, and not the default one");
        verify(buttons.every(button => button.variant === "quiet"));
        verify(buttons[0].mapToItem(anna, 0, 0).y >= findChild(anna, "body").y + findChild(anna, "body").height, "under the text");
        verify(anna.height >= findChild(anna, "body").y + findChild(anna, "body").height + buttons[0].height);
        mouseClick(buttons[1]);
        compare(calls, ["anna invoked later", "anna closed 2"]);
        verify(!side.open, "as a press on the row, the panel goes");
        compare(summaries(), ["ben"]);
    }

    function test_a_row_that_ran_out_offers_no_actions() {
        notify({ summary: "anna" }, [["reply", "antworten"]]);
        board.rows[0].notification.expire();
        openOnMessages();
        compare(summaries(), ["anna"]);
        verify(!findChild(rows()[0], "offers").visible);
    }

    function test_the_row_itself_still_runs_the_default_action_beside_its_buttons() {
        notify({ summary: "anna" }, [["default", "open"], ["reply", "antworten"]]);
        openOnMessages();
        mouseClick(rows()[0], 100, 12);
        compare(calls, ["anna invoked default", "anna closed 2"]);
    }

    function test_the_head_above_the_rows_counts_them_and_removes_them_all_with_undo() {
        notify({ summary: "anna" });
        openOnMessages();
        compare(named("count").text, "1 meldung");
        three();
        waitForRendering(scene);
        compare(named("count").text, "4 meldungen");
        const head = named("head");
        verify(head.visible);
        verify(head.mapToItem(scene, 0, 0).y + head.height <= rows()[0].mapToItem(scene, 0, 0).y, "above the rows");
        verify(named("clear").x + named("clear").width <= head.width && named("clear").x > named("count").width, "the count first, the button at the end");
        compare(named("clear").text, "alle entfernen");
        mouseClick(named("clear"));
        compare(summaries(), []);
        compare(toaster.open.text, "4 meldungen entfernt");
        toaster.open.press();
        compare(summaries().length, 4, "undo for all");
    }

    function test_nothing_stands_below_the_last_row_but_its_hairline() {
        three();
        openOnMessages();
        const last = rows()[2];
        const list = findChild(messages, "rows");
        verify(named("clear").mapToItem(messages, 0, 0).y < list.mapToItem(messages, 0, 0).y, "the button is not at the end");
        verify(messages.height <= list.mapToItem(messages, 0, 0).y + list.height + Geometry.hairline + Tokens.spaceL + 1);
        verify(last.y >= 0);
    }

    function test_a_press_on_a_row_runs_its_default_action_and_the_panel_goes() {
        three();
        openOnMessages();
        mouseClick(rows()[2]);
        compare(calls, ["anna invoked default", "anna closed 2"]);
        verify(!side.open);
        compare(summaries(), ["cleo", "ben"]);
    }

    function test_without_a_default_action_a_press_or_enter_brings_the_app_forward_and_the_panel_goes() {
        three();
        openOnMessages();
        keyClick(Qt.Key_Return);
        compare(Array.from(wanted.signalArguments[0]), ["org.example.chat", "chat"]);
        compare(calls, ["cleo closed 2"]);
        verify(!side.open);
    }

    function test_a_row_that_arrives_comes_in_on_top_and_keeps_the_focus_where_it_was() {
        three();
        openOnMessages();
        keyClick(Qt.Key_Down);
        const ben = rows()[1];
        notify({ summary: "dora" });
        compare(summaries(), ["dora", "cleo", "ben", "anna"]);
        verify(ben.activeFocus, "the rows that stay keep their focus");
    }

    function test_a_leaving_row_drifts_towards_the_trailing_edge_and_fades_then_the_rest_close_the_gap() {
        three();
        openOnMessages();
        Prefs.motion = "on";
        const cleo = rows()[0];
        const ben = rows()[1];
        const benWas = ben.y;
        keyClick(Qt.Key_Delete);
        const going = findChild(cleo, "content");
        wait(Geometry.rowLeaveShare * Tokens.durationShort / 2);
        verify(going.x > 0 && going.x < Geometry.rowLeaveDrift, `drifting: ${going.x}`);
        verify(going.opacity > 0 && going.opacity < 1, `fading: ${going.opacity}`);
        compare(ben.y, benWas, "the rest wait for it");
        tryVerify(() => summaries().length === 2, 1000);
        compare(summaries(), ["ben", "anna"]);
        wait(Tokens.durationModerate / 2);
        verify(ben.y < benWas && ben.y > 0, `closing the gap: ${ben.y}`);
        tryCompare(ben, "y", 0, 1000);
    }

    function test_a_row_that_comes_back_slides_in_from_above_and_fades_up() {
        three();
        openOnMessages();
        keyClick(Qt.Key_Delete);
        Prefs.motion = "on";
        toaster.open.press();
        const cleo = rows()[0];
        wait(Tokens.durationShort / 3);
        verify(cleo.opacity > 0 && cleo.opacity < 1, `fading up: ${cleo.opacity}`);
        verify(cleo.y < 0 && cleo.y > -Geometry.rowEnterShift, `from above: ${cleo.y}`);
        tryCompare(cleo, "opacity", 1, 1000);
        tryCompare(cleo, "y", 0, 1000);
    }

    function test_under_reduced_motion_rows_go_at_once_and_the_undo_window_stays() {
        three();
        openOnMessages();
        pull(rows()[0], 0.6, true);
        compare(summaries(), ["ben", "anna"], "gone at once");
        waitForItemPolished(findChild(messages, "rows"));
        compare(rows()[0].y, 0, "the gap closed with the next layout");
        compare(toaster.open.total, toaster.undoWindow, "the window is the user's time, not motion");
        verify(toaster.undoWindow > 0);
    }

    // Both themes: the panel open on meldungen, with a picture, a long body and a row without body.
    function test_contact_sheet_of_the_notification_centre_in_both_themes() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            init();
            notify({ appName: "updates", summary: "12 updates installed", image: "" });
            notify({ summary: "invoice 2026-10", body: "Your invoice for October is ready. It lists every build minute and every gigabyte of storage you used." });
            notify({ summary: "Mia", body: "Can we move the call to Thursday afternoon?" }, [["reply", "antworten"], ["later", "später"]]);
            openOnMessages();
            keyClick(Qt.Key_Down);
            tryVerify(() => rows().every(row => findChild(row, "icon").status !== Image.Loading));
            waitForRendering(scene);
            grabImage(scene).save(`messages-sheet-${theme}.png`);
        }
    }
}
