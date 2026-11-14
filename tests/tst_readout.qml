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
        readout.layoutSwitched("Deutsch");
        compare(pressed.count, 1);
        compare(readout.word, "tastatur");
        compare(readout.level, -1);
        compare(readout.valueText, "Deutsch");
    }

    function test_each_kind_brings_its_icon_and_a_volume_muted_or_at_nothing_its_muted_one() {
        const cases = [
            { set: () => readout.shortcutPressed("kmix", "increase_volume"), icon: "speaker" },
            { set: () => (readout.muted = true), icon: "speaker-muted" },
            { set: () => { readout.muted = false; readout.volume = 0; }, icon: "speaker-muted" },
            { set: () => readout.shortcutPressed("kmix", "mic_mute"), icon: "microphone" },
            { set: () => (readout.micMuted = true), icon: "microphone-muted" },
            { set: () => { readout.micMuted = false; readout.micVolume = 0; }, icon: "microphone-muted" },
            { set: () => readout.brightnessReported(0, 255, "brightness_key"), icon: "theme" },
            { set: () => readout.layoutSwitched("Deutsch"), icon: "edit" }
        ];
        for (const [i, step] of cases.entries()) {
            step.set();
            compare(readout.icon, step.icon, `step ${i}`);
        }
    }

    // PipeWire tells a value in an event of its own, after the key's: lets the events pending until now run.
    function nextEvent() {
        wait(0);
    }

    function told(): var {
        return news.signalArguments.map(args => args[0]);
    }

    function test_a_volume_key_brings_news_only_with_the_value_that_follows_it() {
        readout.shortcutPressed("kmix", "increase_volume");
        compare(news.count, 0);
        nextEvent();
        readout.volume = 0.86;
        tryCompare(news, "count", 1);
        compare(told(), ["lautstärke 86%"]);
    }

    function test_a_volume_key_then_a_microphone_key_bring_each_value_they_resulted_in_whole_and_nothing_stale() {
        readout.shortcutPressed("kmix", "increase_volume");
        nextEvent();
        readout.volume = 0.86;
        tryCompare(news, "count", 1);
        readout.shortcutPressed("kmix", "mic_mute");
        nextEvent();
        readout.micMuted = true;
        tryCompare(news, "count", 2);
        compare(told(), ["lautstärke 86%", "mikrofon stumm"]);
    }

    function test_a_volume_up_key_at_100_percent_says_100_percent_at_once_as_none_comes_back() {
        readout.volume = 1;
        readout.shortcutPressed("kmix", "increase_volume");
        compare(told(), ["lautstärke 100%"]);
        readout.shortcutPressed("kmix", "increase_volume_small");
        compare(told(), ["lautstärke 100%", "lautstärke 100%"]);
    }

    function test_a_volume_down_key_at_0_percent_muted_says_stumm_at_once() {
        readout.volume = 0;
        readout.muted = true;
        readout.shortcutPressed("kmix", "decrease_volume");
        compare(told(), ["lautstärke stumm"]);
        readout.shortcutPressed("kmix", "decrease_volume_small");
        compare(told(), ["lautstärke stumm", "lautstärke stumm"]);
    }

    function test_a_volume_up_key_at_99_percent_waits_for_the_value_that_comes_back() {
        readout.volume = 0.99;
        readout.shortcutPressed("kmix", "increase_volume");
        compare(news.count, 0);
        nextEvent();
        readout.volume = 1;
        tryCompare(news, "count", 1);
        compare(told(), ["lautstärke 100%"]);
    }

    // plasma-pa unmutes on the way up, mutes at 0 and lowers a volume above the bound to it: each brings a new value.
    function test_a_key_that_still_changes_the_mute_or_the_volume_waits_for_the_value_that_comes_back() {
        const cases = [
            { volume: 1, muted: true, action: "increase_volume", then: { muted: false }, says: "lautstärke 100%" },
            { volume: 0, muted: false, action: "decrease_volume", then: { muted: true }, says: "lautstärke stumm" },
            { volume: 1.2, muted: false, action: "increase_volume", then: { volume: 1 }, says: "lautstärke 100%" },
            { volume: 0.5, muted: true, action: "mute", then: { muted: false }, says: "lautstärke 50%" }
        ];
        for (const each of cases) {
            readout.volume = each.volume;
            readout.muted = each.muted;
            news.clear();
            readout.shortcutPressed("kmix", each.action);
            compare(news.count, 0, each.action);
            nextEvent();
            Object.assign(readout, each.then);
            tryCompare(news, "count", 1);
            compare(told(), [each.says], each.action);
        }
    }

    function test_with_the_volume_allowed_above_100_percent_its_bound_is_150_percent() {
        readout.volumeMax = 1.5;
        readout.volume = 1;
        readout.shortcutPressed("kmix", "increase_volume");
        compare(news.count, 0);
        readout.volume = 1.5;
        readout.shortcutPressed("kmix", "increase_volume");
        compare(told(), ["lautstärke 150%"]);
    }

    function test_the_microphone_volume_keys_say_their_bound_at_once_and_the_microphone_mute_key_always_waits() {
        readout.micVolume = 1;
        readout.shortcutPressed("kmix", "increase_microphone_volume");
        compare(told(), ["mikrofon 100%"]);
        readout.micVolume = 0;
        readout.micMuted = true;
        readout.shortcutPressed("kmix", "decrease_microphone_volume");
        compare(told(), ["mikrofon 100%", "mikrofon stumm"]);
        readout.shortcutPressed("kmix", "mic_mute");
        compare(news.count, 2);
    }

    function test_plasma_pa_s_settings_allow_more_than_100_percent_only_with_raise_maximum_volume_in_general() {
        compare(readout.raisesAboveFull("[General]\nVolumeStep=5\nRaiseMaximumVolume=true\n"), true);
        compare(readout.raisesAboveFull("[General]\nRaiseMaximumVolume[$i]=true"), true);
        compare(readout.raisesAboveFull("[General]\nRaiseMaximumVolume=false"), false);
        compare(readout.raisesAboveFull("[Other]\nRaiseMaximumVolume=true"), false);
        compare(readout.raisesAboveFull("[General]\nVolumeStep=5"), false);
        compare(readout.raisesAboveFull(""), false);
    }

    function test_a_layout_switch_says_the_new_layout_it_brings_and_never_the_one_before() {
        readout.layoutSwitched("Deutsch");
        nextEvent();
        compare(told(), ["tastatur Deutsch"]);
        readout.layoutSwitched("English (US)");
        nextEvent();
        compare(told(), ["tastatur Deutsch", "tastatur English (US)"]);
    }

    function test_a_volume_and_its_mute_changing_together_bring_one_piece_of_news() {
        readout.shortcutPressed("kmix", "mute");
        nextEvent();
        readout.volume = 0.5;
        readout.muted = true;
        tryCompare(news, "count", 1);
        compare(told(), ["lautstärke stumm"]);
    }

    function test_a_change_that_reads_the_same_brings_no_news_and_one_of_another_kind_none_either() {
        readout.shortcutPressed("kmix", "increase_volume");
        nextEvent();
        readout.volume = 0.812;
        nextEvent();
        readout.micVolume = 0.3;
        nextEvent();
        readout.volume = 0.9;
        tryCompare(news, "count", 1);
        compare(told(), ["lautstärke 90%"]);
    }

    function test_a_brightness_key_and_a_layout_switch_bring_their_value_at_once_as_it_came_with_them() {
        readout.brightnessReported(51, 255, "brightness_key");
        compare(told(), ["helligkeit 20%"]);
        readout.layoutSwitched("Deutsch");
        compare(told(), ["helligkeit 20%", "tastatur Deutsch"]);
    }
}
