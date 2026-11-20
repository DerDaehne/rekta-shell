pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import Start

// The installed apps as Apps reads them over Quickshell's stand-ins (tests/stand-ins): the list and the settings pages,
// what a read that finds every entry alike leaves unchanged, and the icons it looks up. The test installs the entries
// and hands each read what grep would print, as the stand-in Process never runs.
// Lint reads Quickshell's own types, which lack what the stand-ins add for the test.
// qmllint disable missing-property read-only-property
TestCase {
    id: testCase

    name: "Apps"

    // What the launcher was asked to start: [entry] for an app, [entry, action] for a desktop action.
    property var launched: []
    property var apps
    property var konsole
    property var dolphin
    property var firefox
    property var kate
    property var notes
    property var tweaks
    // What each desktop file ID's Implements key lists, by ID.
    property var implementing: ({})
    property var display
    property var sound

    Component {
        id: appsComponent

        Apps {
            launcher: QtObject {
                function launch(entry: var) {
                    testCase.launched = [...testCase.launched, [entry]];
                }

                function launchAction(entry: var, action: var) {
                    testCase.launched = [...testCase.launched, [entry, action]];
                }
            }
            usage: QtObject {
                function count(id: string) {
                }
            }
        }
    }

    Component {
        id: entryComponent

        DesktopEntry {}
    }

    Component {
        id: actionComponent

        DesktopAction {}
    }

    SignalSpy {
        id: listSpy

        signalName: "listChanged"
    }

    SignalSpy {
        id: settingsSpy

        signalName: "settingsChanged"
    }

    function entry(id: string, name: string, icon: string, actions: var): var {
        return createTemporaryObject(entryComponent, testCase, {
            id: id,
            name: name,
            genericName: `${name} app`,
            keywords: [name.toLowerCase(), "tool"],
            command: [`/usr/bin/${name.toLowerCase()}`, "%U"],
            icon: icon,
            actions: actions
        });
    }

    function action(id: string, name: string): var {
        return createTemporaryObject(actionComponent, testCase, {
            id: id,
            name: name,
            command: ["run", `--${id}`]
        });
    }

    // Five apps KDE shows, one only GNOME shows, and two System Settings pages, which carry NoDisplay.
    function makeEntries() {
        konsole = entry("org.kde.konsole", "Konsole", "utilities-terminal", []);
        dolphin = entry("org.kde.dolphin", "Dolphin", "system-file-manager", [action("home", "Persönlicher Ordner")]);
        firefox = entry("firefox", "Firefox", "firefox", [action("new-window", "New Window"), action("new-private-window", "New Private Window")]);
        kate = entry("org.kde.kate", "Kate", "kate", []);
        notes = entry("org.example.notes", "Notes", "notes", []);
        tweaks = entry("org.gnome.tweaks", "Tweaks", "tweaks", []);
        display = entry("kcm_kscreen", "Anzeige", "preferences-desktop-display", []);
        sound = entry("kcm_pulseaudio", "Ton", "audio-volume-high", []);
    }

    function install(shown: var) {
        DesktopEntries.applications = {
            values: shown
        };
        DesktopEntries.hidden = [display, sound];
    }

    // What Rules.desktopFileKeys() makes of grep's output over these entries' files.
    function files(): var {
        const all = {};
        for (const known of [...DesktopEntries.applications.values, ...DesktopEntries.hidden])
            all[known.id] = {
                path: `/usr/share/applications/${known.id}.desktop`
            };
        all["org.gnome.tweaks"].OnlyShowIn = ["GNOME"];
        for (const [id, interfaces] of Object.entries(implementing))
            all[id].Implements = interfaces;
        return all;
    }

    function lookups(name: string): int {
        return Quickshell.lookedUp.filter(looked => looked === name).length;
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        launched = [];
        implementing = {};
        makeEntries();
        install([konsole, dolphin, firefox, kate, notes, tweaks]);
        Quickshell.themeIcons = ["utilities-terminal", "system-file-manager", "firefox", "kate", "preferences-desktop-display"];
        Quickshell.lookedUp = [];
        apps = createTemporaryObject(appsComponent, testCase);
        listSpy.target = apps;
        settingsSpy.target = apps;
        listSpy.clear();
        settingsSpy.clear();
    }

    function cleanup() {
        DesktopEntries.applications = {
            values: []
        };
        DesktopEntries.hidden = [];
        Quickshell.themeIcons = [];
    }

    function test_a_read_lists_the_apps_this_desktop_shows_a_to_z_and_the_settings_pages_as_described() {
        apps.read(files());
        compare(apps.list.map(app => [app.id, app.name, app.genericName, app.exec, app.icon]), [["org.kde.dolphin", "Dolphin", "Dolphin app", "dolphin", "image://icon/system-file-manager"], ["firefox", "Firefox", "Firefox app", "firefox", "image://icon/firefox"], ["org.kde.kate", "Kate", "Kate app", "kate", "image://icon/kate"], ["org.kde.konsole", "Konsole", "Konsole app", "konsole", "image://icon/utilities-terminal"], ["org.example.notes", "Notes", "Notes app", "notes", ""]]);
        compare(apps.list[1].keywords, ["firefox", "tool"]);
        compare(apps.list[1].actions.map(desktopAction => [desktopAction.id, desktopAction.text]), [["desktop/firefox/new-window", "New Window"], ["desktop/firefox/new-private-window", "New Private Window"]]);
        compare(apps.settings.map(page => [page.id, page.name, page.exec, page.icon]), [["kcm_kscreen", "Anzeige", "", "image://icon/preferences-desktop-display"], ["kcm_pulseaudio", "Ton", "", ""]]);
        compare(listSpy.count, 1);
        compare(settingsSpy.count, 1);
    }

    function test_an_item_carries_the_words_the_search_finds_it_by_and_a_changed_entry_its_new_ones() {
        apps.read(files());
        compare(apps.list.find(app => app.id === "org.kde.kate").wordLine, " kate kate app kate tool kate");
        kate.keywords = ["kate", "tool", "editor"];
        apps.read(files());
        compare(apps.list.find(app => app.id === "org.kde.kate").wordLine, " kate kate app kate tool editor kate");
    }

    function test_a_read_that_finds_every_entry_alike_changes_neither_list() {
        apps.read(files());
        const list = apps.list;
        const settings = apps.settings;
        apps.read(files());
        apps.read(files());
        verify(apps.list === list, "the same list");
        verify(apps.settings === settings, "the same pages");
        compare(listSpy.count, 1);
        compare(settingsSpy.count, 1);
    }

    function test_an_entry_that_changed_gets_a_new_item_and_every_other_app_keeps_its_own() {
        apps.read(files());
        const before = apps.list;
        kate.name = "Kate Editor";
        apps.read(files());
        compare(listSpy.count, 2);
        compare(apps.list.map(app => app.name), ["Dolphin", "Firefox", "Kate Editor", "Konsole", "Notes"]);
        verify(apps.list[2] !== before[2], "a new item for Kate");
        verify([0, 1, 3, 4].every(k => apps.list[k] === before[k]), "the others' own items");
        compare(settingsSpy.count, 1);
    }

    function test_an_entry_whose_one_field_changed_gets_a_new_item_with_it_data() {
        return [
            {
                tag: "a desktop action more",
                id: "firefox",
                change: () => firefox.actions = [...firefox.actions, action("profile-manager", "Profile Manager")],
                shown: item => item.actions.map(desktopAction => desktopAction.text),
                expected: ["New Window", "New Private Window", "Profile Manager"]
            },
            {
                tag: "keywords",
                id: "org.kde.kate",
                change: () => kate.keywords = ["kate", "tool", "editor"],
                shown: item => item.keywords,
                expected: ["kate", "tool", "editor"]
            },
            {
                tag: "generic name",
                id: "org.kde.kate",
                change: () => kate.genericName = "Text Editor",
                shown: item => item.genericName,
                expected: "Text Editor"
            },
            {
                tag: "the interfaces it implements",
                id: "org.kde.kate",
                change: () => testCase.implementing = {
                    "org.kde.kate": ["rekta.Actions1"]
                },
                shown: item => item.implements,
                expected: ["rekta.Actions1"]
            },
            {
                tag: "program",
                id: "org.kde.kate",
                change: () => kate.command = ["/usr/bin/kwrite", "%U"],
                shown: item => item.exec,
                expected: "kwrite"
            }
        ];
    }

    function test_an_entry_whose_one_field_changed_gets_a_new_item_with_it(data) {
        apps.read(files());
        const before = apps.list.find(app => app.id === data.id);
        data.change();
        apps.read(files());
        compare(listSpy.count, 2);
        const item = apps.list.find(app => app.id === data.id);
        verify(item !== before, "a new item");
        compare(data.shown(item), data.expected);
    }

    function test_an_app_installed_then_removed_changes_the_list_each_time_and_the_others_keep_their_items() {
        apps.read(files());
        const before = apps.list;
        const elisa = entry("org.kde.elisa", "Elisa", "elisa", []);
        install([konsole, dolphin, firefox, kate, notes, tweaks, elisa]);
        apps.read(files());
        compare(apps.list.map(app => app.name), ["Dolphin", "Elisa", "Firefox", "Kate", "Konsole", "Notes"]);
        verify(before.every(app => apps.list.includes(app)), "the others' own items");
        install([konsole, dolphin, firefox, kate, notes, tweaks]);
        apps.read(files());
        compare(apps.list.map(app => app.name), ["Dolphin", "Firefox", "Kate", "Konsole", "Notes"]);
        verify(apps.list.every((app, k) => app === before[k]), "the items from before");
        compare(listSpy.count, 3);
    }

    // Quickshell makes a new object on every scan for an entry whose ID two data directories hold, and deletes the old.
    function test_an_entry_held_by_a_new_object_keeps_its_item_which_then_starts_the_new_object() {
        apps.read(files());
        const item = apps.list.find(app => app.id === "firefox");
        const again = entry("firefox", "Firefox", "firefox", [action("new-window", "New Window"), action("new-private-window", "New Private Window")]);
        install([konsole, dolphin, again, kate, notes, tweaks]);
        apps.read(files());
        compare(listSpy.count, 1);
        verify(apps.list.find(app => app.id === "firefox") === item, "the same item");
        item.launch();
        item.actions[1].run();
        compare(launched.length, 2);
        verify(launched[0][0] === again, "the app started from its new object");
        verify(launched[1][0] === again && launched[1][1] === again.actions[1], "the action from the new one's");
    }

    function test_an_icon_is_looked_up_once_whether_found_or_missing() {
        apps.read(files());
        apps.read(files());
        apps.read(files());
        compare(lookups("kate"), 1);
        compare(lookups("preferences-desktop-display"), 1);
        compare(lookups("notes"), 1);
        compare(lookups("audio-volume-high"), 1);
    }

    function test_an_icon_the_theme_gains_shows_once_its_app_is_listed_anew() {
        apps.read(files());
        Quickshell.themeIcons = [...Quickshell.themeIcons, "notes"];
        apps.read(files());
        compare(apps.list.find(app => app.id === "org.example.notes").icon, "");
        install([konsole, dolphin, firefox, kate, tweaks]);
        apps.read(files());
        install([konsole, dolphin, firefox, kate, notes, tweaks]);
        apps.read(files());
        compare(apps.list.find(app => app.id === "org.example.notes").icon, "image://icon/notes");
        compare(lookups("notes"), 2);
    }

    function test_an_icon_no_entry_names_any_more_is_looked_up_anew_when_an_app_names_it_again() {
        apps.read(files());
        install([konsole, dolphin, firefox, notes, tweaks]);
        Quickshell.themeIcons = Quickshell.themeIcons.filter(name => name !== "kate");
        apps.read(files());
        install([konsole, dolphin, firefox, kate, notes, tweaks]);
        apps.read(files());
        compare(apps.list.find(app => app.id === "org.kde.kate").icon, "");
        compare(lookups("kate"), 2);
    }
}
