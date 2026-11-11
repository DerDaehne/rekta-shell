import QtQuick
import QtTest
import Settings

TestCase {
    name: "Pins"

    readonly property string userFile: JSON.stringify({
        theme: "kept",
        pinned: [
            { id: "org.kde.kate", columns: 3, group: "work" },
            { id: "gone.app" },
            { id: "org.kde.konsole", columns: 2, rows: 2 }
        ]
    })

    function content(text: string): var {
        return Pins.read(text).content;
    }

    function pinned(text: string): var {
        return JSON.parse(text).pinned;
    }

    function test_start_json_holds_a_list_of_desktop_ids_and_sizes() {
        compare(Pins.read('{"pinned": [{"id": "org.kde.kate", "columns": 2}]}').list, [{ id: "org.kde.kate", columns: 2 }]);
        compare(Pins.read('{"pinned": []}').list, [], "nothing pinned is a list too");
    }

    function test_a_missing_file_or_one_without_a_list_shows_the_defaults_and_may_be_written() {
        for (const text of ["", "  \n", '{"theme": "dark"}']) {
            compare(Pins.read(text).list, null, text);
            compare(Pins.read(text).fault, "", text);
        }
    }

    function test_a_file_without_a_json_object_or_with_a_pinned_that_is_no_list_is_broken() {
        for (const text of ["{ broken", "[]", "null", "3", '{"pinned": "kate"}', '{"pinned": {}}']) {
            const read = Pins.read(text);
            compare(read.fault, "broken", text);
            compare(read.list, null, text);
        }
    }

    function test_nothing_is_written_over_a_broken_file() {
        const broken = content('{"pinned": "kate"}');
        compare(Pins.pin(broken, "org.kde.kate"), null);
        compare(Pins.unpin(broken, 0), null);
        compare(Pins.resize(broken, 0, 2, 2), null);
        compare(Pins.move(broken, 0, 1), null);
        compare(Pins.insert(broken, 0, { id: "org.kde.kate" }), null);
    }

    function test_pin_appends_the_app_as_one_unit_and_keeps_every_other_entry_as_written() {
        const written = JSON.parse(Pins.pin(content(userFile), "org.kde.dolphin"));
        compare(written.pinned, [
            { id: "org.kde.kate", columns: 3, group: "work" },
            { id: "gone.app" },
            { id: "org.kde.konsole", columns: 2, rows: 2 },
            { id: "org.kde.dolphin", columns: 1, rows: 1 }
        ]);
        compare(written.theme, "kept");
    }

    function test_pinning_an_app_already_listed_changes_nothing_with_or_without_desktop_ending() {
        compare(Pins.pin(content(userFile), "org.kde.kate"), null);
        compare(Pins.pin(content(userFile), "org.kde.kate.desktop"), null);
        compare(Pins.pin(content(userFile), "gone.app"), null, "an app that is not installed is listed too");
        compare(Pins.pin(content(userFile), ""), null);
    }

    function test_unpin_removes_only_that_entry_counting_on_the_whole_list() {
        compare(pinned(Pins.unpin(content(userFile), 2)), [
            { id: "org.kde.kate", columns: 3, group: "work" },
            { id: "gone.app" }
        ]);
        compare(Pins.unpin(content(userFile), 3), null);
        compare(Pins.unpin(content(userFile), -1), null);
    }

    function test_uninstalled_apps_keep_their_place_through_every_change() {
        const file = content(userFile);
        compare(pinned(Pins.unpin(file, 0))[0].id, "gone.app");
        compare(pinned(Pins.resize(file, 2, 1, 1))[1].id, "gone.app");
        compare(pinned(Pins.move(file, 0, 2)).map(entry => entry.id), ["gone.app", "org.kde.konsole", "org.kde.kate"]);
    }

    function test_resize_keeps_unknown_keys_of_the_file_and_the_entry() {
        const written = JSON.parse(Pins.resize(content(userFile), 0, 2, 1));
        compare(written.pinned[0], { id: "org.kde.kate", columns: 2, rows: 1, group: "work" });
        compare(written.theme, "kept");
        compare(Pins.resize(content(userFile), 3, 1, 1), null);
    }

    function test_an_entry_the_change_does_not_touch_is_not_normalised() {
        compare(pinned(Pins.unpin(content(userFile), 1))[0].columns, 3);
    }

    function test_move_puts_an_entry_at_its_new_place() {
        compare(pinned(Pins.move(content(userFile), 2, 0)).map(entry => entry.id), ["org.kde.konsole", "org.kde.kate", "gone.app"]);
        compare(Pins.move(content(userFile), 1, 1), null);
        compare(Pins.move(content(userFile), 0, 3), null);
    }

    function test_insert_puts_an_entry_back_at_its_place_with_its_keys() {
        const file = content(userFile);
        const removed = file.pinned[0];
        compare(JSON.parse(Pins.insert(content(Pins.unpin(file, 0)), 0, removed)), JSON.parse(userFile));
        compare(pinned(Pins.insert(file, 3, { id: "x" })).length, 4, "at the end is a place too");
        compare(Pins.insert(file, 4, { id: "x" }), null);
    }

    function test_without_a_list_the_first_change_writes_the_defaults_with_it() {
        compare(pinned(Pins.pin(content(""), "org.kde.kate")).map(entry => entry.id),
            ["systemsettings", "org.kde.dolphin", "org.kde.konsole", "org.kde.kate"]);
        const written = JSON.parse(Pins.unpin(content('{"theme": "dark"}'), 1));
        compare(written, { theme: "dark", pinned: [{ id: "systemsettings" }, { id: "org.kde.konsole" }] });
    }

    function test_a_change_writes_indented_json_ending_in_a_newline_and_leaves_its_input_alone() {
        const file = content('{"pinned": []}');
        compare(Pins.pin(file, "org.kde.kate"), '{\n  "pinned": [\n    {\n      "id": "org.kde.kate",\n      "columns": 1,\n      "rows": 1\n    }\n  ]\n}\n');
        compare(file.pinned, []);
    }
}
