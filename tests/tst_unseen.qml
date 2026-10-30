pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Notices
import Rekta
import Start

TestCase {
    id: testCase

    name: "Unseen"
    visible: true
    when: windowShown
    width: 900
    height: 400

    readonly property string pinkIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAGklEQVR4nGN4aTWLbMQwqnlU86jmUc0DqxkAreu3b+7dCC4AAAAASUVORK5CYII="
    property NoticeBoard board

    // Desktop entries the fake lookup knows by app name, as the shell's lookup knows them.
    readonly property var entriesByName: ({ "Chat": "org.example.chat" })

    Component {
        id: boardComponent

        NoticeBoard {
            toaster: Toaster {}
            appOf: (desktopEntry, appName) => desktopEntry || testCase.entriesByName[appName] || ""
        }
    }

    Component {
        id: tileComponent

        AppTile {
            name: "Chat"
            icon: testCase.pinkIcon
        }
    }

    Component {
        id: previewComponent

        Rectangle {
            property var window
            color: "steelblue"
        }
    }

    Component {
        id: runningComponent

        RunningTile {
            title: "Chat: lunch"
            icon: testCase.pinkIcon
        }
    }

    Component {
        id: sheetComponent

        Rectangle {
            width: testCase.width
            height: testCase.height
            color: Tokens.color.bg

            Row {
                x: Tokens.spaceL
                y: Tokens.spaceL
                spacing: Tokens.spaceS

                Repeater {
                    model: [0, 3, 12]

                    delegate: AppTile {
                        required property int modelData

                        name: "Systemeinstellungen"
                        icon: testCase.pinkIcon
                        unseen: modelData
                    }
                }

                RunningTile {
                    title: "Chat: lunch"
                    icon: testCase.pinkIcon
                    unseen: 3
                }
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "system";
        board = createTemporaryObject(boardComponent, testCase);
    }

    function cleanup() {
        // A pointer left over from a test would hover the next tile that appears under it.
        mouseMove(testCase, width - 1, height - 1);
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    // A notification as the server hands it over, as far as the board counts it.
    function notify(appName: string, desktopEntry: string): var {
        const none = { connect: () => {} };
        const fake = {
            lastGeneration: true,
            appName,
            desktopEntry,
            appIcon: "",
            summary: "anna",
            body: "lunch at noon?",
            urgency: NoticeBoard.Normal,
            transient: false,
            image: "",
            actions: [],
            closed: none,
            summaryChanged: none,
            bodyChanged: none
        };
        board.arrive(fake);
        board.rows.forEach(row => row.unseen = true);
        board.rows = board.rows.slice();
        return fake;
    }

    function part(item: var, name: string): var {
        return findChild(item, name);
    }

    function test_a_notification_counts_for_the_app_its_desktop_entry_hint_names() {
        notify("whatever the app calls itself", "org.example.chat");
        notify("other", "org.example.mail");
        compare(board.unseenByApp["org.example.chat"], 1);
        compare(board.unseenByApp["org.example.mail"], 1);
    }

    function test_a_notification_without_a_hint_counts_for_the_app_its_name_fits() {
        notify("Chat", "");
        compare(board.unseenByApp["org.example.chat"], 1);
    }

    function test_a_notification_of_no_known_app_counts_for_none() {
        notify("Nobody", "");
        compare(Object.keys(board.unseenByApp).length, 0);
        compare(board.unseen, 1, "the bar still counts it");
    }

    function test_seeing_the_list_sets_every_app_to_zero() {
        notify("Chat", "");
        notify("x", "org.example.mail");
        board.listInSight = true;
        compare(Object.keys(board.unseenByApp).length, 0);
    }

    function test_removing_a_notification_takes_it_out_of_its_apps_count() {
        notify("Chat", "");
        notify("Chat", "");
        board.remove([board.rows[0]]);
        compare(board.unseenByApp["org.example.chat"], 1);
    }

    function test_the_counts_add_up_to_the_bars_count() {
        notify("Chat", "");
        notify("Chat", "org.example.chat");
        notify("x", "org.example.mail");
        const total = Object.values(board.unseenByApp).reduce((sum, n) => sum + n, 0);
        compare(total, board.unseen);
    }

    function test_an_app_tile_with_unseen_notifications_shows_the_count_over_ungelesen_and_its_name_in_place_of_the_name() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 1 });
        const stat = part(tile, "number");
        compare(stat.text, "1");
        compare(part(tile, "words").text, "ungelesen · Chat");
        verify(stat.visible);
        verify(!part(tile, "name").visible, "the name gives way");
        verify(part(tile, "icon").visible, "the icon stays");
        compare(tile.status, "", "a number is no status");
    }

    function test_an_app_tile_without_unseen_notifications_shows_only_its_name() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 0 });
        verify(!part(tile, "number").visible);
        verify(part(tile, "name").visible);
    }

    function test_a_tile_back_at_zero_shows_its_name_again() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        tile.unseen = 0;
        verify(part(tile, "name").visible);
        verify(!part(tile, "number").visible);
    }

    function test_a_new_count_peeks_in_over_duration_moderate() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        waitForRendering(tile);
        tile.unseen = 3;
        compare(part(tile, "number").text, "3");
        verify(part(tile, "ghost").visible);
        compare(part(tile, "ghost").value, "2");
        compare(part(tile, "peekRun").duration, Tokens.durationModerate);
        tryCompare(part(tile, "ghost"), "visible", false, Tokens.durationModerate * 3);
    }

    function test_the_first_count_is_no_news() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        verify(!part(tile, "ghost").visible);
    }

    function test_a_count_waits_while_the_tile_has_the_focus_and_comes_when_it_is_let_go() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        tile.forceActiveFocus();
        verify(tile.activeFocus);
        tile.unseen = 3;
        compare(part(tile, "number").text, "2", "it waits");
        tile.focus = false;
        tile.parent.forceActiveFocus();
        compare(part(tile, "number").text, "3");
    }

    function test_a_count_that_goes_to_zero_shows_the_name_at_once_without_a_peek() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        waitForRendering(tile);
        tile.unseen = 0;
        verify(part(tile, "name").visible);
        verify(!part(tile, "ghost").visible, "no leaving number over the name");
        verify(!tile.clip);
    }

    function test_a_count_that_comes_from_zero_shows_at_once_without_a_peek() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 0 });
        tile.unseen = 2;
        compare(part(tile, "number").text, "2");
        verify(!part(tile, "ghost").visible);
        verify(!part(tile, "name").visible);
    }

    function test_a_count_that_goes_to_zero_during_a_peek_ends_the_peek() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        waitForRendering(tile);
        tile.unseen = 3;
        verify(part(tile, "ghost").visible);
        tile.unseen = 0;
        verify(!part(tile, "ghost").visible);
        verify(part(tile, "name").visible);
    }

    function test_a_held_count_that_changed_and_then_went_to_zero_shows_the_name_without_a_peek_when_let_go() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        tile.forceActiveFocus();
        tile.unseen = 3;
        tile.unseen = 0;
        compare(part(tile, "number").text, "2", "it waits");
        tile.parent.forceActiveFocus();
        verify(part(tile, "name").visible);
        verify(!part(tile, "ghost").visible, "no leaving number over the name");
        verify(!tile.clip);
    }

    function test_a_pointer_over_the_icon_of_an_app_tile_holds_the_count() {
        const tile = createTemporaryObject(tileComponent, testCase, { x: 300, y: 100, unseen: 2 });
        waitForRendering(tile);
        mouseMove(testCase, 5, 5);
        mouseMove(tile, Geometry.tilePadding + 5, Geometry.tilePadding + 5);
        tryVerify(() => tile.hovered);
        tile.unseen = 3;
        compare(part(tile, "number").text, "2", "it waits");
        mouseMove(testCase, 5, 5);
        tryCompare(part(tile, "number"), "text", "3");
    }

    function test_a_pointer_over_the_preview_of_a_running_tile_holds_the_count() {
        const tile = createTemporaryObject(runningComponent, testCase, { x: 300, y: 100, unseen: 2, preview: previewComponent });
        waitForRendering(tile);
        mouseMove(testCase, 5, 5);
        mouseMove(tile, tile.width / 2, 20);
        tryVerify(() => tile.hovered);
        tile.unseen = 3;
        compare(part(tile, "number").text, "2", "it waits");
        mouseMove(testCase, 5, 5);
        tryCompare(part(tile, "number"), "text", "3");
    }

    function test_the_focus_on_a_running_tile_holds_the_count() {
        const tile = createTemporaryObject(runningComponent, testCase, { unseen: 2 });
        tile.forceActiveFocus();
        verify(tile.activeFocus);
        tile.unseen = 3;
        compare(part(tile, "number").text, "2", "it waits");
        tile.parent.forceActiveFocus();
        compare(part(tile, "number").text, "3");
    }

    function test_under_reduced_motion_the_count_changes_at_once() {
        Prefs.motion = "off";
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        tile.unseen = 5;
        compare(part(tile, "number").text, "5");
        compare(part(tile, "peekRun").duration, 0);
    }

    function test_a_running_tile_shows_the_count_beside_its_icon_in_place_of_the_title() {
        const tile = createTemporaryObject(runningComponent, testCase, { unseen: 4 });
        compare(part(tile, "number").text, "4");
        compare(part(tile, "words").text, "ungelesen · Chat: lunch");
        verify(!part(tile, "title").visible);
        verify(part(tile, "icon").visible);
    }

    function test_a_running_tile_peeks_a_new_count_though_its_stat_sits_in_a_row() {
        const tile = createTemporaryObject(runningComponent, testCase, { unseen: 4 });
        waitForRendering(tile);
        tile.unseen = 5;
        verify(part(tile, "ghost").visible);
        compare(part(tile, "ghost").value, "4");
    }

    function tilesIn(start: var, section: string): var {
        return findChild(findChild(start, section), "grid").children.filter(item => (item as Tile) !== null);
    }

    function test_the_start_hands_a_pinned_tile_the_count_of_its_app_by_id() {
        const start = createTemporaryObject(startComponent, testCase, { unseen: { "org.example.chat": 2 } });
        const [chat, mail] = tilesIn(start, "pinned");
        compare(chat.unseen, 2);
        compare(mail.unseen, 0);
    }

    function test_the_start_hands_a_running_tile_the_count_of_its_windows_app() {
        const start = createTemporaryObject(startComponent, testCase, { unseen: { "org.example.chat": 2 } });
        compare(tilesIn(start, "running")[0].unseen, 2);
    }

    function test_a_pinned_tile_follows_the_count_as_it_changes() {
        const start = createTemporaryObject(startComponent, testCase, { unseen: { "org.example.chat": 2 } });
        start.unseen = { "org.example.chat": 3 };
        compare(tilesIn(start, "pinned")[0].unseen, 3);
    }

    Component {
        id: startComponent

        StartPlace {
            width: testCase.width
            height: testCase.height
            windows: [{ title: "Chat: lunch", appId: "org.example.chat", icon: testCase.pinkIcon, lastActivated: 1, stackingOrder: 0, active: false, activate: () => {} }]
            pinned: [{ id: "org.example.chat", name: "Chat", icon: testCase.pinkIcon, columns: 1, rows: 1, launch: () => {} }, { id: "org.example.mail", name: "Mail", icon: testCase.pinkIcon, columns: 1, rows: 1, launch: () => {} }]
        }
    }

    function test_contact_sheet() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const sheet = createTemporaryObject(sheetComponent, testCase);
            waitForRendering(sheet);
            grabImage(sheet).save(`start-unseen-sheet-${theme}.png`);
        }
    }
}
