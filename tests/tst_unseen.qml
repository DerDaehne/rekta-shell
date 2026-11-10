pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Notices
import Rekta
import Start
import "ContactSheets.js" as ContactSheets

TestCase {
    id: testCase

    name: "Unseen"
    visible: true
    when: windowShown
    width: 1000
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

                AppTile {
                    name: "Chat"
                    icon: testCase.pinkIcon
                    unseen: 128
                    columns: 2
                    rows: 2
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

    function count(tile: var): var {
        return part(tile, "count");
    }

    function test_an_app_tile_with_unseen_notifications_shows_the_count_at_its_top_trailing_corner_beside_its_name() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 1 });
        waitForRendering(tile);
        compare(count(tile).text, "1");
        verify(count(tile).visible);
        compare(count(tile).x + count(tile).width, tile.width - Geometry.tilePadding);
        compare(count(tile).y, Geometry.tilePadding);
        verify(part(tile, "name").visible, "the name stays at the foot");
        verify(part(tile, "icon").visible, "the icon stays");
        compare(tile.status, "", "a count is no status");
        compare(part(tile, "fill").color, Tokens.color.surface);
    }

    function test_the_count_is_m_medium_in_tabular_figures_on_a_line_as_high_as_its_size() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 12 });
        const number = count(tile);
        compare(number.font.pixelSize, Tokens.fontSizeM);
        compare(number.font.weight, Tokens.fontWeightMedium);
        compare(number.font.features.tnum, 1);
        compare(number.lineHeight, Tokens.fontSizeM * Geometry.launchCountLineHeight);
        compare(number.color, Tokens.color.textPrimary);
    }

    function test_an_app_tile_without_unseen_notifications_shows_no_count() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 0 });
        verify(!count(tile).visible);
        verify(part(tile, "name").visible);
    }

    function test_a_tile_back_at_zero_shows_no_count() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        tile.unseen = 0;
        verify(!count(tile).visible);
        verify(part(tile, "name").visible);
    }

    function test_the_tile_reads_its_name_first_then_its_count_and_only_its_name_without_one() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 3 });
        compare(tile.Accessible.name, "Chat, 3 ungelesen");
        tile.unseen = 0;
        compare(tile.Accessible.name, "Chat");
        compare(tile.Accessible.description, "");
    }

    function test_a_new_count_peeks_in_over_duration_moderate() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        waitForRendering(tile);
        tile.unseen = 3;
        compare(count(tile).text, "3");
        const ghost = part(tile, "markedGhost");
        verify(ghost.visible);
        compare(ghost.text, "2");
        compare(Qt.point(ghost.x, ghost.y), count(tile).mapToItem(part(tile, "news"), 0, 0), "where the count stands");
        compare(ghost.font.pixelSize, Tokens.fontSizeM);
        compare(part(tile, "peekRun").duration, Tokens.durationModerate);
        tryCompare(ghost, "visible", false, Tokens.durationModerate * 3);
    }

    function test_a_count_that_gains_or_loses_a_digit_rises_in_its_own_new_place_while_the_old_one_leaves_from_where_it_stood_data() {
        return [
            { tag: "9 to 10", from: 9, to: 10 },
            { tag: "99 to 100", from: 99, to: 100 },
            { tag: "10 to 9", from: 10, to: 9 }
        ];
    }

    function test_a_count_that_gains_or_loses_a_digit_rises_in_its_own_new_place_while_the_old_one_leaves_from_where_it_stood(data) {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: data.from });
        waitForRendering(tile);
        const news = part(tile, "news");
        const before = count(tile).mapToItem(news, 0, 0);
        tile.unseen = data.to;
        const after = count(tile).mapToItem(news, 0, 0);
        verify(after.x !== before.x, "the count moved along the trailing edge");
        compare(part(tile, "markedGhost").x, before.x, "the old one leaves from where it stood");
        compare(part(tile, "incoming").x, after.x, "the new one rises where it stays when the peek ends");
    }

    function test_the_first_count_is_no_news() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        verify(!part(tile, "markedGhost").visible);
        compare(count(tile).text, "2");
    }

    function test_a_count_waits_while_the_tile_has_the_focus_and_comes_when_it_is_let_go() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        tile.forceActiveFocus();
        verify(tile.activeFocus);
        tile.unseen = 3;
        compare(count(tile).text, "2", "it waits");
        tile.focus = false;
        tile.parent.forceActiveFocus();
        compare(count(tile).text, "3");
    }

    function test_a_count_that_goes_to_zero_leaves_at_once_without_a_peek() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        waitForRendering(tile);
        tile.unseen = 0;
        verify(!count(tile).visible);
        verify(!part(tile, "markedGhost").visible, "no leaving number");
        verify(!tile.clip);
    }

    function test_a_count_that_comes_from_zero_shows_at_once_without_a_peek() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 0 });
        tile.unseen = 2;
        compare(count(tile).text, "2");
        verify(count(tile).visible);
        verify(!part(tile, "markedGhost").visible);
    }

    function test_a_count_that_goes_to_zero_during_a_peek_ends_the_peek() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        waitForRendering(tile);
        tile.unseen = 3;
        verify(part(tile, "markedGhost").visible);
        tile.unseen = 0;
        verify(!part(tile, "markedGhost").visible);
        verify(!count(tile).visible);
    }

    function test_a_held_count_that_changed_and_then_went_to_zero_leaves_without_a_peek_when_let_go() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        tile.forceActiveFocus();
        tile.unseen = 3;
        tile.unseen = 0;
        compare(count(tile).text, "2", "it waits");
        tile.parent.forceActiveFocus();
        verify(!count(tile).visible);
        verify(!part(tile, "markedGhost").visible, "no leaving number");
        verify(!tile.clip);
    }

    function test_a_pointer_over_the_icon_of_an_app_tile_holds_the_count() {
        const tile = createTemporaryObject(tileComponent, testCase, { x: 300, y: 100, unseen: 2 });
        waitForRendering(tile);
        mouseMove(testCase, 5, 5);
        mouseMove(tile, Geometry.tilePadding + 5, Geometry.tilePadding + 5);
        tryVerify(() => tile.hovered);
        tile.unseen = 3;
        compare(count(tile).text, "2", "it waits");
        mouseMove(testCase, 5, 5);
        tryCompare(count(tile), "text", "3");
    }

    function test_under_reduced_motion_the_count_changes_at_once() {
        Prefs.motion = "off";
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2 });
        tile.unseen = 5;
        compare(count(tile).text, "5");
        verify(!part(tile, "markedGhost").visible);
        compare(part(tile, "peekRun").duration, 0);
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

    function test_the_start_hands_a_running_tile_no_count_as_the_count_stands_on_its_apps_launch_tile() {
        const start = createTemporaryObject(startComponent, testCase, { unseen: { "org.example.chat": 2 } });
        const running = tilesIn(start, "running")[0];
        compare(part(running, "count"), null);
        compare(running.Accessible.name, "Chat: lunch");
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
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const sheet = createTemporaryObject(sheetComponent, testCase);
            waitForRendering(sheet);
            grabImage(sheet).save(`start-unseen-sheet-${theme}.png`);
        }
    }
}
