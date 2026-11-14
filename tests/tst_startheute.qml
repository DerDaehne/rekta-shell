pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Notices
import Panel
import Rekta
import Start
import State
import "Glide.js" as Glide

// "heute" in the start place: what plays and the newest three notifications, as rows that only show them; live changes,
// holding still, the empty state, the keys and the turn.
TestCase {
    id: testCase

    readonly property easingCurve easeIn: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })

    name: "StartHeute"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1920
    height: 1080

    readonly property string pinkIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAGklEQVR4nGN4aTWLbMQwqnlU86jmUc0DqxkAreu3b+7dCC4AAAAASUVORK5CYII="
    // What the fakes were asked to do, oldest first.
    property var calls: []
    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var start
    property var today
    property NoticeBoard board
    property PlayerChoice choice
    property SignalSpy wanted

    // An MPRIS player as Quickshell has it, as far as "heute" reads it.
    component FakePlayer: QtObject {
        property string identity: "Elisa"
        property string desktopEntry: "org.kde.elisa"
        property int playbackState: PlayerChoice.Playing
        readonly property bool isPlaying: playbackState === PlayerChoice.Playing
        property string trackTitle: "Teardrop"
        property string trackArtist: "Massive Attack"
        property string trackArtUrl: ""
        property bool canRaise: true

        function raise() {
            testCase.calls = [...testCase.calls, `${identity} raised`];
        }
    }

    Component {
        id: playerComponent

        FakePlayer {}
    }

    Component {
        id: sceneComponent

        Item {
            id: scene

            property alias board: noticeBoard
            property alias choice: playerChoice

            Toaster {
                id: region

                width: parent.width
            }

            NoticeBoard {
                id: noticeBoard

                toaster: region
                quiet: true
            }

            PlayerChoice {
                id: playerChoice
            }

            StartPlace {
                objectName: "start"
                width: scene.width
                height: scene.height
                // "heute" is the last section here; "zuletzt" has tests of its own (tst_startzuletzt).
                showRecent: false
                pinned: [testCase.fakeApp("systemsettings", 1), testCase.fakeApp("dolphin", 2), testCase.fakeApp("konsole", 1)]
                board: noticeBoard
                playerChoice: playerChoice
            }
        }
    }

    // A light and a dark window behind the glass.
    Component {
        id: backdropComponent

        Item {
            Rectangle {
                width: parent.width / 2
                height: parent.height
                color: "white"
            }

            Rectangle {
                x: parent.width / 2
                width: parent.width / 2
                height: parent.height
                color: "black"
            }
        }
    }

    Component {
        id: spyComponent

        SignalSpy {}
    }

    function fakeApp(name: string, columns: int): var {
        return {
            id: name,
            name: name,
            icon: testCase.pinkIcon,
            columns: columns,
            rows: 1,
            launch: () => {}
        };
    }

    function fakeWindow(appId: string): var {
        return {
            appId: appId,
            title: appId,
            icon: testCase.pinkIcon,
            lastActivated: 1,
            stackingOrder: 0,
            active: false,
            minimized: false,
            activate: () => {
                testCase.calls = [...testCase.calls, `${appId} activated`];
            }
        };
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "system";
        calls = [];
        makeScene(testCase, testCase.width, testCase.height);
    }

    function cleanup() {
        // A pointer left over from a test would hover what appears under it next.
        mouseMove(testCase, 1, 1);
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    function makeScene(parent: Item, width: real, height: real): Item {
        const scene = createTemporaryObject(sceneComponent, parent, {
            width: width,
            height: height
        });
        start = findChild(scene, "start");
        today = findChild(start, "heute");
        board = scene.board;
        choice = scene.choice;
        wanted = createTemporaryObject(spyComponent, testCase, {
            target: board,
            signalName: "appWanted"
        });
        return scene;
    }

    function named(name: string): var {
        return findChild(start, name);
    }

    // Opens the Start without motion, as a reduced-motion user sees it at once, once the rows that came have settled.
    function openNow() {
        wait(Tokens.durationModerate);
        Prefs.motion = "off";
        start.open();
        Prefs.motion = "system";
        waitForRendering(start);
    }

    function play(properties: var): var {
        const player = createTemporaryObject(playerComponent, testCase, properties ?? {});
        choice.players = [player];
        return player;
    }

    // A signal as a notification has them, to connect() to.
    function signal() {
        const handlers = [];
        return {
            connect: handler => handlers.push(handler),
            emit: (...args) => handlers.forEach(handler => handler(...args))
        };
    }

    // A notification as the server hands it over; `actions` are [identifier, text] pairs.
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
            image: testCase.pinkIcon,
            hints: {},
            closed: signal(),
            summaryChanged: signal(),
            bodyChanged: signal()
        }, properties);
        fake.close = reason => fake.closed.emit(reason);
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

    // Three notifications, the newest first: cleo, ben, anna.
    function three() {
        notify({ summary: "anna", body: "lunch at noon?" }, [["default", "open"], ["reply", "reply"]]);
        notify({ summary: "ben" });
        notify({ summary: "cleo" });
    }

    // The rows in "heute", from the top, leaving ones too.
    function rows(): var {
        return findChild(today, "todayRows").children.filter(child => child instanceof MessageRow);
    }

    function inPlace(): var {
        return rows().filter(row => !row.going).map(row => row.summary);
    }

    function music(): var {
        return findChild(today, "music");
    }

    function test_heute_stands_after_angeheftet_two_units_wide_with_its_title_last_in_the_strip() {
        openNow();
        const section = named("today");
        const pinned = named("pinned");
        compare(named("sectionStrip").titles, ["angeheftet", "heute"]);
        verify(section.visible);
        compare(section.width, 2 * start.unitStep);
        compare(section.x, pinned.x + pinned.width + named("panorama").gap);
        compare(findChild(section, "heading").text, "heute");
        start.windows = [fakeWindow("org.kde.konsole")];
        compare(named("sectionStrip").titles, ["läuft", "angeheftet", "heute"]);
    }

    function test_at_1600_angeheftet_with_many_tiles_widens_only_as_far_as_heute_stays_in_view() {
        makeScene(testCase, 1600, 900);
        start.pinned = Array.from({
            length: 40
        }, (_, i) => fakeApp(`app ${i}`, 1));
        openNow();
        const section = named("today");
        verify(named("pinned").width > 4 * start.unitStep, "angeheftet widens");
        verify(section.x + section.width <= 1600 - Tokens.spaceXl, `${section.x + section.width} past the inset`);
        verify(named("panorama").fit);
    }

    function test_heute_has_the_spaces_and_heading_of_the_other_sections() {
        const section = named("today");
        const pinned = named("pinned");
        compare(section.verticalInset, pinned.verticalInset);
        compare(section.headingSpacing, pinned.headingSpacing);
        compare(section.headingToken, pinned.headingToken);
    }

    function test_a_playing_player_stands_on_top_with_title_and_artist_under_läuft_gerade() {
        play();
        three();
        openNow();
        verify(music().visible);
        compare(findChild(music(), "kicker").text, "läuft gerade");
        compare(findChild(music(), "track").text, "Teardrop · Massive Attack");
        verify(music().mapToItem(today, 0, 0).y < rows()[0].mapToItem(today, 0, 0).y, "above the notifications");
    }

    function test_a_player_paused_with_a_track_stays_and_one_stopped_goes() {
        const player = play({
            playbackState: PlayerChoice.Paused
        });
        openNow();
        verify(music().visible);
        player.playbackState = PlayerChoice.Stopped;
        choice.players = [player];
        tryVerify(() => !music().visible);
    }

    function test_without_a_cover_the_music_icon_stands_beside_the_track() {
        play();
        openNow();
        verify(findChild(music(), "musicIcon").visible);
        verify(!findChild(music(), "cover").visible);
    }

    function test_a_press_on_what_plays_raises_the_player_and_the_start_turns_out_forward() {
        play();
        openNow();
        mouseClick(music());
        compare(calls, ["Elisa raised"]);
        verify(!start.wanted);
    }

    function test_a_player_that_cannot_raise_itself_has_its_window_brought_forward() {
        play({
            canRaise: false
        });
        start.windows = [fakeWindow("org.kde.konsole"), fakeWindow("org.kde.elisa")];
        openNow();
        mouseClick(music());
        compare(calls, ["org.kde.elisa activated"]);
    }

    function test_heute_has_no_playback_buttons() {
        play();
        openNow();
        const buttons = [];
        const collect = item => {
            for (const child of item.children) {
                if (child instanceof IconButton && child.visible)
                    buttons.push(child);
                collect(child);
            }
        };
        collect(today);
        compare(buttons.length, 0);
    }

    function test_the_newest_three_notifications_stand_newest_first() {
        three();
        notify({ summary: "dora" });
        openNow();
        compare(inPlace(), ["dora", "cleo", "ben"]);
    }

    function test_each_row_tells_how_long_ago_against_the_clock() {
        three();
        const later = new Date(Date.now() + 4 * 60000 + 1000);
        today.clock = () => later;
        openNow();
        today.now = today.clock();
        compare(rows().map(row => findChild(row, "time").text), ["vor 4 min", "vor 4 min", "vor 4 min"]);
    }

    function test_the_time_is_renewed_only_while_heute_is_in_sight() {
        three();
        verify(!findChild(today, "tick").running);
        openNow();
        verify(findChild(today, "tick").running);
    }

    function test_a_row_shows_one_line_of_text_and_neither_a_remove_button_nor_actions() {
        three();
        openNow();
        const anna = rows()[2];
        compare(anna.summary, "anna");
        compare(findChild(anna, "body").text, "lunch at noon?");
        compare(findChild(anna, "body").maximumLineCount, 1);
        verify(!findChild(anna, "remove").visible);
        verify(!findChild(anna, "offers").visible);
        compare(findChild(anna, "icon").ground, Qt.rgba(0, 0, 0, 0), "on the glass the picture keeps its square crop");
    }

    function test_delete_on_a_row_removes_nothing() {
        three();
        openNow();
        rows()[0].forceActiveFocus();
        keyClick(Qt.Key_Delete);
        compare(board.rows.length, 3);
    }

    function test_a_press_on_a_row_runs_its_default_action_as_the_centre_does_and_the_start_turns_out() {
        three();
        openNow();
        mouseClick(rows()[2]);
        compare(calls, ["anna invoked default"]);
        verify(!start.wanted);
    }

    function test_a_press_on_a_row_without_a_default_action_brings_its_app_forward() {
        three();
        openNow();
        mouseClick(rows()[0]);
        compare(wanted.count, 1);
        compare(wanted.signalArguments[0][0], "org.example.chat");
    }

    function test_heute_leaves_the_notifications_unseen() {
        three();
        openNow();
        compare(board.unseen, 3);
        verify(board.rows.every(row => row.unseen));
    }

    function test_a_new_notification_enters_at_the_top_and_the_oldest_of_three_leaves() {
        three();
        openNow();
        const anna = rows()[2];
        notify({ summary: "dora" });
        compare(rows()[0].summary, "dora");
        verify(anna.going, "the oldest drifts out");
        compare(inPlace(), ["dora", "cleo", "ben"]);
        tryVerify(() => rows().length === 3, Tokens.durationShort * 4, "then it has gone");
    }

    function test_a_new_row_slides_in_from_above_over_duration_short() {
        const ticks = Glide.ticks(testCase);
        three();
        openNow();
        const since = Date.now();
        notify({ summary: "dora" });
        const dora = rows()[0];
        const fades = Glide.record(dora, "opacity");
        const falls = Glide.record(dora, "y");
        tryVerify(() => fades.length > 0 && dora.opacity === 1, Tokens.durationShort * 4, "it has arrived");
        const stray = Glide.strayOf([{ steps: fades, from: 0, to: 1 }, { steps: falls, from: dora.y - Geometry.rowEnterShift, to: dora.y }], Tokens.durationShort, easeIn, since, ticks);
        verify(stray < 0.06, `it slides in from above and fades up together over duration-short, off by ${stray}`);
    }

    function test_under_the_pointer_heute_holds_still_until_let_go() {
        three();
        openNow();
        mouseMove(rows()[1]);
        notify({ summary: "dora" });
        wait(Tokens.durationShort);
        compare(inPlace(), ["cleo", "ben", "anna"]);
        mouseMove(testCase, 1, 1);
        compare(inPlace(), ["dora", "cleo", "ben"]);
    }

    function test_with_the_focus_in_it_heute_holds_still_until_it_leaves() {
        three();
        openNow();
        rows()[1].forceActiveFocus();
        notify({ summary: "dora" });
        compare(inPlace(), ["cleo", "ben", "anna"]);
        named("pivot").forceActiveFocus();
        compare(inPlace(), ["dora", "cleo", "ben"]);
    }

    function test_under_reduced_motion_a_new_notification_stands_at_once() {
        three();
        openNow();
        Prefs.motion = "off";
        notify({ summary: "dora" });
        compare(rows().map(row => row.summary), ["dora", "cleo", "ben"]);
        compare(rows()[0].opacity, 1);
    }

    function test_a_new_track_peeks_in() {
        const player = play();
        openNow();
        player.trackTitle = "Angel";
        compare(findChild(music(), "track").text, "Angel · Massive Attack");
        const ghost = findChild(music(), "markedGhost");
        verify(ghost.visible);
        compare(ghost.text, "Teardrop · Massive Attack");
    }

    function test_a_new_track_waits_under_the_pointer() {
        const player = play();
        openNow();
        mouseMove(music());
        player.trackTitle = "Angel";
        compare(findChild(music(), "track").text, "Teardrop · Massive Attack");
        mouseMove(testCase, 1, 1);
        compare(findChild(music(), "track").text, "Angel · Massive Attack");
    }

    // The button that counts the waiting updates, once "heute" has laid it out after the rows.
    function waitingButton(): var {
        waitForItemPolished(today);
        return findChild(today, "waiting");
    }

    function test_the_time_stands_at_the_end_of_a_row() {
        three();
        openNow();
        const time = findChild(rows()[0], "time");
        compare(time.x + time.width, rows()[0].width);
    }

    function test_a_row_cannot_be_pulled_away() {
        // The Start's swipe takes a drag across "heute" before a row could, so the row's own pull is checked switched off.
        three();
        openNow();
        verify(!findChild(rows()[0], "pull").enabled);
    }

    function test_a_changed_title_shows_in_its_row() {
        const anna = notify({ summary: "anna" });
        openNow();
        anna.summary = "anna2";
        anna.summaryChanged.emit();
        compare(rows()[0].summary, "anna2");
    }

    function test_when_the_newest_of_four_closes_the_fourth_comes_back_at_the_bottom() {
        three();
        const dora = notify({ summary: "dora" });
        openNow();
        compare(inPlace(), ["dora", "cleo", "ben"]);
        dora.dismiss();
        compare(inPlace(), ["cleo", "ben", "anna"]);
    }

    function test_a_press_on_a_held_row_whose_notification_closed_shows_the_waiting_updates_and_the_start_stays() {
        const anna = notify({ summary: "anna" });
        notify({ summary: "ben" });
        notify({ summary: "cleo" });
        openNow();
        mouseMove(rows()[2]);
        anna.dismiss();
        compare(inPlace(), ["cleo", "ben", "anna"], "held, the row still stands");
        mouseClick(rows()[2]);
        compare(inPlace(), ["cleo", "ben"]);
        compare(wanted.count, 0);
        verify(start.wanted);
    }

    function test_while_held_a_quiet_button_says_how_many_updates_wait() {
        three();
        openNow();
        mouseMove(rows()[1]);
        const more = waitingButton();
        verify(!more.visible, "nothing waits yet");
        notify({ summary: "dora" });
        verify(more.visible);
        compare(more.Accessible.name, "1 aktualisierung wartet · zeigen");
        compare(more.Accessible.role, Accessible.Button);
        compare(findChild(more, "label").color, Tokens.color.textContrastHigh);
        compare(findChild(more, "label").font.pixelSize, Tokens.fontSizeXs);
        notify({ summary: "eve" });
        compare(findChild(more, "label").text, "2 aktualisierungen warten · zeigen");
        mouseMove(waitingButton());
        compare(findChild(more, "label").color, Tokens.color.textPrimary, "under the pointer the words take text-primary");
        mouseMove(testCase, 1, 1);
        verify(!more.visible, "let go, nothing waits");
    }

    function test_the_waiting_button_arrives_from_above_and_fades_up() {
        const ticks = Glide.ticks(testCase);
        Prefs.motion = "on";
        three();
        openNow();
        mouseMove(rows()[1]);
        const more = waitingButton();
        const fades = Glide.record(more, "opacity");
        const falls = Glide.record(more.transform[0], "y");
        const since = Date.now();
        notify({ summary: "dora" });
        verify(more.transform[0].y < 0, "it comes from above");
        tryVerify(() => !findChild(more, "arrive").running, Tokens.durationShort * 4, "it has arrived");
        compare(more.opacity, 1);
        compare(more.transform[0].y, 0);
        const stray = Glide.strayOf([{ steps: fades, from: 0, to: 1 }, { steps: falls, from: -Geometry.arriveDrop, to: 0 }], Tokens.durationShort, easeIn, since, ticks);
        verify(stray < 0.06, `it fades up from above over duration-short, off by ${stray}`);
    }

    function test_a_closed_and_a_changed_notification_wait_as_one_update_each() {
        notify({ summary: "zoe" });
        const anna = notify({ summary: "anna" });
        const ben = notify({ summary: "ben" });
        notify({ summary: "cleo" });
        openNow();
        mouseMove(rows()[0]);
        anna.dismiss();
        compare(waitingButton().count, 1, "anna's close; the older one moving up is no news");
        ben.summary = "ben2";
        ben.summaryChanged.emit();
        compare(waitingButton().count, 2);
    }

    function test_pressing_the_waiting_button_shows_the_updates_while_heute_stays_held() {
        three();
        openNow();
        mouseMove(rows()[1]);
        notify({ summary: "dora" });
        mouseClick(waitingButton());
        verify(today.held);
        compare(inPlace(), ["dora", "cleo", "ben"]);
        verify(!waitingButton().visible);
    }

    function test_a_waiting_track_counts_and_the_button_brings_it() {
        const player = play();
        openNow();
        mouseMove(music());
        player.trackTitle = "Angel";
        compare(waitingButton().count, 1);
        mouseClick(waitingButton());
        compare(findChild(music(), "track").text, "Angel · Massive Attack");
    }

    function test_the_keyboard_reaches_the_waiting_button_and_its_press_keeps_the_focus_in_heute() {
        three();
        openNow();
        rows()[2].forceActiveFocus();
        notify({ summary: "dora" });
        keyClick(Qt.Key_Tab);
        verify(waitingButton().activeFocus);
        keyClick(Qt.Key_Return);
        compare(inPlace(), ["dora", "cleo", "ben"]);
        verify(rows()[0].activeFocus, "the focus goes to the first entry, not left on the hidden button");
    }

    function test_with_nothing_playing_and_no_notification_heute_stays_and_says_so() {
        openNow();
        const empty = findChild(today, "todayEmpty");
        verify(empty.visible);
        compare(empty.text, "nichts läuft, keine meldungen.");
        verify(named("today").visible);
        compare(named("sectionStrip").titles, ["angeheftet", "heute"]);
        notify({ summary: "anna" });
        verify(!empty.visible);
    }

    function test_the_arrows_reach_what_plays_and_each_row_and_enter_presses() {
        play();
        three();
        openNow();
        const pinnedTiles = findChild(named("pinned"), "grid").children.filter(item => (item as Tile) !== null);
        pinnedTiles[pinnedTiles.length - 1].forceActiveFocus();
        keyClick(Qt.Key_Right);
        verify(music().activeFocus, "right from angeheftet");
        keyClick(Qt.Key_Down);
        verify(rows()[0].activeFocus);
        keyClick(Qt.Key_Down);
        verify(rows()[1].activeFocus);
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Up);
        verify(music().activeFocus);
        keyClick(Qt.Key_Left);
        verify(pinnedTiles[pinnedTiles.length - 1].activeFocus, "left back to angeheftet");
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Space);
        compare(calls, ["Elisa raised"]);
    }

    function test_enter_on_a_row_presses_it() {
        three();
        openNow();
        rows()[2].forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(calls, ["anna invoked default"]);
    }

    function test_each_entry_has_its_accessible_name() {
        play();
        three();
        const later = new Date(Date.now() + 4 * 60000 + 1000);
        today.clock = () => later;
        openNow();
        today.now = today.clock();
        compare(music().Accessible.name, "läuft gerade: Teardrop · Massive Attack");
        compare(music().Accessible.role, Accessible.Button);
        compare(rows()[0].Accessible.name, "chat, cleo, vor 4 min");
        compare(rows()[2].Accessible.name, "chat, anna, lunch at noon?, vor 4 min");
    }

    function test_the_entries_turn_in_with_the_start_as_parts_of_its_turn() {
        play();
        three();
        openNow();
        const parts = findChild(start, "turn").partsOf(named("body")).map(part => part.item);
        verify(parts.includes(music()));
        for (const row of rows())
            verify(parts.includes(row), row.summary);
    }

    // One notification the open Start shows, then two more that come while it is closed and move the first one down.
    function closeAndNotifyThree() {
        openNow();
        notify({ summary: "anna" });
        tryVerify(() => !findChild(today, "todayRows").add.running && rows()[0]?.opacity === 1, Tokens.durationShort * 4, "anna has arrived");
        start.close(null);
        tryVerify(() => start.phase === "closed", 3000);
        notify({ summary: "ben" });
        notify({ summary: "cleo" });
        Prefs.motion = "on";
    }

    function rowTurns(turner: var): var {
        return rows().map(row => turner.arrivingTurns.find(turn => turn.part.item === row));
    }

    // Rows that came while the Start was closed arrive with its turn, as its parts: none shows before its own turn,
    // they start from the top, and they are measured where they rest, not on the way of a row's own arrival.
    function test_rows_that_came_while_the_start_was_closed_stay_unseen_until_their_own_turns_which_start_from_the_top() {
        closeAndNotifyThree();
        const turner = findChild(start, "turn");
        start.open();
        tryVerify(() => turner.running, 2000);
        turner.paused = true;
        compare(rows().map(row => row.summary), ["cleo", "ben", "anna"]);
        const turns = rowTurns(turner);
        verify(turns[0].at < turns[1].at && turns[1].at < turns[2].at, turns.map(turn => turn.at - turner.handOverAt).join(", "));
        for (let time = turner.handOverAt; time < turns[2].at; time += 5) {
            turner.elapsed = time;
            wait(5);
            const early = rows().find((row, index) => time < turns[index].at && row.opacity > 0);
            verify(!early, early ? `${early.summary} shows at ${time - turner.handOverAt} ms` : "");
        }
        const measured = turns.map(turn => turn.part.y);
        turner.paused = false;
        turner.finish();
        compare(rows().map(row => row.mapToItem(null, 0, 0).y), measured);
    }

    // A finger plans the opening at once, with no frame between the notifications and the hand-over.
    function test_rows_that_came_while_the_start_was_closed_stay_unseen_as_a_finger_starts_to_open_it() {
        closeAndNotifyThree();
        start.followFinger(1);
        const turns = rowTurns(findChild(start, "turn"));
        wait(Tokens.durationShort);
        compare(rows().map(row => row.opacity), [0, 0, 0]);
        start.letFingerGo();
        tryVerify(() => start.phase === "closed", 3000);
        compare(rows().map(row => row.mapToItem(null, 0, 0).y), turns.map(turn => turn.part.y));
    }

    function test_contact_sheets_of_heute_in_both_themes() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const backdrop = createTemporaryObject(backdropComponent, testCase, {
                width: testCase.width,
                height: testCase.height
            });
            makeScene(backdrop, testCase.width, testCase.height);
            play();
            notify({ summary: "Download fertig", body: "bericht-quartal.pdf wurde in Downloads gespeichert." });
            notify({ summary: "Teamrunde in 10 min", body: "Besprechungsraum Nord, die Folien liegen im Ordner und warten auf alle." });
            notify({ summary: "Beispielgruppe", body: "Treffen wir uns um 18 Uhr am Eingang?" });
            openNow();
            wait(Tokens.durationShort);
            grabImage(backdrop).save(`start-heute-${theme}.png`);
            verify(start.wanted, theme);
        }
    }
}
