pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "Backdrop"
    visible: true
    when: windowShown
    width: 800
    height: 600

    Component {
        id: backdropComponent

        Backdrop {
            width: 1920
            height: 1080
        }
    }

    function cleanup() {
        Prefs.theme = "system";
    }

    function overlap(a: rect, b: rect): bool {
        return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
    }

    function echoOf(backdrop: Item): Echo {
        return findChild(backdrop, "echo");
    }

    function test_cells_are_the_tile_unit_at_every_screen_width() {
        const echo = createTemporaryObject(echoComponent, testCase);
        compare(echo.cell, Tokens.tileUnit);
    }

    function test_the_echo_is_four_cells_wide_and_three_high_with_space_s_between() {
        const echo = createTemporaryObject(echoComponent, testCase);
        compare(echo.width, 4 * Tokens.tileUnit + 3 * Tokens.spaceS);
        compare(echo.height, 3 * Tokens.tileUnit + 2 * Tokens.spaceS);
    }

    function test_the_pattern_is_six_tiles_wide_one_one_tall_one_wide() {
        const echo = createTemporaryObject(echoComponent, testCase);
        const size = echo.pattern.map(tile => `${tile.columns}x${tile.rows}`);
        compare(size.join(" "), "2x1 1x1 1x1 1x2 1x1 2x1");
    }

    function test_no_two_tiles_overlap_and_all_lie_inside_the_echo() {
        const echo = createTemporaryObject(echoComponent, testCase);
        const boxes = echo.pattern.map(tile => echo.tileRect(tile));
        for (let i = 0; i < boxes.length; i++) {
            verify(boxes[i].x + boxes[i].width <= echo.width && boxes[i].y + boxes[i].height <= echo.height);
            for (let j = i + 1; j < boxes.length; j++)
                verify(!overlap(boxes[i], boxes[j]), `tiles ${i} and ${j} overlap`);
        }
    }

    function test_a_tile_of_one_cell_is_a_cell_in_size_and_a_tall_one_spans_two_rows_and_the_gap() {
        const echo = createTemporaryObject(echoComponent, testCase);
        const small = echo.tileRect(echo.pattern[1]);
        compare(small.width, Tokens.tileUnit);
        compare(small.height, Tokens.tileUnit);
        compare(echo.tileRect(echo.pattern[3]).height, 2 * Tokens.tileUnit + Tokens.spaceS);
    }

    function test_the_tiles_are_surface_mixed_70_percent_into_bg() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const echo = createTemporaryObject(echoComponent, testCase);
            const surface = Tokens.color.surface;
            const bg = Tokens.color.bg;
            fuzzyCompare(echo.tint.r, 0.7 * surface.r + 0.3 * bg.r, 0.005);
            fuzzyCompare(echo.tint.g, 0.7 * surface.g + 0.3 * bg.g, 0.005);
            fuzzyCompare(echo.tint.b, 0.7 * surface.b + 0.3 * bg.b, 0.005);
            compare(echo.tint.a, 1, "no further opacity");
        }
    }

    function test_the_echo_stands_space_xl_from_the_right_edge_and_space_xl_above_the_app_bar() {
        const backdrop = createTemporaryObject(backdropComponent, testCase);
        const echo = echoOf(backdrop);
        compare(echo.x + echo.width, backdrop.width - Tokens.spaceXl);
        compare(echo.y + echo.height, backdrop.height - Tokens.appbarHeight - Tokens.spaceXl);
    }

    function test_the_cell_is_the_same_on_a_wide_and_a_narrow_backdrop() {
        const wide = createTemporaryObject(backdropComponent, testCase, { width: 3072, height: 1728 });
        const narrow = createTemporaryObject(backdropComponent, testCase, { width: 1080, height: 1920 });
        compare(echoOf(wide).cell, Tokens.tileUnit);
        compare(echoOf(narrow).cell, Tokens.tileUnit);
    }

    function test_a_solid_backdrop_is_bg_alone_without_an_echo() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const backdrop = createTemporaryObject(backdropComponent, testCase, { solid: true });
            compare(backdrop.color, Tokens.color.bg);
            compare(echoOf(backdrop), null);
            compare(backdrop.children.length, 1, "only the loader");
            compare(backdrop.children[0].item, null);
        }
    }

    function test_the_backdrop_is_bg_and_follows_the_theme_live() {
        const backdrop = createTemporaryObject(backdropComponent, testCase);
        Prefs.theme = "light";
        compare(backdrop.color, Tokens.light.bg);
        const before = String(echoOf(backdrop).tint);
        Prefs.theme = "dark";
        compare(backdrop.color, Tokens.dark.bg);
        verify(String(echoOf(backdrop).tint) !== before);
    }

    Component {
        id: echoComponent

        Echo {}
    }
}
