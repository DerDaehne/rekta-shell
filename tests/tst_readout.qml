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

    SignalSpy {
        id: news

        signalName: "news"
    }

    property var readout

    function init() {
        readout = createTemporaryObject(readoutComponent, testCase);
        pressed.target = readout;
        pressed.clear();
        news.target = readout;
        news.clear();
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
        readout.brightnessReported(51, 255, "brightness_key");
        compare(pressed.count, 1);
        compare(readout.word, "helligkeit");
        compare(readout.valueText, "20%");
        compare(readout.level, 0.2);
    }

    function test_a_change_of_another_display_or_by_a_slider_leaves_the_key_s_percent_alone() {
        readout.brightnessReported(102, 255, "brightness_key");
        compare(readout.valueText, "40%");
        readout.brightnessReported(100, 100, "");
        readout.brightnessReported(100, 100, "slider");
        compare(readout.valueText, "40%");
        compare(readout.level, 0.4);
    }

    function test_a_brightness_change_by_anything_else_shows_nothing() {
        readout.brightnessReported(51, 255, "slider");
        readout.brightnessReported(51, 255, "");
        compare(pressed.count, 0);
        compare(readout.brightness, 0);
    }

    function test_brightness_without_a_known_range_reads_zero_until_the_range_arrives() {
        readout.brightnessReported(51, 0, "brightness_key");
        compare(readout.valueText, "0%");
        readout.brightnessReported(51, 102, "brightness_key");
        compare(readout.valueText, "50%");
    }

    function test_a_layout_switch_shows_the_word_tastatur_and_the_layout_name_in_place_of_the_meter() {
        readout.layoutSwitched();
        compare(pressed.count, 1);
        compare(readout.word, "tastatur");
        compare(readout.level, -1);
        compare(readout.valueText, "English (US)");
    }

    function told(): var {
        return news.signalArguments.map(args => args[0]);
    }

    function test_a_volume_key_brings_news_only_with_the_value_that_follows_it() {
        readout.shortcutPressed("kmix", "increase_volume");
        compare(news.count, 0);
        readout.volume = 0.86;
        tryCompare(news, "count", 1);
        compare(told(), ["lautstärke 86%"]);
    }

    function test_a_volume_key_then_a_microphone_key_bring_each_value_they_resulted_in_whole_and_nothing_stale() {
        readout.shortcutPressed("kmix", "increase_volume");
        readout.volume = 0.86;
        tryCompare(news, "count", 1);
        readout.shortcutPressed("kmix", "mic_mute");
        readout.micMuted = true;
        tryCompare(news, "count", 2);
        compare(told(), ["lautstärke 86%", "mikrofon stumm"]);
    }

    function test_a_volume_key_at_its_limit_brings_no_news() {
        readout.volume = 1;
        readout.shortcutPressed("kmix", "increase_volume");
        compare(pressed.count, 1);
        readout.volume = 0.95;
        tryCompare(news, "count", 1);
        compare(told(), ["lautstärke 95%"]);
    }

    function test_a_volume_and_its_mute_changing_together_bring_one_piece_of_news() {
        readout.shortcutPressed("kmix", "mute");
        readout.volume = 0.5;
        readout.muted = true;
        tryCompare(news, "count", 1);
        compare(told(), ["lautstärke stumm"]);
    }

    function test_a_change_that_reads_the_same_brings_no_news_and_one_of_another_kind_none_either() {
        readout.shortcutPressed("kmix", "increase_volume");
        readout.volume = 0.812;
        readout.micVolume = 0.3;
        readout.volume = 0.9;
        tryCompare(news, "count", 1);
        compare(told(), ["lautstärke 90%"]);
    }

    function test_a_brightness_key_and_a_layout_switch_bring_their_value_at_once_as_it_came_with_them() {
        readout.brightnessReported(51, 255, "brightness_key");
        compare(told(), ["helligkeit 20%"]);
        readout.layoutSwitched();
        compare(told(), ["helligkeit 20%", "tastatur English (US)"]);
    }
}
