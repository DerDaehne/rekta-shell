pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "LiveTile"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 1000

    readonly property easingCurve easeOut: ({ type: Easing.Bezier, bezierCurve: Tokens.easeOut })
    readonly property easingCurve easeIn: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })

    Component {
        id: liveTile

        Tile {
            x: 100
            y: 100

            Stat {
                objectName: "stat"
                value: "412"
                label: "requests a second"
            }
            Sparkline {
                objectName: "spark"
                values: [3, 5, 4, 8, 6, 9]
            }
        }
    }

    Component {
        id: messageTile

        Tile {
            TileMessage {
                objectName: "message"
                text: "Nothing waits."
            }
        }
    }

    // A frame of the contact sheet: a tile, and what moment of which motion it shows.
    Component {
        id: frameComponent

        Column {
            property alias tile: frameTile
            property alias caption: captionText.text

            spacing: Tokens.spaceXs

            Tile {
                id: frameTile

                status: "info"

                Stat {
                    objectName: "stat"
                    value: "412"
                    label: "requests a second"
                }
                Sparkline {
                    objectName: "spark"
                    values: [3, 5, 4, 8, 6, 9]
                }
            }
            Meta {
                id: captionText

                width: frameTile.width
            }
        }
    }

    Component {
        id: sheetComponent

        Rectangle {
            property alias grid: cells

            width: 4 * Tokens.tileUnit + 5 * Tokens.spaceL
            height: cells.height + 2 * Tokens.spaceL
            color: Tokens.color.bg

            Grid {
                id: cells

                x: Tokens.spaceL
                y: Tokens.spaceL
                columns: 4
                spacing: Tokens.spaceL
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    function part(tile, name) {
        return findChild(tile, name);
    }

    // Time control: the motion stops where it is, and its clock is set by hand.
    function seek(item, name, property, value) {
        findChild(item, `${name}Run`).pause();
        findChild(item, name)[property] = value;
    }

    function near(actual, expected, what) {
        verify(Math.abs(actual - expected) < 0.01, `${what}: ${actual}, expected ${expected}`);
    }

    function test_a_sparkline_takes_the_tiles_text_colour_on_every_status_but_success() {
        Prefs.theme = "dark";
        for (const status of ["", "info", "warning", "error"]) {
            const tile = createTemporaryObject(liveTile, testCase, { status: status });
            const spark = part(tile, "spark");
            verify(spark.visible, status);
            compare(part(spark, "line").strokeColor, Tokens.color.textPrimary, status);
            compare(tile.patterns, status === "" ? 2 : 3, status);
        }
        const done = createTemporaryObject(liveTile, testCase, { status: "success" });
        verify(!part(done, "spark").visible);
        compare(done.patterns, 2);
    }

    function test_a_sparkline_is_a_line_2_wide_with_round_joins_in_a_200_by_28_box_scaled_to_its_width() {
        const tile = createTemporaryObject(liveTile, testCase);
        const spark = part(tile, "spark");
        const line = part(spark, "line");
        compare(spark.width, Tokens.tileUnit - 2 * Geometry.tilePadding);
        near(spark.height, spark.width * 28 / 200, "height");
        compare(line.strokeWidth, 2);
        compare(line.joinStyle, ShapePath.RoundJoin);
        compare(line.capStyle, ShapePath.FlatCap);
    }

    function test_its_points_sit_inside_the_box_inset_by_half_the_stroke() {
        const spark = part(createTemporaryObject(liveTile, testCase), "spark");
        const points = spark.layout([2, 4, 6]);
        compare(points.length, 3);
        compare(points[0].x, 1);
        compare(points[0].y, 27);
        compare(points[1].x, 100);
        compare(points[1].y, 14);
        compare(points[2].x, 199);
        compare(points[2].y, 1);
    }

    function test_no_values_draw_nothing_but_keep_the_room_and_a_constant_series_lies_flat_along_the_bottom() {
        const spark = part(createTemporaryObject(liveTile, testCase), "spark");
        spark.values = [];
        compare(spark.drawnPoints.length, 0);
        verify(spark.height > 0);
        for (const series of [[0, 0, 0], [5, 5], [7]]) {
            const points = spark.layout(series);
            verify(points.length >= 2, `${series}`);
            verify(points.every(p => p.y === 27), `${series}`);
            compare(points[points.length - 1].x, 199, `${series}`);
        }
    }

    function test_a_sparkline_draws_in_over_duration_long_only_while_its_place_arrives() {
        const tile = createTemporaryObject(liveTile, testCase);
        const spark = part(tile, "spark");
        const drawIn = part(spark, "drawIn");
        const run = part(spark, "drawInRun");
        verify(!run.running);
        compare(drawIn.progress, 1);

        tile.arrival = "arriving";
        verify(run.running);
        compare(run.duration, Tokens.durationLong);
        compare(run.easing.bezierCurve, Tokens.easeIn);
        seek(spark, "drawIn", "progress", 0.5);
        verify(spark.drawnPoints.length > 1 && spark.drawnPoints.length < 6);
        const end = spark.drawnPoints[spark.drawnPoints.length - 1];
        verify(end.x > 1 && end.x < 199, `drawn up to ${end.x}`);

        // The place turned in after all: the line keeps drawing where it is, it does not start again.
        tile.arrival = "turned";
        compare(drawIn.progress, 0.5);
        tile.arrival = "";
        compare(drawIn.progress, 1);
        compare(spark.drawnPoints.length, 6);
    }

    function test_a_sparkline_still_draws_in_after_a_turn() {
        const tile = createTemporaryObject(liveTile, testCase, { arrival: "turned" });
        verify(part(part(tile, "spark"), "drawInRun").running);
    }

    function test_a_line_that_does_not_draw_in_stands_whole_on_arrival() {
        const tile = createTemporaryObject(liveTile, testCase);
        const spark = part(tile, "spark");
        spark.drawsIn = false;
        tile.arrival = "arriving";
        verify(!part(spark, "drawInRun").running);
        compare(part(spark, "drawIn").progress, 1);
    }

    function test_new_values_on_as_many_points_move_the_line_over_duration_long() {
        const spark = part(createTemporaryObject(liveTile, testCase), "spark");
        const before = spark.layout(spark.values);
        const after = spark.layout([9, 6, 8, 4, 5, 3]);
        spark.values = [9, 6, 8, 4, 5, 3];
        const run = part(spark, "morphRun");
        verify(run.running);
        compare(run.duration, Tokens.durationLong);
        compare(run.easing.bezierCurve, Tokens.easeBase);
        seek(spark, "morph", "progress", 0.5);
        for (let i = 0; i < 6; i++)
            near(spark.drawnPoints[i].y, (before[i].y + after[i].y) / 2, `point ${i}`);

        // From where the line is now, not from where it started.
        spark.values = [3, 5, 4, 8, 6, 9];
        verify(run.running);
        near(part(spark, "morph").from[0].y, (before[0].y + after[0].y) / 2, "starts mid-way");
    }

    function test_new_values_on_another_number_of_points_are_drawn_at_once() {
        const spark = part(createTemporaryObject(liveTile, testCase), "spark");
        spark.values = [1, 2, 3];
        verify(!part(spark, "morphRun").running);
        compare(spark.drawnPoints.length, 3);
        compare(spark.drawnPoints[2].y, 1);
    }

    function test_stale_or_offline_fades_the_line_to_0_35_over_duration_short() {
        const spark = part(createTemporaryObject(liveTile, testCase), "spark");
        spark.stale = true;
        verify(spark.opacity > 0.35, "it fades, it does not jump");
        tryCompare(spark, "opacity", 0.35, Tokens.durationShort * 4);
        spark.stale = false;
        tryCompare(spark, "opacity", 1, Tokens.durationShort * 4);
    }

    function test_an_arriving_place_builds_its_tiles_in_rising_6px_with_a_fade_over_duration_moderate() {
        const tile = createTemporaryObject(liveTile, testCase);
        tile.arrival = "arriving";
        const run = part(tile, "buildInRun");
        verify(run.running);
        compare(tile.opacity, 0);
        near(tile.mapToItem(testCase, 0, 0).y - tile.y, 6, "rise");
        const rise = run.animations[1];
        compare(rise.duration, Tokens.durationModerate);
        compare(rise.easing.bezierCurve, Tokens.easeIn);
        seek(tile, "buildIn", "progress", 0.5);
        compare(tile.opacity, 0.5);
        near(tile.mapToItem(testCase, 0, 0).y - tile.y, 3, "half-way");
        tile.arrival = "";
        compare(tile.opacity, 1);
        near(tile.mapToItem(testCase, 0, 0).y - tile.y, 0, "at rest");
    }

    function test_tiles_build_in_staggered_by_their_index_and_from_ten_on_together() {
        for (const [index, steps] of [[0, 0], [3, 3], [10, 10], [15, 10]]) {
            const tile = createTemporaryObject(liveTile, testCase, { buildIndex: index });
            tile.arrival = "arriving";
            compare(part(tile, "buildInRun").animations[0].duration, steps * Tokens.durationStagger, `index ${index}`);
            compare(tile.opacity, 0, `unseen until its turn (${index})`);
        }
    }

    function test_after_a_turn_tiles_do_not_rise_but_their_sparklines_draw_in() {
        const tile = createTemporaryObject(liveTile, testCase);
        tile.arrival = "turned";
        verify(!part(tile, "buildInRun").running);
        compare(tile.opacity, 1);
        verify(part(part(tile, "spark"), "drawInRun").running);

        // A turn that comes while the place still builds in wins: the tiles stand at once.
        const other = createTemporaryObject(liveTile, testCase, { arrival: "arriving" });
        other.arrival = "turned";
        verify(!part(other, "buildInRun").running);
        compare(other.opacity, 1);
    }

    function test_new_live_data_never_builds_a_tile_in() {
        const tile = createTemporaryObject(liveTile, testCase);
        const stat = part(tile, "stat");
        tile.news("peek", () => stat.value = "413");
        stat.value = "414";
        part(tile, "spark").values = [1, 2, 3, 4, 5, 6];
        tile.news("flip", () => tile.status = "warning");
        verify(!part(tile, "buildInRun").running);
        compare(tile.opacity, 1);
        verify(!part(part(tile, "spark"), "drawInRun").running);
    }

    function test_a_new_number_peeks_the_old_one_up_and_out_and_the_new_one_in_over_duration_moderate() {
        const tile = createTemporaryObject(liveTile, testCase);
        const stat = part(tile, "stat");
        waitForRendering(tile);
        const statY = stat.mapToItem(tile, 0, 0).y;
        verify(stat.height > 0);
        tile.news("peek", () => stat.value = "413");
        compare(stat.value, "413");
        const ghost = part(tile, "ghost");
        const incoming = part(tile, "incoming");
        verify(ghost.visible);
        compare(ghost.value, "412");
        verify(tile.clip, "the old number leaves through the tile's edge");
        compare(part(tile, "peekRun").duration, Tokens.durationModerate);
        seek(tile, "peek", "phase", 0.2);
        waitForRendering(tile);
        compare(ghost.height, stat.height);

        compare(incoming.opacity, 0);
        near(incoming.y - statY, 0.4 * stat.height, "the new one starts 40% below");
        seek(tile, "peek", "phase", 0.3);
        near(ghost.opacity, 1 - easeOut.valueForProgress(0.5), "old at 0.3");
        near(incoming.opacity, easeIn.valueForProgress(0.125), "new at 0.3");
        seek(tile, "peek", "phase", 0.6);
        compare(ghost.opacity, 0);
        near(ghost.mapToItem(tile, 0, 0).y - statY, -0.4 * ghost.height, "the old one ends 40% above");
        seek(tile, "peek", "phase", 1);
        compare(incoming.opacity, 1);
        near(incoming.y, statY, "the new one ends in its place");
    }

    function test_a_peek_ends_after_duration_moderate() {
        const tile = createTemporaryObject(liveTile, testCase);
        const stat = part(tile, "stat");
        tile.news("peek", () => stat.value = "413");
        wait(Tokens.durationModerate / 2);
        verify(part(tile, "ghost").visible);
        tryCompare(part(tile, "ghost"), "visible", false, Tokens.durationModerate * 2);
        verify(!tile.clip);
    }

    function test_news_that_changes_no_number_does_not_peek() {
        const tile = createTemporaryObject(liveTile, testCase);
        tile.news("peek", () => part(tile, "spark").values = [1, 2, 3, 4, 5, 6]);
        verify(!part(tile, "ghost").visible);
        const message = createTemporaryObject(messageTile, testCase);
        message.news("peek", () => part(message, "message").text = "Three failed.");
        compare(part(message, "message").text, "Three failed.");
        verify(!part(message, "ghost").visible);
    }

    function test_a_new_status_flips_the_tile_away_changes_it_halfway_and_turns_it_back() {
        const tile = createTemporaryObject(liveTile, testCase, { status: "info" });
        tile.news("flip", () => tile.status = "error");
        compare(tile.status, "info");
        const run = part(tile, "flipRun");
        verify(run.running);
        compare(run.duration, Tokens.durationModerate);
        const news = part(tile, "news");

        seek(tile, "flip", "phase", 0.25);
        compare(tile.status, "info");
        const away = -90 * easeOut.valueForProgress(0.5);
        near(news.flipAngle, away, "turning away");
        // perspective(turnstile-perspective) rotateX(angle): the angle's sine over the perspective feeds the depth.
        near(tile.transform[0].matrix.m42 * 1000, -Math.sin(away * Math.PI / 180) / Tokens.turnstilePerspective * 1000, "perspective");
        seek(tile, "flip", "phase", 0.5);
        compare(tile.status, "error");
        near(news.flipAngle, 90, "edge on");
        seek(tile, "flip", "phase", 0.75);
        near(news.flipAngle, 90 * (1 - easeIn.valueForProgress(0.5)), "turning back");
        seek(tile, "flip", "phase", 1);
        compare(news.flipAngle, 0);
    }

    function test_a_continuous_reading_changes_in_place_without_motion() {
        const tile = createTemporaryObject(liveTile, testCase);
        const stat = part(tile, "stat");
        tile.news("", () => stat.value = "61");
        compare(stat.value, "61");
        stat.value = "62";
        verify(!part(tile, "ghost").visible);
        verify(!part(tile, "peekRun").running);
        verify(!part(tile, "flipRun").running);
    }

    function test_held_news_waits_and_comes_in_one_step_when_let_go() {
        const tile = createTemporaryObject(liveTile, testCase, { held: true });
        const stat = part(tile, "stat");
        tile.news("peek", () => stat.value = "413");
        tile.news("peek", () => stat.value = "414");
        tile.news("", () => part(tile, "spark").values = [1, 2, 3]);
        compare(stat.value, "412");
        compare(part(tile, "spark").drawnPoints.length, 6);
        verify(!part(tile, "ghost").visible);

        tile.held = false;
        compare(stat.value, "414");
        compare(part(tile, "spark").drawnPoints.length, 3);
        compare(part(tile, "ghost").value, "412", "the old number is the one that was shown");
        verify(part(tile, "peekRun").running);
    }

    function test_a_new_status_among_held_news_flips_the_tile_when_let_go() {
        const tile = createTemporaryObject(liveTile, testCase, { held: true });
        const stat = part(tile, "stat");
        tile.news("peek", () => stat.value = "413");
        tile.news("flip", () => tile.status = "warning");
        tile.held = false;
        verify(part(tile, "flipRun").running);
        verify(!part(tile, "peekRun").running);
        compare(stat.value, "412");
        seek(tile, "flip", "phase", 0.5);
        compare(stat.value, "413");
        compare(tile.status, "warning");
    }

    function test_newer_news_ends_the_running_one_at_once() {
        const tile = createTemporaryObject(liveTile, testCase);
        const stat = part(tile, "stat");
        tile.news("flip", () => tile.status = "error");
        seek(tile, "flip", "phase", 0.25);
        tile.news("peek", () => stat.value = "413");
        compare(tile.status, "error");
        compare(part(tile, "news").flipAngle, 0);
        verify(part(tile, "peekRun").running);
    }

    function test_under_reduced_motion_end_states_come_at_once_and_values_keep_updating() {
        Prefs.motion = "off";
        const tile = createTemporaryObject(liveTile, testCase, { arrival: "arriving", buildIndex: 4 });
        const stat = part(tile, "stat");
        const spark = part(tile, "spark");
        compare(tile.opacity, 1);
        verify(!part(tile, "buildInRun").running);
        compare(part(spark, "drawIn").progress, 1);
        verify(!part(spark, "drawInRun").running);

        spark.values = [9, 6, 8, 4, 5, 3];
        verify(!part(spark, "morphRun").running);
        compare(spark.drawnPoints[0].y, 1);
        tile.news("peek", () => stat.value = "413");
        compare(stat.value, "413");
        verify(!part(tile, "ghost").visible);
        tile.news("flip", () => tile.status = "error");
        compare(tile.status, "error");
        compare(part(tile, "news").flipAngle, 0);
        spark.stale = true;
        compare(spark.opacity, 0.35);
    }

    function frames() {
        const list = [];
        for (const k of [0.25, 0.5, 0.75, 1])
            list.push([`build-in ${k}`, buildingIn(k)]);
        for (const k of [0, 0.25, 0.5, 0.75])
            list.push([`peek ${k}`, peeking(k)]);
        for (const k of [0.25, 0.45, 0.55, 0.75])
            list.push([`flip ${k}`, flipping(k)]);
        list.push(["morph 0.5", (tile, stat, spark) => {
                    spark.values = [9, 6, 8, 4, 5, 3];
                    seek(spark, "morph", "progress", 0.5);
                }]);
        list.push(["stale", (tile, stat, spark) => spark.stale = true]);
        list.push(["success: no line", tile => tile.status = "success"]);
        list.push(["neutral", tile => tile.status = ""]);
        return list;
    }

    function buildingIn(progress) {
        return (tile, stat, spark) => {
            tile.arrival = "arriving";
            seek(tile, "buildIn", "progress", progress);
            seek(spark, "drawIn", "progress", progress);
        };
    }

    function peeking(phase) {
        return (tile, stat) => {
            tile.news("peek", () => stat.value = "1260");
            seek(tile, "peek", "phase", phase);
        };
    }

    function flipping(phase) {
        return tile => {
            tile.news("flip", () => tile.status = "error");
            seek(tile, "flip", "phase", phase);
        };
    }

    // Moments in between, held by hand: build-in and draw-in, peek, flip, and the line's own changes. The tiles are
    // laid out before the news comes, as live tiles are; fill colours and the stale fade, which run on their own
    // clock, settle before the picture is taken.
    function test_contact_sheet_of_live_tile_motion_in_between() {
        Prefs.motion = "on";
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const sheet = createTemporaryObject(sheetComponent, testCase);
            const cells = frames().map(([caption, show]) => [createTemporaryObject(frameComponent, sheet.grid, { caption: caption }), show]);
            waitForRendering(sheet);
            for (const [cell, show] of cells)
                show(cell.tile, part(cell.tile, "stat"), part(cell.tile, "spark"));
            wait(Tokens.durationShort * 1.2);
            grabImage(sheet).save(`live-sheet-${theme}.png`);
            verify(sheet.height > 4 * Tokens.tileUnit, theme);
        }
    }
}
