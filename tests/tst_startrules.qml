import QtQuick
import QtTest
import Start

TestCase {
    name: "StartRules"

    function doctor(outputs: var): string {
        return JSON.stringify({ outputs: outputs });
    }

    function test_the_primary_output_is_the_enabled_one_with_the_lowest_priority() {
        compare(Rules.primaryOutput(doctor([
            { name: "DP-1", enabled: true, priority: 2 },
            { name: "HDMI-1", enabled: false, priority: 1 },
            { name: "DP-2", enabled: true, priority: 1 }
        ])), "DP-2");
    }

    function test_an_output_whose_priority_was_never_set_counts_as_the_lowest_as_kwin_sorts_it() {
        compare(Rules.primaryOutput(doctor([
            { name: "Virtual-1", enabled: true, priority: 1 },
            { name: "Virtual-0", enabled: true, priority: 0 }
        ])), "Virtual-0");
    }

    function test_without_usable_output_data_there_is_no_primary() {
        compare(Rules.primaryOutput(""), "");
        compare(Rules.primaryOutput("not json"), "");
        compare(Rules.primaryOutput(doctor([{ name: "DP-1", enabled: false, priority: 1 }])), "");
    }

    function test_qts_placeholder_screen_without_an_area_is_no_real_screen() {
        const placeholder = { name: "", width: 0, height: 0 };
        const screen = { name: "Virtual-1", width: 1280, height: 800 };
        compare(Rules.realScreens([placeholder]), []);
        compare(Rules.realScreens([placeholder, screen]), [screen]);
    }

    function test_the_primary_screen_is_the_named_one_else_the_first_and_none_without_a_real_screen() {
        const first = { name: "Virtual-1", width: 1280, height: 800 };
        const second = { name: "Virtual-2", width: 800, height: 1280 };
        compare(Rules.primaryScreen([first, second], "Virtual-2"), second);
        compare(Rules.primaryScreen([first, second], "gone"), first);
        compare(Rules.primaryScreen(Rules.realScreens([{ name: "", width: 0, height: 0 }]), ""), null);
    }

    function test_an_app_starts_in_a_systemd_scope_of_its_own_named_after_its_desktop_file() {
        compare(Rules.scopeCommand("org.kde.konsole", ["konsole", "--new-tab"], 1234),
            ["systemd-run", "--user", "--scope", "--unit=app-org.kde.konsole-1234", "--", "konsole", "--new-tab"]);
    }

    function test_a_unit_name_writes_what_it_cannot_hold_as_systemd_escape_does() {
        compare(Rules.escapeUnitName("org.kde.kate_2"), "org.kde.kate_2");
        compare(Rules.escapeUnitName("my-app 2"), "my\\x2dapp\\x202");
    }

    function test_start_json_holds_a_list_of_desktop_ids_and_sizes() {
        compare(Rules.listedPins('{"pinned": [{"id": "org.kde.kate", "columns": 2}]}'), [{ id: "org.kde.kate", columns: 2 }]);
        compare(Rules.listedPins('{"pinned": []}'), [], "nothing pinned is a list too");
        compare(Rules.listedPins('{"pinned": "kate"}'), null);
        compare(Rules.listedPins("{ broken"), null);
    }

    function test_without_a_pinned_list_plasmas_own_apps_are_pinned_if_installed() {
        const installed = id => id !== "org.kde.dolphin";
        compare(Rules.pinnedTiles(undefined, installed).map(tile => tile.id), ["systemsettings", "org.kde.konsole"]);
    }

    function test_a_pinned_tile_spans_one_or_two_units_and_an_uninstalled_app_is_left_out() {
        const tiles = Rules.pinnedTiles([
            { id: "org.kde.kate.desktop", columns: 2 },
            { id: "gone" },
            { id: "org.kde.konsole", columns: 4, rows: 0 },
            { columns: 1 }
        ], id => id !== "gone");
        compare(tiles, [
            { id: "org.kde.kate", columns: 2, rows: 1 },
            { id: "org.kde.konsole", columns: 2, rows: 1 }
        ]);
    }

    function test_desktop_entries_are_looked_for_in_the_data_home_then_the_data_dirs_as_quickshell_does() {
        compare(Rules.applicationDirs("/h/data", "/h", "/a:/b"), ["/h/data/applications", "/a/applications", "/b/applications"]);
        compare(Rules.applicationDirs("", "/h", ""), ["/h/.local/share/applications", "/usr/local/share/applications", "/usr/share/applications"]);
    }

    // What grep prints over two directories: a file, a NUL, a line.
    readonly property var dirs: ["/u/.local/share/applications", "/usr/share/applications"]
    readonly property string grepped: [
        "/u/.local/share/applications/org.kde.kate.desktop\0Type=Application",
        "/usr/share/applications/org.kde.kate.desktop\0Type=Application",
        "/usr/share/applications/org.kde.kate.desktop\0OnlyShowIn=GNOME;",
        "/usr/share/applications/kde/gnome-only.desktop\0Type=Application",
        "/usr/share/applications/kde/gnome-only.desktop\0OnlyShowIn = GNOME;Unity;",
        "/usr/share/applications/not-kde.desktop\0Type=Application",
        "/usr/share/applications/not-kde.desktop\0NotShowIn=KDE;",
        "/usr/share/applications/kde-only.desktop\0OnlyShowIn=KDE;",
        ""
    ].join("\n")

    function test_the_show_in_lists_are_read_per_desktop_file_id_from_the_first_directory_that_has_the_file() {
        const files = Rules.showIn(grepped, dirs);
        verify(files["org.kde.kate"].OnlyShowIn === undefined, "the user's own copy without the list wins");
        compare(files["kde-gnome-only"].OnlyShowIn, ["GNOME", "Unity"], "a subdirectory joins the ID with a dash");
        compare(files["not-kde"].NotShowIn, ["KDE"]);
        compare(files["kde-only"].OnlyShowIn, ["KDE"]);
    }

    function fakeEntry(id: string, name: string): var {
        return { id: id, name: name };
    }

    function test_under_kde_an_app_only_for_gnome_or_not_for_kde_is_left_out() {
        const entries = [fakeEntry("org.kde.kate", "Kate"), fakeEntry("kde-gnome-only", "Tweaks"), fakeEntry("not-kde", "Files"), fakeEntry("kde-only", "Discover"), fakeEntry("unread", "Zed")];
        const files = Rules.showIn(grepped, dirs);
        compare(Rules.listedApps(entries, files, "KDE").map(app => app.name), ["Discover", "Kate", "Zed"]);
        compare(Rules.listedApps(entries, files, "GNOME").map(app => app.name), ["Files", "Kate", "Tweaks", "Zed"]);
        compare(Rules.listedApps(entries, files, "").map(app => app.name), ["Files", "Kate", "Zed"], "no desktop: only apps without OnlyShowIn");
    }

    function test_the_first_desktop_of_xdg_current_desktop_that_an_entry_names_decides() {
        const file = { OnlyShowIn: ["GNOME"], NotShowIn: ["KDE"] };
        verify(Rules.shown(file, ["GNOME", "KDE"]));
        verify(!Rules.shown(file, ["KDE", "GNOME"]));
    }

    function test_apps_are_listed_a_to_z_whatever_the_case() {
        const entries = [fakeEntry("b", "Blender"), fakeEntry("k", "konsole"), fakeEntry("a", "ark"), fakeEntry("d", "Dolphin")];
        compare(Rules.listedApps(entries, {}, "KDE").map(app => app.name), ["ark", "Blender", "Dolphin", "konsole"]);
    }

    function test_an_app_s_program_is_the_name_of_the_file_its_command_runs() {
        compare(Rules.programName(["/usr/bin/konsole", "--new-tab"]), "konsole");
        compare(Rules.programName(["dolphin"]), "dolphin");
        compare(Rules.programName([]), "");
    }

    function app(name: string, genericName: string, keywords: var, exec: string): var {
        return { id: name.toLowerCase(), name: name, genericName: genericName, keywords: keywords, exec: exec };
    }

    // A–Z, as the app model gives them.
    readonly property var installed: [
        app("Dateien", "Dateiverwaltung", ["files", "explorer"], "dolphin"),
        app("Kate", "Text Editor", ["text"], "kate"),
        app("Konsole", "Terminal", ["terminal", "shell", "prompt"], "konsole"),
        app("Telegram", "Messenger", ["chat"], "telegram-desktop")
    ]

    function hitNames(text: string): var {
        return Rules.hits(installed, text).map(hit => hit.name);
    }

    function test_an_app_is_found_by_its_name_its_generic_name_its_keywords_or_its_program() {
        compare(hitNames("kon"), ["Konsole"]);
        compare(hitNames("term"), ["Konsole"], "a keyword or the generic name");
        compare(hitNames("sole"), ["Konsole"], "inside the name");
        compare(hitNames("dol"), ["Dateien"], "the program");
        compare(hitNames("xyz"), []);
    }

    function test_hits_come_best_first_then_a_to_z() {
        compare(hitNames("te"), ["Telegram", "Kate", "Konsole", "Dateien"], "3, then 2 A–Z, then 1 inside a name");
    }

    function test_space_around_the_typed_text_does_not_count() {
        compare(hitNames("kon "), ["Konsole"]);
    }

    function startedHitNames(text: string, starts: var): var {
        return Rules.hits(installed, text, starts).map(hit => hit.name);
    }

    function test_an_app_started_more_often_comes_before_one_that_matches_as_well_or_better() {
        compare(startedHitNames("te", { dateien: 1 }), ["Dateien", "Telegram", "Kate", "Konsole"]);
        compare(startedHitNames("te", { kate: 3, konsole: 2 }), ["Kate", "Konsole", "Telegram", "Dateien"]);
    }

    function test_apps_started_equally_often_keep_the_order_without_starts() {
        compare(startedHitNames("te", { kate: 2, konsole: 2 }), ["Kate", "Konsole", "Telegram", "Dateien"]);
        compare(startedHitNames("te", {}), hitNames("te"), "no starts, the order as before");
        compare(startedHitNames("te", undefined), hitNames("te"));
    }

    function test_a_start_counts_one_more_without_changing_the_counts_before() {
        const before = { kate: 1 };
        compare(Rules.counted(before, "kate"), { kate: 2 });
        compare(Rules.counted(before, "konsole"), { kate: 1, konsole: 1 });
        compare(before, { kate: 1 });
    }

    function test_counts_survive_a_round_trip_through_the_usage_file_and_a_broken_file_gives_none() {
        const counts = Rules.counted(Rules.counted({}, "kate"), "kate");
        compare(Rules.parseStarts(JSON.stringify(counts)), { kate: 2 });
        compare(Rules.parseStarts(""), {}, "no file");
        compare(Rules.parseStarts("{ not json"), {});
        compare(Rules.parseStarts("[1, 2]"), {});
        compare(Rules.parseStarts("null"), {});
        compare(Rules.parseStarts('{"kate": 2, "a": "x", "b": -1, "c": 1.5, "d": 0}'), { kate: 2 }, "only whole numbers from 1");
    }

    function test_the_usage_file_lives_in_the_state_directory_or_below_the_home() {
        compare(Rules.stateDir("/s", "/h"), "/s/rekta-shell");
        compare(Rules.stateDir("", "/h"), "/h/.local/state/rekta-shell");
        compare(Rules.stateDir(undefined, undefined), "");
    }

    // Applies the steps to `from`, as the hit model takes them.
    function stepped(from: var, to: var): var {
        const list = from.slice();
        for (const step of Rules.steps(from, to)) {
            if (step.remove !== undefined)
                list.splice(step.remove, 1);
            else if (step.move !== undefined)
                list.splice(step.to, 0, ...list.splice(step.move, 1));
            else
                list.splice(step.insert, 0, step.id);
        }
        return list;
    }

    function test_the_hits_change_by_removing_moving_and_inserting_so_a_hit_that_stays_is_kept() {
        compare(stepped(["a", "b", "c", "d"], ["c", "x", "a"]), ["c", "x", "a"]);
        compare(stepped([], ["a", "b"]), ["a", "b"]);
        compare(stepped(["a", "b"], []), []);
        compare(Rules.steps(["a", "b", "c"], ["c", "a"]), [{ remove: 1 }, { move: 1, to: 0 }]);
        compare(Rules.steps(["a", "b"], ["a", "b"]), [], "nothing to do when nothing changes");
    }

    function test_a_typed_key_jumps_to_the_next_name_it_starts_whatever_the_case_round_past_the_end() {
        const names = ["ark", "Dateien", "Dolphin", "Elisa", "dragon"];
        compare(Rules.jumpTarget(names, -1, "d"), 1, "from nothing, the first");
        compare(Rules.jumpTarget(names, 1, "D"), 2, "after the one in focus");
        compare(Rules.jumpTarget(names, 4, "d"), 1, "round past the end");
        compare(Rules.jumpTarget(names, 1, "a"), 0);
        compare(Rules.jumpTarget(names, 0, "a"), 0, "the only one stays");
        compare(Rules.jumpTarget(names, 2, "q"), -1, "none starts with it");
        compare(Rules.jumpTarget([], -1, "a"), -1);
    }

    function test_running_windows_come_most_recently_active_first_then_topmost_first() {
        const windows = [
            { title: "low", lastActivated: 0, stackingOrder: 1 },
            { title: "active", lastActivated: 500, stackingOrder: 0 },
            { title: "high", lastActivated: 0, stackingOrder: 3 },
            { title: "earlier", lastActivated: 200, stackingOrder: 2 }
        ];
        compare(Rules.recentFirst(windows).map(w => w.title), ["active", "earlier", "high", "low"]);
        compare(windows[0].title, "low", "the given list stays as it was");
    }

    function test_windows_without_a_time_follow_the_stacking_order_whatever_order_they_came_in() {
        const windows = [2, 5, 1, 4, 3, 6].map(order => ({ title: `${order}`, lastActivated: 0, stackingOrder: order }));
        compare(Rules.recentFirst(windows).map(w => w.title), ["6", "5", "4", "3", "2", "1"]);
    }

    // A grid of three across with a wide tile below: | a | b | c | over | wide | d |.
    readonly property var rects: [
        { x: 0, y: 0, width: 150, height: 150 },
        { x: 158, y: 0, width: 150, height: 150 },
        { x: 316, y: 0, width: 150, height: 150 },
        { x: 0, y: 158, width: 308, height: 150 },
        { x: 316, y: 158, width: 150, height: 150 }
    ]

    function test_an_arrow_moves_to_the_nearest_tile_that_way_in_the_same_row_or_column() {
        compare(Rules.neighbour(rects[0], rects, "right"), 1);
        compare(Rules.neighbour(rects[2], rects, "left"), 1);
        compare(Rules.neighbour(rects[1], rects, "down"), 3, "the wide tile lies under b too");
        compare(Rules.neighbour(rects[3], rects, "up"), 0, "of a and b, the one in line with its start");
        compare(Rules.neighbour(rects[4], rects, "left"), 3);
    }

    function test_an_arrow_passes_a_nearer_tile_outside_its_row_or_column() {
        const from = { x: 0, y: 0, width: 150, height: 150 };
        const aside = { x: 790, y: 158, width: 150, height: 150 };
        const below = { x: 0, y: 474, width: 150, height: 150 };
        compare(Rules.neighbour(from, [from, aside, below], "down"), 2);
    }

        function test_past_the_last_tile_that_way_an_arrow_finds_none() {
        compare(Rules.neighbour(rects[2], rects, "right"), -1);
        compare(Rules.neighbour(rects[0], rects, "up"), -1);
        compare(Rules.neighbour(rects[4], rects, "down"), -1);
    }
}
