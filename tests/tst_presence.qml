pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import "Glide.js" as Glide

TestCase {
    id: testCase

    name: "Presence"
    when: windowShown
    width: 800
    height: 600

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var presence
    property var box
    property int applied: 0
    readonly property easingCurve easeIn: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })

    Component {
        id: presenceComponent

        Presence {}
    }

    Component {
        id: boxComponent

        Item {
            width: testCase.width
            height: testCase.height

            Tile {
                objectName: "tile"
                x: 10

                Facts {
                    objectName: "content"
                    text: "30 of 30 runs"
                }
            }

            Rectangle {
                objectName: "row"
                y: 200
                width: 300
                height: 40
                color: "steelblue"
            }

            Rectangle {
                objectName: "between"
                y: 200
                width: 300
                height: 40
                color: "orange"
                visible: false
            }

            Tile {
                objectName: "other"
                x: 200
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        presence = createTemporaryObject(presenceComponent, testCase);
        box = createTemporaryObject(boxComponent, testCase);
        applied = 0;
    }

    function cleanup() {
        Prefs.motion = "system";
    }

    function named(name: string): var {
        return findChild(box, name);
    }

    function motionOf(item: var): var {
        return presence.moving.find(motion => motion.item === item);
    }

    function apply() {
        applied++;
    }

    // A row comes in the place of "row", which makes room below it.
    function comeBetween() {
        presence.change([], [named("row")], () => {
            named("between").visible = true;
            named("row").y = 240;
        }, () => [named("between")], 1);
    }

    function test_those_that_go_leave_first_a_tile_shrinking_a_row_drifting_to_its_trailing_edge() {
        const started = Date.now();
        presence.change([named("tile"), named("row")], [], apply, () => [], 0);
        const tile = motionOf(named("tile"));
        const row = motionOf(named("row"));
        compare(tile.duration, Geometry.leaveShare * Tokens.durationShort);
        compare(tile.curve, Tokens.easeOut);
        compare(tile.to.scale, Geometry.leaveTileScale);
        compare(tile.to.opacity, 0);
        compare(row.to.x, Geometry.leaveRowDrift);
        compare(row.to.scale, 1);
        compare(applied, 0, "the change waits for them");
        tryVerify(() => applied === 1, 1000);
        verify(Date.now() - started >= Geometry.leaveShare * Tokens.durationShort - 2);
        compare(presence.moving.length, 0, "once the change is made they let go");
    }

    function test_those_that_come_arrive_a_tile_rising_from_96_percent_a_row_from_above() {
        presence.change([], [], apply, () => [named("tile"), named("row")], 2);
        compare(applied, 1, "nothing leaves, so the change is made at once");
        const tile = motionOf(named("tile"));
        const row = motionOf(named("row"));
        compare(tile.from.y, Geometry.arriveShift);
        compare(tile.from.scale, Geometry.arriveTileScale);
        compare(tile.from.opacity, 0);
        compare(tile.duration, Tokens.durationModerate);
        compare(tile.curve, Tokens.easeIn);
        compare(row.from.y, -Geometry.arriveShift);
        compare(row.duration, Tokens.durationShort);
        compare(named("tile").opacity, 0, "unseen as it starts");
        tryVerify(() => presence.moving.length === 0, 1000);
    }

    function test_a_row_that_comes_between_others_waits_unseen_until_those_after_it_have_glided_then_arrives_from_above() {
        const ticks = Glide.ticks(testCase);
        const between = named("between");
        comeBetween();
        const glide = motionOf(named("row"));
        const coming = motionOf(between);
        verify(glide !== undefined && !glide.fades, "the row after it glides down");
        compare(glide.from.y, -40);
        verify(coming !== undefined, "it is to arrive");
        compare(between.opacity, 0, "unseen while it waits");
        const glided = Glide.record(glide, "progress");
        const shows = Glide.record(between, "opacity");
        const falls = Glide.record(coming.shift, "y");
        tryVerify(() => !presence.running, Tokens.durationModerate * 4, "all at rest");
        const landed = glided[glided.length - 1];
        compare(landed.value, 1, "the row glided to its place");
        verify(shows.length > 0 && shows.every(step => step.order > landed.order), "never seen while the row glides");
        const stray = Glide.strayOf([{ steps: shows, from: 0, to: 1 }, { steps: falls, from: -Geometry.arriveShift, to: 0 }], Tokens.durationShort, easeIn, landed.at, ticks);
        verify(stray < 0.06, `then it comes from above with a fade along ease-in over duration-short, off by ${stray}`);
        compare(between.opacity, 1);
    }

    function test_a_row_waiting_for_room_waits_through_a_newer_change_until_nothing_glides_any_more() {
        const between = named("between");
        comeBetween();
        presence.change([], [named("other")], () => named("other").x = 400, () => [], 0);
        const glides = presence.moving.filter(motion => !motion.fades);
        compare(glides.length, 2, "the row and the tile glide");
        const glided = glides.map(glide => Glide.record(glide, "progress"));
        const shows = Glide.record(between, "opacity");
        compare(between.opacity, 0, "still unseen");
        tryVerify(() => !presence.running, Tokens.durationModerate * 4, "all at rest");
        const landed = Math.max(...glided.map(steps => steps[steps.length - 1].order));
        verify(shows.length > 0 && shows.every(step => step.order > landed), "it comes once both have landed");
        compare(between.opacity, 1);
    }

    function test_a_row_waiting_for_room_waits_for_a_glide_a_newer_change_redirects_midway_until_it_lands() {
        const between = named("between");
        const row = named("row");
        comeBetween();
        const first = motionOf(row);
        tryVerify(() => first.progress > 0.3, Tokens.durationModerate, "the row is on its way");
        presence.change([], [row], () => row.y = 300, () => [], 0);
        const redirected = motionOf(row);
        verify(redirected !== first && !redirected.fades, "the row glides on to its new place");
        compare(between.opacity, 0, "still unseen");
        const glided = Glide.record(redirected, "progress");
        const shows = Glide.record(between, "opacity");
        tryVerify(() => !presence.running, Tokens.durationModerate * 4, "all at rest");
        const landed = glided[glided.length - 1];
        compare(landed.value, 1, "the redirected glide landed");
        verify(shows.length > 0 && shows.every(step => step.order > landed.order), "it comes only once that glide has landed");
        compare(between.opacity, 1);
    }

    function test_a_row_waiting_for_room_arrives_once_the_row_gliding_below_it_leaves_instead_and_is_gone() {
        const between = named("between");
        const row = named("row");
        comeBetween();
        const glide = motionOf(row);
        tryVerify(() => glide.progress > 0.3, Tokens.durationModerate, "the row is on its way");
        presence.change([row], [], () => row.visible = false, () => [], 0);
        const leaving = motionOf(row);
        verify(leaving.fades, "the row leaves");
        const left = Glide.record(leaving, "progress");
        const shows = Glide.record(between, "opacity");
        tryVerify(() => !presence.running, Tokens.durationModerate * 4, "all at rest");
        verify(left.length > 0, "the row left");
        const gone = left[left.length - 1];
        verify(shows.length > 0 && shows.every(step => step.order > gone.order), "unseen while the row leaves");
        compare(between.opacity, 1);
        compare(between.transform.length, 0, "it let go");
    }

    function test_a_row_that_comes_at_the_end_with_nothing_gliding_arrives_at_once() {
        presence.change([], [named("tile"), named("other")], apply, () => [named("row")], 1);
        verify(presence.moving.every(motion => motion.fades), "the others stay where they are");
        verify(motionOf(named("row")).run.running, "it arrives as the change is made");
    }

    function test_a_tile_that_comes_arrives_at_once_while_the_others_glide() {
        const other = named("other");
        presence.change([], [other], () => other.x = 400, () => [named("tile")], 1);
        verify(!motionOf(other).fades, "the other tile glides");
        verify(motionOf(named("tile")).run.running, "the tile arrives meanwhile");
    }

    function test_an_item_lets_go_as_it_lands_its_own_opacity_and_transform_back() {
        const tile = named("tile");
        const transforms = tile.transform.length;
        presence.change([], [], apply, () => [tile], 1);
        verify(tile.transform.length > transforms);
        tryVerify(() => !presence.running, 1000);
        compare(tile.opacity, 1);
        compare(tile.transform.length, transforms);
    }

    function test_those_that_stay_glide_from_where_they_were_to_where_they_are_now() {
        const other = named("other");
        presence.change([named("tile")], [other], () => {
            named("tile").visible = false;
            other.x = 10;
        }, () => [], 0);
        tryVerify(() => motionOf(other) !== undefined, 1000);
        const glide = motionOf(other);
        compare(glide.from.x, 190);
        compare(glide.to.x, 0);
        compare(glide.duration, Tokens.durationModerate);
        compare(glide.curve, Tokens.easeBase);
        verify(!glide.fades);
        verify(other.mapToItem(null, 0, 0).x > 10, "on its way from where it was");
        tryVerify(() => !presence.running, 1000);
        compare(other.mapToItem(null, 0, 0).x, 10);
    }

    function test_a_resized_tile_scales_from_its_old_size_and_its_content_shows_over_the_last_45_percent() {
        const ticks = Glide.ticks(testCase);
        const tile = named("tile");
        const facts = findChild(tile, "content");
        const shows = Glide.record(tile, "contentOpacity");
        const since = Date.now();
        presence.change([], [tile], () => tile.columns = 2, () => [], 0);
        const glide = motionOf(tile);
        verify(glide !== undefined);
        fuzzyCompare(glide.from.sx, Tokens.tileUnit / (2 * Tokens.tileUnit + Tokens.spaceS), 0.001, "from one unit of the two");
        compare(glide.from.sy, 1);
        compare(glide.duration, Tokens.durationModerate);
        compare(glide.curve, Tokens.easeBase);
        verify(glide.resized);
        fuzzyCompare(tile.mapToItem(null, tile.width, 0).x - tile.mapToItem(null, 0, 0).x, Tokens.tileUnit, 2, "shows its old width at first");
        compare(tile.contentOpacity, 0);
        compare(facts.parent.opacity, 0, "its content hidden");
        tryVerify(() => !presence.running, 1000);
        compare(tile.contentOpacity, 1);
        const lastShare = { valueForProgress: share => Math.max(0, share - Geometry.resizeContentFrom) / (1 - Geometry.resizeContentFrom) };
        const stray = Glide.strayOf([{ steps: shows, from: 0, to: 1 }], Tokens.durationModerate, lastShare, since, ticks);
        verify(stray < 0.06, `hidden before 55%, then shown evenly to the end: off by ${stray}`);
        compare(tile.width, 2 * Tokens.tileUnit + Tokens.spaceS);
    }

    function test_a_tile_that_only_moves_keeps_its_content_shown() {
        const other = named("other");
        presence.change([], [other], () => other.x = 400, () => [], 0);
        verify(!motionOf(other).resized);
        compare(other.contentOpacity, 1);
    }

    function test_more_than_sixty_changes_apply_at_once() {
        presence.change([named("tile")], [], apply, () => [named("row")], Geometry.presenceAtOnceAbove);
        compare(applied, 1);
        verify(!presence.running);
    }

    function test_under_reduced_motion_a_change_applies_at_once() {
        Prefs.motion = "off";
        presence.change([named("tile")], [], apply, () => [named("row")], 1);
        compare(applied, 1);
        verify(!presence.running);
        compare(named("row").opacity, 1);
    }

    function test_under_reduced_motion_a_row_between_others_shows_at_once() {
        Prefs.motion = "off";
        comeBetween();
        verify(!presence.running);
        compare(named("between").opacity, 1);
        compare(named("row").mapToItem(null, 0, 0).y, 240);
    }

    function test_a_change_without_motion_lands_what_still_moves_from_before() {
        presence.change([], [], apply, () => [named("tile")], 1);
        verify(presence.running);
        Prefs.motion = "off";
        presence.change([], [], apply, () => [], 0);
        verify(!presence.running);
        compare(named("tile").opacity, 1);
    }

    function test_a_newer_change_makes_the_waiting_one_at_once() {
        presence.change([named("tile")], [], apply, () => [], 0);
        presence.change([named("row")], [], apply, () => [], 0);
        compare(applied, 1, "the first is made");
        compare(named("tile").opacity, 1, "and its tile let go");
        verify(motionOf(named("row")) !== undefined);
        tryVerify(() => applied === 2, 1000);
    }

    function test_complete_puts_everything_at_rest_now() {
        presence.change([named("tile")], [], apply, () => [named("row")], 1);
        presence.complete();
        compare(applied, 1);
        verify(!presence.running);
        compare(named("row").opacity, 1);
    }

    function test_complete_shows_a_row_still_waiting_for_room_at_rest() {
        comeBetween();
        presence.complete();
        verify(!presence.running);
        compare(named("between").opacity, 1);
        compare(named("between").transform.length, 0);
    }
}
