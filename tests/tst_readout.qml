import QtQuick
import QtTest
import Readout

TestCase {
    id: testCase

    name: "Readout"

    Component {
        id: readoutComponent

        KeyReadout {
            volume: 0.81
            micVolume: 0.4
            brightnessMax: 255
            layoutName: "English (US)"
        }
    }

    SignalSpy {
        id: pressed

        signalName: "pressed"
    }

    property var readout

    function init() {
        readout = createTemporaryObject(readoutComponent, testCase);
        pressed.target = readout;
        pressed.clear();
    }

    function test_a_volume_key_shows_the_volume_in_percent() {
        for (const action of ["increase_volume", "decrease_volume", "increase_volume_small", "decrease_volume_small"]) {
            pressed.clear();
            readout.shortcutPressed("kmix", action);
            compare(pressed.count, 1, action);
            compare(readout.word, "lautstärke");
            compare(readout.valueText, "81%");
            compare(readout.level, 0.81);
        }
    }

    function test_the_mute_key_shows_the_word_stumm_in_place_of_the_number() {
        readout.muted = true;
        readout.shortcutPressed("kmix", "mute");
        compare(readout.word, "lautstärke");
        compare(readout.valueText, "stumm");
        compare(readout.level, 0);
    }

    function test_the_microphone_keys_show_the_microphone_with_its_state() {
        for (const action of ["mic_mute", "increase_microphone_volume", "decrease_microphone_volume"]) {
            pressed.clear();
            readout.shortcutPressed("kmix", action);
            compare(pressed.count, 1, action);
            compare(readout.word, "mikrofon");
            compare(readout.valueText, "40%");
        }
        readout.micMuted = true;
        compare(readout.valueText, "stumm");
    }

    function test_a_volume_above_100_percent_fills_the_meter_and_says_its_number() {
        readout.volume = 1.5;
        readout.shortcutPressed("kmix", "increase_volume");
        compare(readout.level, 1);
        compare(readout.valueText, "150%");
    }

    function test_the_value_follows_the_system_while_the_display_stands() {
        readout.shortcutPressed("kmix", "increase_volume");
        readout.volume = 0.86;
        compare(readout.valueText, "86%");
        compare(pressed.count, 1);
    }

    function test_a_shortcut_of_another_component_or_another_action_shows_nothing() {
        readout.shortcutPressed("mediacontrol", "increase_volume");
        readout.shortcutPressed("kmix", "something_else");
        readout.shortcutPressed("kmix", "");
        compare(pressed.count, 0);
    }

    function test_a_brightness_change_by_a_key_shows_the_percent_of_the_range() {
        readout.brightnessReported("display0", 51, "powerdevil", "brightness_key");
        compare(pressed.count, 1);
        compare(readout.word, "helligkeit");
        compare(readout.valueText, "20%");
        compare(readout.level, 0.2);
        compare(readout.brightnessDisplay, "display0");
    }

    function test_a_brightness_change_by_anything_else_shows_nothing() {
        readout.brightnessReported("display0", 51, "powerdevil", "slider");
        readout.brightnessReported("display0", 51, "powerdevil", "");
        compare(pressed.count, 0);
        compare(readout.brightness, 0);
    }

    function test_brightness_without_a_known_range_reads_zero_until_the_range_arrives() {
        readout.brightnessMax = 0;
        readout.brightnessReported("display0", 51, "powerdevil", "brightness_key");
        compare(readout.valueText, "0%");
        readout.brightnessMax = 102;
        compare(readout.valueText, "50%");
    }

    function test_a_layout_switch_shows_the_word_tastatur_and_the_layout_name_in_place_of_the_meter() {
        readout.layoutSwitched();
        compare(pressed.count, 1);
        compare(readout.word, "tastatur");
        compare(readout.level, -1);
        compare(readout.valueText, "English (US)");
    }
}
