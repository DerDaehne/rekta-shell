import QtQuick
import QtTest
import Rekta

TestCase {
    name: "Turnstile"

    readonly property real tile: Tokens.tileUnit

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

    function cleanup() {
        Tokens.reducedMotion = false;
    }

    function test_a_tile_weighs_as_a_tile_and_every_part_lies_between_the_lightest_and_the_heaviest() {
        fuzzyCompare(Turnstile.heft(tile, tile), Geometry.heftAtTile, 1e-9);
        compare(Turnstile.heft(1, 1), Geometry.heftMin);
        compare(Turnstile.heft(4000, 3000), Geometry.heftMax);
    }

    function test_light_parts_start_first_and_take_less_time() {
        const line = part(0, 400, 100, 20);
        const window = part(0, 0, 1200, 800);
        const turns = Turnstile.plan([window, line], Tokens.durationModerate, 0);
        verify(turnOf(turns, line).at < turnOf(turns, window).at);
        verify(turnOf(turns, line).duration < turnOf(turns, window).duration);
        fuzzyCompare(turnOf(turns, window).duration, Geometry.heftMax * Tokens.durationModerate, 1e-9);
    }

    function test_parts_of_one_heft_follow_in_reading_order_half_a_stagger_apart_six_steps_at_most() {
        const row = [];
        for (let i = 7; i >= 0; i--)
            row.push(part(i * (tile + Tokens.spaceS), 0, tile, tile));
        const turns = Turnstile.plan(row, Tokens.durationShort, 0);
        const first = (Geometry.heftAtTile - Geometry.heftMin) * Geometry.heftStaggerSteps * Tokens.durationStagger;
        const step = Geometry.sameHeftStagger * Tokens.durationStagger;
        compare(turns.map(turn => turn.part.x), row.map(p => p.x).reverse());
        for (let i = 0; i < turns.length; i++)
            fuzzyCompare(turns[i].at, first + Math.min(i, Geometry.sameHeftSteps) * step, 1e-9);
    }

    function test_a_row_turns_in_the_perspective_of_its_farthest_reach() {
        const near = part(0, 100, tile, tile);
        const far = part(2 * tile, 100, tile, tile);
        const below = part(0, 400, tile, tile);
        const turns = Turnstile.plan([near, far, below], Tokens.durationShort, 0);
        const rowPerspective = Tokens.turnstilePerspective + Geometry.turnPerspectivePerReach * 3 * tile;
        fuzzyCompare(turnOf(turns, near).perspective, rowPerspective, 1e-9);
        fuzzyCompare(turnOf(turns, far).perspective, rowPerspective, 1e-9);
        fuzzyCompare(turnOf(turns, below).perspective, Tokens.turnstilePerspective + Geometry.turnPerspectivePerReach * tile, 1e-9);
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
        const ends = turns.map(turn => turn.at + Geometry.turnOverlap * turn.duration);
        fuzzyCompare(Turnstile.nextPlaceAt(turns), Math.max(...ends), 1e-9);
        compare(Turnstile.nextPlaceAt([]), 0);
    }

    function test_under_reduced_motion_every_part_turns_at_once_and_in_no_time() {
        Tokens.reducedMotion = true;
        const turns = Turnstile.plan([part(0, 0, tile, tile), part(0, 400, 1200, 800)], Tokens.durationModerate, 0);
        compare(turns.map(turn => turn.at), [0, 0]);
        compare(turns.map(turn => turn.duration), [0, 0]);
    }
}
