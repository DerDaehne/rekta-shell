pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "AppBar"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1200
    height: 600

    // The bar along the bottom of a scene, with controls of every priority around its middle.
    Component {
        id: sceneComponent

        Item {
            id: scene

            property alias bar: appBar
            property real barWidth: 1200
            property real viewportHeight: 600
            property bool withCentre: false

            width: 1200
            height: 600

            AppBar {
                id: appBar

                objectName: "bar"
                y: scene.height - height
                width: scene.barWidth
                viewportHeight: scene.viewportHeight
                area: Qt.size(scene.barWidth, scene.height)
                centre: scene.withCentre ? centreSlot : null

                AppBarButton { objectName: "back"; icon: "window"; text: "back"; priority: 3 }
                AppBarMiddle { objectName: "middle"; parts: ["konsole", "~/projects: build the shell and its tests"] }
                Rectangle { id: centreSlot; objectName: "centre"; visible: scene.withCentre; implicitWidth: 80; width: implicitWidth; height: 48; color: "transparent" }
                AppBarButton { objectName: "pause"; icon: "pause"; text: "pause"; priority: 2 }
                AppBarButton { objectName: "in the background"; icon: "window"; text: "in the background"; priority: 0 }
                AppBarButton { objectName: "messages"; icon: "bell"; text: "messages"; priority: 1; disabledReason: "comes with the panel" }
                AppBarButton { objectName: "theme"; icon: "theme"; text: "theme and colours"; priority: 1 }
                AppBarButton { objectName: "controls"; icon: "tune"; text: "controls"; priority: 0 }
            }
        }
    }

    Component {
        id: buttonComponent

        AppBarButton {
            icon: "search"
            text: "back"
        }
    }

    Component {
        id: spy

        SignalSpy {
            signalName: "clicked"
        }
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var scene
    property AppBar bar

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
    }

    function cleanup() {
        Tips.hide();
        Tips.hiddenAt = -Infinity;
        Prefs.theme = "system";
        Prefs.density = "auto";
        Prefs.motion = "system";
    }

    function makeScene(properties) {
        scene = createTemporaryObject(sceneComponent, testCase, properties);
        bar = scene.bar;
        return scene;
    }

    function named(name: string): var {
        return findChild(scene, name);
    }

    function controls(): var {
        return ["back", "pause", "in the background", "messages", "theme", "controls"].map(named);
    }

    function endOf(item: Item): real {
        return item.x + item.width;
    }

    // The widths of the controls left in the bar, "more" and the gaps between them.
    function rowWidth(items: var): real {
        return items.reduce((sum, item) => sum + item.width, 0) + bar.gap * (items.length - 1);
    }

    function test_a_control_is_at_least_48_square_in_either_density() {
        for (const density of ["compact", "comfortable"]) {
            Prefs.density = density;
            const control = createTemporaryObject(buttonComponent, testCase);
            const box = findChild(control, "box");
            compare(box.height, Geometry.appBarControl, density);
            verify(box.width >= Geometry.appBarControl, density);
            compare(control.height, Geometry.appBarControl);
            control.icon = "";
            control.text = "a";
            compare(box.width, Geometry.appBarControl, `a short word keeps the minimum width (${density})`);
        }
    }

    function test_a_control_is_a_glyph_and_a_word_inside_its_padding() {
        const control = createTemporaryObject(buttonComponent, testCase);
        const glyph = findChild(control, "glyph");
        const label = findChild(control, "label");
        compare(glyph.x, Geometry.appBarControlPadding);
        compare(glyph.size, Geometry.appBarGlyph);
        compare(label.x, Geometry.appBarControlPadding + Geometry.appBarGlyph + Geometry.appBarControlGap);
        compare(findChild(control, "box").width, Math.ceil(label.x + label.implicitWidth + Geometry.appBarControlPadding), "whole pixels");
        compare(label.font.pixelSize, Tokens.fontSizeXs);
        compare(label.font.weight, Tokens.fontWeightSemibold);
        compare(label.color, Tokens.color.textPrimary);
        compare(control.Accessible.name, "back");
    }

    function test_a_count_follows_the_word_in_tabular_figures_and_none_shows_at_zero() {
        const control = createTemporaryObject(buttonComponent, testCase);
        const label = findChild(control, "label");
        const count = findChild(control, "count");
        const box = findChild(control, "box");
        const width = box.width;
        verify(!count.visible);
        compare(count.implicitWidth, 0);
        compare(control.words, "back");
        control.count = 3;
        verify(count.visible);
        compare(count.text, " 3");
        compare(count.x, label.x + label.implicitWidth);
        compare(count.font.features["tnum"], 1);
        compare(count.font.weight, Tokens.fontWeightSemibold);
        compare(box.width, Math.ceil(label.x + label.implicitWidth + count.implicitWidth + Geometry.appBarControlPadding));
        verify(box.width > width);
        compare(control.Accessible.name, "back 3");
    }

    function test_a_new_count_peeks_in_the_old_one_leaving_upwards_while_the_new_one_rises_from_below() {
        Prefs.motion = "on";
        const control = createTemporaryObject(buttonComponent, testCase, { count: 3 });
        const count = findChild(control, "count");
        const ghost = findChild(control, "ghost");
        const peek = findChild(control, "peek");
        const run = findChild(control, "peekRun");
        verify(!ghost.visible, "the first count is no news");
        control.count = 4;
        verify(run.running);
        compare(run.duration, Tokens.durationModerate);
        compare(ghost.text, " 3");
        compare(count.text, " 4");
        run.pause();
        peek.phase = 0.1;
        compare(count.opacity, 0, "the new one waits 0.2 ×");
        verify(ghost.opacity > 0 && ghost.opacity < 1);
        verify(ghost.transform[0].y < 0, "the old one moves up");
        peek.phase = 0.6;
        compare(ghost.opacity, 0, "gone after 0.6 ×");
        compare(ghost.transform[0].y, -Geometry.peekShift * ghost.height);
        verify(count.opacity > 0 && count.transform[0].y > 0, "the new one rises from below");
        peek.phase = 1;
        compare(count.opacity, 1);
        compare(count.transform[0].y, 0);
    }

    function test_under_reduced_motion_a_new_count_stands_at_once() {
        Prefs.motion = "off";
        const control = createTemporaryObject(buttonComponent, testCase, { count: 1 });
        control.count = 2;
        tryVerify(() => !findChild(control, "peekRun").running);
        compare(findChild(control, "count").opacity, 1);
        verify(!findChild(control, "ghost").visible);
    }

    function test_hover_and_press_lay_the_hover_colour_under_the_control() {
        const control = createTemporaryObject(buttonComponent, testCase, { x: 40, y: 40 });
        const press = findChild(control, "press");
        compare(press.opacity, 0);
        compare(press.color, Tokens.color.hover);
        compare(press.radius, Tokens.radiusS);
        mousePress(control, 10, 10);
        tryCompare(press, "opacity", 1);
        mouseRelease(control, 10, 10);
    }

    function test_space_and_enter_press_a_control_and_a_click_gives_no_focus() {
        const control = createTemporaryObject(buttonComponent, testCase, { x: 40, y: 40 });
        const clicked = createTemporaryObject(spy, testCase, { target: control });
        mouseClick(control, 10, 10);
        compare(clicked.count, 1);
        verify(!control.activeFocus);
        verify(control.activeFocusOnTab);
        control.forceActiveFocus();
        verify(findChild(control, "box").children.some(child => child instanceof FocusRing && child.visible));
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Return);
        compare(clicked.count, 3);
    }

    function test_a_disabled_control_stays_focusable_is_read_with_its_reason_and_does_not_act() {
        const control = createTemporaryObject(buttonComponent, testCase, { x: 40, y: 40, disabledReason: "comes with the palette" });
        const clicked = createTemporaryObject(spy, testCase, { target: control });
        compare(control.implicitWidth, findChild(control, "box").width, "no reason beside it");
        compare(control.Accessible.description, "comes with the palette");
        compare(findChild(control, "label").color, Tokens.color.disabled);
        mousePress(control, 10, 10);
        wait(Tokens.durationShort + 50);
        compare(findChild(control, "press").opacity, 0, "no press colour on a disabled control");
        mouseRelease(control, 10, 10);
        control.forceActiveFocus();
        verify(control.activeFocus);
        keyClick(Qt.Key_Space);
        compare(clicked.count, 0);
    }

    function test_a_disabled_control_s_reason_is_its_tooltip() {
        const control = createTemporaryObject(buttonComponent, testCase, { x: 40, y: 200, disabledReason: "comes with the palette" });
        const box = findChild(control, "box");
        mouseMove(testCase, 5, 5);
        mouseMove(box);
        compare(Tips.target, null, "not before tip-delay");
        tryCompare(Tips, "target", box, Tokens.durationTipDelay * 2);
        compare(Tips.text, "comes with the palette");
        mousePress(box);
        compare(Tips.target, null, "a press hides it");
        mouseRelease(box);
        mouseMove(testCase, 5, 5);
        control.forceActiveFocus();
        compare(Tips.target, box, "keyboard focus shows it at once");
        control.focus = false;
        compare(Tips.target, null, "and the focus leaving hides it");
        control.disabledReason = "";
        control.forceActiveFocus();
        compare(Tips.target, null, "a control that can act has no tip");
    }

    function test_a_control_s_tooltip_rises_above_it_and_stays_inside_the_window() {
        makeScene({});
        const messages = findChild(named("messages"), "box");
        const at = messages.mapToItem(bar, 0, 0);
        const place = bar.tipPlace(messages, Qt.size(120, 24));
        compare(place.side, "above");
        compare(place.y, at.y - Geometry.tipGap - 24, "tip-gap above the control, past the bar's top edge");
        compare(place.x, Math.round(at.x + messages.width / 2 - 60), "centred over it");
        const last = findChild(named("controls"), "box");
        compare(bar.tipPlace(last, Qt.size(300, 24)).x, bar.width - 300 - Tokens.spaceS, "space-s from the window's side");
    }

    function test_away_the_bar_slides_down_out_of_sight_with_ease_out() {
        Prefs.motion = "on";
        makeScene({});
        const slide = findChild(bar, "slide");
        bar.away = true;
        verify(bar.sliding);
        compare(slide.duration, Tokens.durationShort);
        compare(slide.easing.type, Easing.Bezier);
        compare(slide.easing.bezierCurve, Tokens.easeOut);
        tryCompare(bar, "sliding", false, Tokens.durationShort * 4);
        compare(bar.transform[0].y, bar.height);
    }

    function test_back_from_away_the_bar_arrives_with_ease_in() {
        Prefs.motion = "on";
        makeScene({});
        bar.away = true;
        tryCompare(bar, "sliding", false, Tokens.durationShort * 4);
        bar.away = false;
        verify(bar.sliding);
        compare(findChild(bar, "slide").easing.bezierCurve, Tokens.easeIn);
        tryCompare(bar, "sliding", false, Tokens.durationShort * 4);
        compare(bar.transform[0].y, 0);
    }

    function test_under_reduced_motion_the_bar_goes_and_comes_back_at_once() {
        Prefs.motion = "off";
        makeScene({});
        bar.away = true;
        compare(bar.transform[0].y, bar.height);
        verify(!bar.sliding);
        bar.away = false;
        compare(bar.transform[0].y, 0);
    }

    function test_the_bar_is_glass_under_a_hairline_at_the_app_bar_height() {
        makeScene({});
        compare(bar.height, Tokens.appbarHeight);
        compare(bar.color, Tokens.color.glass);
        const hairline = named("hairline");
        compare(hairline.y, 0);
        compare(hairline.height, Geometry.hairline);
        compare(hairline.width, bar.width);
        compare(hairline.color, Tokens.color.textContrastLow);
        for (const control of controls())
            compare(control.y, (Tokens.appbarHeight - Geometry.appBarControl) / 2);
    }

    function test_the_bar_centres_its_items_again_when_its_height_changes() {
        makeScene({});
        bar.height = 0;
        named("pause").text = "pause all";
        bar.height = Tokens.appbarHeight;
        for (const item of controls().concat(named("middle")))
            compare(item.y, Math.round((Tokens.appbarHeight - item.height) / 2), item.objectName);
    }

    function test_the_bar_takes_space_m_padding_when_compact_and_space_xl_sideways() {
        makeScene({ barWidth: 700 });
        compare(bar.padding, Tokens.spaceM);
        scene.barWidth = 760;
        compare(bar.padding, Tokens.spaceXl);
        scene.viewportHeight = 480;
        compare(bar.padding, Tokens.spaceM, "a short viewport is compact");
    }

    function test_with_room_every_control_stays_and_more_is_hidden() {
        makeScene({});
        verify(controls().every(control => control.visible));
        verify(!bar.more.visible);
        compare(named("back").x, bar.padding);
        compare(endOf(named("controls")), bar.width - bar.padding, "the controls after the middle stand at the end");
        compare(named("middle").x, endOf(named("back")) + bar.gap);
        compare(endOf(named("middle")), named("pause").x - bar.gap);
    }

    function test_at_760px_controls_move_into_more_least_important_first() {
        makeScene({ barWidth: 760 });
        const moved = controls().filter(control => control.overflowed);
        const staying = controls().filter(control => !control.overflowed);
        verify(moved.length > 0);
        verify(bar.more.visible);
        const all = controls();
        for (const gone of moved) {
            for (const kept of staying)
                verify(gone.priority < kept.priority || (gone.priority === kept.priority && all.indexOf(gone) > all.indexOf(kept)), `${gone.text} moved before ${kept.text}`);
        }
        verify(rowWidth(staying.concat(bar.more)) <= bar.width - 2 * bar.padding, "what stays fits");
        const lastMoved = moved.reduce((most, control) => control.priority > most.priority ? control : most);
        verify(rowWidth(staying.concat(lastMoved, bar.more)) > bar.width - 2 * bar.padding, "no control moved that would have fit");
        compare(endOf(bar.more), bar.width - bar.padding, "more ends the bar");
    }

    function test_more_is_the_german_word_as_its_text_and_accessible_name() {
        makeScene({ barWidth: 760 });
        compare(bar.more.text, "mehr");
        compare(bar.more.Accessible.name, "mehr");
    }

    function test_more_repeats_the_moved_controls_words_in_their_order_and_nothing_disappears() {
        for (const width of [760, 500, 360]) {
            makeScene({ barWidth: width });
            mouseClick(bar.more, 10, 10);
            verify(bar.menu.open);
            const rows = bar.menu.items();
            const moved = controls().filter(control => control.overflowed);
            compare(rows.map(row => row.text), moved.map(control => control.text), `${width}px`);
            for (const control of controls())
                verify(control.visible !== control.overflowed, `${control.text} is in the bar or in more at ${width}px`);
            bar.menu.close(false);
        }
    }

    function test_a_moved_control_keeps_its_reason_and_choosing_it_in_more_presses_it() {
        makeScene({ barWidth: 360 });
        mouseClick(bar.more, 10, 10);
        const rows = bar.menu.items();
        const messages = rows.find(row => row.text === "messages");
        compare(messages.label, "messages (comes with the panel)");
        verify(messages.disabled);
        const row = rows.find(row => !row.disabled);
        const clicked = createTemporaryObject(spy, testCase, { target: named(row.text) });
        bar.menu.choose(messages);
        verify(bar.menu.open, "a disabled one does nothing");
        bar.menu.choose(row);
        compare(clicked.count, 1);
        verify(!bar.menu.open);
    }

    function test_more_opens_its_menu_above_itself_at_the_trailing_edge() {
        makeScene({ barWidth: 760 });
        mouseClick(bar.more, 10, 10);
        const menu = bar.menu;
        compare(menu.side, "above");
        compare(menu.y + menu.height, bar.more.y - Geometry.floatGap, "space-xs above more");
        compare(menu.x + menu.width, endOf(bar.more), "flush with the trailing edge of more");
        mouseClick(bar.more, 10, 10);
        verify(!menu.open, "more closes it again");
    }

    function test_the_middle_cuts_its_words_before_any_control_moves() {
        makeScene({ viewportHeight: 400 });
        const middle = named("middle");
        const others = controls();
        scene.barWidth = rowWidth(others) + 2 * bar.padding + bar.gap + 60;
        verify(!bar.more.visible);
        verify(others.every(control => control.visible));
        verify(middle.visible);
        compare(middle.width, 60);
        verify(middle.width < middle.implicitWidth);
        verify(findChild(middle, "part 0").width < findChild(middle, "part 0").implicitWidth || findChild(middle, "part 1").truncated);
    }

    function test_the_middle_is_gone_while_more_shows() {
        makeScene({ barWidth: 600 });
        verify(bar.more.visible);
        verify(!named("middle").visible);
    }

    function test_the_last_part_of_the_middle_is_cut_and_the_others_keep_their_words() {
        makeScene({ viewportHeight: 400 });
        const middle = named("middle");
        const first = findChild(middle, "part 0");
        const second = findChild(middle, "part 1");
        scene.barWidth = rowWidth(controls()) + 2 * bar.padding + bar.gap + first.implicitWidth + Tokens.spaceS + 40;
        compare(first.width, first.implicitWidth);
        compare(second.x, Math.ceil(first.implicitWidth) + Tokens.spaceS);
        verify(second.truncated);
        compare(second.font.pixelSize, Tokens.fontSizeXs);
        compare(second.color, Tokens.color.textContrastHigh);
        compare(first.baselineOffset + first.y, second.baselineOffset + second.y, "one baseline");
    }

    function test_a_pinned_middle_keeps_its_words_up_to_half_the_bar_and_the_controls_make_room() {
        makeScene({ barWidth: 820, viewportHeight: 400 });
        const middle = named("middle");
        middle.parts = ["g", "then a place, a section, an item or a command, and the key for each of them in the palette, grouped, with the words of each group"];
        verify(!bar.more.visible, "unpinned, the middle gives way");
        middle.pinned = true;
        verify(middle.implicitWidth > 410);
        compare(middle.width, 410);
        verify(bar.more.visible, "the controls make room");
        verify(middle.visible, "a pinned middle stays while more shows");
        const staying = controls().filter(control => control.visible);
        verify(rowWidth(staying.concat(middle, bar.more)) <= bar.width - 2 * bar.padding);
        const lastMoved = controls().filter(control => control.overflowed).reduce((most, control) => control.priority > most.priority ? control : most);
        verify(rowWidth(staying.concat(lastMoved, middle, bar.more)) > bar.width - 2 * bar.padding, "only as many move as half the bar needs");
        middle.parts = ["g", "then a place"];
        compare(middle.width, middle.implicitWidth, "shorter words keep their own width");
        middle.pinned = false;
        verify(controls().every(control => control.visible), "the controls come back");
    }

    function test_the_centre_item_stays_centred_and_nothing_runs_under_it() {
        for (const width of [1200, 900, 760]) {
            makeScene({ barWidth: width, withCentre: true });
            const centre = named("centre");
            compare(centre.x, Math.round((width - centre.width) / 2), `${width}px`);
            const shown = controls().concat(named("middle"), bar.more).filter(item => item.visible);
            for (const item of shown)
                verify(endOf(item) <= centre.x - bar.gap || item.x >= endOf(centre) + bar.gap, `${item.objectName} keeps clear of the centre at ${width}px`);
            const trailing = shown.filter(item => item.x > centre.x).sort((a, b) => a.x - b.x);
            compare(endOf(trailing[trailing.length - 1]), width - bar.padding, `the trailing side ends the bar at ${width}px`);
            for (let i = 1; i < trailing.length; i++)
                compare(trailing[i].x - endOf(trailing[i - 1]), bar.gap, `the trailing side stands together at ${width}px`);
        }
    }

    function test_the_trailing_side_keeps_a_gap_from_the_centre_item_up_to_the_last_pixel_of_its_room() {
        makeScene({ withCentre: true });
        const centre = named("centre");
        const trailing = controls().slice(1);
        // The trailing side runs from a gap after the centre to the padding; this width gives it exactly its controls.
        const exact = 2 * (rowWidth(trailing) + centre.width / 2 + bar.gap + bar.padding);
        scene.barWidth = exact;
        verify(!bar.more.visible);
        compare(trailing[0].x, endOf(centre) + bar.gap, "at exactly its room it stands a gap from the centre");
        scene.barWidth = exact - 2;
        verify(bar.more.visible, "a pixel less and a control moves into more");
        for (const item of trailing.concat(bar.more).filter(item => item.visible))
            verify(item.x >= endOf(centre) + bar.gap, `${item.objectName} keeps the gap`);
    }

    function test_a_pinned_middle_never_runs_under_the_centre_item() {
        makeScene({ barWidth: 1200, withCentre: true });
        const middle = named("middle");
        middle.pinned = true;
        middle.parts = ["konsole", "a title much longer than the room the leading side of the bar has to give it, longer still than that"];
        verify(middle.width < middle.implicitWidth, "the leading side is full");
        compare(endOf(middle), named("centre").x - bar.gap);
        verify(named("back").overflowed, "the leading control makes room for it");
        verify(middle.visible, "and it stays while more shows");
    }

    function test_only_the_side_that_does_not_fit_gives_up_controls() {
        makeScene({ barWidth: 760, withCentre: true });
        named("back").priority = -1;
        verify(bar.more.visible);
        verify(named("back").visible, "the least important control stays where its side fits");
        verify(controls().slice(1).some(control => control.overflowed));
    }

    function test_among_equally_important_controls_the_last_moves_first() {
        makeScene({ viewportHeight: 400 });
        const first = named("in the background");
        const last = named("controls");
        first.text = last.text;
        compare(first.width, last.width);
        const others = controls().filter(control => control !== first && control !== last);
        scene.barWidth = rowWidth(others.concat(first, bar.more)) + bar.gap + 2 * bar.padding;
        verify(last.overflowed);
        verify(!first.overflowed);
    }

    function test_the_bar_lays_out_again_when_a_word_changes() {
        makeScene({ viewportHeight: 400 });
        const pause = named("pause");
        verify(!bar.more.visible);
        pause.text = "pause every build of every branch, every pull request and every nightly run of the shell and its tests";
        verify(bar.more.visible);
        pause.text = "pause";
        verify(!bar.more.visible);
    }

    function test_contact_sheet() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const sheet = createTemporaryObject(sheetComponent, testCase);
            mouseClick(findChild(sheet, "narrow").more, 10, 10);
            const back = findChild(findChild(sheet, "wide"), "back");
            Tips.show(findChild(back, "box"), back.disabledReason);
            waitForRendering(sheet);
            wait(Tokens.durationFloat + 50);
            grabImage(sheet).save(`appbar-sheet-${theme}.png`);
        }
    }

    // A wide bar with the centre item and a disabled control showing its reason, a bar full at 760px with more open, a
    // pinned middle.
    Component {
        id: sheetComponent

        Rectangle {
            width: 1200
            height: 600
            color: Tokens.color.bg

            // Under the glass: a status fill, so the bar's translucency shows.
            component Ground: Rectangle {
                x: 0
                width: 300
                height: 72
                color: Tokens.color.statusInfoTile
            }

            component Bar: AppBar {
                property alias middle: line

                width: 1200
                viewportHeight: 600
                area: Qt.size(width, 600)
                centre: slot

                AppBarButton { objectName: "back"; icon: "window"; text: "back"; priority: 3; disabledReason: "comes with the palette" }
                AppBarMiddle { id: line; parts: ["konsole", "~/projects: build the shell"] }
                Text { id: slot; text: "14:32"; font.pixelSize: Tokens.fontSizeXs; font.weight: Tokens.fontWeightSemibold; color: Tokens.color.textPrimary }
                AppBarButton { icon: "window"; text: "in the background"; priority: 0 }
                AppBarButton { icon: "bell"; text: "messages"; priority: 2 }
                AppBarButton { icon: "tune"; text: "controls"; priority: 1 }
            }

            Ground { y: 24 }
            Ground { y: 344 }
            Ground { y: 464 }
            Bar { id: wide; objectName: "wide"; y: 40 }
            Bar { objectName: "narrow"; y: 360; width: 760 }
            Bar { y: 480; width: 1000; Component.onCompleted: middle.pinned = true }

            Tooltip {
                readonly property var place: target ? wide.tipPlace(target, Qt.size(width, height)) : { x: 0, y: 0, side: "above" }

                x: wide.x + place.x
                y: wide.y + place.y
                side: place.side
            }
        }
    }
}
