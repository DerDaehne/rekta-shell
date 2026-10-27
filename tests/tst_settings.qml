import QtQuick
import QtTest
import Settings

TestCase {
    id: testCase

    name: "Settings"

    property var layers: null

    Component {
        id: layersComponent

        Layers {
            readonly property bool solid: value("background") === "solid"
        }
    }

    SignalSpy {
        id: writes

        target: testCase.layers
        signalName: "writeRequested"
    }

    function init() {
        layers = createTemporaryObject(layersComponent, this);
        writes.clear();
    }

    function written(): var {
        return JSON.parse(writes.signalArguments[writes.count - 1][0]);
    }

    function test_without_any_file_a_setting_has_the_shells_own_value() {
        compare(layers.value("background"), "rekta");
        verify(!layers.differs("background"));
    }

    function test_a_nix_default_replaces_the_shells_own_value() {
        layers.defaultsText = '{"background":"solid"}';
        compare(layers.value("background"), "solid");
        compare(layers.preset("background"), "solid");
        verify(!layers.differs("background"));
    }

    function test_the_users_value_wins_over_the_nix_default_and_differs_from_it() {
        layers.defaultsText = '{"background":"solid"}';
        layers.userText = '{"version":1,"background":"rekta"}';
        compare(layers.value("background"), "rekta");
        compare(layers.preset("background"), "solid");
        verify(layers.differs("background"));
    }

    function test_a_user_value_equal_to_the_default_does_not_differ() {
        layers.userText = '{"version":1,"background":"rekta"}';
        verify(!layers.differs("background"));
    }

    function test_a_value_of_another_type_than_the_settings_own_is_not_taken() {
        layers.defaultsText = '{"background":"solid"}';
        layers.userText = '{"version":1,"background":3}';
        compare(layers.value("background"), "solid");
        layers.defaultsText = '{"background":true}';
        compare(layers.value("background"), "rekta");
    }

    function test_a_changed_user_file_takes_effect_at_once() {
        verify(!layers.solid);
        layers.userText = '{"version":1,"background":"solid"}';
        verify(layers.solid);
        layers.userText = "";
        verify(!layers.solid);
    }

    function test_a_broken_user_file_leaves_the_defaults_and_is_never_written_over() {
        layers.writable = true;
        layers.defaultsText = '{"background":"solid"}';
        for (const broken of ['{"background":"rekta"', '["rekta"]', '"rekta"', '{"version":"1","background":"rekta"}']) {
            ignoreWarning(/settings.json holds no JSON object/);
            layers.userText = broken;
            compare(layers.fault, "broken", broken);
            compare(layers.value("background"), "solid", broken);
            verify(!layers.set("background", "rekta"), broken);
            layers.userText = "";
        }
        compare(writes.count, 0);
    }

    function test_a_file_of_a_later_version_is_read_but_never_written() {
        layers.writable = true;
        layers.userText = '{"version":2,"background":"solid"}';
        compare(layers.fault, "newer");
        compare(layers.value("background"), "solid");
        verify(!layers.set("background", "rekta"));
        compare(writes.count, 0);
    }

    function test_without_the_write_gate_nothing_is_written() {
        verify(!layers.writable, "the gate starts closed");
        verify(!layers.set("background", "solid"));
        compare(writes.count, 0);
    }

    function test_a_new_user_file_starts_at_version_one() {
        layers.writable = true;
        verify(layers.set("background", "solid"));
        compare(written(), {
            version: 1,
            background: "solid"
        });
    }

    function test_a_write_keeps_every_key_it_does_not_know() {
        layers.writable = true;
        layers.userText = '{"version":1,"later":{"tiles":[1,2]},"background":"rekta"}';
        verify(layers.set("background", "solid"));
        compare(written(), {
            version: 1,
            later: {
                tiles: [1, 2]
            },
            background: "solid"
        });
    }

    function test_only_a_setting_there_is_in_its_own_type_is_written() {
        layers.writable = true;
        verify(!layers.set("unknown", "solid"));
        verify(!layers.set("background", 1));
        compare(writes.count, 0);
    }
}
