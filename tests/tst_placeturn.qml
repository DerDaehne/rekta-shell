pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import "ContactSheets.js" as ContactSheets

TestCase {
    id: testCase

    name: "PlaceTurn"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 2150
    height: 1130

    property Item scene: null
    property Item first: null
    property Item second: null
    property Item third: null
    property PlaceTurn turner: null

    SignalSpy {
        id: landedSpy

        target: testCase.turner
        signalName: "landed"
    }

    Component {
        id: sceneComponent

        // Three places and the turn between them: eight tiles under a title, a run's detail with buttons and a wide
        // tile, and the logs.
        Rectangle {
            width: 672
            height: 480
            color: Tokens.color.bg

            PlaceTurn {
                objectName: "turner"
            }

            Item {
                objectName: "first"
                anchors.fill: parent

                Column {
                    x: Tokens.spaceL
                    y: Tokens.spaceL
                    spacing: Tokens.spaceM

                    Title {
                        objectName: "title"
                        text: "builds"
                    }
                    Grid {
                        columns: 4
                        spacing: Tokens.spaceS

                        Repeater {
                            model: 8

                            delegate: Tile {
                                id: tile

                                required property int index

                                objectName: `tile${index}`
                                opens: true
                                status: ["", "success", "", "error", "", "", "warning", ""][index]

                                Kicker {
                                    text: `nightly ${tile.index + 1}`
                                }
                            }
                        }
                    }
                    Body {
                        objectName: "note"
                        text: "eight pipelines, two of them need you"
                    }
                }
                Tile {
                    objectName: "away"
                    x: 4000
                }
                Body {
                    objectName: "hidden"
                    visible: false
                    text: "not shown"
                }
            }

            Item {
                objectName: "second"
                anchors.fill: parent
                visible: false

                Column {
                    x: Tokens.spaceL
                    y: Tokens.spaceL
                    spacing: Tokens.spaceM

                    Title {
                        text: "nightly 2"
                    }
                    Body {
                        text: "ran 14 minutes, all 212 tests passed"
                    }
                    Row {
                        spacing: Tokens.spaceS

                        Button {
                            objectName: "rerun"
                            text: "run again"
                        }
                        Button {
                            text: "logs"
                            variant: "quiet"
                        }
                    }
                    Tile {
                        objectName: "summary"
                        opens: true
                        columns: 2
                        status: "success"

                        TileMessage {
                            text: "every step green"
                        }
                    }
                }
            }

            Item {
                objectName: "third"
                anchors.fill: parent
                visible: false

                Title {
                    objectName: "logs"
                    x: Tokens.spaceL
                    y: Tokens.spaceL
                    text: "logs"
                }
                Progress {
                    objectName: "upload"
                    x: Tokens.spaceL
                    y: 120
                    width: 400
                    label: "uploading"
                    value: 0.4
                }
            }
        }
    }

    Component {
        id: clippedComponent

        // A place away from the window's corner: two tiles laid out in a box inside a box that clips them, its edge at
        // 100, 80 on the screen, and a tile beside it, under the place's own edge at 40, 30.
        Rectangle {
            width: 672
            height: 480
            color: Tokens.color.bg

            PlaceTurn {
                objectName: "turner"
            }

            Item {
                objectName: "place"
                x: 40
                y: 30
                width: 632
                height: 450

                Item {
                    x: 60
                    y: 50
                    width: 400
                    height: 250
                    clip: true

                    Item {
                        x: 20
                        width: 380
                        height: 250

                        Tile {
                            objectName: "flush"
                        }
                        Tile {
                            objectName: "lower"
                            x: 180
                            y: 40
                        }
                    }
                }
                Tile {
                    objectName: "beside"
                    x: 480
                }
            }
        }
    }

    Component {
        id: frameComponent

        // One moment of the turn: a scene of its own, held at that moment, with what it shows.
        Column {
            property alias label: caption.text

            spacing: Tokens.spaceXs

            Loader {
                sourceComponent: sceneComponent
            }
            Meta {
                id: caption
            }
        }
    }

    Component {
        id: sheetComponent

        // The frames of one turn, three to a row, on the current theme's ground.
        Rectangle {
            property alias frames: grid

            width: grid.width + 2 * Tokens.spaceL
            height: grid.height + 2 * Tokens.spaceL
            color: Tokens.color.bg

            Grid {
                id: grid

                x: Tokens.spaceL
                y: Tokens.spaceL
                columns: 3
                spacing: Tokens.spaceL
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        scene = createTemporaryObject(sceneComponent, testCase);
        turner = findChild(scene, "turner");
        first = findChild(scene, "first");
        second = findChild(scene, "second");
        third = findChild(scene, "third");
        landedSpy.clear();
        waitForRendering(scene);
    }

    function cleanup() {
        turner.finish();
        turner.paused = false;
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    // Untyped: qmllint stops without a word on members a typed Item lacks (a Tile's sink, say).
    function named(name: string): var {
        return findChild(scene, name);
    }

    function turnOf(turns: var, item: Item): var {
        return turns.find(turn => turn.part.item === item);
    }

    // The rotation a turning part carries, or null when it rests.
    function rotationOf(item: Item): var {
        return Array.from(item.transform).find(transform => (transform as Rotation) !== null) ?? null;
    }

    // Starts the turn from the first place to the second with its clock stopped, so each test sets the moment.
    function turnToSecond(options: var) {
        turner.go(first, second, options);
        turner.paused = true;
    }

    function startOf(heft: real): real {
        return (heft - Tokens.heftMin) * Tokens.heftSpread * Tokens.durationStagger;
    }

    function test_a_tile_turns_as_one_part_and_a_layout_box_lets_its_children_turn_one_by_one() {
        turnToSecond();
        const parts = turner.leavingTurns.map(turn => turn.part.item);
        verify(parts.includes(named("title")));
        verify(parts.includes(named("note")));
        for (let i = 0; i < 8; i++)
            verify(parts.includes(named(`tile${i}`)), `tile${i}`);
        compare(parts.length, 10, "the title, the eight tiles and the note, not their column or grid nor what a tile holds");
        verify(!parts.includes(named("away")), "a part out of view stays where it is");
        verify(!parts.includes(named("hidden")));
    }

    function test_a_progress_bar_turns_as_one_part_its_track_and_fill_together() {
        first.visible = false;
        third.visible = true;
        turner.go(third, null);
        turner.paused = true;
        const progress = named("upload");
        const parts = turner.leavingTurns.map(turn => turn.part.item);
        verify(parts.includes(findChild(progress, "bar")));
        verify(!parts.includes(findChild(progress, "fill")));
    }

    function test_a_part_turns_about_the_leading_edge_of_the_box_that_clips_it_wherever_its_place_lies() {
        const clipped = createTemporaryObject(clippedComponent, testCase);
        const clippedTurner = findChild(clipped, "turner");
        clippedTurner.go(findChild(clipped, "place"), null);
        clippedTurner.paused = true;
        // The edge's x and the part's top against the edge's y, from the part's top left, and the reach of its row.
        const expected = [["flush", -20, 0, 20 + Tokens.tileUnit], ["lower", -200, Tokens.tileUnit / 2, 200 + Tokens.tileUnit], ["beside", -480, 0, 480 + Tokens.tileUnit]];
        for (const [name, x, y, reach] of expected) {
            const rotation = rotationOf(findChild(clipped, name));
            compare(rotation.origin.x, x, name);
            compare(rotation.origin.y, y, name);
            fuzzyCompare(rotation.distanceToPlane, Tokens.turnstilePerspective + Tokens.turnstileReach * reach, 1e-9);
        }
        clippedTurner.finish();
    }

    function test_each_part_starts_and_lasts_by_its_heft_leaving_and_arriving() {
        turnToSecond();
        const title = named("title");
        const titleTurn = turnOf(turner.leavingTurns, title);
        const titleHeft = Turnstile.heft(title.width, title.height);
        fuzzyCompare(titleTurn.at, startOf(titleHeft), 1e-9);
        fuzzyCompare(titleTurn.duration, Tokens.durationShort * titleHeft, 1e-9);
        const tile = named("tile0");
        const tileTurn = turnOf(turner.leavingTurns, tile);
        const tileHeft = Turnstile.heft(tile.width, tile.height);
        fuzzyCompare(tileTurn.at, startOf(tileHeft), 1e-9);
        fuzzyCompare(tileTurn.duration, Tokens.durationShort * tileHeft, 1e-9);

        turner.elapsed = turner.handOverAt;
        const summary = named("summary");
        const summaryTurn = turnOf(turner.arrivingTurns, summary);
        const summaryHeft = Turnstile.heft(summary.width, summary.height);
        fuzzyCompare(summaryTurn.at, turner.handOverAt + startOf(summaryHeft), 1e-9);
        fuzzyCompare(summaryTurn.duration, Tokens.durationModerate * summaryHeft, 1e-9);
    }

    function test_tiles_of_one_heft_follow_in_reading_order_half_a_stagger_apart_six_steps_at_most() {
        turnToSecond();
        const tiles = turner.leavingTurns.filter(turn => turn.part.item.objectName.startsWith("tile"));
        compare(tiles.map(turn => turn.part.item.objectName), ["tile0", "tile1", "tile2", "tile3", "tile4", "tile5", "tile6", "tile7"]);
        const tileHeft = Turnstile.heft(tiles[0].part.width, tiles[0].part.height);
        for (let i = 0; i < tiles.length; i++) {
            const byOrder = Math.min(i, Geometry.sameHeftSteps) * Geometry.sameHeftStagger * Tokens.durationStagger;
            fuzzyCompare(tiles[i].at, startOf(tileHeft) + byOrder, 1e-9);
        }
    }

    function test_a_leaving_part_swings_sixty_degrees_toward_the_viewer_whole_for_its_first_forty_percent() {
        turnToSecond();
        const tile = named("tile1");
        const turn = turnOf(turner.leavingTurns, tile);
        const rotation = rotationOf(tile);
        compare(rotation.origin.x, -tile.parent.mapToItem(first, tile.x, tile.y).x, "around the place's leading edge");
        compare(rotation.distanceToPlane, turn.perspective);
        turner.elapsed = turn.at;
        compare(rotation.angle, 0);
        compare(tile.opacity, 1);
        turner.elapsed = turn.at + Tokens.turnOutWhole * turn.duration;
        verify(rotation.angle < 0, "toward the viewer");
        compare(tile.opacity, 1);
        verify(!tile.layer.enabled, "drawn as it is while whole");
        turner.elapsed = turn.at + Tokens.turnOutWhole * turn.duration + 2;
        verify(tile.opacity < 1);
        // cubic-bezier(0.35, 0, 0.65, 0.6) is symmetric in time: halfway it has come 0.35 of its way, gathering speed.
        turner.elapsed = turn.at + turn.duration / 2;
        fuzzyCompare(rotation.angle, -0.35 * Tokens.turnstileOutAngle, 0.05);
        verify(tile.opacity > 0 && tile.opacity < 1);
        verify(tile.layer.enabled, "fading as one");
        // The fade runs the same curve over the rest of the time: halfway through it, it has come 0.35 of its way.
        turner.elapsed = turn.at + (Tokens.turnOutWhole + (1 - Tokens.turnOutWhole) / 2) * turn.duration;
        fuzzyCompare(tile.opacity, 1 - 0.35, 0.02);
        turner.elapsed = turn.at + turn.duration;
        verify(turner.elapsed < turner.handOverAt);
        compare(rotation.angle, -Tokens.turnstileOutAngle);
        compare(tile.opacity, 0);
    }

    function test_an_arriving_part_swings_in_from_seventy_degrees_on_the_other_side_whole_after_its_first_share() {
        turnToSecond();
        turner.elapsed = turner.handOverAt;
        const tile = named("summary");
        const turn = turnOf(turner.arrivingTurns, tile);
        const rotation = rotationOf(tile);
        turner.elapsed = turn.at;
        compare(rotation.angle, Tokens.turnstileInAngle);
        compare(tile.opacity, 0);
        turner.elapsed = turn.at + 0.2 * turn.duration;
        verify(tile.opacity > 0 && tile.opacity < 1);
        verify(tile.layer.enabled, "fading as one");
        // The fade runs the same curve over its share of the time: 0.83 of its way at 0.4325 of it.
        turner.elapsed = turn.at + 0.4325 * Tokens.turnInWhole * turn.duration;
        fuzzyCompare(tile.opacity, 0.83, 0.03);
        // The animation clock counts whole milliseconds.
        turner.elapsed = turn.at + Tokens.turnInWhole * turn.duration - 2;
        verify(tile.opacity < 1);
        turner.elapsed = turn.at + Tokens.turnInWhole * turn.duration + 1;
        compare(tile.opacity, 1);
        verify(!tile.layer.enabled, "drawn as it is once whole");
        // cubic-bezier(0.22, 0.9, 0.6, 0.98) has come 0.83 of its way at 0.4325 of its time: quick at first.
        turner.elapsed = turn.at + 0.4325 * turn.duration;
        fuzzyCompare(rotation.angle, Tokens.turnstileInAngle * (1 - 0.83), 0.2);
        turner.elapsed = turn.at + turn.duration;
        compare(rotationOf(tile), null, "let go as it lands");
        compare(tile.opacity, 1);
    }

    function test_the_next_place_shows_when_the_last_leaving_part_is_three_quarters_through() {
        turnToSecond();
        const handOver = Math.max(...turner.leavingTurns.map(turn => turn.at + Tokens.turnOverlap * turn.duration));
        compare(turner.handOverAt, handOver);
        turner.elapsed = handOver - 1;
        verify(first.visible);
        verify(!second.visible);
        turner.elapsed = handOver;
        verify(!first.visible);
        verify(second.visible);
        const tile = named("tile7");
        compare(rotationOf(tile), null, "the parts of the place gone rest again, out of sight");
        compare(tile.opacity, 1);
        for (const turn of turner.arrivingTurns)
            verify(turn.at >= handOver);
        compare(named("summary").opacity, 0, "the next place's parts wait in their first pose");
    }

    function test_the_tiles_of_a_place_turned_in_arrive_turned_and_do_not_build_in_again() {
        turnToSecond();
        const summary = named("summary");
        turner.elapsed = turner.handOverAt;
        compare(summary.arrival, "turned");
        turner.elapsed = 5000;
        compare(summary.opacity, 1);
        summary.arrival = "arriving";
        compare(summary.opacity, 0, "let go, its opacity is its build-in's again");
    }

    function test_a_place_left_or_gone_back_to_stands_as_it_is_without_building_in() {
        const tile = named("tile0");
        tile.arrival = "arriving";
        turnToSecond();
        compare(tile.arrival, "", "the turn wins over the build-in");
        compare(findChild(tile, "buildIn").progress, 1, "it leaves from its end state");
        turner.elapsed = 5000;
        turner.go(second, first, {
            back: true
        });
        turner.finish();
        compare(tile.arrival, "", "the place comes back as it was left");
    }

    function test_the_pressed_tile_keeps_its_press_and_turns_last_from_its_pressed_pose() {
        const tile = named("tile5");
        mousePress(tile, tile.width * 0.8, tile.height * 0.8);
        mouseRelease(tile, tile.width * 0.8, tile.height * 0.8);
        turnToSecond({
            pressed: tile
        });
        const turn = turnOf(turner.leavingTurns, tile);
        compare(turner.leavingTurns[turner.leavingTurns.length - 1], turn, "it goes last");
        for (const other of turner.leavingTurns)
            verify(other.at <= turn.at);
        const reach = tile.parent.mapToItem(first, tile.x, tile.y).x + tile.width;
        fuzzyCompare(turn.perspective, Tokens.turnstilePerspective + Tokens.turnstileReach * reach, 1e-9);
        verify(tile.pressX > 0 && tile.pressY > 0, "where it was pressed");
        wait(Tokens.durationPress + Tokens.durationShort + 50);
        compare(tile.sink, 1, "still pressed when the press alone would have let go");
        turner.elapsed = turn.at + turn.duration / 2;
        verify(tile.sink > 0 && tile.sink < 1, "the press lets go along the turn");
        verify(rotationOf(tile).angle < 0);
        turner.elapsed = turner.handOverAt;
        verify(!tile.pressed);
    }

    function test_a_tile_opened_without_a_press_sinks_in_its_centre_before_it_turns() {
        first.visible = false;
        second.visible = true;
        const tile = named("summary");
        turner.go(second, third, {
            pressed: tile
        });
        turner.paused = true;
        compare(tile.pressX, 0);
        compare(tile.pressY, 0);
        verify(tile.pressed);
        const turn = turnOf(turner.leavingTurns, tile);
        fuzzyCompare(turn.at, Tokens.durationPress, 10);
        verify(turner.leavingTurns.every(other => other === turn || other.at < turn.at), "once it has sunk, after the others started");
    }

    function test_a_tile_pressed_a_moment_before_waits_only_for_the_rest_of_its_sink() {
        first.visible = false;
        second.visible = true;
        const tile = named("summary");
        mousePress(tile, tile.width / 2, tile.height / 2);
        wait(Tokens.durationPress / 2);
        const since = findChild(tile, "press").since;
        const sunkBefore = Date.now() - since;
        turner.go(second, third, {
            pressed: tile
        });
        const sunkAfter = Date.now() - since;
        turner.paused = true;
        mouseRelease(tile, tile.width / 2, tile.height / 2);
        const turn = turnOf(turner.leavingTurns, tile);
        const lastOther = Math.max(...turner.leavingTurns.filter(other => other !== turn).map(other => other.at));
        verify(turn.at >= Math.max(lastOther, Tokens.durationPress - sunkAfter), `${turn.at} ms`);
        verify(turn.at <= Math.max(lastOther, Tokens.durationPress - sunkBefore), `${turn.at} ms`);
    }

    function test_back_runs_the_other_way_round_each_part_starting_whole_and_at_rest() {
        turnToSecond();
        turner.elapsed = 5000;
        const summary = named("summary");
        turner.go(second, first, {
            back: true,
            pressed: summary
        });
        turner.paused = true;
        for (const turn of turner.leavingTurns) {
            compare(turn.part.item.opacity, 1, turn.part.item.objectName);
            compare(rotationOf(turn.part.item).angle, 0, turn.part.item.objectName);
        }
        verify(!summary.pressed, "going back, no tile opened the place");
        const button = named("rerun");
        const turn = turnOf(turner.leavingTurns, button);
        turner.elapsed = turn.at + turn.duration;
        compare(rotationOf(button).angle, Tokens.turnstileOutAngle, "away from the viewer");
        turner.elapsed = turner.handOverAt;
        const tile = named("tile0");
        turner.elapsed = turnOf(turner.arrivingTurns, tile).at;
        compare(rotationOf(tile).angle, -Tokens.turnstileInAngle);
    }

    function test_a_turn_runs_on_its_own_clock_and_lands() {
        turner.go(first, second);
        verify(turner.running);
        tryCompare(landedSpy, "count", 1, 3000);
        verify(!turner.running);
        verify(!first.visible);
        verify(second.visible);
        compare(rotationOf(named("summary")), null);
    }

    function test_a_frame_that_comes_late_still_lets_every_part_go() {
        turnToSecond();
        turner.elapsed = 5000;
        verify(!turner.running);
        compare(landedSpy.count, 1);
        verify(second.visible);
        compare(rotationOf(named("summary")), null);
        compare(named("summary").opacity, 1);
    }

    function test_a_navigation_during_the_turn_finishes_it_and_goes_to_the_new_target() {
        turnToSecond();
        turner.elapsed = turner.handOverAt / 2;
        const tile = named("tile0");
        verify(rotationOf(tile) !== null);
        turner.go(second, third);
        turner.paused = true;
        compare(landedSpy.count, 1, "the first turn ended");
        verify(!first.visible);
        compare(rotationOf(tile), null);
        compare(tile.opacity, 1);
        verify(second.visible);
        verify(turnOf(turner.leavingTurns, named("rerun")), "the place it went to leaves now");
        turner.finish();
        verify(!turner.running);
        verify(!second.visible);
        verify(third.visible);
        compare(rotationOf(named("rerun")), null);
        compare(rotationOf(named("logs")), null);
    }

    function test_a_part_lands_on_the_pixels_it_rests_on() {
        first.visible = false;
        second.visible = true;
        waitForRendering(scene);
        const atRest = grabImage(scene);
        second.visible = false;
        first.visible = true;
        turnToSecond();
        turner.elapsed = turner.handOverAt;
        const end = Math.max(...turner.arrivingTurns.map(turn => turn.at + turn.duration));
        turner.elapsed = end - 1000 / 60;
        const lastFrame = grabImage(scene);
        turner.elapsed = end;
        verify(!turner.running, "every part let go as it landed");
        const landed = grabImage(scene);
        wait(100);
        const later = grabImage(scene);
        verify(!lastFrame.equals(landed), "the frame before still moves");
        verify(landed.equals(later), "nothing shifts, sharpens or settles after it lands");
        verify(landed.equals(atRest), "it lands on the pixels it rests on");
    }

    function test_under_reduced_motion_the_next_place_stands_at_once() {
        Prefs.motion = "off";
        const tile = named("tile0");
        turner.go(first, second, {
            pressed: tile
        });
        verify(!turner.running);
        verify(!first.visible);
        verify(second.visible);
        compare(landedSpy.count, 1);
        verify(!tile.pressed);
        compare(rotationOf(named("summary")), null);
        compare(named("summary").opacity, 1);
    }

    // How much wider a part's top edge shows than its bottom edge: above 0 when its top leans toward the viewer.
    function topLean(item: Item): real {
        const width = (left, right) => right.x - left.x;
        const top = width(item.mapToItem(scene, 0, 0), item.mapToItem(scene, item.width, 0));
        const bottom = width(item.mapToItem(scene, 0, item.height), item.mapToItem(scene, item.width, item.height));
        return top - bottom;
    }

    function test_about_the_bottom_edge_each_part_turns_on_the_bottom_line_of_the_box_that_clips_it_wherever_its_place_lies() {
        const clipped = createTemporaryObject(clippedComponent, testCase);
        const clippedTurner = findChild(clipped, "turner");
        clippedTurner.go(findChild(clipped, "place"), null, {
            edge: "bottom"
        });
        clippedTurner.paused = true;
        // The box's bottom against the part's top, from the part's top left, which is also the reach of its row. The
        // clipping box ends at 80 + 250 on the screen, the place at 30 + 450.
        const expected = [["flush", 330 - 80], ["lower", 330 - 120], ["beside", 480 - 30]];
        for (const [name, reach] of expected) {
            const rotation = rotationOf(findChild(clipped, name));
            compare(rotation.axis, Qt.vector3d(1, 0, 0), name);
            compare(rotation.origin.x, Tokens.tileUnit / 2, name);
            compare(rotation.origin.y, reach, name);
            fuzzyCompare(rotation.distanceToPlane, Tokens.turnstilePerspective + Tokens.turnstileReach * reach, 1e-9);
        }
        clippedTurner.finish();
    }

    function test_about_the_bottom_edge_a_part_leaving_forward_tips_its_top_toward_the_viewer_and_an_arriving_one_rises_with_its_top_from_behind() {
        turnToSecond({
            edge: "bottom"
        });
        const tile = named("tile1");
        const leaving = turnOf(turner.leavingTurns, tile);
        turner.elapsed = leaving.at + leaving.duration / 2;
        verify(rotationOf(tile).angle < 0);
        verify(topLean(tile) > 1, `${topLean(tile)}`);
        turner.elapsed = turner.handOverAt;
        const summary = named("summary");
        const arriving = turnOf(turner.arrivingTurns, summary);
        turner.elapsed = arriving.at + arriving.duration / 4;
        verify(rotationOf(summary).angle > 0);
        verify(topLean(summary) < -1, `${topLean(summary)}`);
    }

    function test_about_the_bottom_edge_a_part_going_back_tips_its_top_away_from_the_viewer() {
        turnToSecond();
        turner.elapsed = 5000;
        turner.go(second, first, {
            back: true,
            edge: "bottom"
        });
        turner.paused = true;
        const tile = named("summary");
        const turn = turnOf(turner.leavingTurns, tile);
        turner.elapsed = turn.at + Tokens.turnOutWhole * turn.duration;
        compare(rotationOf(tile).axis, Qt.vector3d(1, 0, 0));
        verify(topLean(tile) < -1, `${topLean(tile)}`);
    }

    function test_about_the_bottom_edge_the_pressed_tile_turns_last_from_its_pressed_pose() {
        const tile = named("tile5");
        mousePress(tile, tile.width * 0.8, tile.height * 0.8);
        mouseRelease(tile, tile.width * 0.8, tile.height * 0.8);
        turnToSecond({
            pressed: tile,
            edge: "bottom"
        });
        const turn = turnOf(turner.leavingTurns, tile);
        compare(turner.leavingTurns[turner.leavingTurns.length - 1], turn, "it goes last");
        compare(turn.axis, Qt.vector3d(1, 0, 0));
        compare(turn.originY, scene.height - tile.parent.mapToItem(first, tile.x, tile.y).y);
        turner.elapsed = turn.at + turn.duration / 2;
        verify(tile.sink > 0 && tile.sink < 1, "the press lets go along the turn");
        verify(topLean(tile) > 1, `${topLean(tile)}`);
    }

    function test_a_turn_that_keeps_its_landed_parts_can_be_set_back_from_its_end_and_the_next_turn_lets_them_go() {
        turner.go(null, second, {
            edge: "bottom"
        });
        turner.paused = true;
        turner.keepsLanded = true;
        const turns = turner.arrivingTurns;
        const end = Math.max(...turns.map(turn => turn.at + turn.duration));
        turner.elapsed = end;
        compare(turner.turning.length, turns.length, "landed, every part is still held");
        compare(landedSpy.count, 0);
        const first = turns[0];
        turner.elapsed = first.at + first.duration / 2;
        const angle = rotationOf(first.part.item).angle;
        verify(angle > 0 && angle < Tokens.turnstileInAngle, `${angle}`);
        turner.go(second, null);
        landedSpy.clear();
        verify(!turner.keepsLanded, "a new turn keeps nothing unless told");
        turner.elapsed = turner.handOverAt;
        compare(landedSpy.count, 1, "with nothing to arrive at it lands at the hand-over");
    }

    function test_a_paused_turn_shows_whatever_moment_its_elapsed_time_names_earlier_ones_too() {
        turnToSecond({
            edge: "bottom"
        });
        const tile = named("tile0");
        const turn = turnOf(turner.leavingTurns, tile);
        turner.elapsed = turn.at + turn.duration * 0.6;
        const later = rotationOf(tile).angle;
        turner.elapsed = turn.at + turn.duration * 0.3;
        verify(rotationOf(tile).angle > later, "back to a smaller swing");
        turner.elapsed = 0;
        compare(rotationOf(tile).angle, 0);
        compare(tile.opacity, 1);
        verify(first.visible);
    }

    function test_under_reduced_motion_a_turn_about_the_bottom_edge_stands_at_once() {
        Prefs.motion = "off";
        turner.go(first, second, {
            edge: "bottom"
        });
        verify(!turner.running);
        verify(!first.visible);
        verify(second.visible);
        compare(landedSpy.count, 1);
        compare(rotationOf(named("summary")), null);
        compare(named("summary").opacity, 1);
    }

    // Starts the turn of one frame's own scene, its clock stopped.
    function startFrameTurn(frame: Item): var {
        const frameTurner = findChild(frame, "turner");
        frameTurner.go(findChild(frame, "first"), findChild(frame, "second"), {
            pressed: findChild(frame, "tile5")
        });
        frameTurner.paused = true;
        return frameTurner;
    }

    function test_contact_sheet_of_a_turn_in_both_themes() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        scene.visible = false;
        const labels = ["a tile pressed", "leaving, halfway", "leaving, the pressed tile last", "arriving, a quarter in", "arriving, halfway", "landed"];
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const sheet = createTemporaryObject(sheetComponent, testCase);
            const shots = labels.map(label => createTemporaryObject(frameComponent, sheet.frames, {
                    label: label
                }));
            waitForRendering(sheet);
            const turners = shots.map(shot => startFrameTurn(shot));
            wait(Tokens.durationPress + 20);
            const handOver = turners[0].handOverAt;
            turners[1].elapsed = handOver / 2;
            turners[2].elapsed = handOver * 0.85;
            for (const frameTurner of turners.slice(3))
                frameTurner.elapsed = handOver;
            const end = Math.max(...turners[3].arrivingTurns.map(turn => turn.at + turn.duration));
            turners[3].elapsed = handOver + (end - handOver) / 4;
            turners[4].elapsed = handOver + (end - handOver) / 2;
            turners[5].elapsed = end;
            grabImage(sheet).save(`placeturn-sheet-${theme}.png`);
            verify(!turners[5].running, theme);
            for (const frameTurner of turners)
                frameTurner.finish();
            sheet.destroy();
        }
    }
}
