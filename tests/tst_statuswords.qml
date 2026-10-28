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
        return model.deviations.map(word => word.word);
    }

    function test_when_all_is_normal_no_word_stands() {
        compare(make({}).deviations.length, 0);
    }

    function test_muted_and_do_not_disturb_are_neutral() {
        const model = make({ muted: true, doNotDisturb: true });
        compare(texts(model), ["stumm", "nicht stören"]);
        compare(model.deviations.map(word => word.status), ["", ""]);
    }

    function test_microphone_battery_and_offline_are_errors_before_the_neutral_words() {
        const model = make({ muted: true, doNotDisturb: true, offline: true, batteryLow: true, batteryPercent: 12 });
        compare(texts(model), ["akku 12 %", "offline", "stumm", "nicht stören"]);
        compare(model.deviations.map(word => word.status), ["error", "error", "", ""]);
    }

    function test_the_errors_keep_their_order() {
        const model = make({ microphoneInUse: true, batteryLow: true, batteryPercent: 9 });
        compare(texts(model), ["mikrofon an", "akku 9 %"]);
    }

    function test_a_word_opens_the_place_where_it_can_be_changed() {
        const model = make({ microphoneInUse: true, offline: true, muted: true, doNotDisturb: true, batteryLow: true });
        compare(model.deviations.map(word => word.opens), ["sound", "power", "connections", "sound", "doNotDisturb"]);
    }

    function test_every_word_names_what_it_opens() {
        compare(make({ muted: true }).deviations[0].name, "stumm, öffnet ton");
        compare(make({ offline: true }).deviations[0].name, "offline, öffnet verbindungen");
        compare(make({ doNotDisturb: true }).deviations[0].name, "nicht stören, öffnet anzeige");
    }

    function test_the_battery_word_names_the_energy_profile_or_else_the_group_it_would_stand_in() {
        compare(make({ batteryLow: true, batteryPercent: 5, powerProfiles: true }).deviations[0].name, "akku 5 %, öffnet energieprofil");
        compare(make({ batteryLow: true, batteryPercent: 5, powerProfiles: false }).deviations[0].name, "akku 5 %, öffnet sitzung");
    }

    function test_the_count_of_the_rest_opens_the_controls_at_the_top() {
        const model = make({ muted: true, doNotDisturb: true });
        const more = model.more(model.deviations);
        compare(more.word, "+2");
        compare(more.opens, "");
        compare(more.name, "+2, öffnet steuerung");
    }

    function test_the_count_has_the_error_square_when_a_hidden_word_is_an_error() {
        const model = make({ offline: true, muted: true, doNotDisturb: true });
        compare(model.more(model.deviations.slice(1)).status, "", "the rest are choices");
        compare(model.more(model.deviations).status, "error");
        compare(model.more(model.deviations.slice(0, 1)).status, "error");
    }

    function test_the_keys_cover_every_word_that_can_stand() {
        const model = make({ microphoneInUse: true, batteryLow: true, offline: true, muted: true, doNotDisturb: true });
        for (const word of model.deviations.concat([model.more(model.deviations)]))
            verify(model.keys.includes(word.key), word.key);
    }
}
