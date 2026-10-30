pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "Pivot"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 700

    readonly property list<string> manyTitles: ["overview", "activity", "settings", "members", "history", "billing", "integrations"]

    Component {
        id: pivotComponent

        Pivot {
            width: 400
            placeWidth: 1000
            viewportHeight: 700
            titles: testCase.manyTitles
        }
    }

    Component {
        id: facetsComponent

        Facets {
            width: 300
            height: 100

            Rectangle {
                objectName: "first"
                anchors.fill: parent
            }
            Rectangle {
                objectName: "second"
                anchors.fill: parent
            }
            Rectangle {
                objectName: "third"
                anchors.fill: parent
            }
        }
    }

    Component {
        id: sheetComponent

        // The strip along the top as nav and facet, the active title at the start, in the middle and at the end, and the
        // list down the side, on the current theme's ground.
        Rectangle {
            width: 980
            height: column.height + 2 * Tokens.spaceL
            color: Tokens.color.bg

            Column {
                id: column

                x: Tokens.spaceL
                y: Tokens.spaceL
                spacing: Tokens.spaceL

                Repeater {
                    model: [["nav", 0], ["nav", 3], ["facet", 0], ["facet", 3], ["facet", 6]]

                    delegate: Pivot {
                        required property var modelData

                        width: 600
                        placeWidth: 1000
                        viewportHeight: 700
                        level: modelData[0]
                        currentIndex: modelData[1]
                        titles: testCase.manyTitles
                    }
                }
                Pivot {
                    width: 300
                    placeWidth: 1000
                    viewportHeight: 700
                    side: true
                    currentIndex: 2
                    titles: ["inbox", "drafts", "sent", "archive"]
                }
            }
        }
    }

    Component {
        id: ringGroundComponent

        // A pivot with room around it, on the ground, so a grab shows what the strip cuts off.
        Rectangle {
            property alias pivot: ringed

            width: 480
            height: ringed.height + 2 * Tokens.spaceL
            color: Tokens.color.bg

            Pivot {
                id: ringed

                x: Tokens.spaceL
                y: Tokens.spaceL
                width: 400
                placeWidth: 1000
                viewportHeight: 700
                titles: testCase.manyTitles
                focus: true
            }
        }
    }

    // The named sides of the title whose ring is cut off: the pixel just outside the title's edge, in the middle of the ring's stroke, lacks the focus colour.
    function ringSidesCutOff(ground, index, names = ["left", "right", "top", "bottom"]) {
        const title = titleOf(ground.pivot, index);
        const box = title.mapToItem(ground, 0, 0);
        const mid = Geometry.focusRingOffset + Geometry.focusRingWidth / 2;
        const image = grabImage(ground);
        const sides = {
            left: [box.x - mid, box.y + title.height / 2],
            right: [box.x + title.width + mid, box.y + title.height / 2],
            top: [box.x + title.width / 2, box.y - mid],
            bottom: [box.x + title.width / 2, box.y + title.height + mid]
        };
        return names.filter(side => !Qt.colorEqual(image.pixel(Math.floor(sides[side][0]), Math.floor(sides[side][1])), Tokens.color.focus));
    }

    // The same for the top and the bottom only: a gliding title may stand partly outside the view sideways.
    function ringRowsCutOff(ground, index) {
        return ringSidesCutOff(ground, index, ["top", "bottom"]);
    }

    function test_the_focus_ring_of_the_active_title_shows_on_all_four_sides_at_the_start_in_the_middle_and_at_the_end() {
        Prefs.motion = "off";
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            for (const index of [0, 3, 6]) {
                const ground = createTemporaryObject(ringGroundComponent, testCase);
                ground.pivot.currentIndex = index;
                ground.pivot.forceActiveFocus(Qt.TabFocusReason);
                waitForRendering(ground);
                compare(ringSidesCutOff(ground, index), [], `${theme}, title ${index}: sides cut off`);
                grabImage(ground).save(`pivot-ring-${theme}-${index}.png`);
                ground.destroy();
            }
        }
    }

    function test_the_focus_ring_shows_whole_on_a_strip_that_is_gliding() {
        Prefs.motion = "off";
        const ground = createTemporaryObject(ringGroundComponent, testCase);
        ground.pivot.currentIndex = 6;
        ground.pivot.forceActiveFocus(Qt.TabFocusReason);
        waitForRendering(ground);
        const strip = findChild(ground.pivot, "strip");
        tryVerify(() => Math.abs(strip.contentX - (strip.contentWidth - strip.width)) < 1, 500);
        Prefs.motion = "on";
        const from = strip.contentX;
        ground.pivot.select(5);
        tryVerify(() => strip.contentX !== from, 500, "the strip is under way");
        verify(findChild(ground.pivot, "glide").running, "the glide is still running");
        waitForRendering(ground);
        const rows = ringRowsCutOff(ground, 5);
        compare(rows, [], "top and bottom of the ring stay whole while the strip glides");
    }

    function test_a_title_crossing_the_edge_of_the_pivot_is_cut_there() {
        Prefs.motion = "off";
        const ground = createTemporaryObject(ringGroundComponent, testCase);
        ground.pivot.select(3);
        waitForRendering(ground);
        const ringRoom = Geometry.focusRingOffset + Geometry.focusRingWidth;
        const viewRight = ground.pivot.x + ground.pivot.width + ringRoom;
        const crossing = [0, 1, 2, 3, 4, 5, 6].map(k => titleOf(ground.pivot, k)).find(t => {
            const box = t.mapToItem(ground, 0, 0);
            return box.x < viewRight - 8 && box.x + t.width > viewRight + 8;
        });
        verify(crossing, "a title reaches across the right edge of the view");
        const box = crossing.mapToItem(ground, 0, 0);
        const image = grabImage(ground);
        let inside = false, outside = false;
        for (let y = Math.floor(box.y); y < box.y + crossing.height; y++) {
            for (let x = Math.floor(box.x); x < Math.min(box.x + crossing.width, ground.width); x++) {
                if (Qt.colorEqual(image.pixel(x, y), Tokens.color.bg))
                    continue;
                inside = inside || x < viewRight;
                outside = outside || x >= viewRight;
            }
        }
        verify(inside, "the title shows inside the view");
        verify(!outside, "nothing of it shows beyond the view");
    }

    function test_titles_stay_at_the_top_of_a_pivot_taller_than_they_are() {
        const pivot = createTemporaryObject(pivotComponent, testCase, {
            height: 400
        });
        compare(pivot.mapFromItem(titleOf(pivot, 0), 0, 0).y, 0);
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
    }

    function sameCurve(actual, expected) {
        const a = Array.from(actual);
        return a.length === expected.length && a.every((v, k) => Math.abs(v - expected[k]) < 1e-9);
    }

    // Where pivotGlide() puts the strip for the title at index i, from the titles' own widths.
    function expectedGlide(pivot, i) {
        const n = pivot.titles.length;
        let x = 0, left = 0, span = 0, previous = 0;
        for (let k = 0; k < n; k++) {
            const title = titleOf(pivot, k);
            const w = k === i ? title.restingWidth : title.restingWidth * title.ratio;
            if (k === i - 1)
                previous = x;
            if (k === i) {
                left = x;
                span = w;
            }
            x += w + Tokens.spaceL;
        }
        const most = Math.max(0, x - Tokens.spaceL - pivot.width);
        return Math.min(most, Math.max(0, left + span - pivot.width, Math.min(most * i / (n - 1), i > 0 ? previous : left)));
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
        Prefs.density = "auto";
    }

    function titleOf(pivot, index) {
        return findChild(pivot, `title-${index}`);
    }

    function test_choosing_a_title_never_reorders_and_only_the_old_and_new_change_size() {
        Prefs.motion = "off";
        const pivot = createTemporaryObject(pivotComponent, testCase);
        const height = pivot.height;
        const scales = [];
        for (let k = 0; k < 7; k++)
            scales.push(findChild(titleOf(pivot, k), "word").shrink);
        pivot.select(3);
        for (let k = 1; k < 7; k++)
            verify(titleOf(pivot, k).x > titleOf(pivot, k - 1).x, "the order stays");
        for (let k = 0; k < 7; k++) {
            const scale = findChild(titleOf(pivot, k), "word").shrink;
            if (k === 0 || k === 3)
                verify(scale !== scales[k], `title ${k} changes`);
            else
                compare(scale, scales[k], `title ${k} stays`);
        }
        compare(findChild(titleOf(pivot, 3), "word").shrink, 1);
        fuzzyCompare(findChild(titleOf(pivot, 0), "word").shrink, pivot.inactiveSize / pivot.activeSize, 0.0001);
        compare(pivot.height, height, "the strip's height never changes");
        const baseline = k => {
            const word = findChild(titleOf(pivot, k), "word");
            return pivot.mapFromItem(word, 0, word.baselineOffset).y;
        };
        fuzzyCompare(baseline(0), baseline(3), 0.5, "every title scales around its own baseline");
    }

    function test_every_title_stands_in_a_line_box_of_the_active_size_times_line_height_nav() {
        const pivot = createTemporaryObject(pivotComponent, testCase);
        for (let k = 0; k < pivot.titles.length; k++)
            fuzzyCompare(titleOf(pivot, k).height, Math.round(pivot.activeSize) * Tokens.lineHeightNav, 1e-9, `title ${k}`);
    }

    function test_the_strip_glides_by_the_active_titles_place_in_the_order() {
        Prefs.motion = "off";
        const pivot = createTemporaryObject(pivotComponent, testCase);
        const strip = findChild(pivot, "strip");
        compare(strip.contentX, 0, "the first title shows the start");
        pivot.select(6);
        // The grid lays out at the next polish; the strip already rests where the new widths put the end.
        tryVerify(() => Math.abs(strip.contentX - (strip.contentWidth - strip.width)) < 1, 500, "the last title shows the end");
        for (let i = 0; i < 7; i++) {
            pivot.select(i);
            waitForRendering(pivot);
            const title = titleOf(pivot, i);
            verify(title.x - strip.contentX >= -0.5, `title ${i} starts in sight`);
            verify(title.x + title.width - strip.contentX <= strip.width + 0.5, `title ${i} ends in sight`);
        }
    }

    function test_the_strip_moves_in_proportion_to_the_place_in_the_order() {
        Prefs.motion = "off";
        const pivot = createTemporaryObject(pivotComponent, testCase);
        const strip = findChild(pivot, "strip");
        for (let i = 0; i < 7; i++) {
            pivot.select(i);
            fuzzyCompare(strip.contentX, expectedGlide(pivot, i), 0.01, `title ${i}`);
        }
        verify(expectedGlide(pivot, 3) > expectedGlide(pivot, 2), "further along the order, further along the strip");
    }

    function test_the_title_before_the_active_one_stays_in_reach() {
        Prefs.motion = "off";
        const pivot = createTemporaryObject(pivotComponent, testCase);
        pivot.select(1);
        compare(findChild(pivot, "strip").contentX, 0, "the first title stays whole while the second is active");
    }

    function test_a_long_active_title_is_whole_in_sight() {
        Prefs.motion = "off";
        const pivot = createTemporaryObject(pivotComponent, testCase, { titles: ["overview", "an unusually long title", "b", "c", "d", "e"] });
        const strip = findChild(pivot, "strip");
        const title = titleOf(pivot, 1);
        const first = titleOf(pivot, 0);
        // Room for the long title, but not for it behind the first one.
        pivot.width = first.restingWidth * first.ratio + Tokens.spaceL + title.restingWidth - 8;
        pivot.select(1);
        waitForRendering(pivot);
        verify(title.restingWidth < pivot.width, "the title can fit");
        verify(first.restingWidth * first.ratio + Tokens.spaceL + title.restingWidth > pivot.width, "but not behind the first one");
        verify(title.x - strip.contentX >= -0.5, "it starts in sight");
        verify(title.x + title.width - strip.contentX <= strip.width + 0.5, "it ends in sight");
    }

    function test_a_strip_that_fits_holds_still() {
        Prefs.motion = "off";
        const pivot = createTemporaryObject(pivotComponent, testCase, { width: 900, titles: ["one", "two", "three"] });
        const strip = findChild(pivot, "strip");
        for (let i = 0; i < 3; i++) {
            pivot.select(i);
            compare(strip.contentX, 0);
        }
    }

    function test_the_glide_and_the_size_change_take_their_own_times() {
        const pivot = createTemporaryObject(pivotComponent, testCase);
        const strip = findChild(pivot, "strip");
        const glide = findChild(pivot, "glide");
        compare(glide.duration, Tokens.durationPivotGlide);
        verify(sameCurve(glide.easing.bezierCurve, Tokens.easePivotGlide), "the glide eases with pivot-glide");
        pivot.select(6);
        wait(Tokens.durationPivotSize + 60);
        compare(findChild(titleOf(pivot, 6), "word").shrink, 1, "the size change is over after pivot-size");
        verify(strip.contentX < strip.contentWidth - strip.width - 1, "the glide is still running");
        tryCompare(strip, "contentX", strip.contentWidth - strip.width, Tokens.durationPivotGlide * 2);
    }

    function test_down_the_side_the_title_in_sight_steps_in_and_nothing_reflows() {
        Prefs.motion = "off";
        const pivot = createTemporaryObject(pivotComponent, testCase, { side: true, titles: ["inbox", "drafts", "sent"] });
        const ys = [0, 1, 2].map(k => titleOf(pivot, k).y);
        compare(findChild(titleOf(pivot, 0), "word").x, Tokens.spaceM);
        compare(findChild(titleOf(pivot, 1), "word").x, 0);
        pivot.select(1);
        compare(findChild(titleOf(pivot, 0), "word").x, 0);
        compare(findChild(titleOf(pivot, 1), "word").x, Tokens.spaceM);
        compare([0, 1, 2].map(k => titleOf(pivot, k).y), ys, "the list never reflows");
        compare(findChild(titleOf(pivot, 0), "word").shrink, 1, "one size down the side");
    }

    function test_compact_turns_the_side_list_into_the_strip_and_nav_into_facet_sizes() {
        const pivot = createTemporaryObject(pivotComponent, testCase, { side: true, level: "nav", placeWidth: 400 });
        verify(pivot.compact);
        verify(!pivot.down);
        compare(pivot.activeSize, Tokens.fluid(Tokens.fontSizePivotActive, 400));
    }

    function test_the_arrows_home_and_end_pick_a_title_and_wrap() {
        const pivot = createTemporaryObject(pivotComponent, testCase);
        const picks = [];
        pivot.selected.connect(index => picks.push(index));
        pivot.forceActiveFocus();
        keyClick(Qt.Key_Right);
        compare(pivot.currentIndex, 1);
        keyClick(Qt.Key_End);
        compare(pivot.currentIndex, 6);
        keyClick(Qt.Key_Right);
        compare(pivot.currentIndex, 0, "past the end comes the start");
        keyClick(Qt.Key_Left);
        compare(pivot.currentIndex, 6, "before the start comes the end");
        keyClick(Qt.Key_Home);
        compare(pivot.currentIndex, 0);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Up);
        compare(pivot.currentIndex, 0, "Up and Down do nothing along the top");
        compare(picks, [1, 6, 0, 6, 0]);
        const ring = Array.from(titleOf(pivot, 0).children).find(child => child.onFill !== undefined);
        verify(ring.visible, "the ring is on the active title");
    }

    function test_an_arrow_with_alt_ctrl_or_meta_is_not_the_strips() {
        const pivot = createTemporaryObject(pivotComponent, testCase);
        pivot.forceActiveFocus();
        keyClick(Qt.Key_Right, Qt.AltModifier);
        keyClick(Qt.Key_Right, Qt.ControlModifier);
        keyClick(Qt.Key_Right, Qt.MetaModifier);
        compare(pivot.currentIndex, 0);
    }

    function test_down_the_side_up_and_down_pick() {
        const pivot = createTemporaryObject(pivotComponent, testCase, { side: true });
        pivot.forceActiveFocus();
        keyClick(Qt.Key_Down);
        compare(pivot.currentIndex, 1);
        keyClick(Qt.Key_Up);
        compare(pivot.currentIndex, 0);
        keyClick(Qt.Key_Right);
        compare(pivot.currentIndex, 0, "Right does nothing down the side");
    }

    function test_a_title_under_the_pointer_darkens() {
        const pivot = createTemporaryObject(pivotComponent, testCase);
        const word = findChild(titleOf(pivot, 2), "word");
        compare(word.color, Tokens.color.textContrastMedium);
        mouseMove(titleOf(pivot, 2));
        tryCompare(word, "color", Tokens.color.textPrimary, Tokens.durationShort * 3);
        const hover = Array.from(titleOf(pivot, 2).data).find(child => child.cursorShape !== undefined);
        compare(hover.cursorShape, Qt.PointingHandCursor, "the pointer becomes a hand");
    }

    function test_a_click_picks_its_title() {
        const pivot = createTemporaryObject(pivotComponent, testCase);
        mouseClick(titleOf(pivot, 1));
        compare(pivot.currentIndex, 1);
        verify(!pivot.activeFocus, "a click gives no focus");
    }

    function test_a_facet_comes_in_from_the_side_of_its_place_in_the_order() {
        const facets = createTemporaryObject(facetsComponent, testCase);
        const shift = findChild(facets, "shift");
        const holder = findChild(facets, "holder");
        const enter = findChild(facets, "enter");
        compare(enter.duration, 0.75 * Tokens.durationModerate);
        for (const step of enter.animations) {
            compare(step.duration, 0.75 * Tokens.durationModerate);
            verify(sameCurve(step.easing.bezierCurve, Tokens.easeOut), "it eases out");
        }
        verify(findChild(facets, "first").visible);
        verify(!findChild(facets, "second").visible);
        facets.currentIndex = 2;
        verify(!findChild(facets, "first").visible, "the one left goes at once");
        verify(findChild(facets, "third").visible);
        compare(shift.x, Tokens.slideDistance, "forward: from slide-distance at the trailing edge");
        verify(holder.opacity < 1);
        wait(0.75 * Tokens.durationModerate / 2);
        verify(shift.x > 0, "still moving halfway");
        tryCompare(shift, "x", 0, Tokens.durationModerate * 2);
        compare(holder.opacity, 1);
        facets.currentIndex = 1;
        compare(shift.x, -Tokens.slideDistance, "back: from slide-distance at the leading edge");
        tryCompare(shift, "x", 0, Tokens.durationModerate * 2);
    }

    function test_the_first_display_of_facets_stands_still() {
        const facets = createTemporaryObject(facetsComponent, testCase, { currentIndex: 2 });
        verify(findChild(facets, "third").visible);
        verify(!findChild(facets, "first").visible);
        compare(findChild(facets, "shift").x, 0);
        compare(findChild(facets, "holder").opacity, 1);
    }

    function test_under_reduced_motion_everything_lands_at_once() {
        Prefs.motion = "off";
        const pivot = createTemporaryObject(pivotComponent, testCase);
        const strip = findChild(pivot, "strip");
        pivot.select(6);
        compare(findChild(titleOf(pivot, 6), "word").shrink, 1);
        tryVerify(() => Math.abs(strip.contentX - (strip.contentWidth - strip.width)) < 1, 500);
        const facets = createTemporaryObject(facetsComponent, testCase);
        facets.currentIndex = 1;
        tryCompare(findChild(facets, "shift"), "x", 0, 50);
    }

    // The pivots follow the one current theme and density, so the sheet is drawn once per pair.
    function test_contact_sheet_of_pivots_in_both_themes_and_densities() {
        Prefs.motion = "off";
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const sheet = createTemporaryObject(sheetComponent, testCase);
                waitForRendering(sheet);
                grabImage(sheet).save(`pivot-sheet-${theme}-${density}.png`);
                verify(sheet.height > 0, `${theme} ${density}`);
                sheet.destroy();
            }
        }
    }
}
