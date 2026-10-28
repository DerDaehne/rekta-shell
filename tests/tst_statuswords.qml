import QtQuick
import QtTest
import State

TestCase {
    id: testCase

    name: "StatusWords"

    Component {
        id: wordsComponent

        StatusWords {}
    }

    function make(flags) {
        return createTemporaryObject(wordsComponent, testCase, flags);
    }

    function texts(model) {
        return model.words.map(word => word.word);
    }

    function test_when_all_is_normal_no_word_stands() {
        compare(make({}).words.length, 0);
    }

    function test_muted_and_do_not_disturb_are_neutral() {
        const model = make({ muted: true, doNotDisturb: true });
        compare(texts(model), ["stumm", "nicht stören"]);
        compare(model.words.map(word => word.status), ["", ""]);
    }

    function test_microphone_battery_and_offline_are_errors_before_the_neutral_words() {
        const model = make({ muted: true, doNotDisturb: true, offline: true, batteryLow: true, batteryPercent: 12 });
        compare(model.deviations.map(word => word.word), ["akku 12 %", "offline", "stumm", "nicht stören"]);
        compare(model.deviations.map(word => word.status), ["error", "error", "", ""]);
    }

    function test_the_errors_keep_their_order() {
        const model = make({ microphoneInUse: true, batteryLow: true, batteryPercent: 9 });
        compare(texts(model), ["mikrofon an", "akku 9 %"]);
        compare(model.words.map(word => word.status), ["error", "error"]);
    }

    function test_four_deviations_show_two_words_and_plus_two() {
        const model = make({ microphoneInUse: true, offline: true, muted: true, doNotDisturb: true });
        compare(texts(model), ["mikrofon an", "offline", "+2"]);
        compare(model.words[2].opens, "");
    }

    function test_a_word_opens_the_place_where_it_can_be_changed() {
        const model = make({ microphoneInUse: true, offline: true, muted: true, doNotDisturb: true, batteryLow: true });
        compare(model.deviations.map(word => word.opens), ["sound", "power", "connections", "sound", "doNotDisturb"]);
    }

    function test_every_word_names_what_it_opens() {
        compare(make({ muted: true }).words[0].name, "stumm, öffnet ton");
        compare(make({ offline: true }).words[0].name, "offline, öffnet verbindungen");
    }

    function test_the_keys_cover_every_word_that_can_stand() {
        const model = make({ microphoneInUse: true, batteryLow: true, offline: true, muted: true, doNotDisturb: true });
        for (const word of model.words.concat(model.deviations))
            verify(model.keys.includes(word.key), word.key);
        verify(model.keys.includes("more"));
    }
}
