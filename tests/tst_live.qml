pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtTest
import Rekta
import "ContactSheets.js" as ContactSheets
import "Glide.js" as Glide

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
    readonly property easingCurve landing: ({ type: Easing.Bezier, bezierCurve: Tokens.easeLanding })
    readonly property easingCurve linear: ({ type: Easing.Linear })

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

    // A count the tile marks to peek, as a page marks one `data-rk-peek` (rekta.js:4342).
    Component {
        id: countTile

        Tile {
            x: 100
            y: 100
            peekPart: count

            Body {
                id: count

                objectName: "count"
                text: "3"
                font.pixelSize: Tokens.fontSizeM
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
        // No news came before this test.
        Greet.runs = new Map();
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Greet.now = () => Date.now();
    }

    // The news of each tile, told at once.
    function tellAll(tiles) {
        for (const tile of tiles)
            tile.news("peek", () => part(tile, "stat").value = String(Number(part(tile, "stat").value) + 1));
    }

    function waitsOf(tiles) {
        return tiles.map(tile => part(tile, "news").wait);
    }

    // How many pieces of news this window's run has counted.
    function toldHere() {
        return Greet.runs.get(testCase.Window.window)?.told ?? 0;
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

    // A motion's way from the telling: still for `hold` ms, then linear over duration-moderate.
    function heldThenLinear(hold) {
        const whole = hold + Tokens.durationModerate;
        return { whole, valueForProgress: share => Math.max(0, (share * whole - hold) / Tokens.durationModerate) };
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

    function test_a_sparkline_is_a_line_2_wide_with_round_joins_on_the_screen_at_any_width_in_a_box_200_to_28() {
        const tile = createTemporaryObject(liveTile, testCase);
        const spark = part(tile, "spark");
        const line = part(spark, "line");
        compare(spark.width, Tokens.tileUnit - 2 * Geometry.tilePadding);
        near(spark.height, spark.width * 28 / 200, "height");
        compare(line.joinStyle, ShapePath.RoundJoin);
        compare(line.capStyle, ShapePath.FlatCap);
        for (const width of [100, 200, 400]) {
            spark.width = width;
            compare(line.strokeWidth, 2, `${width}`);
            compare(part(spark, "shape").scale, 1, `${width}: the shape is not scaled with the box`);
            compare(part(spark, "shape").width, width);
        }
    }

    function test_its_points_sit_1px_inside_the_box_on_every_side_at_any_width() {
        const spark = part(createTemporaryObject(liveTile, testCase), "spark");
        for (const width of [100, 200, 400]) {
            spark.width = width;
            spark.values = [2, 4, 6];
            const height = width * 28 / 200;
            const points = spark.drawnPoints;
            compare(points.length, 3, `${width}`);
            near(points[0].x, 1, `${width}: first, from the leading edge`);
            near(points[0].y, height - 1, `${width}: the lowest, above the bottom`);
            near(points[1].x, width / 2, `${width}: middle`);
            near(points[1].y, height / 2, `${width}: middle`);
            near(points[2].x, width - 1, `${width}: last, from the trailing edge`);
            near(points[2].y, 1, `${width}: the highest, below the top`);
        }
    }

    function test_no_values_draw_nothing_but_keep_the_room_and_a_constant_series_lies_flat_1px_above_the_bottom() {
        const spark = part(createTemporaryObject(liveTile, testCase), "spark");
        spark.values = [];
        compare(spark.drawnPoints.length, 0);
        verify(spark.height > 0);
        for (const series of [[0, 0, 0], [5, 5], [7]]) {
            spark.values = series;
            const points = spark.drawnPoints;
            verify(points.length >= 2, `${series}`);
            verify(points.every(p => Math.abs(p.y - (spark.height - 1)) < 0.01), `${series}`);
            near(points[0].x, 1, `${series}`);
            near(points[points.length - 1].x, spark.width - 1, `${series}`);
        }
    }

    function test_a_sparkline_draws_in_over_duration_long_uncovered_from_the_leading_edge_only_while_its_place_arrives() {
        const tile = createTemporaryObject(liveTile, testCase);
        const spark = part(tile, "spark");
        const drawIn = part(spark, "drawIn");
        const run = part(spark, "drawInRun");
        const wipe = part(spark, "wipe");
        const overhang = Geometry.sparkWipeOverhang;
        verify(!run.running);
        compare(drawIn.progress, 1);
        compare(wipe.x, -overhang);
        compare(wipe.width, spark.width + 2 * overhang, "whole, with the overhang all around");

        tile.arrival = "arriving";
        verify(run.running);
        compare(run.duration, Tokens.durationLong);
        compare(run.easing.bezierCurve, Tokens.easeIn);
        seek(spark, "drawIn", "progress", 0);
        compare(wipe.width, overhang, "from the strip left of the box");
        seek(spark, "drawIn", "progress", 0.5);
        compare(wipe.x, -overhang, "it grows from the leading edge");
        near(wipe.x + wipe.width, (spark.width + overhang) / 2, "half of the way: p · (W + 2) from the box edge");
        compare(wipe.height, spark.height + 2 * overhang);
        compare(spark.drawnPoints.length, 6, "the line is whole, only uncovered");

        // The place turned in after all: the line keeps drawing where it is, it does not start again.
        tile.arrival = "turned";
        compare(drawIn.progress, 0.5);
        tile.arrival = "";
        compare(drawIn.progress, 1);
        compare(wipe.width, spark.width + 2 * overhang);
    }

    function test_a_sparkline_draws_in_to_the_end_when_the_animation_ends() {
        const tile = createTemporaryObject(liveTile, testCase, { arrival: "arriving" });
        const spark = part(tile, "spark");
        tryCompare(part(spark, "drawInRun"), "running", false, Tokens.durationLong * 3);
        compare(part(spark, "wipe").width, spark.width + 2 * Geometry.sparkWipeOverhang);
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
        const drawnBefore = spark.onScreen(before);
        const drawnAfter = spark.onScreen(after);
        spark.values = [9, 6, 8, 4, 5, 3];
        const run = part(spark, "morphRun");
        verify(run.running);
        compare(run.duration, Tokens.durationLong);
        compare(run.easing.bezierCurve, Tokens.easeBase);
        seek(spark, "morph", "progress", 0.5);
        for (let i = 0; i < 6; i++)
            near(spark.drawnPoints[i].y, (drawnBefore[i].y + drawnAfter[i].y) / 2, `point ${i}`);

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

    function test_an_arriving_tile_rises_arrive_distance_over_duration_long_and_fades_up_over_duration_short_both_landing() {
        const ticks = Glide.ticks(testCase);
        const tile = createTemporaryObject(liveTile, testCase);
        const buildIn = part(tile, "buildIn");
        const rises = Glide.record(buildIn, "rise");
        const fades = Glide.record(buildIn, "fade");
        const since = Date.now();
        tile.arrival = "arriving";
        const run = part(tile, "buildInRun");
        verify(run.running);
        compare(tile.opacity, 0);
        near(tile.mapToItem(testCase, 0, 0).y - tile.y, Tokens.arriveDistance, "it starts arrive-distance below");
        tryVerify(() => buildIn.rise === 1, Tokens.durationLong * 3, "the rise ends exactly on 1");
        tryVerify(() => buildIn.fade === 1, Tokens.durationLong * 3, "the fade ends exactly on 1");
        const riseStray = Glide.strayOf([{ steps: rises, from: 0, to: 1 }], Tokens.durationLong, landing, since, ticks);
        verify(riseStray < 0.06, `the rise follows ease-landing over duration-long, off by ${riseStray}`);
        const fadeStray = Glide.strayOf([{ steps: fades, from: 0, to: 1 }], Tokens.durationShort, landing, since, ticks);
        verify(fadeStray < 0.06, `the fade follows ease-landing over duration-short, off by ${fadeStray}`);
        near(tile.mapToItem(testCase, 0, 0).y - tile.y, 0, "at rest");
    }

    function test_half_risen_a_tile_stands_half_of_arrive_distance_below_and_a_turn_or_the_arrival_s_end_sets_it_at_rest() {
        const tile = createTemporaryObject(liveTile, testCase);
        tile.arrival = "arriving";
        seek(tile, "buildIn", "rise", 0.5);
        part(tile, "buildIn").fade = 0.5;
        compare(tile.opacity, 0.5);
        near(tile.mapToItem(testCase, 0, 0).y - tile.y, Tokens.arriveDistance / 2, "half-way");
        tile.arrival = "";
        compare(tile.opacity, 1);
        near(tile.mapToItem(testCase, 0, 0).y - tile.y, 0, "at rest");
        tile.arrival = "arriving";
        tile.arrival = "turned";
        compare(tile.opacity, 1, "a turn ends the build-in at once");
        near(tile.mapToItem(testCase, 0, 0).y - tile.y, 0, "at rest after a turn");
    }

    function test_tiles_build_in_duration_greet_apart_in_their_order_four_steps_at_most() {
        for (const [index, steps] of [[0, 0], [1, 1], [2, 2], [3, 3], [4, 3], [9, 3]]) {
            const tile = createTemporaryObject(liveTile, testCase, { buildIndex: index });
            tile.arrival = "arriving";
            compare(part(tile, "buildInRun").animations[0].duration, steps * Tokens.durationGreet, `index ${index}`);
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
        const began = Date.now();
        tile.news("peek", () => stat.value = "413");
        const ghost = part(tile, "ghost");
        verify(ghost.visible);
        const shown = Glide.record(ghost, "visible");
        tryCompare(ghost, "visible", false, Tokens.durationModerate * 3);
        verify(shown[0].at - began >= Tokens.durationModerate / 2, "still there halfway through duration-moderate");
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

    function test_a_part_the_tile_marks_peeks_its_new_number_as_a_stat_does() {
        const tile = createTemporaryObject(countTile, testCase);
        const count = part(tile, "count");
        waitForRendering(tile);
        const countY = count.mapToItem(tile, 0, 0).y;
        const width = count.width;
        tile.news("peek", () => count.text = "4");
        compare(count.text, "4");
        const ghost = part(tile, "markedGhost");
        const incoming = part(tile, "incoming");
        verify(ghost.visible);
        verify(!part(tile, "ghost").visible, "no stat leaves");
        compare(ghost.text, "3");
        compare(ghost.font.pixelSize, Tokens.fontSizeM);
        compare(ghost.width, width, "as wide as the old number");
        verify(tile.clip, "the old number leaves through the tile's edge");
        seek(tile, "peek", "phase", 0.2);
        waitForRendering(tile);
        compare(ghost.height, count.height);
        compare(incoming.opacity, 0);
        near(incoming.y - countY, 0.4 * count.height, "the new one starts 40% below");
        seek(tile, "peek", "phase", 0.6);
        compare(ghost.opacity, 0);
        near(ghost.mapToItem(tile, 0, 0).y - countY, -0.4 * ghost.height, "the old one ends 40% above");
        seek(tile, "peek", "phase", 1);
        compare(incoming.opacity, 1);
        near(incoming.y, countY, "the new one ends in its place");
    }

    function test_news_that_leaves_the_marked_part_as_it_was_does_not_peek() {
        const tile = createTemporaryObject(countTile, testCase);
        tile.news("peek", () => part(tile, "count").text = "3");
        verify(!part(tile, "markedGhost").visible);
        verify(!tile.clip);
    }

    function test_under_reduced_motion_a_marked_part_changes_at_once() {
        Prefs.motion = "off";
        const tile = createTemporaryObject(countTile, testCase);
        tile.news("peek", () => part(tile, "count").text = "4");
        compare(part(tile, "count").text, "4");
        verify(!part(tile, "markedGhost").visible);
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

    function test_news_on_several_tiles_at_once_comes_in_reading_order_duration_greet_apart_whatever_order_it_was_told_in() {
        const first = createTemporaryObject(liveTile, testCase, { x: 100, y: 100 });
        const second = createTemporaryObject(liveTile, testCase, { x: 300, y: 100 });
        const third = createTemporaryObject(liveTile, testCase, { x: 100, y: 300 });
        waitForRendering(third);
        tellAll([third, second, first]);
        tryCompare(part(third, "news"), "wait", 2 * Tokens.durationGreet);
        compare(waitsOf([first, second, third]), [0, Tokens.durationGreet, 2 * Tokens.durationGreet]);
        for (const tile of [first, second, third]) {
            const run = part(tile, "peekRun");
            verify(run.running, "each peek is on its way");
            compare(run.animations[0].duration, part(tile, "news").wait, "its wait comes before its motion");
            compare(run.duration, Tokens.durationModerate, "the peek itself keeps its time");
        }
    }

    function test_four_steps_at_most_the_rest_of_the_tiles_with_news_go_with_the_fourth() {
        const tiles = [0, 1, 2, 3, 4, 5].map(k => createTemporaryObject(liveTile, testCase, { x: 100 + 200 * (k % 3), y: 100 + 200 * Math.floor(k / 3) }));
        waitForRendering(tiles[5]);
        tellAll(tiles);
        tryCompare(part(tiles[5], "news"), "wait", 3 * Tokens.durationGreet);
        compare(waitsOf(tiles), [0, 1, 2, 3, 3, 3].map(step => step * Tokens.durationGreet));
    }

    function test_news_within_duration_moderate_of_the_first_takes_the_next_step_and_after_it_the_count_starts_over() {
        const tiles = [0, 1, 2, 3].map(k => createTemporaryObject(liveTile, testCase, { x: 100 + 200 * k, y: 100 }));
        waitForRendering(tiles[3]);
        Greet.now = () => 1000;
        tellAll([tiles[0], tiles[1]]);
        tryCompare(part(tiles[1], "news"), "wait", Tokens.durationGreet);
        Greet.now = () => 1100;
        tellAll([tiles[2]]);
        tryCompare(part(tiles[2], "news"), "wait", 2 * Tokens.durationGreet - 100, 500, "the third step, less the time already gone");
        Greet.now = () => 1000 + Tokens.durationModerate;
        tellAll([tiles[3]]);
        tryVerify(() => toldHere() === 4, 500, "at duration-moderate it still counts in the run");
        compare(part(tiles[3], "news").wait, 0, "its step has passed");
        Greet.now = () => 1001 + Tokens.durationModerate;
        tellAll([tiles[0]]);
        tryVerify(() => toldHere() === 1, 500, "a new run of news");
        compare(part(tiles[0], "news").wait, 0);
    }

    function test_news_on_one_tile_alone_waits_nothing_and_a_tile_told_twice_before_the_frame_joins_once() {
        const tile = createTemporaryObject(liveTile, testCase);
        const stat = part(tile, "stat");
        tile.news("peek", () => stat.value = "413");
        tile.news("peek", () => stat.value = "414");
        wait(0);
        compare(part(tile, "news").wait, 0);
        compare(toldHere(), 1);
    }

    // The bar and the Start are windows of their own, lying on the screen as they will.
    function test_news_in_another_window_counts_on_its_own_and_waits_nothing_for_this_one() {
        const here = createTemporaryObject(liveTile, testCase, { x: 100, y: 100 });
        const other = createTemporaryQmlObject(`import QtQuick
            import Rekta
            Window { visible: true; width: 400; height: 400; Tile { objectName: "tile"; x: 100; y: 300; Stat { objectName: "stat"; value: "412"; label: "requests a second" } } }`, testCase);
        const there = findChild(other, "tile");
        waitForRendering(there);
        tellAll([here, there]);
        tryVerify(() => toldHere() === 1, 500, "this window counts only its own");
        compare(waitsOf([here, there]), [0, 0], "each is the first of its window");
        compare(Greet.runs.get(other).told, 1);
    }

    function test_a_tile_s_wait_holds_its_peek_which_then_runs_its_whole_time_from_its_step_on() {
        const ticks = Glide.ticks(testCase);
        const tiles = [0, 1, 2].map(k => createTemporaryObject(liveTile, testCase, { x: 100, y: 100 + 200 * k }));
        waitForRendering(tiles[2]);
        const phases = Glide.record(part(tiles[2], "peek"), "phase");
        const since = Date.now();
        tellAll(tiles);
        tryCompare(part(tiles[2], "news"), "wait", 2 * Tokens.durationGreet);
        tryCompare(part(tiles[2], "news"), "peeking", false, Tokens.durationModerate * 3);
        const curve = heldThenLinear(2 * Tokens.durationGreet);
        const stray = Glide.strayOf([{ steps: phases, from: 0, to: 1 }], curve.whole, curve, since, ticks);
        verify(stray < 0.06, `the peek runs its whole time from its step on, off by ${stray}`);
    }

    // In the shell a frame can come between the telling and its step, and Qt restarts a running group for a changed
    // pause only before its first tick.
    function test_a_peek_that_has_moved_a_tick_when_its_step_comes_stands_again_and_runs_its_whole_time_after_the_step() {
        const ticks = Glide.ticks(testCase);
        const tile = createTemporaryObject(liveTile, testCase);
        waitForRendering(tile);
        const news = part(tile, "news");
        tile.news("peek", () => part(tile, "stat").value = "413");
        tryVerify(() => part(tile, "peek").phase > 0, 500, "a tick moved it");
        const phases = Glide.record(part(tile, "peek"), "phase");
        const since = Date.now();
        news.waitFor(Tokens.durationGreet);
        compare(part(tile, "peek").phase, 0, "the old number stands again");
        compare(part(tile, "ghost").opacity, 1);
        compare(part(tile, "incoming").opacity, 0);
        tryCompare(news, "peeking", false, Tokens.durationModerate * 3);
        const curve = heldThenLinear(Tokens.durationGreet);
        const stray = Glide.strayOf([{ steps: phases, from: 0, to: 1 }], curve.whole, curve, since, ticks);
        verify(stray < 0.06, `held for its step, then its whole time, off by ${stray}`);
    }

    function test_a_flip_that_has_turned_a_tick_when_its_step_comes_stands_unturned_again_and_turns_its_whole_time_after_the_step() {
        const ticks = Glide.ticks(testCase);
        const tile = createTemporaryObject(liveTile, testCase, { status: "info" });
        waitForRendering(tile);
        const news = part(tile, "news");
        tile.news("flip", () => tile.status = "error");
        tryVerify(() => part(tile, "flip").phase > 0, 500, "a tick turned it");
        const phases = Glide.record(part(tile, "flip"), "phase");
        const since = Date.now();
        news.waitFor(Tokens.durationGreet);
        compare(part(tile, "flip").phase, 0, "unturned again");
        compare(news.flipAngle, 0);
        tryVerify(() => !part(tile, "flipRun").running, Tokens.durationModerate * 3);
        compare(tile.status, "error");
        const curve = heldThenLinear(Tokens.durationGreet);
        const stray = Glide.strayOf([{ steps: phases, from: 0, to: 1 }], curve.whole, curve, since, ticks);
        verify(stray < 0.06, `held for its step, then its whole time, off by ${stray}`);
    }

    function test_told_alone_after_it_waited_last_time_a_tile_s_peek_starts_at_once() {
        const ticks = Glide.ticks(testCase);
        const first = createTemporaryObject(liveTile, testCase, { x: 100, y: 100 });
        const second = createTemporaryObject(liveTile, testCase, { x: 100, y: 300 });
        waitForRendering(second);
        tellAll([first, second]);
        tryCompare(part(second, "news"), "wait", Tokens.durationGreet);
        tryCompare(part(second, "news"), "peeking", false, Tokens.durationModerate * 3);
        const phases = Glide.record(part(second, "peek"), "phase");
        const since = Date.now();
        tellAll([second]);
        tryCompare(part(second, "news"), "peeking", false, Tokens.durationModerate * 3);
        compare(part(second, "news").wait, 0);
        const stray = Glide.strayOf([{ steps: phases, from: 0, to: 1 }], Tokens.durationModerate, linear, since, ticks);
        verify(stray < 0.06, `it starts at once, off by ${stray}`);
    }

    function test_as_it_is_told_again_after_a_finished_peek_the_old_number_stands_before_anything_moves() {
        const tile = createTemporaryObject(liveTile, testCase);
        waitForRendering(tile);
        const stat = part(tile, "stat");
        tile.news("peek", () => stat.value = "413");
        tryCompare(part(tile, "news"), "peeking", false, Tokens.durationModerate * 3);
        tile.news("peek", () => stat.value = "414");
        compare(part(tile, "peek").phase, 0, "nothing has moved yet");
        compare(part(tile, "ghost").opacity, 1);
        compare(part(tile, "ghost").value, "413");
        compare(part(tile, "incoming").opacity, 0);
    }

    function test_news_whose_step_has_passed_waits_nothing_though_the_tile_waited_last_time() {
        const first = createTemporaryObject(liveTile, testCase, { x: 100, y: 100 });
        const second = createTemporaryObject(liveTile, testCase, { x: 100, y: 300 });
        waitForRendering(second);
        Greet.now = () => 1000;
        tellAll([first, second]);
        tryCompare(part(second, "news"), "wait", Tokens.durationGreet);
        Greet.now = () => 1000 + 3 * Tokens.durationGreet;
        tellAll([second]);
        compare(part(second, "peekRun").animations[0].duration, 0, "the telling starts with no pause of the last time");
        tryVerify(() => toldHere() === 3, 500, "it counts in the run");
        compare(part(second, "news").wait, 0, "its step has passed");
    }

    function test_while_it_waits_a_peek_shows_the_old_number_standing_and_a_flip_stands_unturned_changing_only_after() {
        const first = createTemporaryObject(liveTile, testCase, { x: 100, y: 100 });
        const second = createTemporaryObject(liveTile, testCase, { x: 100, y: 300 });
        const third = createTemporaryObject(liveTile, testCase, { x: 100, y: 500, status: "info" });
        waitForRendering(third);
        tellAll([first, second]);
        third.news("flip", () => third.status = "error");
        tryCompare(part(third, "news"), "wait", 2 * Tokens.durationGreet);
        compare(part(second, "news").wait, Tokens.durationGreet);
        const ghost = part(second, "ghost");
        verify(ghost.visible, "the old number stands");
        compare(ghost.opacity, 1);
        compare(ghost.value, "412");
        compare(part(second, "incoming").opacity, 0, "the new one waits below");
        compare(part(second, "peek").phase, 0);
        compare(part(third, "news").flipAngle, 0, "unturned");
        compare(third.status, "info", "unchanged while it waits");
        tryVerify(() => part(third, "flip").phase > 0, Tokens.durationModerate, "then it turns");
        compare(third.status, "info", "the change comes halfway through the turn, not before");
        tryCompare(third, "status", "error", Tokens.durationModerate * 3);
    }

    function test_under_reduced_motion_news_on_several_tiles_comes_at_once() {
        Prefs.motion = "off";
        const tiles = [0, 1, 2].map(k => createTemporaryObject(liveTile, testCase, { x: 100, y: 100 + 200 * k }));
        tellAll(tiles);
        compare(tiles.map(tile => part(tile, "stat").value), ["413", "413", "413"]);
        wait(0);
        compare(waitsOf(tiles), [0, 0, 0]);
        verify(tiles.every(tile => !part(tile, "ghost").visible));
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

    // The build-in at `share` of duration-long: the rise on its curve, the fade whole after duration-short of it.
    function buildingIn(share) {
        return (tile, stat, spark) => {
            tile.arrival = "arriving";
            seek(tile, "buildIn", "rise", landing.valueForProgress(share));
            part(tile, "buildIn").fade = landing.valueForProgress(Math.min(1, share * Tokens.durationLong / Tokens.durationShort));
            seek(spark, "drawIn", "progress", share);
        };
    }

    // News takes its step among the sheet's other tiles (Greet) after the event loop has run, and a step restarts its
    // motion; so each one takes its step before it is held at its moment.
    function peeking(phase) {
        return (tile, stat) => {
            tile.news("peek", () => stat.value = "1260");
            wait(0);
            seek(tile, "peek", "phase", phase);
        };
    }

    function flipping(phase) {
        return tile => {
            tile.news("flip", () => tile.status = "error");
            wait(0);
            seek(tile, "flip", "phase", phase);
        };
    }

    // Moments in between, held by hand: build-in and draw-in, peek, flip, and the line's own changes. The tiles are
    // laid out before the news comes, as live tiles are; fill colours and the stale fade, which run on their own
    // clock, settle before the picture is taken.
    function test_contact_sheet_of_live_tile_motion_in_between() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
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
