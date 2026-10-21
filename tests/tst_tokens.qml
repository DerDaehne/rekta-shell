import QtQuick
import QtTest
import Rekta

TestCase {
    name: "Tokens"

    function cleanup() {
        Tokens.theme = "light";
        Tokens.density = "compact";
        Tokens.reducedMotion = false;
    }

    function test_fluid_size_clamps_to_min_and_max_and_interpolates_between() {
        const size = { min: 10, max: 20, viewport: 0.01 };
        compare(Tokens.fluid(size, 500), 10);
        compare(Tokens.fluid(size, 1500), 15);
        compare(Tokens.fluid(size, 3000), 20);
    }

    function test_fluid_keeps_a_fixed_size() {
        compare(Tokens.fluid(Tokens.fontSizeM, 3000), Tokens.fontSizeM);
    }

    function test_every_token_font_size_is_fixed_or_fluid() {
        for (const name of ["fontSizeL", "fontSizeTitle", "fontSizeNavActive", "fontSizePivotActive"]) {
            const size = Tokens[name];
            verify(size.min < size.max, name);
            compare(Tokens.fluid(size, 0), size.min, name);
            compare(Tokens.fluid(size, 1e6), size.max, name);
        }
    }

    function test_reduced_motion_sets_every_motion_duration_to_zero() {
        for (const name of Tokens.motionDurations)
            verify(Tokens[name] > 0, name);
        Tokens.reducedMotion = true;
        for (const name of Tokens.motionDurations)
            compare(Tokens[name], 0, name);
    }

    function test_reduced_motion_keeps_timing_durations() {
        const before = Tokens.timingDurations.map(name => Tokens[name]);
        Tokens.reducedMotion = true;
        compare(Tokens.timingDurations.map(name => Tokens[name]), before);
        verify(before.every(ms => ms > 0));
    }

    function test_theme_switches_the_colour_set() {
        compare(Tokens.color, Tokens.light);
        Tokens.theme = "dark";
        compare(Tokens.color, Tokens.dark);
        verify(Tokens.color.bg !== Tokens.light.bg);
    }

    function test_density_switches_control_and_row_sizes() {
        compare(Tokens.controlHeight, Tokens.compact.controlHeight);
        Tokens.density = "comfortable";
        compare(Tokens.controlHeight, Tokens.comfortable.controlHeight);
        compare(Tokens.rowHeight, Tokens.comfortable.rowHeight);
        verify(Tokens.comfortable.controlHeight > Tokens.compact.controlHeight);
    }

    function test_translucent_colours_keep_their_alpha() {
        compare(Tokens.light.bg.a, 1);
        verify(Tokens.light.hover.a > 0 && Tokens.light.hover.a < 0.5, "hover is a faint overlay");
        verify(Tokens.dark.shading.a > 0.5 && Tokens.dark.shading.a < 1, "shading dims, it does not hide");
    }

    function test_easings_are_qt_bezier_curves_ending_at_one() {
        for (const name of ["easeBase", "easeIn", "easeOut", "easePivotGlide"]) {
            const curve = Tokens[name];
            compare(curve.length, 6, name);
            compare(curve[4], 1, name);
            compare(curve[5], 1, name);
        }
    }

    function test_the_typeface_is_the_product_choice() {
        compare(Tokens.fontSans, "Atkinson Hyperlegible Next");
    }
}
