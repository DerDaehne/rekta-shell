import QtQuick
import QtTest
import Rekta

TestCase {
    name: "Turnstile"

    readonly property real tile: Tokens.heftReference

    function part(x: real, y: real, width: real, height: real): var {
        return {
            x: x,
            y: y,
            width: width,
            height: height
        };
    }

    function turnOf(turns: var, wanted: var): var {
        return turns.find(turn => turn.part === wanted);
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
    }

    function cleanup() {
        Tokens.reducedMotion = false;
    }

    function test_a_part_of_heft_reference_square_weighs_as_a_tile_and_every_part_lies_between_the_lightest_and_the_heaviest() {
        fuzzyCompare(Turnstile.heft(tile, tile), Tokens.heftTile, 1e-9);
        verify(Turnstile.heft(Tokens.tileUnit, Tokens.tileUnit) > Tokens.heftTile, "the product's larger tile unit is no reference");
        compare(Turnstile.heft(1, 1), Tokens.heftMin);
        compare(Turnstile.heft(4000, 3000), Tokens.heftMax);
    }

    function test_between_the_bounds_a_part_weighs_eight_tenths_of_its_area_in_tiles_to_the_power_of_0_35() {
        const weigh = (width, height) => Tokens.heftTile * Math.pow(width * height / (tile * tile), Tokens.heftExponent);
        fuzzyCompare(Turnstile.heft(310, 150), weigh(310, 150), 1e-9);
        fuzzyCompare(Turnstile.heft(400, 24), weigh(400, 24), 1e-9);
        verify(weigh(310, 150) > Tokens.heftMin && weigh(310, 150) < Tokens.heftMax);
    }

    function test_light_parts_start_first_and_take_less_time() {
        const line = part(0, 400, 100, 20);
        const window = part(0, 0, 1200, 800);
        const turns = Turnstile.plan([window, line], Tokens.durationModerate, 0);
        verify(turnOf(turns, line).at < turnOf(turns, window).at);
        verify(turnOf(turns, line).duration < turnOf(turns, window).duration);
        fuzzyCompare(turnOf(turns, window).duration, Tokens.heftMax * Tokens.durationModerate, 1e-9);
    }

    function test_parts_of_one_heft_follow_in_reading_order_half_a_stagger_apart_six_steps_at_most() {
        const row = [];
        for (let i = 7; i >= 0; i--)
            row.push(part(i * (tile + Tokens.spaceS), 0, tile, tile));
        const turns = Turnstile.plan(row, Tokens.durationShort, 0);
        const first = (Tokens.heftTile - Tokens.heftMin) * Tokens.heftSpread * Tokens.durationStagger;
        const step = Geometry.sameHeftStagger * Tokens.durationStagger;
        compare(turns.map(turn => turn.part.x), row.map(p => p.x).reverse());
        for (let i = 0; i < turns.length; i++)
            fuzzyCompare(turns[i].at, first + Math.min(i, Geometry.sameHeftSteps) * step, 1e-9);
    }

    function test_parts_at_one_place_keep_the_order_they_come_in() {
        const parts = [];
        for (let i = 0; i < 12; i++)
            parts.push(part(0, 0, tile, tile + i % 2));
        for (const given of [parts, parts.slice().reverse()]) {
            const turns = Turnstile.plan(given, Tokens.durationShort, 0);
            compare(turns.map(turn => given.indexOf(turn.part)), given.map((part, index) => index));
        }
    }

    function test_a_row_turns_in_the_perspective_of_its_farthest_reach() {
        const near = part(0, 100, tile, tile);
        const far = part(2 * tile, 100, tile, tile);
        const below = part(0, 400, tile, tile);
        const turns = Turnstile.plan([near, far, below], Tokens.durationShort, 0);
        const rowPerspective = Tokens.turnstilePerspective + Tokens.turnstileReach * 3 * tile;
        fuzzyCompare(turnOf(turns, near).perspective, rowPerspective, 1e-9);
        fuzzyCompare(turnOf(turns, far).perspective, rowPerspective, 1e-9);
        fuzzyCompare(turnOf(turns, below).perspective, Tokens.turnstilePerspective + Tokens.turnstileReach * tile, 1e-9);
    }

    function test_a_part_flush_with_the_top_turns_from_its_top_and_any_other_from_its_middle() {
        const top = part(0, 1, tile, tile);
        const lower = part(0, 300, tile, 2 * tile);
        const turns = Turnstile.plan([top, lower], Tokens.durationShort, 0);
        compare(turnOf(turns, top).originY, 0);
        compare(turnOf(turns, lower).originY, tile);
    }

    function test_the_next_place_starts_when_the_last_part_is_three_quarters_through() {
        const turns = Turnstile.plan([part(0, 0, tile, tile), part(4 * tile, 0, 4 * tile, 4 * tile)], Tokens.durationShort, 0);
        const ends = turns.map(turn => turn.at + Tokens.turnOverlap * turn.duration);
        fuzzyCompare(Turnstile.nextPlaceAt(turns), Math.max(...ends), 1e-9);
        compare(Turnstile.nextPlaceAt([]), 0);
    }

    function test_no_place_change_outlasts_its_longest_and_the_heaviest_one_reaches_it() {
        const mixed = [part(0, 0, tile, tile), part(200, 0, 1200, 800), part(0, 300, 100, 20), part(400, 300, 2 * tile, tile)];
        const heavy = [];
        for (let i = 0; i < 8; i++)
            heavy.push(part(i * 10, 0, 1200, 800));
        const longest = Turnstile.longestPlaceChange(Tokens.durationShort, Tokens.durationModerate);
        for (const parts of [mixed, heavy]) {
            const leaving = Turnstile.plan(parts, Tokens.durationShort, 0);
            const arriving = Turnstile.plan(parts, Tokens.durationModerate, Turnstile.nextPlaceAt(leaving));
            const end = Math.max(...arriving.map(turn => turn.at + turn.duration));
            verify(end <= longest + 1e-9, `${end} ms outlasts ${longest} ms`);
            if (parts === heavy)
                fuzzyCompare(end, longest, 1e-9);
        }
    }

    function test_a_part_in_a_clipping_box_turns_around_its_edge_and_counts_its_reach_and_top_from_it() {
        const clip = {
            x: 100,
            y: 200
        };
        const flush = Object.assign(part(140, 201, tile, tile), {
            clip: clip
        });
        const lower = Object.assign(part(300, 400, tile, tile), {
            clip: clip
        });
        const turns = Turnstile.plan([flush, lower], Tokens.durationShort, 0);
        compare(turnOf(turns, flush).originX, clip.x - flush.x);
        compare(turnOf(turns, flush).originY, 0);
        compare(turnOf(turns, lower).originY, tile / 2);
        fuzzyCompare(turnOf(turns, lower).perspective, Tokens.turnstilePerspective + Tokens.turnstileReach * (lower.x + tile - clip.x), 1e-9);
    }

    function test_the_pressed_tile_turns_last_in_a_row_of_its_own_once_the_others_started_and_it_has_sunk() {
        const pressed = part(0, 100, tile, tile);
        const neighbour = part(tile + Tokens.spaceS, 100, tile, tile);
        const line = part(0, 0, 400, 20);
        const others = Turnstile.plan([line, neighbour], Tokens.durationShort, 0);
        const lastStart = Math.max(...others.map(turn => turn.at));
        const turn = Turnstile.pressedTurn(pressed, Tokens.durationShort, others, 0);
        compare(turn.at, lastStart);
        fuzzyCompare(turn.duration, Tokens.heftTile * Tokens.durationShort, 1e-9);
        fuzzyCompare(turn.perspective, Tokens.turnstilePerspective + Tokens.turnstileReach * tile, 1e-9);
        compare(Turnstile.pressedTurn(pressed, Tokens.durationShort, others, lastStart + 40).at, lastStart + 40);
    }

    function test_under_reduced_motion_every_part_turns_at_once_and_in_no_time() {
        Tokens.reducedMotion = true;
        const turns = Turnstile.plan([part(0, 0, tile, tile), part(0, 400, 1200, 800)], Tokens.durationModerate, 0);
        compare(turns.map(turn => turn.at), [0, 0]);
        compare(turns.map(turn => turn.duration), [0, 0]);
    }

    // A box 100 from the screen's leading side and 200 from its top, 800 by 600: its bottom edge lies at 800.
    readonly property var box: ({
            x: 100,
            y: 200,
            width: 800,
            height: 600
        })

    function boxed(x: real, y: real, width: real, height: real): var {
        return Object.assign(part(x, y, width, height), {
            clip: box
        });
    }

    function test_rekta_s_turn_is_about_the_vertical_axis_and_the_bottom_edge_s_about_the_horizontal_one() {
        const tilePart = boxed(140, 300, tile, tile);
        compare(Turnstile.plan([tilePart], Tokens.durationShort, 0)[0].axis, Qt.vector3d(0, 1, 0));
        compare(Turnstile.plan([tilePart], Tokens.durationShort, 0, "bottom")[0].axis, Qt.vector3d(1, 0, 0));
    }

    function test_folded_up_each_part_turns_about_its_own_bottom_edge_from_its_middle_in_800_plus_1_2_times_its_own_height() {
        const tilePart = boxed(101, 300, 150, 150);
        const line = boxed(400, 300, 348, 23);
        const turns = Turnstile.plan([tilePart, line], 400, 0, "bottom");
        compare([turnOf(turns, tilePart).originX, turnOf(turns, tilePart).originY], [75, 150]);
        compare([turnOf(turns, line).originX, turnOf(turns, line).originY], [174, 23]);
        fuzzyCompare(turnOf(turns, tilePart).perspective, 980, 1e-9);
        fuzzyCompare(turnOf(turns, line).perspective, 827.6, 1e-9);
    }

    // The Start as it opens at 1920 × 1080: its title, its strip, three section heads in a row, the first row of tiles
    // under "angeheftet" and a line of text beside them a little lower, given out of order.
    readonly property var startTitle: part(48, 0, 1824, 94)
    readonly property var startStrip: part(48, 94, 1824, 55)
    readonly property var runningHead: part(48, 196, 348, 39)
    readonly property var pinnedHead: part(452, 196, 704, 39)
    readonly property var todayHead: part(1212, 196, 348, 39)
    readonly property var wideTile: part(452, 267, 348, 170)
    readonly property var smallTile: part(808, 267, 170, 170)
    readonly property var sentence: part(1212, 284, 348, 23)
    readonly property var startLayout: [sentence, smallTile, todayHead, wideTile, startStrip, pinnedHead, startTitle, runningHead]

    function test_folded_up_the_parts_start_in_reading_order_a_row_one_stagger_after_the_row_above_its_parts_spread_over_that_stagger_front_to_back() {
        const turns = Turnstile.plan(startLayout, 400, 0, "bottom");
        compare(turns.map(turn => turn.part), [startTitle, startStrip, runningHead, pinnedHead, todayHead, wideTile, smallTile, sentence]);
        compare(turns.map(turn => turn.at), [0, 30, 60, 70, 80, 90, 105, 120]);
    }

    function test_folded_up_parts_whose_tops_round_to_one_multiple_of_8_share_a_row_and_the_next_multiple_starts_the_next_row() {
        const atTop196 = part(0, 196, 100, 20);
        const atTop203 = part(200, 203, 100, 20);
        const atTop204 = part(0, 204, 100, 20);
        const turns = Turnstile.plan([atTop204, atTop203, atTop196], 400, 1000, "bottom");
        compare(turns.map(turn => turn.part), [atTop196, atTop203, atTop204]);
        compare(turns.map(turn => turn.at), [1000, 1015, 1030]);
    }

    function test_folded_up_a_row_of_seven_tiles_starts_its_last_one_before_the_first_of_the_row_below() {
        const row = [0, 1, 2, 3, 4, 5, 6].map(column => part(48 + 178 * column, 267, 170, 170));
        const below = part(48, 445, 170, 170);
        const turns = Turnstile.plan([below, ...row.slice().reverse()], 400, 0, "bottom");
        compare(turns.map(turn => turn.part), [...row, below]);
        compare(turns.map(turn => Math.round(turn.at * 1000) / 1000), [0, 4.286, 8.571, 12.857, 17.143, 21.429, 25.714, 30]);
    }

    function test_folded_up_heft_sets_only_how_long_a_part_takes() {
        const square = part(808, 267, 150, 150);
        const turns = Turnstile.plan([sentence, startTitle, square], 400, 0, "bottom");
        compare(turns.map(turn => turn.part), [startTitle, square, sentence]);
        compare(turns.map(turn => turn.at), [0, 30, 60]);
        fuzzyCompare(turnOf(turns, startTitle).duration, 560, 1e-9);
        fuzzyCompare(turnOf(turns, square).duration, 320, 1e-9);
        fuzzyCompare(turnOf(turns, sentence).duration, 400 * Turnstile.heft(348, 23), 1e-9);
    }

    function test_folded_away_backwards_the_last_part_in_goes_first_and_the_title_last() {
        const turns = Turnstile.plan(startLayout, 250, 0, "bottom", true);
        const startOf = wanted => turnOf(turns, wanted).at;
        compare([startTitle, startStrip, runningHead, pinnedHead, todayHead, wideTile, smallTile, sentence].map(startOf), [120, 90, 60, 50, 40, 30, 15, 0]);
    }

    function test_folded_away_the_pressed_tile_turns_last_about_its_own_bottom_edge_in_a_row_of_its_own() {
        const pressed = part(452, 445, 170, 170);
        const others = Turnstile.plan(startLayout, 250, 0, "bottom");
        const turn = Turnstile.pressedTurn(pressed, 250, others, 0, "bottom");
        compare(turn.at, 120);
        compare(turn.axis, Qt.vector3d(1, 0, 0));
        compare([turn.originX, turn.originY], [85, 170]);
        fuzzyCompare(turn.perspective, 1004, 1e-9);
    }

    function test_under_reduced_motion_every_part_folds_at_once_and_in_no_time_either_way() {
        Tokens.reducedMotion = true;
        for (const backwards of [false, true]) {
            const turns = Turnstile.plan(startLayout, Tokens.durationModerate, 0, "bottom", backwards);
            compare(turns.map(turn => turn.at), [0, 0, 0, 0, 0, 0, 0, 0]);
            compare(turns.map(turn => turn.duration), [0, 0, 0, 0, 0, 0, 0, 0]);
        }
    }
}
