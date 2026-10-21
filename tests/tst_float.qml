pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "FloatingSurfaces"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 600

    readonly property size window: Qt.size(1000, 600)

    Component {
        id: surfaceComponent

        FloatSurface {
            area: Qt.size(1000, 600)

            MenuItem {
                text: "open"
            }
        }
    }

    Component {
        id: rowComponent

        MenuItem {
            text: "open"
        }
    }

    Component {
        id: menuSheetComponent

        // One menu with every kind of row, a focused one among them, opened below its control; and a tip above its
        // control. On the current theme's ground.
        Rectangle {
            width: 980
            height: 560
            color: Tokens.color.bg

            IconButton {
                id: more

                objectName: "more"
                x: Tokens.spaceL
                y: Tokens.spaceL
                icon: "more"
                label: "more"
                variant: "quiet"
            }

            Menu {
                objectName: "menu"
                readonly property var at: Placement.float(parent.mapFromItem(more, 0, 0, more.width, more.height), Qt.size(width, height), Qt.size(parent.width, parent.height))

                control: more
                x: at.x
                y: at.y
                side: at.side

                MenuItem { text: "open"; keyHint: "Enter" }
                MenuItem { objectName: "focused"; text: "rename"; keyHint: "F2" }
                MenuItem { text: "print"; disabledReason: "needs a printer" }
                MenuSeparator {}
                MenuLabel { text: "sort by" }
                MenuItem { kind: "radio"; text: "name"; checked: true }
                MenuItem { kind: "radio"; text: "date" }
                MenuSeparator {}
                MenuItem { kind: "checkbox"; text: "show hidden"; checked: true }
                MenuItem { kind: "checkbox"; text: "show sizes" }
            }

            IconButton {
                id: close

                x: 600
                y: 120
                icon: "close"
                label: "close"
            }

            Tooltip {
                readonly property var at: Placement.tip(parent.mapFromItem(close, 0, 0, close.width, close.height), Qt.size(width, height), Qt.size(parent.width, parent.height))

                target: close
                text: "close"
                x: at.x
                y: at.y
                side: at.side
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

    function verifyInside(placed, size, label) {
        const edge = Tokens.spaceS;
        verify(placed.x >= edge && placed.x + size.width <= window.width - edge, `${label}: x ${placed.x}`);
        verify(placed.y >= edge && placed.y + size.height <= window.height - edge, `${label}: y ${placed.y}`);
    }

    function test_a_surface_opens_below_its_control_at_its_leading_edge() {
        const placed = Placement.float(Qt.rect(100, 100, 80, 32), Qt.size(200, 150), window);
        compare(placed.side, "below");
        compare(placed.x, 100);
        compare(placed.y, 132 + Geometry.floatGap);
    }

    function test_with_no_room_below_it_opens_above() {
        const placed = Placement.float(Qt.rect(100, 500, 80, 32), Qt.size(200, 150), window);
        compare(placed.side, "above");
        compare(placed.y, 500 - Geometry.floatGap - 150);
        compare(placed.x, 100);
    }

    function test_with_room_on_neither_side_it_takes_the_larger_and_stays_inside() {
        const below = Placement.float(Qt.rect(100, 100, 80, 32), Qt.size(200, 500), window);
        compare(below.side, "below", "more room below");
        verifyInside(below, Qt.size(200, 500), "below");
        const above = Placement.float(Qt.rect(100, 400, 80, 32), Qt.size(200, 500), window);
        compare(above.side, "above", "more room above");
        verifyInside(above, Qt.size(200, 500), "above");
    }

    function test_near_the_trailing_edge_it_opens_from_the_control_s_trailing_edge() {
        const placed = Placement.float(Qt.rect(900, 100, 80, 32), Qt.size(200, 150), window);
        compare(placed.x, 980 - 200);
        const offRight = Placement.float(Qt.rect(950, 100, 80, 32), Qt.size(200, 150), window);
        compare(offRight.x, window.width - Tokens.spaceS - 200, "a control past the edge opens from the window's edge");
    }

    function test_a_surface_never_leaves_the_window() {
        const size = Qt.size(250, 300);
        for (let x = -40; x <= 1040; x += 60) {
            for (let y = -20; y <= 620; y += 40)
                verifyInside(Placement.float(Qt.rect(x, y, 48, 32), size, window), size, `control at ${x}, ${y}`);
        }
    }

    function test_a_tip_sits_centred_above_its_control() {
        const placed = Placement.tip(Qt.rect(400, 300, 32, 32), Qt.size(60, 25), window);
        compare(placed.side, "above");
        compare(placed.x, 416 - 30);
        compare(placed.y, 300 - Geometry.tipGap - 25);
    }

    function test_a_tip_goes_below_when_there_is_no_room_above() {
        const placed = Placement.tip(Qt.rect(400, 20, 32, 32), Qt.size(60, 25), window);
        compare(placed.side, "below");
        compare(placed.y, 52 + Geometry.tipGap);
    }

    function test_a_tip_keeps_off_the_window_s_sides() {
        compare(Placement.tip(Qt.rect(0, 300, 32, 32), Qt.size(120, 25), window).x, Tokens.spaceS);
        compare(Placement.tip(Qt.rect(980, 300, 20, 32), Qt.size(120, 25), window).x, window.width - Tokens.spaceS - 120);
    }

    function test_a_surface_has_the_ground_a_hairline_edge_and_no_shadow() {
        Prefs.theme = "dark";
        const surface = createTemporaryObject(surfaceComponent, testCase);
        compare(surface.color, Tokens.color.bg);
        compare(surface.border.color, Tokens.color.textContrastMedium);
        compare(surface.border.width, 1);
        compare(surface.radius, Tokens.radiusS);
        surface.open = true;
        const row = surface.rows[0];
        // A Column lays out at polish.
        tryCompare(surface, "height", 2 + 2 * Tokens.spaceXs + Tokens.rowHeight, 1000, "space-xs above the first row and below the last");
        compare(row.mapToItem(surface, 0, 0).y, 1 + Tokens.spaceXs);
        compare(surface.z, Tokens.layerFloat);
    }

    // Only rows that show count, so the width is measured open.
    function test_a_surface_is_as_wide_as_its_widest_row_between_12rem_and_24rem() {
        const surface = createTemporaryObject(surfaceComponent, testCase, { open: true });
        compare(surface.width, 192, "a short row still gets 12rem");
        const row = createTemporaryObject(rowComponent, surface.rows[0].parent, { text: "rename this schedule and every run in it", keyHint: "Ctrl Shift R" });
        compare(surface.width, Math.min(384, row.implicitWidth + 2));
        verify(row.implicitWidth > 192, "the long row widens it");
        row.text = "rename this schedule, every run in it, every note and every file the runs have written, at once";
        compare(surface.width, 384, "at most 24rem");
        surface.area = Qt.size(300, 600);
        compare(surface.width, 300 - 2 * Tokens.spaceM, "less in a narrow window, space-m from its sides");
        surface.area = Qt.size(180, 600);
        compare(surface.width, 192, "the minimum wins, as min-width does");
    }

    function test_a_surface_is_at_most_24rem_or_60_percent_high_and_scrolls_the_rest() {
        const surface = createTemporaryObject(surfaceComponent, testCase, { open: true });
        const column = surface.rows[0].parent;
        for (let i = 0; i < 20; i++)
            createTemporaryObject(rowComponent, column, { text: `run ${i}` });
        surface.area = Qt.size(1000, 800);
        tryCompare(surface, "height", 384);
        surface.area = Qt.size(1000, 600);
        compare(surface.height, 360, "or 60% of the window");
        const scroller = findChild(surface, "scroller");
        verify(scroller.contentHeight > scroller.height);
        verify(scroller.interactive, "it scrolls");
        surface.area = Qt.size(1000, 400);
        compare(surface.height, 240);
    }

    function test_a_surface_comes_in_with_a_fade_and_a_4px_shift_away_from_its_control_over_duration_float() {
        Prefs.motion = "on";
        const surface = createTemporaryObject(surfaceComponent, testCase);
        const comingIn = findChild(surface, "comingIn");
        compare(comingIn.duration, Tokens.durationFloat);
        compare(comingIn.easing.type, Easing.Bezier);
        compare(comingIn.easing.bezierCurve, Tokens.easeIn);
        surface.open = true;
        compare(surface.opacity, 0, "it fades in");
        compare(surface.shift, -4, "below, it comes down from its control");
        tryCompare(surface, "entry", 1, Tokens.durationFloat * 4);
        compare(surface.opacity, 1);
        compare(surface.shift, 0);
        surface.open = false;
        surface.side = "above";
        surface.open = true;
        compare(surface.shift, 4, "above, it rises from its control");
        surface.entry = 0.5;
        compare(surface.shift, 2);
        compare(surface.opacity, 0.5);
    }

    function test_a_surface_leaves_at_once() {
        Prefs.motion = "on";
        const surface = createTemporaryObject(surfaceComponent, testCase, { open: true });
        tryCompare(surface, "entry", 1, Tokens.durationFloat * 4);
        surface.open = false;
        verify(!surface.visible);
        wait(Tokens.durationFloat / 3);
        verify(!surface.visible, "and stays gone, with nothing played out");
    }

    function test_under_reduced_motion_a_surface_is_there_at_once() {
        Prefs.motion = "off";
        const surface = createTemporaryObject(surfaceComponent, testCase);
        surface.open = true;
        verify(surface.visible);
        compare(surface.opacity, 1);
        compare(surface.shift, 0);
    }

    // The menu and the tip follow the one current theme and density, so the sheet is drawn once per pair.
    function test_contact_sheet_of_a_menu_and_a_tip_in_both_themes_and_densities() {
        Prefs.motion = "off";
        for (const theme of ["light", "dark"]) {
            for (const density of ["compact", "comfortable"]) {
                Prefs.theme = theme;
                Prefs.density = density;
                const sheet = createTemporaryObject(menuSheetComponent, testCase);
                const menu = findChild(sheet, "menu");
                menu.open = true;
                findChild(sheet, "focused").forceActiveFocus();
                waitForRendering(sheet);
                grabImage(sheet).save(`float-sheet-${theme}-${density}.png`);
                compare(menu.side, "below", `${theme} ${density}`);
                sheet.destroy();
            }
        }
    }
}
