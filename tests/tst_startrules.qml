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

    function test_without_a_pinned_list_plasmas_own_apps_are_pinned_if_installed() {
        const installed = id => id !== "org.kde.dolphin";
        compare(Rules.pinnedTiles(undefined, installed).map(tile => tile.id), ["systemsettings", "org.kde.konsole"]);
    }

    function test_a_pinned_tile_spans_one_to_four_units_across_and_one_or_two_down_and_an_uninstalled_app_is_left_out() {
        const tiles = Rules.pinnedTiles([
            { id: "org.kde.kate.desktop", columns: 2 },
            { id: "gone" },
            { id: "org.kde.konsole", columns: 4, rows: 0 },
            { columns: 1 },
            null,
            { id: "org.kde.dolphin", columns: 7, rows: 3 }
        ], id => id !== "gone");
        compare(tiles, [
            { id: "org.kde.kate", columns: 2, rows: 1, index: 0 },
            { id: "org.kde.konsole", columns: 4, rows: 1, index: 2 },
            { id: "org.kde.dolphin", columns: 4, rows: 2, index: 5 }
        ], "each keeps its index in the file's list");
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

    function names(prefix: string, count: int): var {
        return Array.from({ length: count }, (_, i) => `${prefix}${String.fromCharCode(97 + i % 26)}${i}`);
    }

    function test_alle_apps_has_a_section_per_initial_a_to_z_with_an_accent_under_its_letter_and_digits_and_signs_in_hash_first() {
        const sections = Rules.letterSections(["3D Viewer", "_scratch", "ark", "Ärger", "Audacity", "Blender", "Écran", "elisa", "Zeal"], 4);
        compare(sections.map(section => section.title), ["#", "a", "b", "e", "z"]);
        compare(sections.map(section => [section.first, section.count]), [[0, 2], [2, 3], [5, 1], [6, 2], [8, 1]]);
    }

    function test_a_section_is_as_many_units_wide_as_its_apps_need_in_the_rows_at_most_six() {
        const units = count => Rules.letterSections(names("k", count), 4)[0].units;
        compare(units(1), 1);
        compare(units(4), 1);
        compare(units(5), 2);
        compare(units(13), 4);
        compare(units(24), 6, "six units hold six times the rows");
        compare(Rules.letterSections(names("k", 5), 1)[0].units, 5, "one row: a unit per app");
    }

    function test_a_letter_with_more_apps_than_six_units_hold_splits_into_near_equal_parts_the_larger_first() {
        compare(Rules.letterSections(names("k", 25), 4).map(part => part.count), [13, 12]);
        compare(Rules.letterSections(names("k", 27), 4).map(part => [part.first, part.count, part.units]), [[0, 14, 4], [14, 13, 4]]);
        compare(Rules.letterSections(names("k", 50), 4).map(part => part.count), [17, 17, 16]);
        compare(Rules.letterSections(names("k", 24), 4).length, 1, "what six units hold stays whole");
    }

    function test_each_part_is_named_by_the_first_two_letters_of_its_first_and_last_app() {
        const kde = ["Kaddressbook", "Kalgebra", "Kate", "KCalc", "KCharSelect", "Kdenlive", "KDiskFree", "KFind", "KGeography", "KHelpCenter", "KInfoCenter", "Kleopatra", "KMahjongg", "KMail", "KolourPaint", "Konsole", "Konversation", "KPat", "Krita", "KRuler", "KSnapshot", "KStars", "KSudoku", "KSysGuard", "KTorrent", "KTurtle", "KWrite"];
        compare(Rules.letterSections(kde, 4).map(part => part.title), ["ka–km", "ko–kw"]);
        compare(Rules.letterSections(["K3b", ...kde.slice(1), "KÖnig"], 4).map(part => part.title), ["kb–km", "ko–ko"], "letters only, lower case, accents dropped");
    }

    function test_stacked_every_initial_is_one_section_one_unit_wide_and_none_splits() {
        const sections = Rules.letterSections(names("k", 60), Infinity);
        compare(sections.length, 1);
        compare(sections[0].title, "k");
        compare(sections[0].count, 60);
        compare(sections[0].units, 1, "one column holds them all");
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

    function test_only_desktop_entries_named_kcm_are_settings_pages() {
        verify(Rules.isSettingsPage("kcm_bluetooth"));
        verify(!Rules.isSettingsPage("org.kde.kate"));
    }

    function test_windows_match_by_title_or_app_the_most_recent_first_among_equals() {
        const windows = [
            { title: "notes", app: "Kate", lastActivated: 5, stackingOrder: 0 },
            { title: "build log", app: "Konsole", lastActivated: 9, stackingOrder: 0 },
            { title: "kate help", app: "Okular", lastActivated: 7, stackingOrder: 0 }
        ];
        compare(Rules.windowHits(windows, "kate").map(entry => entry.title), ["kate help", "notes"]);
        compare(Rules.windowHits(windows, "log").map(entry => entry.title), ["build log"]);
    }

    function test_the_rows_come_in_the_order_windows_settings_commands_and_empty_groups_are_left_out() {
        const noop = () => {};
        const sources = {
            windows: [{ title: "Dateien", app: "", lastActivated: 1, stackingOrder: 0, activate: noop }],
            settings: [{ id: "kcm_x", name: "Datum", genericName: "", keywords: [], exec: "", icon: "", launch: noop }],
            commands: [{ text: "dateien zu", keywords: [], run: noop }],
            decimalPoint: "."
        };
        compare(Rules.rowGroups(sources, "da", {}, true).map(group => group.name), ["fenster", "einstellungen", "befehle"]);
        compare(Rules.rowGroups(sources, "dat", {}, true).map(group => group.name), ["fenster", "einstellungen", "befehle"]);
        compare(Rules.rowGroups(sources, "datu", {}, true).map(group => group.name), ["einstellungen"]);
        compare(Rules.rowGroups(sources, "zzz", {}, true), []);
    }

    function test_only_the_very_first_row_is_the_best_hit_and_only_when_no_app_matches() {
        const noop = () => {};
        const sources = { windows: [], settings: [], commands: [{ text: "sperren", keywords: [], run: noop }, { text: "stumm an", keywords: [], run: noop }], decimalPoint: "." };
        const without = Rules.rowGroups(sources, "s", {}, true);
        compare(without[0].rows.map(row => row.best === true), [true, false]);
        const with_ = Rules.rowGroups(sources, "s", {}, false);
        compare(with_[0].rows.map(row => row.best === true), [false, false]);
    }

    function test_a_command_that_takes_an_amount_is_said_with_it_and_comes_first() {
        const commands = [
            { text: "stumm an", keywords: ["ton"], run: () => {} },
            { word: "ton", at: percent => ({ text: `ton auf ${percent} %`, run: () => {} }) }
        ];
        compare(Rules.commandHits(commands, "ton 30").map(command => command.text), ["ton auf 30 %"]);
        compare(Rules.commandHits(commands, "to 500").map(command => command.text), ["ton auf 100 %"]);
        compare(Rules.commandHits(commands, "ton").map(command => command.text), ["stumm an"]);
    }

    function test_a_key_reply_reads_as_the_first_combination_in_rekta_s_words() {
        compare(Rules.keyText([[[0x10000000 | 0x4c, 0, 0, 0]]]), "Super+L");
        compare(Rules.keyText([[0x10000000 | 0x4c]]), "Super+L");
        compare(Rules.keyText([[0x04000000 | 0x08000000 | 0x01000007]]), "Ctrl+Alt+Delete");
        compare(Rules.keyText([[0x10000000 | 0x01000012]]), "Super+←");
        compare(Rules.keyText([[0x02000000 | 0x01000030]]), "Shift+F1");
        compare(Rules.keyText([[0x20]]), "Space");
    }

    function test_the_modifiers_stand_in_the_order_ctrl_alt_shift_super_whatever_order_their_flags_have() {
        compare(Rules.keyText([[0x10000000 | 0x02000000 | 0x08000000 | 0x04000000 | 0x5a]]), "Ctrl+Alt+Shift+Super+Z");
    }

    function test_a_modifier_that_is_the_whole_shortcut_reads_as_its_name_alone() {
        compare(Rules.keyText([[0x01000022]]), "Super");
        compare(Rules.keyText([[0x10000000 | 0x01000022]]), "Super");
        compare(Rules.keyText([[0x04000000 | 0x01000023]]), "Ctrl+Alt");
    }

    function test_no_key_bound_reads_as_no_text() {
        compare(Rules.keyText([]), "");
        compare(Rules.keyText([[0, 0, 0, 0]]), "");
        compare(Rules.keyText(undefined), "");
        compare(Rules.keyText([[0x01000099]]), "");
        compare(Rules.keyText([[0x10000000 | 0x01000099]]), "", "not the modifiers of a key it cannot name");
    }

    function test_a_command_row_carries_the_key_of_its_command() {
        const sources = { windows: [], settings: [], commands: [{ text: "sperren", keywords: [], key: "Meta L", run: () => {} }, { text: "stumm an", keywords: [], run: () => {} }], decimalPoint: "." };
        compare(Rules.rowGroups(sources, "s", {}, true)[0].rows.map(row => row.key), ["Meta L", ""]);
    }

    function test_a_calculation_comes_first_as_the_best_hit_and_its_row_copies_the_result() {
        const copied = [];
        const sources = {
            windows: [{ title: "table 1 5 3", app: "", lastActivated: 1, stackingOrder: 0, activate: () => {} }],
            settings: [],
            commands: [],
            decimalPoint: ",",
            copy: text => copied.push(text)
        };
        const groups = Rules.rowGroups(sources, "1,5 * 3", {}, true);
        compare(groups.map(group => group.name), ["rechnen", "fenster"]);
        compare(groups[0].rows.map(row => row.text), ["= 4,5"]);
        compare(groups.map(group => group.rows[0].best === true), [true, false]);
        groups[0].rows[0].run();
        compare(copied, ["4,5"]);
        compare(Rules.rowGroups(sources, "1/0", {}, true).map(group => group.name), [], "no row for a division by zero");
    }

    function test_without_any_hit_the_way_on_searches_the_web_for_the_text_and_is_the_best_hit() {
        const opened = [];
        const rows = Rules.waysOut("café & co", "https://search.example/?q=\\{@}&t=kde", url => opened.push(url));
        compare(rows.map(row => row.text), ["„café & co“ im web suchen"]);
        verify(rows[0].best);
        rows[0].run();
        compare(opened, ["https://search.example/?q=caf%C3%A9%20%26%20co&t=kde"]);
        compare(Rules.waysOut("café", "", url => opened.push(url)), [], "none without a web search");
    }

    function test_kde_searches_the_web_with_the_default_web_shortcut_or_kio_s_own_while_none_is_set() {
        compare(Rules.defaultWebShortcut("[General]\nDefaultWebShortcut=ecosia\n"), "ecosia");
        compare(Rules.defaultWebShortcut("[General]\nDefaultWebShortcut[$i]=qwant\n"), "qwant", "with a KConfig flag");
        compare(Rules.defaultWebShortcut(""), "duckduckgo");
        compare(Rules.defaultWebShortcut("[Other]\nDefaultWebShortcut=ecosia\n"), "duckduckgo", "only [General] counts");
    }

    function test_no_web_search_while_web_shortcuts_are_off_or_the_user_chose_none() {
        compare(Rules.defaultWebShortcut("[General]\nEnableWebShortcuts=false\nDefaultWebShortcut=ecosia\n"), "");
        compare(Rules.defaultWebShortcut("[General]\nDefaultWebShortcut=\n"), "");
    }

    // What grep prints over a provider's files: a file, a NUL, a line, as the file writes \{@}.
    readonly property var providerFiles: ["/u/share/kf6/searchproviders/p.desktop", "/usr/share/kf6/searchproviders/p.desktop"]

    function providerLine(file: int, line: string): string {
        return `${providerFiles[file]}\0${line}`;
    }

    function test_a_provider_s_search_address_comes_from_its_first_file_for_the_locale_else_its_own() {
        const both = [providerLine(1, "Query=https://system.example/?q=\\\\{@}"), providerLine(0, "Query=https://user.example/?q=\\\\{@}"), providerLine(0, "Query[de]=https://user.example/de?q=\\\\{@}"), ""].join("\n");
        compare(Rules.providerQuery(both, providerFiles, "de_DE"), "https://user.example/de?q=\\{@}", "the user's file, in German");
        compare(Rules.providerQuery(both, providerFiles, "fr_FR"), "https://user.example/?q=\\{@}", "its own without one for the locale");
        compare(Rules.providerQuery(providerLine(1, "Query=https://system.example/?q=\\\\{@}"), providerFiles, "C"), "https://system.example/?q=\\{@}", "the system's while the user has none");
    }

    function test_a_provider_s_search_address_for_the_whole_locale_comes_before_the_one_for_its_language() {
        const all = [providerLine(0, "Query=https://user.example/?q=\\\\{@}"), providerLine(0, "Query[pt]=https://user.example/pt?q=\\\\{@}"), providerLine(0, "Query[pt_BR]=https://user.example/br?q=\\\\{@}"), ""].join("\n");
        compare(Rules.providerQuery(all, providerFiles, "pt_BR"), "https://user.example/br?q=\\{@}");
        compare(Rules.providerQuery(all, providerFiles, "pt_PT"), "https://user.example/pt?q=\\{@}");
    }

    function test_a_provider_without_a_file_or_a_place_for_the_text_gives_no_search_address() {
        compare(Rules.providerQuery("", providerFiles, "de_DE"), "");
        compare(Rules.providerQuery(providerLine(0, "Query=https://user.example/?q=\\\\{1}"), providerFiles, "de_DE"), "");
    }
}
