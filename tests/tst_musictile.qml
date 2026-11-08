pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Start
import State

TestCase {
    id: testCase

    name: "MusicTile"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 600

    readonly property string pinkIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAGklEQVR4nGN4aTWLbMQwqnlU86jmUc0DqxkAreu3b+7dCC4AAAAASUVORK5CYII="
    readonly property string teardrop: "Läuft gerade: Teardrop · Massive Attack"
    readonly property string angel: "Läuft gerade: Angel · Massive Attack"
    property PlayerChoice choice

    // An MPRIS player as Quickshell has it, as far as the Start reads it.
    component FakePlayer: QtObject {
        property string identity: "Elisa"
        property int playbackState: PlayerChoice.Playing
        readonly property bool isPlaying: playbackState === PlayerChoice.Playing
        property string trackTitle: "Teardrop"
        property string trackArtist: "Massive Attack"
    }

    Component {
        id: playerComponent

        FakePlayer {}
    }

    Component {
        id: choiceComponent

        PlayerChoice {}
    }

    Component {
        id: tileComponent

        AppTile {
            name: "Elisa"
            icon: testCase.pinkIcon
            columns: 2
        }
    }

    // The Start as the shell feeds it: the line of what plays, by the app of the player that plays.
    Component {
        id: startComponent

        StartPlace {
            width: testCase.width
            height: testCase.height
            pinned: [{ id: "org.kde.elisa", name: "Elisa", icon: testCase.pinkIcon, columns: 2, rows: 1, launch: () => {} }, { id: "org.example.mail", name: "Mail", icon: testCase.pinkIcon, columns: 2, rows: 1, launch: () => {} }, { id: "org.kde.vvave", name: "Vvave", icon: testCase.pinkIcon, columns: 1, rows: 1, launch: () => {} }]
            lines: Rules.playingLines(testCase.choice?.playingPlayer ?? null, testCase.choice?.playingPlayer?.identity === "Vvave" ? "org.kde.vvave" : "org.kde.elisa")
        }
    }

    Component {
        id: sheetComponent

        Rectangle {
            width: testCase.width
            height: 3 * Tokens.tileUnit + Tokens.spaceS + 2 * Tokens.spaceL
            color: Tokens.color.bg

            Flow {
                x: Tokens.spaceL
                y: Tokens.spaceL
                width: 5 * Tokens.tileUnit + 4 * Tokens.spaceS
                spacing: Tokens.spaceS

                AppTile {
                    name: "Elisa"
                    icon: testCase.pinkIcon
                    line: testCase.teardrop
                }

                AppTile {
                    name: "Elisa"
                    icon: testCase.pinkIcon
                    columns: 2
                    line: testCase.teardrop
                }

                AppTile {
                    name: "Elisa"
                    icon: testCase.pinkIcon
                    columns: 2
                    unseen: 3
                    line: "Läuft gerade: Unfinished Sympathy (Paul Oakenfold Remix, extended) · Massive Attack, Shara Nelson"
                }

                AppTile {
                    name: "Elisa"
                    icon: testCase.pinkIcon
                    columns: 2
                    rows: 2
                    line: testCase.angel
                }
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "system";
        choice = createTemporaryObject(choiceComponent, testCase);
    }

    function cleanup() {
        // A pointer left over from a test would hover the next tile that appears under it.
        mouseMove(testCase, width - 1, height - 1);
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    function player(properties: var): var {
        return createTemporaryObject(playerComponent, testCase, properties ?? {});
    }

    function line(item: var): var {
        return findChild(item, "line");
    }

    function test_a_wide_launch_tile_shows_the_newest_line_between_its_icon_and_its_name() {
        const tile = createTemporaryObject(tileComponent, testCase, { line: teardrop });
        waitForRendering(tile);
        const text = line(tile);
        verify(text.visible);
        compare(text.text, teardrop);
        const name = findChild(tile, "name");
        const icon = findChild(tile, "icon");
        compare(text.mapToItem(tile, 0, text.height).y + Tokens.spaceS, name.mapToItem(tile, 0, 0).y, "space-s above the name");
        verify(text.mapToItem(tile, 0, 0).y > icon.y + icon.height, "below the icon");
        compare(text.mapToItem(tile, 0, 0).x, Geometry.tilePadding);
        compare(text.width, tile.width - 2 * Geometry.tilePadding);
    }

    function test_the_line_is_s_regular_in_the_primary_text_colour_on_compact_lines() {
        const text = line(createTemporaryObject(tileComponent, testCase, { line: teardrop }));
        compare(text.font.pixelSize, Tokens.fontSizeS);
        compare(text.font.weight, Tokens.fontWeightRegular);
        compare(text.color, Tokens.color.textPrimary);
        compare(text.lineHeight, Tokens.fontSizeS * Tokens.lineHeightCompact);
    }

    function test_a_long_line_ends_in_an_ellipsis_after_two_lines() {
        const long = "Läuft gerade: " + "Unfinished Sympathy ".repeat(8) + "· Massive Attack";
        const tile = createTemporaryObject(tileComponent, testCase, { line: long });
        waitForRendering(tile);
        const text = line(tile);
        compare(text.lineCount, 2);
        verify(text.truncated);
        compare(text.elide, Text.ElideRight);
    }

    function test_a_tile_one_unit_wide_shows_no_line() {
        const tile = createTemporaryObject(tileComponent, testCase, { columns: 1, line: teardrop });
        verify(!line(tile).visible);
        verify(findChild(tile, "name").visible);
    }

    function test_a_tile_without_a_line_shows_none() {
        verify(!line(createTemporaryObject(tileComponent, testCase)).visible);
    }

    function test_the_tile_reads_its_name_then_its_count_then_its_line() {
        const tile = createTemporaryObject(tileComponent, testCase, { line: teardrop });
        compare(tile.Accessible.name, `Elisa, ${teardrop}`);
        tile.unseen = 2;
        compare(tile.Accessible.name, `Elisa, 2 ungelesen, ${teardrop}`);
    }

    function test_a_tile_one_unit_wide_does_not_read_the_line_it_does_not_show() {
        const tile = createTemporaryObject(tileComponent, testCase, { columns: 1, line: teardrop });
        compare(tile.Accessible.name, "Elisa");
    }

    function test_a_new_line_peeks_in_over_duration_moderate() {
        const tile = createTemporaryObject(tileComponent, testCase, { line: teardrop });
        waitForRendering(tile);
        tile.line = angel;
        compare(line(tile).text, angel);
        const ghost = findChild(tile, "markedGhost");
        verify(ghost.visible);
        compare(ghost.text, teardrop);
        compare(Qt.point(ghost.x, ghost.y), line(tile).mapToItem(findChild(tile, "news"), 0, 0), "where the line stands");
        compare(ghost.font.pixelSize, Tokens.fontSizeS);
        compare(ghost.maximumLineCount, Geometry.launchLineCount, "the old line leaves as it stood, two lines at most");
        compare(ghost.wrapMode, line(tile).wrapMode);
        compare(ghost.elide, Text.ElideRight);
        compare(findChild(tile, "incoming").sourceItem, line(tile), "the new line rises");
        tryCompare(ghost, "visible", false, Tokens.durationModerate * 3);
    }

    function test_a_new_line_of_another_height_rises_where_it_stands_while_the_old_one_leaves_from_where_it_stood() {
        const long = "Läuft gerade: " + "Unfinished Sympathy ".repeat(8) + "· Massive Attack";
        const tile = createTemporaryObject(tileComponent, testCase, { line: long });
        waitForRendering(tile);
        const news = findChild(tile, "news");
        const before = line(tile).mapToItem(news, 0, 0);
        tile.line = angel;
        compare(findChild(tile, "markedGhost").y, before.y, "the old one leaves from where it stood");
        waitForRendering(tile);
        const after = line(tile).mapToItem(news, 0, 0);
        verify(after.y > before.y, "one line is lower than two above the name");
        compare(findChild(tile, "peek").to, after, "the new one rises where it stays when the peek ends");
    }

    function test_the_first_line_is_no_news() {
        const tile = createTemporaryObject(tileComponent, testCase, { line: teardrop });
        verify(!findChild(tile, "markedGhost").visible);
        compare(line(tile).text, teardrop);
    }

    function test_a_line_that_comes_shows_at_once_without_a_peek() {
        const tile = createTemporaryObject(tileComponent, testCase);
        waitForRendering(tile);
        tile.line = teardrop;
        verify(line(tile).visible);
        verify(!findChild(tile, "markedGhost").visible);
    }

    function test_a_line_that_goes_leaves_at_once_without_a_peek() {
        const tile = createTemporaryObject(tileComponent, testCase, { line: teardrop });
        waitForRendering(tile);
        tile.line = "";
        verify(!line(tile).visible);
        verify(!findChild(tile, "markedGhost").visible);
        verify(!tile.clip);
    }

    function test_a_line_waits_while_the_tile_has_the_focus_and_comes_when_it_is_let_go() {
        const tile = createTemporaryObject(tileComponent, testCase, { line: teardrop });
        tile.forceActiveFocus();
        tile.line = angel;
        compare(line(tile).text, teardrop, "it waits");
        tile.parent.forceActiveFocus();
        compare(line(tile).text, angel);
    }

    function test_a_pointer_over_the_tile_holds_the_line() {
        const tile = createTemporaryObject(tileComponent, testCase, { x: 300, y: 100, line: teardrop });
        waitForRendering(tile);
        mouseMove(testCase, 5, 5);
        mouseMove(tile, Geometry.tilePadding + 5, Geometry.tilePadding + 5);
        tryVerify(() => tile.hovered);
        tile.line = angel;
        compare(line(tile).text, teardrop, "it waits");
        mouseMove(testCase, 5, 5);
        tryCompare(line(tile), "text", angel);
    }

    function test_under_reduced_motion_a_new_line_comes_at_once() {
        Prefs.motion = "off";
        const tile = createTemporaryObject(tileComponent, testCase, { line: teardrop });
        tile.line = angel;
        compare(line(tile).text, angel);
        verify(!findChild(tile, "markedGhost").visible);
    }

    function test_a_new_count_after_a_new_line_peeks_the_count_and_not_the_line() {
        const tile = createTemporaryObject(tileComponent, testCase, { unseen: 2, line: teardrop });
        waitForRendering(tile);
        tile.line = angel;
        tile.unseen = 3;
        const ghost = findChild(tile, "markedGhost");
        compare(ghost.text, "2");
        compare(findChild(tile, "incoming").sourceItem, findChild(tile, "count"));
        compare(line(tile).text, angel, "the line's change came at once when the count's news ended its peek");
    }

    function test_a_playing_player_gives_its_app_the_line_of_title_and_artist() {
        choice.players = [player()];
        compare(Rules.playingLines(choice.playingPlayer, "org.kde.elisa"), { "org.kde.elisa": teardrop });
    }

    function test_a_track_without_an_artist_is_its_title_alone() {
        choice.players = [player({ trackArtist: "" })];
        compare(Rules.playingLines(choice.playingPlayer, "org.kde.elisa"), { "org.kde.elisa": "Läuft gerade: Teardrop" });
    }

    function test_no_line_without_a_track_title_or_without_a_known_app() {
        choice.players = [player({ trackTitle: "", trackArtist: "" })];
        compare(Rules.playingLines(choice.playingPlayer, "org.kde.elisa"), {});
        choice.players = [player()];
        compare(Rules.playingLines(choice.playingPlayer, ""), {});
    }

    function test_a_paused_player_or_none_gives_no_line() {
        choice.players = [player({ playbackState: PlayerChoice.Paused })];
        compare(Rules.playingLines(choice.playingPlayer, "org.kde.elisa"), {});
        choice.players = [];
        compare(Rules.playingLines(choice.playingPlayer, ""), {});
    }

    // The Start open at once, as after its turn.
    function openStart(properties: var): var {
        const start = createTemporaryObject(startComponent, testCase, properties ?? {});
        Prefs.motion = "off";
        start.open();
        Prefs.motion = "system";
        waitForRendering(start);
        return start;
    }

    function tilesIn(start: var): var {
        return findChild(findChild(start, "pinned"), "grid").children.filter(item => (item as Tile) !== null);
    }

    function test_the_pinned_tile_of_the_playing_players_app_shows_what_plays_and_the_others_none() {
        choice.players = [player()];
        const start = openStart();
        const [elisa, mail] = tilesIn(start);
        compare(line(elisa).text, teardrop);
        verify(line(elisa).visible);
        verify(!line(mail).visible);
    }

    function test_a_new_track_peeks_onto_the_pinned_tile() {
        const elisaPlayer = player();
        choice.players = [elisaPlayer];
        const start = openStart();
        const elisa = tilesIn(start)[0];
        elisaPlayer.trackTitle = "Angel";
        compare(line(elisa).text, angel);
        compare(findChild(elisa, "markedGhost").text, teardrop);
        verify(findChild(elisa, "markedGhost").visible);
    }

    function test_pausing_takes_the_line_off_the_tile() {
        const elisaPlayer = player();
        choice.players = [elisaPlayer];
        const start = openStart();
        elisaPlayer.playbackState = PlayerChoice.Paused;
        verify(!line(tilesIn(start)[0]).visible);
    }

    function test_of_two_playing_players_only_the_chosen_ones_tile_shows_a_line() {
        const elisaPlayer = player();
        const vvavePlayer = player({ identity: "Vvave", trackTitle: "Angel" });
        choice.players = [elisaPlayer, vvavePlayer];
        choice.pick(vvavePlayer);
        const start = openStart();
        const [elisa, , vvave] = tilesIn(start);
        verify(!line(elisa).visible);
        compare(vvave.line, angel, "the chosen one's tile has the line, here one unit wide, so it shows none");
        verify(!line(vvave).visible);
        choice.pick(elisaPlayer);
        compare(line(elisa).text, teardrop);
        compare(vvave.line, "");
    }

    function test_a_paused_player_picked_in_the_panel_leaves_the_line_with_the_one_that_plays() {
        const elisaPlayer = player();
        const vvavePlayer = player({ identity: "Vvave", trackTitle: "Angel", playbackState: PlayerChoice.Paused });
        choice.players = [elisaPlayer, vvavePlayer];
        choice.pick(vvavePlayer);
        const start = openStart();
        compare(tilesIn(start)[0].line, teardrop);
    }

    function test_the_best_hit_of_a_search_shows_the_line_of_its_app() {
        choice.players = [player()];
        const start = openStart({
            apps: [{ id: "org.kde.elisa", name: "Elisa", genericName: "Music Player", keywords: [], exec: "elisa", icon: testCase.pinkIcon, launch: () => {} }]
        });
        Prefs.motion = "off";
        for (const character of "elisa")
            keyClick(character);
        Prefs.motion = "system";
        waitForRendering(start);
        const best = start.hitTiles()[0];
        verify(best.best);
        compare(line(best).text, teardrop);
        verify(line(best).visible);
    }

    function test_contact_sheet() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const sheet = createTemporaryObject(sheetComponent, testCase);
            waitForRendering(sheet);
            grabImage(sheet).save(`start-music-sheet-${theme}.png`);
        }
    }
}
