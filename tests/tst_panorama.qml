pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "Panorama"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1400
    height: 1000

    readonly property real sectionWidth: 3 * Tokens.tileUnit + 2 * Tokens.spaceS + 2 * Tokens.spaceXl
    readonly property list<string> titles: ["running", "pinned", "today", "recent", "all"]

    // A section whose content is `tall` high, so it scrolls within itself when that is more than the panorama's box.
    Component {
        id: sectionComponent

        Section {
            id: section

            property real tall: 1200

            Item {
                width: parent.width
                height: section.tall
            }
        }
    }

    Component {
        id: panoramaComponent

        Panorama {
            width: 1400
            height: 500
            viewportHeight: 800
        }
    }

    Component {
        id: stripAndPanoramaComponent

        Item {
            property alias strip: strip
            property alias panorama: panorama

            width: 1400
            height: 600

            Pivot {
                id: strip

                width: parent.width
                placeWidth: 1400
                viewportHeight: 800
                level: "nav"
                titles: testCase.titles
            }
            Panorama {
                id: panorama

                y: strip.height
                width: 1400
                height: 500
                placeWidth: 1400
                viewportHeight: 800
                sectionStrip: strip
            }
        }
    }

    Component {
        id: wideComponent

        Item {
            property alias strip: strip
            property alias facets: facets
            property alias inner: inner

            width: 1400
            height: 700

            Pivot {
                id: strip

                width: parent.width
                placeWidth: 1400
                viewportHeight: 800
                level: "facet"
                titles: ["one", "two", "three", "four"]
            }
            Facets {
                id: facets

                y: strip.height
                width: parent.width
                height: 500
                facetStrip: strip

                Rectangle {
                    objectName: "facet0"
                    anchors.fill: parent
                    color: Tokens.color.surface
                }
                Rectangle {
                    objectName: "facet1"
                    anchors.fill: parent
                    color: Tokens.color.surface
                }
                Item {
                    objectName: "facet2"
                    anchors.fill: parent

                    Item {
                        id: inner

                        objectName: "inner2"
                        activeFocusOnTab: true
                        width: 20
                        height: 20
                    }
                }
                Rectangle {
                    objectName: "facet3"
                    anchors.fill: parent
                    color: Tokens.color.surface
                }
            }
        }
    }

    Component {
        id: sheetComponent

        Rectangle {
            property bool overflowing: false

            width: 1400
            height: 2 * 440 + 3 * Tokens.spaceL
            color: Tokens.color.bg

            Column {
                x: 0
                y: Tokens.spaceL
                spacing: Tokens.spaceL

                Repeater {
                    model: [2, 5]

                    delegate: Item {
                        id: block

                        required property int modelData

                        width: 1400
                        height: 440

                        Pivot {
                            id: strip

                            x: Tokens.spaceXl
                            width: parent.width - 2 * Tokens.spaceXl
                            placeWidth: 1400
                            viewportHeight: 800
                            level: "nav"
                            titles: testCase.titles.slice(0, block.modelData)
                        }
                        Panorama {
                            id: panorama

                            objectName: `panorama-${block.modelData}`
                            y: strip.height
                            width: parent.width
                            height: 380
                            placeWidth: 1400
                            viewportHeight: 800
                            sectionStrip: strip

                            Component.onCompleted: {
                                if (block.modelData > 2)
                                    goTo(2, false, true);
                            }

                            Section {
                                title: "running"

                                TileGrid {
                                    columns: 3
                                    Tile {
                                        status: "success"
                                        columns: 2
                                    }
                                    Tile {}
                                    Tile {
                                        status: "warning"
                                    }
                                    Tile {
                                        opens: true
                                    }
                                }
                            }
                            Section {
                                title: "pinned"

                                TileGrid {
                                    columns: 3
                                    Tile {
                                        opens: true
                                    }
                                    Tile {
                                        status: "info"
                                    }
                                    Tile {
                                        status: "error"
                                    }
                                }
                            }
                            Section {
                                title: "today"
                                visible: block.modelData > 2

                                TileGrid {
                                    columns: 3
                                    Tile {
                                        rows: 2
                                    }
                                    Tile {}
                                    Tile {
                                        status: "info"
                                    }
                                }
                            }
                            Section {
                                title: "recent"
                                visible: block.modelData > 2

                                Body {
                                    width: parent.width
                                    text: "Sections are sized in tile units: a wider window shows more of them, never wider ones."
                                }
                            }
                            Section {
                                title: "all"
                                visible: block.modelData > 2

                                Body {
                                    width: parent.width
                                    text: "The last section can reach the left edge."
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    // A wheel event as Qt hands it over: pixel deltas point against the web's, the pointer at x, y.
    function wheelEvent(dy, props) {
        return Object.assign({
            x: 300,
            y: 200,
            angleDelta: Qt.point(0, 0),
            pixelDelta: Qt.point(0, -dy),
            modifiers: 0
        }, props);
    }

    function makePanorama(count, tall) {
        const panorama = createTemporaryObject(panoramaComponent, testCase);
        for (let k = 0; k < count; k++)
            sectionComponent.createObject(panorama.sectionParent, {
                title: `section ${k}`,
                tall: tall ?? 1200
            });
        return panorama;
    }

    // The sections' content comes in a Column, which lays out on the next frame.
    function settled(panorama) {
        const first = panorama.sectionParent.children[0];
        tryVerify(() => first.contentHeight > 2 * Tokens.spaceL + 10);
        waitForRendering(panorama);
    }

    function sectionAt(panorama, k) {
        return panorama.sectionParent.children[k];
    }

    // The latch's questions, answered from a script, for the rules on their own.
    function hostOf(inner, panRoom) {
        return {
            innerAt: () => inner,
            room: () => inner !== null && inner.room,
            panRoom: () => panRoom
        };
    }

    function test_sections_are_as_wide_as_three_tiles_with_their_gaps_and_a_wider_window_shows_more_of_them() {
        const panorama = makePanorama(5);
        compare(sectionAt(panorama, 0).width, sectionWidth);
        compare(sectionWidth, 622);
        compare(sectionAt(panorama, 0).x, Tokens.spaceXl);
        compare(sectionAt(panorama, 1).x, Tokens.spaceXl + sectionWidth + Tokens.spaceXl);
        panorama.width = 2200;
        compare(sectionAt(panorama, 0).width, sectionWidth);
        verify(sectionAt(panorama, 2).x + sectionWidth + Tokens.spaceXl <= 2200, "a third section is now in sight");
    }

    function test_a_section_can_ask_for_a_width_of_its_own() {
        const panorama = makePanorama(2);
        sectionAt(panorama, 0).sectionWidth = 900;
        compare(sectionAt(panorama, 0).width, 900);
        compare(sectionAt(panorama, 1).x, Tokens.spaceXl + 900 + Tokens.spaceXl);
        compare(sectionAt(panorama, 1).width, sectionWidth);
    }

    function test_a_section_is_as_high_as_the_panorama_and_scrolls_within_itself() {
        const panorama = makePanorama(2);
        settled(panorama);
        compare(sectionAt(panorama, 0).height, 500);
        verify(sectionAt(panorama, 0).contentHeight > 500);
        compare(panorama.scroller.contentHeight, 500, "the panorama is never taller than its box");
    }

    function test_when_every_section_fits_nothing_scrolls_and_a_jump_stays_at_the_start() {
        Prefs.motion = "off";
        const panorama = makePanorama(2, 100);
        verify(panorama.fit);
        compare(panorama.scroller.contentWidth, panorama.width, "no spacer behind the last section");
        verify(!panorama.scroller.interactive);
        verify(!panorama.handleWheel(wheelEvent(300), 0), "the wheel is not taken");
        panorama.goTo(1, false, false);
        compare(panorama.currentIndex, 1);
        compare(panorama.scroller.contentX, 0);
    }

    function test_a_jump_aligns_a_section_flush_left_or_as_far_as_the_panorama_scrolls() {
        Prefs.motion = "off";
        const panorama = makePanorama(5);
        verify(!panorama.fit);
        panorama.goTo(2, false, false);
        compare(panorama.scroller.contentX, sectionAt(panorama, 2).x - Tokens.spaceXl);
        panorama.goTo(4, false, false);
        compare(panorama.scroller.contentX, panorama.scroller.contentWidth - panorama.width, "the last reaches the left edge");
        compare(sectionAt(panorama, 4).x - panorama.scroller.contentX, Tokens.spaceXl);
        panorama.goTo(0, false, false);
        compare(panorama.scroller.contentX, 0);
    }

    function test_the_end_spacer_lets_the_last_section_reach_the_left_edge_and_no_further() {
        const panorama = makePanorama(3);
        const spacer = Math.max(0, 1400 - 2 * Tokens.spaceXl - sectionWidth - Tokens.spaceXl);
        const reach = Tokens.spaceXl + 3 * sectionWidth + 2 * Tokens.spaceXl;
        compare(panorama.scroller.contentWidth, reach + Tokens.spaceXl + spacer + Tokens.spaceXl);
    }

    // The wheel latch, rules 1 to 6 (layout.md:42–66; rekta.js:872–900).

    function test_events_closer_than_the_latch_are_one_gesture_however_long_it_lasts() {
        const down = {
            ctrl: false,
            shift: false,
            dx: 0,
            dy: 40
        };
        const host = hostOf(null, true);
        let routed = WheelLatch.route(null, down, 1000, Tokens.durationWheelLatch, host);
        verify(routed.fresh);
        const first = routed.gesture;
        for (const at of [1150, 1300, 1450]) {
            routed = WheelLatch.route(routed.gesture, down, at, Tokens.durationWheelLatch, host);
            verify(!routed.fresh, `at ${at}`);
        }
        compare(first.target, "pan");
        routed = WheelLatch.route(routed.gesture, down, 1450 + Tokens.durationWheelLatch, Tokens.durationWheelLatch, host);
        verify(!routed.fresh, "exactly the latch apart is still the same gesture");
        routed = WheelLatch.route(routed.gesture, down, 1450 + 2 * Tokens.durationWheelLatch + 1, Tokens.durationWheelLatch, host);
        verify(routed.fresh, "more than the latch apart starts another");
        compare(Tokens.durationWheelLatch, 200);
    }

    function test_rule_1_a_gesture_that_starts_on_a_scroller_with_room_belongs_to_it() {
        const inner = {
            room: true
        };
        const down = {
            ctrl: false,
            shift: false,
            dx: 0,
            dy: 40
        };
        let routed = WheelLatch.route(null, down, 0, 200, hostOf(inner, true));
        compare(routed.action, "inner");
        compare(routed.gesture.inner, inner);
        inner.room = false;
        routed = WheelLatch.route(routed.gesture, down, 100, 200, hostOf(inner, true));
        compare(routed.action, "swallow", "at its end the rest of the gesture is swallowed, never sideways");
        routed = WheelLatch.route(routed.gesture, down, 250, 200, hostOf(inner, true));
        compare(routed.action, "swallow", "the gesture is still alive 150 ms later");
        routed = WheelLatch.route(routed.gesture, down, 700, 200, hostOf(null, true));
        compare(routed.action, "pan", "the next gesture finds no room inside and moves the panorama");
    }

    function test_rule_2_a_gesture_that_starts_on_the_panorama_keeps_moving_it_over_scrollable_sections() {
        const down = {
            ctrl: false,
            shift: false,
            dx: 0,
            dy: 40
        };
        let routed = WheelLatch.route(null, down, 0, 200, hostOf(null, true));
        compare(routed.action, "pan");
        routed = WheelLatch.route(routed.gesture, down, 100, 200, hostOf({
            room: true
        }, true));
        compare(routed.action, "pan", "a section that could scroll passes under the pointer");
        routed = WheelLatch.route(routed.gesture, down, 400, 200, hostOf({
            room: true
        }, true));
        compare(routed.action, "inner", "inner scroll gets the next gesture");
    }

    function test_rule_3_horizontal_input_and_shift_wheel_stay_native() {
        const host = hostOf({
            room: true
        }, true);
        compare(WheelLatch.route(null, {
            ctrl: false,
            shift: false,
            dx: 40,
            dy: 5
        }, 0, 200, host).action, "pass");
        compare(WheelLatch.route(null, {
            ctrl: false,
            shift: false,
            dx: 40,
            dy: 40
        }, 0, 200, host).action, "pass", "equal is horizontal");
        compare(WheelLatch.route(null, {
            ctrl: false,
            shift: true,
            dx: 0,
            dy: 40
        }, 0, 200, host).action, "pass");
        const gesture = WheelLatch.route(null, {
            ctrl: false,
            shift: false,
            dx: 40,
            dy: 5
        }, 0, 200, host).gesture;
        compare(gesture.target, "native");
        compare(WheelLatch.route(gesture, {
            ctrl: false,
            shift: false,
            dx: 0,
            dy: 40
        }, 100, 200, host).action, "pass", "a native gesture stays native");
    }

    function test_rule_3_a_horizontal_event_inside_a_gesture_is_native_without_ending_it() {
        const down = {
            ctrl: false,
            shift: false,
            dx: 0,
            dy: 40
        };
        let routed = WheelLatch.route(null, down, 0, 200, hostOf(null, true));
        routed = WheelLatch.route(routed.gesture, {
            ctrl: false,
            shift: false,
            dx: 40,
            dy: 0
        }, 100, 200, hostOf(null, true));
        compare(routed.action, "pass");
        routed = WheelLatch.route(routed.gesture, down, 200, 200, hostOf(null, true));
        compare(routed.action, "pan");
        verify(!routed.fresh);
    }

    function test_rule_4_at_either_end_the_wheel_falls_through() {
        const down = {
            ctrl: false,
            shift: false,
            dx: 0,
            dy: 40
        };
        const up = {
            ctrl: false,
            shift: false,
            dx: 0,
            dy: -40
        };
        compare(WheelLatch.route(null, down, 0, 200, hostOf(null, false)).action, "pass");
        compare(WheelLatch.route(null, up, 0, 200, hostOf(null, false)).action, "pass");
    }

    function test_rule_5_ctrl_wheel_zooms_and_does_not_touch_the_gesture() {
        const routed = WheelLatch.route(null, {
            ctrl: true,
            shift: false,
            dx: 0,
            dy: 40
        }, 0, 200, hostOf(null, true));
        compare(routed.action, "pass");
        compare(routed.gesture, null);
        verify(!routed.fresh);
    }

    function test_a_plain_vertical_wheel_moves_the_panorama_sideways_by_what_it_turned() {
        const panorama = makePanorama(5, 100);
        verify(panorama.handleWheel(wheelEvent(120), 0));
        compare(panorama.scroller.contentX, 120);
        verify(panorama.handleWheel(wheelEvent(-50), 50));
        compare(panorama.scroller.contentX, 70);
    }

    function test_a_wheel_notch_is_the_platforms_lines_of_sixteen_pixels() {
        const panorama = makePanorama(5, 100);
        const lines = Application.styleHints.wheelScrollLines;
        verify(panorama.handleWheel(wheelEvent(0, {
            angleDelta: Qt.point(0, -120)
        }), 0));
        compare(panorama.scroller.contentX, lines * Geometry.wheelLinePixels);
    }

    function test_the_wheel_through_the_window_moves_the_panorama() {
        const panorama = makePanorama(5, 100);
        waitForRendering(panorama);
        mouseWheel(panorama, 300, 200, 0, -120);
        tryVerify(() => panorama.scroller.contentX > 0);
    }

    function test_rule_1_in_the_panorama_a_section_with_room_scrolls_and_the_panorama_stays() {
        const panorama = makePanorama(5);
        settled(panorama);
        const section = sectionAt(panorama, 0);
        panorama.handleWheel(wheelEvent(100, {
            x: 100
        }), 0);
        compare(section.contentY, 100);
        compare(panorama.scroller.contentX, 0);
    }

    function test_rule_1_at_the_end_of_a_section_the_rest_of_the_gesture_is_swallowed() {
        const panorama = makePanorama(5);
        settled(panorama);
        const section = sectionAt(panorama, 0);
        const most = section.contentHeight - section.height;
        section.contentY = most - 30;
        verify(panorama.handleWheel(wheelEvent(20, {
            x: 100
        }), 0));
        verify(panorama.handleWheel(wheelEvent(100, {
            x: 100
        }), 100), "taken by the section");
        compare(section.contentY, most);
        verify(panorama.handleWheel(wheelEvent(100, {
            x: 100
        }), 150), "swallowed at its end");
        compare(panorama.scroller.contentX, 0, "it never turns into a sideways move");
        verify(panorama.handleWheel(wheelEvent(100, {
            x: 100
        }), 150 + Tokens.durationWheelLatch + 1));
        compare(panorama.scroller.contentX, 100, "the next gesture finds no room inside: the panorama moves");
    }

    function test_rule_2_a_gesture_on_a_section_without_room_keeps_moving_the_panorama_over_the_next_one() {
        const panorama = makePanorama(5);
        settled(panorama);
        const first = sectionAt(panorama, 0);
        first.contentY = first.contentHeight - first.height;
        panorama.handleWheel(wheelEvent(50, {
            x: 100
        }), 0);
        compare(panorama.scroller.contentX, 50);
        const second = sectionAt(panorama, 1);
        const over = second.x - panorama.scroller.contentX + 100;
        panorama.handleWheel(wheelEvent(50, {
            x: over
        }), 100);
        compare(second.contentY, 0, "the section under the pointer is not scrolled");
        compare(panorama.scroller.contentX, 100);
        panorama.handleWheel(wheelEvent(50, {
            x: over
        }), 400);
        compare(second.contentY, 50, "the next gesture belongs to it");
    }

    function test_rule_3_horizontal_wheel_and_shift_wheel_are_not_latched() {
        const panorama = makePanorama(5);
        settled(panorama);
        verify(!panorama.handleWheel(wheelEvent(0, {
            pixelDelta: Qt.point(-40, 0)
        }), 0), "left to the items below");
        compare(panorama.scroller.contentX, 0);
        verify(panorama.handleWheel(wheelEvent(60, {
            modifiers: Qt.ShiftModifier,
            x: 100
        }), 1000));
        compare(panorama.scroller.contentX, 60, "Shift+wheel scrolls sideways, as a browser does");
        compare(sectionAt(panorama, 0).contentY, 0);
    }

    function test_rule_4_the_wheel_falls_through_at_both_ends_of_the_panorama() {
        const panorama = makePanorama(5, 100);
        verify(!panorama.handleWheel(wheelEvent(-100), 0), "up at the start");
        panorama.scroller.contentX = panorama.scroller.contentWidth - panorama.width;
        verify(!panorama.handleWheel(wheelEvent(100), 1000), "down at the end");
    }

    function test_rule_5_ctrl_wheel_is_left_to_zoom() {
        const panorama = makePanorama(5, 100);
        verify(!panorama.handleWheel(wheelEvent(100, {
            modifiers: Qt.ControlModifier
        }), 0));
        compare(panorama.scroller.contentX, 0);
    }

    function test_rule_6_compact_never_redirects() {
        const panorama = makePanorama(5, 100);
        panorama.width = 600;
        verify(!panorama.sideways);
        verify(!panorama.handleWheel(wheelEvent(100), 0));
        compare(panorama.scroller.contentX, 0);
    }

    function test_compact_stacks_the_sections_and_scrolls_vertically() {
        const panorama = makePanorama(3, 100);
        panorama.width = 600;
        settled(panorama);
        const first = sectionAt(panorama, 0);
        const second = sectionAt(panorama, 1);
        compare(first.x, Tokens.spaceM);
        compare(first.width, 600 - 2 * Tokens.spaceM);
        compare(first.y, 0);
        compare(second.y, first.height);
        verify(!first.interactive, "a stacked section does not scroll within itself");
        verify(panorama.scroller.contentHeight > panorama.height);
        compare(panorama.scroller.contentWidth, 600);
    }

    // Keys (navigation.md:292–294).

    function test_arrow_and_page_keys_jump_to_the_previous_and_next_section_flush_left() {
        Prefs.motion = "off";
        const panorama = makePanorama(5);
        panorama.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(panorama.currentIndex, 1);
        compare(panorama.scroller.contentX, sectionAt(panorama, 1).x - Tokens.spaceXl);
        keyClick(Qt.Key_PageDown);
        compare(panorama.currentIndex, 2);
        keyClick(Qt.Key_Left);
        compare(panorama.currentIndex, 1);
        keyClick(Qt.Key_PageUp);
        compare(panorama.currentIndex, 0);
        keyClick(Qt.Key_Left);
        compare(panorama.currentIndex, 0, "no wrap at the start");
    }

    function test_home_and_end_jump_to_the_first_and_the_last_section() {
        Prefs.motion = "off";
        const panorama = makePanorama(5);
        panorama.forceActiveFocus();
        keyClick(Qt.Key_End);
        compare(panorama.currentIndex, 4);
        compare(panorama.scroller.contentX, panorama.scroller.contentWidth - panorama.width);
        keyClick(Qt.Key_Right);
        compare(panorama.currentIndex, 4, "no wrap at the end");
        keyClick(Qt.Key_Home);
        compare(panorama.currentIndex, 0);
        compare(panorama.scroller.contentX, 0);
    }

    function test_keys_with_alt_ctrl_or_meta_are_not_the_panoramas() {
        Prefs.motion = "off";
        const panorama = makePanorama(5);
        panorama.forceActiveFocus();
        for (const modifier of [Qt.AltModifier, Qt.ControlModifier, Qt.MetaModifier]) {
            keyClick(Qt.Key_Right, modifier);
            compare(panorama.currentIndex, 0);
        }
    }

    function test_keys_act_only_when_the_panorama_itself_has_the_focus() {
        Prefs.motion = "off";
        const panorama = makePanorama(5);
        sectionAt(panorama, 0).focusHeading();
        verify(sectionAt(panorama, 0).headingFocused);
        keyClick(Qt.Key_Right);
        compare(panorama.currentIndex, 0);
    }

    function test_a_panorama_that_fits_steps_through_its_sections_without_scrolling() {
        Prefs.motion = "off";
        const panorama = makePanorama(2);
        panorama.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(panorama.currentIndex, 1);
        compare(panorama.scroller.contentX, 0);
    }

    function test_in_the_strip_enter_aligns_the_section_and_gives_its_heading_the_focus() {
        Prefs.motion = "off";
        const place = createTemporaryObject(stripAndPanoramaComponent, testCase);
        for (let k = 0; k < 5; k++)
            sectionComponent.createObject(place.panorama.sectionParent, {
                title: `section ${k}`
            });
        place.strip.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(place.panorama.currentIndex, 1);
        compare(place.panorama.scroller.contentX, place.panorama.startOf(1), "an arrow only aligns");
        verify(!sectionAt(place.panorama, 1).headingFocused, "and leaves the focus on the strip");
        keyClick(Qt.Key_Return);
        verify(sectionAt(place.panorama, 1).headingFocused, "Enter moves the focus to the heading");
    }

    function test_enter_on_the_title_of_the_section_in_sight_still_moves_the_focus_to_its_heading() {
        Prefs.motion = "off";
        const place = createTemporaryObject(stripAndPanoramaComponent, testCase);
        for (let k = 0; k < 5; k++)
            sectionComponent.createObject(place.panorama.sectionParent, {
                title: `section ${k}`
            });
        place.strip.forceActiveFocus();
        keyClick(Qt.Key_Enter);
        verify(sectionAt(place.panorama, 0).headingFocused);
    }

    // The strip follows the scroll, and a press on it scrolls there (navigation.md:56–62; motion.md "Panorama scroll").

    function test_the_strip_follows_a_section_scrolled_into_view_by_wheel() {
        const place = createTemporaryObject(stripAndPanoramaComponent, testCase);
        for (let k = 0; k < 5; k++)
            sectionComponent.createObject(place.panorama.sectionParent, {
                title: `section ${k}`,
                tall: 100
            });
        compare(place.strip.currentIndex, 0);
        place.panorama.handleWheel(wheelEvent(700), 0);
        compare(place.panorama.currentIndex, 1, "the section within a third of the edge");
        compare(place.strip.currentIndex, 1);
        place.panorama.handleWheel(wheelEvent(700), 1000);
        compare(place.strip.currentIndex, 2);
        place.panorama.handleWheel(wheelEvent(5000), 2000);
        compare(place.strip.currentIndex, 4, "at the end the last one");
        place.panorama.handleWheel(wheelEvent(-5000), 3000);
        compare(place.strip.currentIndex, 0);
    }

    function test_the_strip_follows_a_section_scrolled_into_view_by_touch() {
        const place = createTemporaryObject(stripAndPanoramaComponent, testCase);
        for (let k = 0; k < 5; k++)
            sectionComponent.createObject(place.panorama.sectionParent, {
                title: `section ${k}`,
                tall: 100
            });
        place.panorama.scroller.contentX = sectionAt(place.panorama, 3).x - Tokens.spaceXl - 100;
        compare(place.strip.currentIndex, 3);
    }

    function test_a_press_on_the_strip_scrolls_there_in_the_glide_time_and_the_title_stays_chosen() {
        Prefs.motion = "on";
        const place = createTemporaryObject(stripAndPanoramaComponent, testCase);
        for (let k = 0; k < 5; k++)
            sectionComponent.createObject(place.panorama.sectionParent, {
                title: `section ${k}`,
                tall: 100
            });
        waitForRendering(place);
        place.strip.select(3);
        compare(place.strip.currentIndex, 3);
        verify(place.panorama.gliding);
        wait(Tokens.durationPivotGlide / 2);
        verify(place.panorama.scroller.contentX > 0 && place.panorama.scroller.contentX < place.panorama.startOf(3), "still on its way");
        compare(place.strip.currentIndex, 3, "sections that pass by do not take the mark");
        tryCompare(place.panorama.scroller, "contentX", place.panorama.startOf(3), 2 * Tokens.durationPivotGlide);
        compare(place.strip.currentIndex, 3);
    }

    function test_a_section_that_cannot_scroll_flush_left_stays_the_one_chosen_after_a_press() {
        Prefs.motion = "off";
        const place = createTemporaryObject(stripAndPanoramaComponent, testCase);
        for (let k = 0; k < 5; k++)
            sectionComponent.createObject(place.panorama.sectionParent, {
                title: `section ${k}`,
                tall: 100
            });
        place.strip.select(1);
        place.strip.select(4);
        compare(place.panorama.scroller.contentX, place.panorama.scroller.contentWidth - place.panorama.width);
        compare(place.strip.currentIndex, 4);
    }

    function test_a_wheel_after_a_jump_lets_the_strip_follow_again() {
        Prefs.motion = "off";
        const place = createTemporaryObject(stripAndPanoramaComponent, testCase);
        for (let k = 0; k < 5; k++)
            sectionComponent.createObject(place.panorama.sectionParent, {
                title: `section ${k}`,
                tall: 100
            });
        place.strip.select(2);
        place.panorama.handleWheel(wheelEvent(-670), 0);
        compare(place.strip.currentIndex, 1);
    }

    function test_a_size_class_change_keeps_the_section_being_read() {
        Prefs.motion = "off";
        const panorama = makePanorama(5);
        settled(panorama);
        panorama.goTo(2, false, false);
        panorama.width = 600;
        compare(panorama.currentIndex, 2);
        fuzzyCompare(panorama.scroller.contentY, panorama.startOf(2), 1);
        panorama.width = 1400;
        compare(panorama.currentIndex, 2);
        compare(panorama.scroller.contentX, sectionAt(panorama, 2).x - Tokens.spaceXl);
    }

    function test_under_reduced_motion_a_jump_is_instant() {
        Prefs.motion = "off";
        const panorama = makePanorama(5);
        panorama.goTo(3, false, false);
        compare(panorama.scroller.contentX, sectionAt(panorama, 3).x - Tokens.spaceXl);
        verify(!panorama.gliding);
    }

    // The strip's own wheel (layout.md:68–71; rekta.js stripWheel()).

    function test_a_plain_vertical_wheel_over_a_strip_that_does_not_fit_moves_it_sideways() {
        const strip = createTemporaryObject(stripAndPanoramaComponent, testCase).strip;
        strip.width = 120;
        waitForRendering(strip);
        const flick = findChild(strip, "strip");
        flick.contentX = 0;
        verify(flick.contentWidth > flick.width);
        verify(strip.stripWheel(wheelEvent(30)));
        compare(flick.contentX, 30);
        verify(!strip.stripWheel(wheelEvent(30, {
            modifiers: Qt.ControlModifier
        })));
        verify(!strip.stripWheel(wheelEvent(30, {
            modifiers: Qt.ShiftModifier
        })));
        verify(!strip.stripWheel(wheelEvent(0, {
            pixelDelta: Qt.point(-30, 0)
        })));
        verify(!strip.stripWheel(wheelEvent(-30)) || flick.contentX === 0, "the start falls through only once there");
    }

    function test_a_strip_that_fits_does_not_take_the_wheel() {
        const strip = createTemporaryObject(stripAndPanoramaComponent, testCase).strip;
        verify(!strip.stripWheel(wheelEvent(30)));
    }

    function test_at_either_end_the_strip_lets_the_wheel_fall_through() {
        const strip = createTemporaryObject(stripAndPanoramaComponent, testCase).strip;
        strip.width = 120;
        waitForRendering(strip);
        const flick = findChild(strip, "strip");
        flick.contentX = 0;
        verify(!strip.stripWheel(wheelEvent(-30)));
        flick.contentX = flick.contentWidth - flick.width;
        verify(!strip.stripWheel(wheelEvent(30)));
    }

    // A wide facet pivot (navigation.md:52–64).

    function test_below_pivot_wide_one_facet_shows_at_a_time_and_a_pivot_that_picks_the_place_is_never_wide() {
        const place = createTemporaryObject(wideComponent, testCase);
        place.facets.width = Tokens.pivotWide - 1;
        verify(!place.facets.wide);
        verify(findChild(place.facets, "facet0").visible);
        verify(!findChild(place.facets, "facet1").visible);
        place.facets.width = Tokens.pivotWide;
        verify(place.facets.wide);
        place.strip.level = "nav";
        verify(!place.facets.wide, "a nav pivot never goes wide");
    }

    function test_from_pivot_wide_up_every_facet_shows_side_by_side_in_tile_units() {
        const place = createTemporaryObject(wideComponent, testCase);
        verify(place.facets.wide);
        for (let k = 0; k < 4; k++) {
            const facet = findChild(place.facets, `facet${k}`);
            verify(facet.visible, `facet ${k}`);
            compare(facet.parent.width, sectionWidth);
            compare(facet.width, sectionWidth, "the facet fills its place");
            compare(facet.parent.x, k * (sectionWidth + Tokens.spaceXl), "no inset in the row");
        }
    }

    function test_the_strip_stays_and_follows_the_facet_scrolled_into_view() {
        const place = createTemporaryObject(wideComponent, testCase);
        const row = findChild(place.facets, "row");
        verify(place.strip.visible);
        compare(place.strip.currentIndex, 0);
        row.scroller.contentX = row.sectionParent.children[1].x - 20;
        compare(place.strip.currentIndex, 1);
        row.scroller.contentX = row.scroller.contentWidth - row.width;
        compare(place.strip.currentIndex, 3, "at the end the last one");
    }

    function test_a_facet_chosen_on_the_strip_scrolls_to_the_leading_edge() {
        Prefs.motion = "off";
        const place = createTemporaryObject(wideComponent, testCase);
        const row = findChild(place.facets, "row");
        place.strip.select(2);
        compare(row.scroller.contentX, row.startOf(2));
        compare(place.strip.currentIndex, 2);
        place.strip.select(0);
        compare(row.scroller.contentX, 0);
    }

    function test_tab_on_the_strip_enters_the_facet_chosen_and_goes_on_through_it() {
        Prefs.motion = "off";
        const place = createTemporaryObject(wideComponent, testCase);
        place.strip.select(2);
        place.strip.forceActiveFocus();
        keyClick(Qt.Key_Tab);
        const slot = findChild(place.facets, "facet2").parent;
        verify(slot.activeFocus, "the facet chosen, not the first one");
        keyClick(Qt.Key_Tab);
        verify(place.inner.activeFocus, "and on from there through the facet");
    }

    function test_narrow_again_the_facets_are_back_in_their_holder_in_order() {
        Prefs.motion = "off";
        const place = createTemporaryObject(wideComponent, testCase);
        place.facets.width = 1000;
        verify(!place.facets.wide);
        const holder = findChild(place.facets, "holder");
        compare(holder.children.length, 4);
        compare(holder.children[2].objectName, "facet2");
        verify(holder.children[0].visible);
        verify(!holder.children[1].visible);
        place.strip.select(2);
        verify(holder.children[2].visible);
        verify(!holder.children[0].visible);
    }

    // A control in a section, to see where Tab and the focus lead.
    Component {
        id: controlComponent

        Item {
            width: 20
            height: 20
            activeFocusOnTab: true
        }
    }

    function makeWithControls(place) {
        for (let k = 0; k < 5; k++) {
            const section = sectionComponent.createObject(place.panorama.sectionParent, {
                title: `section ${k}`,
                tall: 100
            }) as Section;
            controlComponent.createObject(section.contentItem, {
                objectName: `control-${k}`,
                x: 10,
                y: 100
            });
        }
    }

    function test_after_enter_on_the_strip_tab_goes_on_inside_that_section() {
        Prefs.motion = "off";
        const place = createTemporaryObject(stripAndPanoramaComponent, testCase);
        makeWithControls(place);
        place.strip.forceActiveFocus();
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Return);
        verify(sectionAt(place.panorama, 2).headingFocused);
        keyClick(Qt.Key_Tab);
        verify(findChild(place.panorama, "control-2").activeFocus, "the control of that section, not the first one");
    }

    function test_a_key_after_a_jump_by_the_strip_lets_the_strip_follow_the_scroll_again() {
        Prefs.motion = "off";
        const place = createTemporaryObject(stripAndPanoramaComponent, testCase);
        makeWithControls(place);
        place.strip.select(4);
        place.panorama.scroller.contentX = 0;
        compare(place.strip.currentIndex, 4, "a jump wins over the follow until the user does something");
        place.panorama.forceActiveFocus();
        keyClick(Qt.Key_A);
        place.panorama.scroller.contentX = 100;
        compare(place.strip.currentIndex, 0);
    }

    function test_a_key_jump_is_followed_as_the_user_scrolls_on() {
        Prefs.motion = "off";
        const place = createTemporaryObject(stripAndPanoramaComponent, testCase);
        makeWithControls(place);
        place.panorama.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(place.strip.currentIndex, 1);
        place.panorama.scroller.contentX = 0;
        compare(place.strip.currentIndex, 0, "a key does not hold the mark against the scroll");
    }

    function test_a_key_jump_glides_and_lands_flush_left_in_the_glide_time() {
        Prefs.motion = "on";
        const panorama = makePanorama(5, 100);
        panorama.forceActiveFocus();
        keyClick(Qt.Key_End);
        compare(panorama.currentIndex, 4);
        verify(panorama.gliding);
        wait(Tokens.durationPivotGlide / 2);
        verify(panorama.scroller.contentX > 0 && panorama.scroller.contentX < panorama.startOf(4), "on its way");
        tryCompare(panorama.scroller, "contentX", panorama.startOf(4), 2 * Tokens.durationPivotGlide);
        compare(panorama.scroller.contentX, panorama.scroller.contentWidth - panorama.width);
    }

    function test_another_key_during_a_jump_does_not_cut_it_off() {
        Prefs.motion = "on";
        const panorama = makePanorama(5, 100);
        panorama.forceActiveFocus();
        keyClick(Qt.Key_End);
        wait(Tokens.durationPivotGlide / 5);
        keyClick(Qt.Key_A);
        verify(panorama.gliding, "a key that is no jump leaves the glide running");
        tryCompare(panorama.scroller, "contentX", panorama.startOf(4), 2 * Tokens.durationPivotGlide);
        keyClick(Qt.Key_Home);
        wait(Tokens.durationPivotGlide / 5);
        const reading = panorama.currentIndex;
        keyClick(Qt.Key_Right);
        compare(panorama.currentIndex, Math.min(4, reading + 1), "the next one from the section the scroll has reached");
        tryCompare(panorama.scroller, "contentX", panorama.startOf(panorama.currentIndex), 2 * Tokens.durationPivotGlide);
    }

    function test_a_wheel_that_scrolls_a_section_leaves_a_jump_running() {
        Prefs.motion = "on";
        const panorama = makePanorama(5);
        settled(panorama);
        panorama.goTo(4, false, false);
        wait(Tokens.durationPivotGlide / 5);
        const over = sectionAt(panorama, 0).x - panorama.scroller.contentX + 100;
        panorama.handleWheel(wheelEvent(30, {
            x: Math.max(60, over)
        }), 1000);
        verify(panorama.gliding);
        verify(!panorama.handleWheel(wheelEvent(30, {
            modifiers: Qt.ControlModifier
        }), 2000));
        verify(panorama.gliding, "Ctrl+wheel is not the panorama's either");
    }

    function test_a_wheel_during_a_jump_takes_the_panorama_over() {
        Prefs.motion = "on";
        const panorama = makePanorama(5, 100);
        panorama.goTo(4, false, false);
        wait(Tokens.durationPivotGlide / 4);
        verify(panorama.gliding);
        panorama.handleWheel(wheelEvent(10), 1000);
        verify(!panorama.gliding);
    }

    function test_a_focused_item_beyond_the_edge_scrolls_into_view_with_the_inset_clear() {
        Prefs.motion = "off";
        const place = createTemporaryObject(stripAndPanoramaComponent, testCase);
        makeWithControls(place);
        const panorama = place.panorama;
        const far = findChild(panorama, "control-4");
        far.forceActiveFocus();
        const at = far.mapToItem(panorama.scroller, 0, 0).x;
        verify(at >= Tokens.spaceXl - 1 && at + far.width <= panorama.width, `in sight, at ${at}`);
        findChild(panorama, "control-0").forceActiveFocus();
        compare(panorama.scroller.contentX, 10, "back by as little as it takes, the inset clear");
    }

    function test_a_focus_inside_a_section_already_in_sight_does_not_scroll() {
        Prefs.motion = "off";
        const place = createTemporaryObject(stripAndPanoramaComponent, testCase);
        makeWithControls(place);
        findChild(place.panorama, "control-1").forceActiveFocus();
        compare(place.panorama.scroller.contentX, 0);
    }

    function test_shift_wheel_moves_the_wide_facet_row_and_a_plain_wheel_does_not() {
        const place = createTemporaryObject(wideComponent, testCase);
        const row = findChild(place.facets, "row");
        verify(!row.handleWheel(wheelEvent(60), 0), "a vertical wheel is left to the facets");
        compare(row.scroller.contentX, 0);
        verify(row.handleWheel(wheelEvent(60, {
            modifiers: Qt.ShiftModifier
        }), 1000));
        compare(row.scroller.contentX, 60);
        verify(row.handleWheel(wheelEvent(-100, {
            modifiers: Qt.ShiftModifier
        }), 2000));
        compare(row.scroller.contentX, 0);
        verify(!row.handleWheel(wheelEvent(-100, {
            modifiers: Qt.ShiftModifier
        }), 3000), "at the start it falls through");
    }

    function test_the_wide_facet_row_takes_the_wheel_through_the_window_with_shift() {
        const place = createTemporaryObject(wideComponent, testCase);
        waitForRendering(place);
        mouseWheel(place.facets, 300, 200, 0, -120, Qt.NoButton, Qt.ShiftModifier);
        tryVerify(() => findChild(place.facets, "row").scroller.contentX > 0);
    }

    function test_a_hidden_section_takes_no_room_and_does_not_count() {
        const panorama = makePanorama(5, 100);
        verify(!panorama.fit);
        for (const k of [2, 3, 4])
            sectionAt(panorama, k).visible = false;
        verify(panorama.fit, "two sections fit");
        compare(panorama.scroller.contentWidth, panorama.width);
        compare(panorama.sectionItems().length, 2);
        sectionAt(panorama, 3).visible = true;
        compare(sectionAt(panorama, 3).x, Tokens.spaceXl + 2 * (sectionWidth + Tokens.spaceXl), "the third visible one follows the second");
        verify(sectionAt(panorama, 1).separated);
    }

    function test_the_facet_rows_section_width_reaches_its_places() {
        const place = createTemporaryObject(wideComponent, testCase);
        place.facets.sectionWidth = 400;
        compare(findChild(place.facets, "facet1").parent.width, 400);
        compare(findChild(place.facets, "facet1").parent.x, 400 + Tokens.spaceXl);
    }

    // Contact sheets

    function test_contact_sheets_of_a_panorama_that_fits_and_one_that_overflows_in_both_themes() {
        Prefs.motion = "off";
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const sheet = createTemporaryObject(sheetComponent, testCase);
            waitForRendering(sheet);
            verify(findChild(sheet, "panorama-2").fit, "the upper one fits");
            verify(!findChild(sheet, "panorama-5").fit, "the lower one overflows");
            grabImage(sheet).save(`panorama-sheet-${theme}.png`);
            verify(sheet.height > 0, theme);
            sheet.destroy();
        }
    }
}
