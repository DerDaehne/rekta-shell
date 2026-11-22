import QtQuick
import QtTest
import Rekta
import "../shell"

TestCase {
    name: "BlurRegion"

    Item {
        id: glass
    }

    BlurRegion {
        id: region

        behind: glass
    }

    function cleanup() {
        Prefs.transparency = "system";
        Prefs.ground = "normal";
        Prefs.theme = "system";
        Prefs.systemReducedTransparency = false;
        region.behind = glass;
        region.shading = false;
    }

    function test_the_region_covers_its_item_while_transparency_is_normal() {
        compare(region.item, glass);
    }

    function test_less_transparency_takes_the_blur_away_and_normal_brings_it_back() {
        Prefs.transparency = "reduce";
        compare(region.item, null);
        Prefs.transparency = "normal";
        compare(region.item, glass);
    }

    function test_a_system_asking_for_less_transparency_takes_the_blur_away_unless_normal_is_set() {
        Prefs.systemReducedTransparency = true;
        compare(region.item, null);
        Prefs.transparency = "normal";
        compare(region.item, glass);
    }

    function test_the_black_ground_takes_the_blur_away_behind_glass_and_normal_brings_it_back() {
        Prefs.theme = "dark";
        Prefs.ground = "black";
        compare(region.item, null);
        Prefs.ground = "normal";
        compare(region.item, glass);
    }

    function test_the_black_ground_leaves_the_blur_where_the_light_theme_has_its_own_ground() {
        Prefs.theme = "light";
        Prefs.ground = "black";
        compare(region.item, glass);
    }

    function test_a_shading_keeps_its_blur_on_the_black_ground_but_not_under_less_transparency() {
        Prefs.theme = "dark";
        Prefs.ground = "black";
        region.shading = true;
        compare(region.item, glass);
        Prefs.transparency = "reduce";
        compare(region.item, null);
    }

    function test_no_item_is_no_blur_either_way() {
        region.behind = null;
        compare(region.item, null);
        Prefs.transparency = "normal";
        compare(region.item, null);
    }
}
