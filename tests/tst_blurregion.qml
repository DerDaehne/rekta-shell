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
        Prefs.systemReducedTransparency = false;
        region.behind = glass;
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

    function test_no_item_is_no_blur_either_way() {
        region.behind = null;
        compare(region.item, null);
        Prefs.transparency = "normal";
        compare(region.item, null);
    }
}
