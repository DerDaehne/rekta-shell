pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import Start

// How the Start's parts turn: folded up about their own bottom edges in reading order on every way into and out of the
// windows, about Rekta's leading edge between its places. The Start here is 1600 × 900 with three pinned apps, no window.
TestCase {
    id: testCase

    name: "StartTurn"
    visible: true
    when: windowShown
    width: 1600
    height: 900

    function fakeApp(name: string): var {
        return {
            id: `org.example.${name}`,
            name: name,
            icon: "",
            columns: 1,
            rows: 1,
            launch: () => {}
        };
    }

    Component {
        id: startComponent

        StartPlace {
            width: testCase.width
            height: testCase.height
            windows: []
            pinned: [testCase.fakeApp("systemsettings"), testCase.fakeApp("dolphin"), testCase.fakeApp("konsole")]
        }
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var start
    property var turner

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        start = createTemporaryObject(startComponent, testCase);
        turner = findChild(start, "turn");
    }

    function cleanup() {
        turner.finish();
        Prefs.motion = "system";
    }

    function named(name: string): var {
        return findChild(start, name);
    }

    function openNow() {
        Prefs.motion = "off";
        start.open();
        Prefs.motion = "system";
        waitForRendering(start);
    }

    function verifyAboutTheBottomEdge(turns: var) {
        verify(turns.length > 0);
        compare(turner.edge, "bottom");
        for (const turn of turns)
            compare(turn.axis, Qt.vector3d(1, 0, 0), turn.part.item.objectName);
    }

    function rotationOf(item: Item): var {
        return Array.from(item.transform).find(transform => (transform as Rotation) !== null) ?? null;
    }

    function turnOf(turns: var, item: Item): var {
        return turns.find(turn => turn.part.item === item);
    }

    function pinnedTiles(): var {
        return findChild(named("pinned"), "grid").children.filter(item => (item as Tile) !== null);
    }

    // The section heads in the order they stand, front to back.
    function headings(turns: var): var {
        return turns.filter(turn => turn.part.item.objectName === "heading").sort((a, b) => a.part.x - b.part.x).map(turn => turn.part.item);
    }

    // The Start opening, its parts planned and held where they wait to turn in.
    function holdTheOpening() {
        Prefs.motion = "on";
        start.open();
        tryVerify(() => turner.running, 2000);
        turner.paused = true;
    }

    function test_opening_the_title_starts_then_the_strip_then_the_section_heads_then_the_tiles_a_row_15_ms_after_the_one_above_and_7_5_ms_from_front_to_back() {
        holdTheOpening();
        const turns = turner.arrivingTurns;
        verifyAboutTheBottomEdge(turns);
        const startOf = item => turnOf(turns, item).at - turner.handOverAt;
        compare(startOf(named("pivot")), 0);
        compare(startOf(named("sectionStrip")), 15);
        compare(headings(turns).map(startOf), [30, 37.5, 45]);
        compare(pinnedTiles().map(startOf), [45, 52.5, 60]);
    }

    function test_opening_each_part_turns_about_its_own_bottom_edge_from_its_middle_in_800_plus_1_2_times_its_own_height() {
        holdTheOpening();
        for (const turn of turner.arrivingTurns) {
            const name = turn.part.item.objectName;
            compare([turn.originX, turn.originY], [turn.part.width / 2, turn.part.height], name);
            fuzzyCompare(turn.perspective, 800 + 1.2 * turn.part.height, 1e-9);
        }
        const tile = rotationOf(pinnedTiles()[0]);
        compare(tile.origin, Qt.vector3d(85, 170, 0));
        fuzzyCompare(tile.distanceToPlane, 1004, 1e-9);
        compare(rotationOf(named("pivot")).origin, Qt.vector3d(752, 87.1, 0));
    }

    function test_at_half_tempo_the_title_turns_in_over_280_ms_and_a_tile_over_174_7_and_out_over_175_and_109_2() {
        holdTheOpening();
        compare(turnOf(turner.arrivingTurns, named("pivot")).duration, 280);
        fuzzyCompare(turnOf(turner.arrivingTurns, pinnedTiles()[0]).duration, 174.65, 0.01);
        turner.finish();
        keyClick(Qt.Key_Escape);
        compare(turnOf(turner.leavingTurns, named("pivot")).duration, 175);
        fuzzyCompare(turnOf(turner.leavingTurns, pinnedTiles()[0]).duration, 109.16, 0.01);
    }

    // Two boxes {x, y, width, height} overlap by more than a rounding error.
    function overlap(a: var, b: var): bool {
        const apart = 0.5;
        return a.x + a.width > b.x + apart && b.x + b.width > a.x + apart && a.y + a.height > b.y + apart && b.y + b.height > a.y + apart;
    }

    // The box a part is drawn in, its rotation and perspective included.
    function drawnBox(item: Item): var {
        const corners = [[0, 0], [item.width, 0], [0, item.height], [item.width, item.height]].map(([x, y]) => item.mapToItem(null, x, y));
        const xs = corners.map(corner => corner.x);
        const ys = corners.map(corner => corner.y);
        return {
            x: Math.min(...xs),
            y: Math.min(...ys),
            width: Math.max(...xs) - Math.min(...xs),
            height: Math.max(...ys) - Math.min(...ys)
        };
    }

    // Two parts cross when, in one frame of the opening, the boxes they are drawn in overlap though their boxes at rest
    // do not: a part rising through the one above it, or a later one over an earlier one.
    function test_opening_no_two_parts_ever_cross_in_any_frame() {
        holdTheOpening();
        const turns = turner.arrivingTurns;
        const end = Math.max(...turns.map(turn => turn.at + turn.duration));
        const apartAtRest = [];
        turns.forEach((a, index) => apartAtRest.push(...turns.slice(index + 1).filter(b => !overlap(a.part, b.part)).map(b => [a, b])));
        verify(apartAtRest.length > 40, `${apartAtRest.length} pairs`);
        for (let time = turner.handOverAt; time <= end; time += 1000 / 60) {
            turner.elapsed = time;
            const crossing = apartAtRest.find(([a, b]) => overlap(drawnBox(a.part.item), drawnBox(b.part.item)));
            verify(!crossing, crossing ? `${crossing[0].part.item} and ${crossing[1].part.item} at ${time - turner.handOverAt} ms` : "");
        }
    }

    function test_closed_back_the_parts_fold_away_the_last_one_in_first_and_the_title_last() {
        holdTheOpening();
        const opening = turner.arrivingTurns.map(turn => [turn.part.item, turn.at - turner.handOverAt]);
        const lastIn = Math.max(...opening.map(([, at]) => at));
        turner.finish();
        keyClick(Qt.Key_Escape);
        verify(turner.back);
        verifyAboutTheBottomEdge(turner.leavingTurns);
        for (const [item, at] of opening)
            compare(turnOf(turner.leavingTurns, item).at, lastIn - at, item.objectName);
        compare(turnOf(turner.leavingTurns, named("pivot")).at, 90);
        compare(pinnedTiles().map(tile => turnOf(turner.leavingTurns, tile).at), [45, 37.5, 30]);
    }

    function test_a_finger_takes_every_part_s_turn_on_monotonically_and_back_the_same_way() {
        Prefs.motion = "on";
        const way = start.screenHeight / 2;
        const steps = 20;
        const angles = [];
        for (let step = 0; step <= steps; step++) {
            start.followFinger(way * step / steps);
            angles.push(turner.arrivingTurns.map(turn => rotationOf(turn.part.item)?.angle ?? 0));
        }
        verify(turner.arrivingTurns.length > 5, `${turner.arrivingTurns.length} parts`);
        compare(angles[0].every(angle => angle === Tokens.turnstileInAngle), true, "all wait in their first pose");
        compare(angles[steps].every(angle => angle === 0), true, "all at rest at the end of the way");
        for (let step = 1; step <= steps; step++)
            verify(angles[step].every((angle, index) => angle <= angles[step - 1][index]), `on at step ${step}`);
        for (let step = steps; step >= 0; step--) {
            start.followFinger(way * step / steps);
            compare(turner.arrivingTurns.map(turn => rotationOf(turn.part.item)?.angle ?? 0), angles[step], `back at step ${step}`);
        }
        start.letFingerGo();
    }

    function test_closed_back_the_parts_turn_out_about_the_bottom_edge() {
        openNow();
        keyClick(Qt.Key_Escape);
        verify(turner.back);
        verifyAboutTheBottomEdge(turner.leavingTurns);
    }

    function test_after_a_tile_press_the_parts_fold_away_forward_in_reading_order_the_title_first_and_the_pressed_tile_last() {
        openNow();
        const pressed = pinnedTiles()[1];
        mouseClick(pressed);
        verify(!turner.back);
        verifyAboutTheBottomEdge(turner.leavingTurns);
        compare(turnOf(turner.leavingTurns, named("pivot")).at, 0);
        compare(turnOf(turner.leavingTurns, named("sectionStrip")).at, 15);
        compare(turner.leavingTurns[turner.leavingTurns.length - 1].part.item, pressed);
        verify(turner.leavingTurns.every(turn => turn.at <= turnOf(turner.leavingTurns, pressed).at));
    }

    // As the Start steps aside for an app started elsewhere.
    function test_left_forward_without_a_tile_the_parts_turn_out_about_the_bottom_edge() {
        openNow();
        start.leave({
            back: false,
            pressed: null
        });
        verify(!turner.back);
        verifyAboutTheBottomEdge(turner.leavingTurns);
    }

    function test_a_change_of_place_inside_the_start_keeps_rekta_s_leading_edge() {
        openNow();
        keyClick(Qt.Key_Right);
        verify(turner.running);
        compare(turner.edge, "leading");
        for (const turn of turner.leavingTurns)
            compare(turn.axis, Qt.vector3d(0, 1, 0));
    }

    function test_under_reduced_motion_the_start_stands_open_at_once_and_closes_at_once() {
        Prefs.motion = "off";
        compare(named("waitForWindows").interval, 0);
        start.open();
        verify(!turner.running);
        compare(start.phase, "open");
        keyClick(Qt.Key_Escape);
        verify(!turner.running);
        tryCompare(start, "phase", "closed", 1000);
    }
}
