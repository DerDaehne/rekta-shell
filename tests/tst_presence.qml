pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

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
            }

            Rectangle {
                objectName: "row"
                y: 200
                width: 300
                height: 40
                color: "steelblue"
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
}
