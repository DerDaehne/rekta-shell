pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import DBusCounterpart
import RektaShell.DBus
import Start
import "../shell/services"

TestCase {
    id: testCase

    name: "Actions"

    readonly property string service: "rekta.Actions"
    readonly property string path: "/rekta/Actions"
    readonly property string iface: "rekta.Actions1"
    readonly property var amountSchema: ({
            type: "object",
            properties: {
                percent: {
                    type: "integer",
                    minimum: 0,
                    maximum: 100
                }
            },
            required: ["percent"]
        })
    // Meta+L as kglobalaccel replies it: a list of key sequences, each a list of Qt key codes.
    readonly property var metaL: [[0x10000000 | 0x4c, 0, 0, 0]]

    // What the commands did, what kglobalaccel replies by action name, and every ActionsChanged the counterpart heard in
    // this file; an interface of an earlier test may still send as it goes, so only the current owner's count.
    property var calls: []
    property var replies: ({})
    property var heardAll: []
    property string owner
    readonly property var heard: heardAll.filter(sender => sender === owner)
    property var commands
    property var exporter
    // The apps the Start lists, as Apps.list has them, and the registry over them and the commands.
    property var apps: null
    property var registry
    property var providers

    Counterpart {
        id: counterpart

        onHeard: sender => testCase.heardAll = [...testCase.heardAll, sender]
    }

    Component {
        id: commandsComponent

        Commands {
            launcher: QtObject {
                property bool starts: true

                function lock() {
                    testCase.calls = [...testCase.calls, "lock"];
                }

                function ask(service: string, path: string, iface: string, method: string, args: var, signature: string, done: var) {
                    const reply = testCase.replies[args[0][1]];
                    if (reply !== undefined)
                        done([reply]);
                }
            }
            panel: QtObject {
                property bool dark: false
                property bool doNotDisturb: false

                function setDark(on: bool) {
                    testCase.calls = [...testCase.calls, `dark ${on}`];
                    dark = on;
                }

                function setDoNotDisturb(on: bool) {
                    testCase.calls = [...testCase.calls, `quiet ${on}`];
                    doNotDisturb = on;
                }
            }
            session: QtObject {
                function show(focusOn: string) {
                    testCase.calls = [...testCase.calls, `banner ${focusOn}`];
                }
            }
            keyMap: QtObject {
                function show() {
                    testCase.calls = [...testCase.calls, "key map"];
                }
            }
            sink: QtObject {
                property var audio: QtObject {
                    property real volume: 0.5
                    property bool muted: false
                }
            }
        }
    }

    Component {
        id: registryComponent

        Actions {
            commands: testCase.commands?.list ?? []
            apps: testCase.apps
            provided: testCase.providers?.list ?? []
        }
    }

    Component {
        id: providersComponent

        ActionProviders {
            sessionDesktop: "rekta"
            apps: testCase.apps
        }
    }

    // Another program on the bus, to own a name the first one has let go, and a client of the shell as other programs are.
    Component {
        id: counterpartComponent

        Counterpart {}
    }

    Component {
        id: clientComponent

        DBusConnection {}
    }

    Component {
        id: exporterComponent

        ActionsInterface {
            sessionDesktop: ""
            entries: testCase.registry?.list ?? []
            shellVersion: "0.1.5+20261122.1830.abc1234"
        }
    }

    // The shell's launcher, as the session's own shell has it: it calls on the bus.
    Launcher {
        id: shellLauncher
    }

    // Starts what a desktop action asks for as the shell's launcher does, at a fixed time, and notes what it would run;
    // an action of an app that runs over D-Bus goes to the shell's launcher.
    readonly property var launcher: QtObject {
        property bool starts: true

        function launchAction(entry: var, action: var) {
            testCase.calls = [...testCase.calls, Rules.launchContext(entry, action.command, 1234)];
        }

        function activateAction(busName: string, actionId: string, done: var) {
            shellLauncher.activateAction(busName, actionId, done);
        }
    }

    function desktopEntry(id: string, name: string, icon: string, actions: var): var {
        return {
            id,
            name,
            icon,
            workingDirectory: "",
            actions
        };
    }

    function desktopAction(id: string, name: string, icon: string, command: var): var {
        return {
            id,
            name,
            icon,
            command
        };
    }

    // The desktop entries as Quickshell reads them: three apps with desktop actions, Dolphin's with one without Exec (it
    // would run over D-Bus) and one without a name, Notes without any icon; an app without actions; one only GNOME shows.
    function desktopEntries(): var {
        const firefox = desktopEntry("firefox", "Firefox", "firefox", [
            desktopAction("new-window", "New Window", "", ["firefox", "--new-window"]),
            desktopAction("new-private-window", "New Private Window", "private-browsing", ["firefox", "--private-window"])
        ]);
        const dolphin = desktopEntry("org.kde.dolphin", "Dolphin", "system-file-manager", [
            desktopAction("home", "Persönlicher Ordner", "user-home", ["dolphin", "--new-window", "~"]),
            desktopAction("background", "Im Hintergrund", "", []),
            desktopAction("nameless", "", "", ["dolphin"])
        ]);
        dolphin.workingDirectory = "/srv/files";
        const notes = desktopEntry("org.example.notes", "Notes", "", [desktopAction("new-note", "New Note", "", ["notes", "--new"])]);
        const kate = desktopEntry("org.kde.kate", "Kate", "kate", []);
        const tweaks = desktopEntry("org.gnome.tweaks", "Tweaks", "tweaks", [desktopAction("reset", "Reset", "", ["gnome-tweaks", "--reset"])]);
        return [firefox, dolphin, notes, kate, tweaks];
    }

    // Two apps that run over D-Bus (DBusActivatable): Text Editor's action has an Exec, Fonts' has none; Fonts' file lies
    // in a subdirectory, so its desktop file ID is not its bus name.
    function dbusEntries(): var {
        const textEditor = desktopEntry("org.gnome.TextEditor", "Text Editor", "org.gnome.TextEditor", [desktopAction("new-window", "New Window", "", ["gnome-text-editor", "--new-window"])]);
        const fonts = desktopEntry("gnome-org.gnome.font-viewer", "Fonts", "org.gnome.font-viewer", [desktopAction("install-font", "Install Font", "font-x-generic", [])]);
        return [textEditor, fonts];
    }

    // The apps as the Start lists them under KDE (Apps.read), with only what the registry reads of them.
    function listedApps(entries: var): var {
        const files = {
            "org.gnome.tweaks": {
                OnlyShowIn: ["GNOME"]
            },
            "org.gnome.TextEditor": {
                path: "/usr/share/applications/org.gnome.TextEditor.desktop",
                DBusActivatable: true
            },
            "gnome-org.gnome.font-viewer": {
                path: "/usr/share/applications/gnome/org.gnome.font-viewer.desktop",
                DBusActivatable: true
            }
        };
        return Rules.listedApps(entries, files, "KDE").map(entry => ({
                    id: entry.id,
                    name: entry.name,
                    implements: [],
                    actions: Rules.desktopActions(entry, Rules.busName(files[entry.id]), testCase.launcher)
                }));
    }


    function initTestCase() {
        verify(counterpart.listen(iface, "ActionsChanged"));
        // A round trip on the counterpart's connection: its subscription has reached the bus.
        counterpart.nameOwner("org.freedesktop.DBus");
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        calls = [];
        counterpart.forgetCalls();
        replies = {};
        owner = "";
        apps = null;
        commands = createTemporaryObject(commandsComponent, testCase);
        providers = createTemporaryObject(providersComponent, testCase);
        registry = createTemporaryObject(registryComponent, testCase);
    }

    function exportFor(sessionDesktop: string): var {
        // An interface of an earlier test may still hold the name until its deferred destruction has run.
        tryVerify(() => counterpart.nameOwner(service) === "");
        exporter = createTemporaryObject(exporterComponent, testCase, {
            sessionDesktop
        });
        if (sessionDesktop === "rekta") {
            tryVerify(() => counterpart.nameOwner(service) !== "");
            owner = counterpart.nameOwner(service);
        }
        return exporter;
    }

    function callShell(iface: string, member: string, args: var): var {
        let answer = null;
        const store = (signature, values, error) => answer = {
            signature,
            values,
            error
        };
        counterpart.replied.connect(store);
        counterpart.call(service, path, iface, member, args);
        tryVerify(() => answer !== null);
        counterpart.replied.disconnect(store);
        return answer;
    }

    function listActions(): var {
        const answer = callShell(iface, "ListActions", []);
        compare(answer.error, "");
        compare(answer.signature, "a(sa{sv})");
        return answer.values[0];
    }

    function invoke(id: var, parameters: var): var {
        return callShell(iface, "Invoke", [id, parameters]);
    }

    function action(id: string): var {
        return listActions().find(entry => entry[0] === id)?.[1];
    }

    // What ListActions says of an action that changes something and can be undone, or of another kind as `more` has it.
    function described(title: string, keywords: var, description: string, more: var): var {
        return Object.assign({
            title,
            keywords,
            readOnly: false,
            destructive: false,
            description,
            consequence: "undoable",
            available: true
        }, more);
    }

    function test_list_actions_names_each_command_with_what_it_does_now() {
        exportFor("rekta");
        compare(listActions(), [["lock", described("sperren", ["lock"], "Locks the session; the user unlocks it with their password.", {})], ["switch-user", described("benutzer wechseln", ["switch", "user"], "Opens the session bar with the focus on switching user; nothing happens until the user chooses it there.", {})], ["logout", described("abmelden", ["logout"], "Opens the session bar with the focus on logging out; the session ends only when the user chooses it there.", {
                    destructive: true,
                    consequence: "irreversible"
                })], ["reboot", described("neu starten", ["reboot", "restart"], "Opens the session bar with the focus on restarting; the computer restarts only when the user chooses it there.", {
                    destructive: true,
                    consequence: "irreversible"
                })], ["shutdown", described("ausschalten", ["shutdown", "power", "off"], "Opens the session bar with the focus on shutting down; the computer shuts down only when the user chooses it there.", {
                    destructive: true,
                    consequence: "irreversible"
                })], ["dark", described("dunkel an", ["dark", "theme"], "Switches the desktop between its light and its dark look. The state is true while it is dark.", {
                    state: false
                })], ["do-not-disturb", described("nicht stören an", ["quiet", "dnd"], "Silences notifications, or lets them through again. The state is true while they are silenced.", {
                    state: false
                })], ["key-map", described("tastenkürzel", ["shortcuts", "keys", "tasten", "hilfe"], "Shows the map of the keyboard shortcuts.", {
                    key: "?",
                    readOnly: true,
                    consequence: "none"
                })], ["mute", described("stumm an", ["mute", "ton"], "Mutes the default audio output, or unmutes it. The state is true while it is muted.", {
                    state: false
                })], ["volume", {
                    title: "ton",
                    parameters: JSON.stringify(amountSchema),
                    readOnly: false,
                    destructive: false,
                    description: "Sets the volume of the default audio output to a percent. The state is the volume in percent.",
                    consequence: "undoable",
                    available: true,
                    state: 50
                }]]);
    }

    function test_the_state_of_a_command_is_its_state_now_and_apart_from_its_title() {
        exportFor("rekta");
        commands.panel.dark = true;
        commands.panel.doNotDisturb = true;
        commands.sink.audio.muted = true;
        commands.sink.audio.volume = 0.3;
        compare(action("dark").state, true);
        compare(action("do-not-disturb").state, true);
        compare(action("mute").state, true);
        compare(action("volume").state, 30);
        compare(action("lock").state, undefined, "a command without a state has none");
    }

    function test_without_an_audio_output_the_sound_commands_stay_listed_as_not_available_with_the_reason() {
        commands.sink = null;
        exportFor("rekta");
        for (const id of ["mute", "volume"]) {
            compare(action(id).available, false, id);
            compare(action(id).reason, "there is no audio output", id);
            compare(action(id).state, undefined, id);
        }
        compare(action("lock").available, true);
        compare(action("lock").reason, undefined, "an action that can run gives no reason");
    }

    function test_invoking_a_command_that_is_not_available_answers_not_done_with_the_reason_and_runs_nothing() {
        commands.sink = null;
        exportFor("rekta");
        for (const [id, parameters] of [["mute", {}], ["volume", {
                    percent: 30
                }]]) {
            compare(invoke(id, parameters), {
                signature: "a{sv}",
                values: [{
                        done: false,
                        reason: "there is no audio output"
                    }],
                error: ""
            }, id);
        }
    }


    function test_the_search_and_the_bus_offer_the_same_commands() {
        exportFor("rekta");
        compare(listActions().map(entry => entry[0]), commands.list.map(command => command.id));
        compare(listActions().map(entry => entry[1].title), commands.list.map(command => command.text ?? command.word));
    }

    function test_invoking_dunkel_switches_it_and_sends_actions_changed_once() {
        exportFor("rekta");
        compare(invoke("dark", {}), {
            signature: "a{sv}",
            values: [{
                    done: true,
                    state: true
                }],
            error: ""
        });
        compare(calls, ["dark true"]);
        tryVerify(() => heard.length === 1);
        compare(action("dark").title, "dunkel aus");
        compare(heard.length, 1, "the list read after the signal brings no second one");
        invoke("do-not-disturb", {});
        tryVerify(() => heard.length === 2);
        compare(action("do-not-disturb").title, "nicht stören aus");
        compare(calls, ["dark true", "quiet true"]);
    }

    function test_a_key_read_later_is_listed_and_announced_and_the_same_key_again_is_not() {
        exportFor("rekta");
        compare(action("lock").key, undefined);
        replies = {
            "Lock Session": metaL
        };
        commands.readKeys();
        tryVerify(() => heard.length === 1);
        compare(action("lock").key, "Super+L");
        commands.readKeys();
        listActions();
        compare(heard.length, 1);
    }

    function test_ton_sets_the_volume_to_the_percent_it_is_given() {
        exportFor("rekta");
        compare(JSON.parse(action("volume").parameters), amountSchema);
        compare(invoke("volume", {
            percent: 30
        }).values, [{
                done: true,
                state: 30
            }]);
        compare(commands.sink.audio.volume, 0.3);
        compare(invoke("volume", {
            percent: 100
        }).error, "");
        compare(commands.sink.audio.volume, 1);
        compare(invoke("volume", {
            percent: 0
        }).error, "");
        compare(commands.sink.audio.volume, 0);
    }

    function test_the_actions_that_end_the_session_only_open_the_banner() {
        exportFor("rekta");
        for (const id of ["logout", "reboot", "shutdown"]) {
            compare(action(id).destructive, true, id);
            compare(invoke(id, {}).error, "", id);
        }
        compare(calls, ["banner logout", "banner reboot", "banner shutdown"]);
    }

    function test_an_unknown_action_and_a_wrong_or_missing_percent_are_refused_and_nothing_runs() {
        exportFor("rekta");
        const unknown = invoke("explode", {});
        compare(unknown.error, "org.freedesktop.DBus.Error.Failed");
        compare(unknown.values, ["there is no action explode"]);
        for (const parameters of [{}, {
                    percent: "dreißig"
                }, {
                    percent: 101
                }, {
                    percent: -1
                }, {
                    percent: 30.5
                }, {
                    percent: true
                }]) {
            const refused = invoke("volume", parameters);
            compare(refused.error, "org.freedesktop.DBus.Error.Failed", JSON.stringify(parameters));
            compare(refused.values, [`volume takes {"percent": a whole number from 0 to 100}`]);
        }
        compare(invoke(5, {}).error, "org.freedesktop.DBus.Error.InvalidArgs", "an id that is no text");
        compare(invoke("dark", "dunkel").error, "org.freedesktop.DBus.Error.InvalidArgs", "parameters that are no dictionary");
        compare(callShell(iface, "Invoke", ["dark"]).error, "org.freedesktop.DBus.Error.InvalidArgs", "no parameters");
        compare(commands.sink.audio.volume, 0.5);
        compare(calls, []);
        compare(listActions().length, 10, "the interface answers on");
    }

    // What the registry holds for each desktop action, without its run().
    function desktopActionsListed(): var {
        return registry.list.slice(commands.list.length).map(entry => ({
                    id: entry.id,
                    text: entry.text,
                    keywords: entry.keywords,
                    app: entry.app,
                    appName: entry.appName,
                    icon: entry.icon
                }));
    }

    function test_the_registry_holds_the_shells_commands_then_each_desktop_action_of_a_listed_app_in_the_apps_words() {
        compare(registry.list, commands.list, "before the apps are read");
        apps = listedApps(desktopEntries());
        compare(registry.list.slice(0, commands.list.length), commands.list);
        const of = (app, appName) => ({
                keywords: [appName],
                app,
                appName
            });
        compare(desktopActionsListed(), [Object.assign(of("org.kde.dolphin", "Dolphin"), {
                        id: "desktop/org.kde.dolphin/home",
                        text: "Persönlicher Ordner",
                        icon: "user-home"
                    }), Object.assign(of("firefox", "Firefox"), {
                        id: "desktop/firefox/new-window",
                        text: "New Window",
                        icon: "firefox"
                    }), Object.assign(of("firefox", "Firefox"), {
                        id: "desktop/firefox/new-private-window",
                        text: "New Private Window",
                        icon: "private-browsing"
                    }), Object.assign(of("org.example.notes", "Notes"), {
                        id: "desktop/org.example.notes/new-note",
                        text: "New Note",
                        icon: ""
                    })], "Dolphin's actions without Exec or name, Kate without actions and Tweaks, shown only in GNOME, bring none");
    }

    function test_list_actions_gives_a_desktop_action_its_app_and_icon_and_the_shells_commands_stay_as_they_were() {
        exportFor("rekta");
        const own = listActions();
        apps = listedApps(desktopEntries());
        const all = listActions();
        compare(all.slice(0, own.length), own);
        const plain = (title, keywords, app) => described(title, keywords, `Runs the "${title}" action of ${keywords[0]}.`, {
                app
            });
        compare(all.slice(own.length), [["desktop/org.kde.dolphin/home", Object.assign(plain("Persönlicher Ordner", ["Dolphin"], "org.kde.dolphin"), {
                            icon: "user-home"
                        })], ["desktop/firefox/new-window", Object.assign(plain("New Window", ["Firefox"], "firefox"), {
                            icon: "firefox"
                        })], ["desktop/firefox/new-private-window", Object.assign(plain("New Private Window", ["Firefox"], "firefox"), {
                            icon: "private-browsing"
                        })], ["desktop/org.example.notes/new-note", plain("New Note", ["Notes"], "org.example.notes")]], "an action without any icon has none");
    }

    function test_invoking_a_desktop_action_starts_its_command_in_a_scope_of_its_app_in_the_apps_directory() {
        apps = listedApps(desktopEntries());
        exportFor("rekta");
        compare(invoke("desktop/org.kde.dolphin/home", {}), {
            signature: "a{sv}",
            values: [{
                    done: true
                }],
            error: ""
        });
        compare(invoke("desktop/firefox/new-private-window", {}).error, "");
        compare(calls, [{
                    command: ["systemd-run", "--user", "--scope", "--unit=app-org.kde.dolphin-1234", "--", "dolphin", "--new-window", "~"],
                    workingDirectory: "/srv/files"
                }, {
                    command: ["systemd-run", "--user", "--scope", "--unit=app-firefox-1234", "--", "firefox", "--private-window"]
                }]);
    }

    function test_a_desktop_action_the_registry_does_not_list_is_refused_and_nothing_starts() {
        apps = listedApps(desktopEntries());
        exportFor("rekta");
        for (const id of ["desktop/org.kde.dolphin/background", "desktop/org.gnome.tweaks/reset", "desktop/firefox", "desktop/firefox/"]) {
            const refused = invoke(id, {});
            compare(refused.error, "org.freedesktop.DBus.Error.Failed", id);
            compare(refused.values, [`there is no action ${id}`], id);
        }
        compare(calls, []);
    }

    function test_an_app_with_desktop_actions_coming_or_going_sends_actions_changed_once_and_a_reread_that_lists_the_same_sends_none() {
        const withoutFirefox = () => desktopEntries().filter(entry => entry.id !== "firefox");
        apps = listedApps(withoutFirefox());
        exportFor("rekta");
        apps = listedApps(desktopEntries());
        tryVerify(() => heard.length === 1);
        apps = listedApps(desktopEntries());
        apps = listedApps([...desktopEntries(), desktopEntry("org.kde.okular", "Okular", "okular", [])]);
        // A round trip on the interface's own connection: a signal it sent before the answer has arrived by now.
        listActions();
        compare(heard.length, 1, "the same actions read again, and an app without actions, bring none");
        apps = listedApps(withoutFirefox());
        tryVerify(() => heard.length === 2);
        listActions();
        compare(heard.length, 2);
    }

    function test_an_app_that_runs_over_dbus_lists_each_named_action_also_one_without_exec() {
        apps = listedApps([...desktopEntries(), ...dbusEntries()]);
        exportFor("rekta");
        const listed = [
            "desktop/org.kde.dolphin/home",
            "desktop/firefox/new-window",
            "desktop/firefox/new-private-window",
            "desktop/gnome-org.gnome.font-viewer/install-font",
            "desktop/org.example.notes/new-note",
            "desktop/org.gnome.TextEditor/new-window"
        ];
        compare(listActions().map(entry => entry[0]).filter(id => id.startsWith("desktop/")), listed, "Dolphin's action without Exec stays out, as Dolphin does not run over D-Bus");
        compare(action("desktop/gnome-org.gnome.font-viewer/install-font"), {
            title: "Install Font",
            keywords: ["Fonts"],
            app: "gnome-org.gnome.font-viewer",
            icon: "font-x-generic",
            readOnly: false,
            destructive: false
            ,description: `Runs the "Install Font" action of Fonts; done is false with the app's D-Bus error as the reason if it cannot be reached or fails.`,
            consequence: "undoable",
            available: true
        });
    }

    function test_invoking_an_action_of_an_app_that_runs_over_dbus_calls_activate_action_on_its_file_name_and_path_and_starts_no_exec() {
        apps = listedApps(dbusEntries());
        exportFor("rekta");
        verify(counterpart.takeName("org.gnome.font-viewer"));
        verify(counterpart.takeName("org.gnome.TextEditor"));
        counterpart.answerAt("/org/gnome/font_viewer", []);
        counterpart.answerAt("/org/gnome/TextEditor", []);
        const invoked = [
            ["desktop/gnome-org.gnome.font-viewer/install-font", "/org/gnome/font_viewer", "install-font"],
            ["desktop/org.gnome.TextEditor/new-window", "/org/gnome/TextEditor", "new-window"]
        ];
        for (const [id, path, actionId] of invoked) {
            compare(invoke(id, {}), {
                signature: "a{sv}",
                values: [{
                        done: true
                    }],
                error: ""
            }, id);
            tryVerify(() => counterpart.lastCall.path === path, 5000, id);
            compare(counterpart.lastCall, {
                path,
                interface: "org.freedesktop.Application",
                member: "ActivateAction",
                args: [actionId, [], {}]
            }, id);
            compare(counterpart.lastSignature, "sava{sv}", id);
        }
        compare(calls, [], "Text Editor's Exec does not run");
        counterpart.releaseName("org.gnome.font-viewer");
        counterpart.releaseName("org.gnome.TextEditor");
    }

    function test_an_action_whose_app_cannot_be_reached_is_logged_as_a_warning_and_invoke_answers_not_done_with_the_bus_error() {
        apps = listedApps(dbusEntries());
        exportFor("rekta");
        compare(counterpart.nameOwner("org.gnome.TextEditor"), "");
        ignoreWarning(/^Launcher: session bus org\.gnome\.TextEditor \/org\/gnome\/TextEditor org\.freedesktop\.Application\.ActivateAction \["new-window",\[\],\{\}\]: org\.freedesktop\.DBus\.Error\.ServiceUnknown: .+$/);
        const answer = invoke("desktop/org.gnome.TextEditor/new-window", {});
        compare(answer.error, "");
        compare(answer.values[0].done, false);
        verify(answer.values[0].reason.startsWith("org.freedesktop.DBus.Error.ServiceUnknown: "), answer.values[0].reason);
        // A round trip on the launcher's own connection: the bus has answered the call before it by now.
        let answered = false;
        shellLauncher.sessionBus.call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetId", [], "", () => answered = true);
        tryVerify(() => answered);
        compare(calls, []);
    }

    function test_the_error_an_app_answers_activate_action_with_is_the_reason_at_most_a_thousand_characters_long() {
        apps = listedApps(dbusEntries());
        exportFor("rekta");
        verify(counterpart.takeName("org.gnome.TextEditor"));
        counterpart.failAt("/org/gnome/TextEditor", "org.gnome.Failed", "e".repeat(5000));
        ignoreWarning(/^Launcher: session bus org\.gnome\.TextEditor .+: org\.gnome\.Failed: e+$/);
        const answer = invoke("desktop/org.gnome.TextEditor/new-window", {});
        compare(answer.error, "");
        compare(answer.values[0].done, false);
        compare(answer.values[0].reason.length, 1000);
        verify(answer.values[0].reason.startsWith("org.gnome.Failed: eee"), answer.values[0].reason.slice(0, 40));
        counterpart.releaseName("org.gnome.TextEditor");
    }

    function test_an_app_that_holds_activate_action_back_leaves_the_shell_answering_and_ends_the_call_with_no_reply_after_the_wait() {
        apps = listedApps(dbusEntries());
        exportFor("rekta");
        verify(counterpart.takeName("org.gnome.TextEditor"));
        counterpart.ignoreAt("/org/gnome/TextEditor");
        compare(shellLauncher.activationTimeout, 20000, "less than the 25 s of a caller that uses the defaults");
        shellLauncher.activationTimeout = 2000;
        ignoreWarning(/^Launcher: session bus org\.gnome\.TextEditor .+: org\.freedesktop\.DBus\.Error\.NoReply: .+$/);
        let held = null;
        const store = (signature, values, error) => {
            if (signature === "a{sv}")
                held = {
                    values,
                    error
                };
        };
        counterpart.replied.connect(store);
        counterpart.call(service, path, iface, "Invoke", ["desktop/org.gnome.TextEditor/new-window", {}]);
        tryVerify(() => counterpart.lastCall.member === "ActivateAction");
        verify(listActions().length > 0, "the shell answers while the app holds the call");
        compare(held, null, "the call is still open");
        tryVerify(() => held !== null);
        counterpart.replied.disconnect(store);
        compare(held.error, "");
        compare(held.values[0].done, false);
        verify(held.values[0].reason.startsWith("org.freedesktop.DBus.Error.NoReply"), held.values[0].reason);
        shellLauncher.activationTimeout = 20000;
        counterpart.releaseName("org.gnome.TextEditor");
    }

    function test_a_session_call_without_arguments_that_fails_is_logged_without_any() {
        ignoreWarning(/^Launcher: session bus org\.freedesktop\.ScreenSaver \/ScreenSaver org\.freedesktop\.ScreenSaver\.GetActive: org\.freedesktop\.DBus\.Error\.ServiceUnknown: .+$/);
        let answer = null;
        shellLauncher.call(false, "org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", "GetActive", [], "", error => answer = error);
        tryVerify(() => answer !== null);
        verify(String(answer).startsWith("org.freedesktop.DBus.Error.ServiceUnknown"), answer);
    }

    readonly property string probeName: "org.example.Prober"
    readonly property string probeId: `provider/${probeName}/`
    readonly property var probeActions: [
        {
            id: "open",
            properties: {
                title: "Open file",
                keywords: ["file", "open"],
                parameters: JSON.stringify({
                    type: "object",
                    properties: {
                        path: {
                            type: "string"
                        }
                    },
                    additionalProperties: true,
                    required: ["path"]
                }),
                readOnly: true,
                icon: "document-open"
            }
        },
        {
            id: "plain",
            properties: {
                title: "Plain"
            }
        },
        {
            id: "wipe",
            properties: {
                title: "Wipe everything",
                destructive: true
            }
        }
    ]

    // The apps the Start lists, among them one whose desktop file says Implements=rekta.Actions1.
    function appsWithProvider(): var {
        return [...listedApps(desktopEntries()), {
                id: probeName,
                name: "Prober",
                iconName: "prober",
                implements: ["rekta.Actions1", "org.example.Other"],
                actions: []
            }];
    }

    // A round trip on the providers' own connection: what it sent before has reached the bus, and so has its answer.
    function settle() {
        let answered = false;
        providers.bus.call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetId", [], "", () => answered = true);
        tryVerify(() => answered);
    }

    function startProvider() {
        counterpart.provide(path, probeActions);
        verify(counterpart.takeName(probeName));
    }

    function stopProvider() {
        counterpart.releaseName(probeName);
        counterpart.failInvokes(false);
        counterpart.failInvokesWithMessage("the provider failed");
    }

    function providedIds(): var {
        return listActions().map(entry => entry[0]).filter(id => id.startsWith("provider/"));
    }

    function test_a_running_provider_lists_its_actions_named_for_its_app_without_a_destructive_one() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => providedIds().length === 2);
        compare(providedIds(), [`${probeId}open`, `${probeId}plain`]);
        compare(action(`${probeId}open`), {
            title: "Open file",
            keywords: ["file", "open"],
            parameters: probeActions[0].properties.parameters,
            readOnly: true,
            destructive: false,
            app: probeName,
            icon: "document-open",
            description: `Runs the "Open file" action of Prober.`,
            consequence: "none",
            available: true
        });
        compare(action(`${probeId}plain`).icon, "prober");
        verify(action(`${probeId}wipe`) === undefined, "a foreign destructive action is not listed");
        stopProvider();
    }

    function test_a_provider_already_running_when_its_app_is_read_is_listed() {
        startProvider();
        exportFor("rekta");
        apps = appsWithProvider();
        tryVerify(() => providedIds().length === 2);
        stopProvider();
    }

    function test_an_invoke_of_a_foreign_destructive_action_is_refused_and_never_reaches_the_provider() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => providedIds().length === 2);
        const refused = invoke(`${probeId}wipe`, {});
        compare(refused.error, "org.freedesktop.DBus.Error.Failed");
        compare(counterpart.callsTo("Invoke"), 0);
        stopProvider();
    }

    // Names the provider's rows: [{id, properties}] as counterpart.provide takes them.
    function row(id: string, properties: var): var {
        return {
            id,
            properties
        };
    }

    function serve(actions: var) {
        counterpart.provide(path, actions);
        verify(counterpart.takeName(probeName));
        tryVerify(() => counterpart.callsTo("ListActions") >= 1);
        settle();
    }

    function test_the_test_bus_starts_the_probe_program_for_a_call_to_its_name() {
        counterpart.claimEchoName();
        counterpart.call(probeName, "/probe", "org.example.Probe", "Ping", []);
        tryVerify(() => counterpart.callsTo("Activated") === 1, 20000);
        // The pending start ends once something owns the name.
        verify(counterpart.takeName(probeName));
        counterpart.releaseName(probeName);
    }

    function test_a_provider_that_announces_a_change_and_quits_is_not_started_again_by_the_shell() {
        counterpart.claimEchoName();
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => providedIds().length === 2);
        counterpart.emitSignal(path, iface, "ActionsChanged", []);
        counterpart.releaseName(probeName);
        counterpart.nameOwner("org.freedesktop.DBus");
        settle();
        tryVerify(() => providedIds().length === 0);
        // Nothing to wait for: a start would come within the bus's round trips, long before this.
        wait(1000);
        compare(counterpart.callsTo("Activated"), 0);
    }

    // Makes the shell believe `believed` owns the probe's name while `actual` does, as it may for a moment after a change.
    function misinformShell(believed: var, actual: var): var {
        believed.provide(path, probeActions);
        actual.provide(path, probeActions);
        verify(actual.takeName(probeName));
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        tryVerify(() => providedIds().length === 2);
        providers.owners = {
            [probeName]: believed.uniqueName()
        };
        believed.forgetCalls();
        actual.forgetCalls();
        return providers;
    }

    function test_the_shell_reads_and_invokes_through_the_unique_name_of_the_owner_it_knows() {
        const actual = createTemporaryObject(counterpartComponent, testCase);
        misinformShell(counterpart, actual);
        providers.read(probeName);
        tryVerify(() => counterpart.callsTo("ListActions") === 1);
        compare(invoke(`${probeId}open`, {}).error, "");
        tryVerify(() => counterpart.callsTo("Invoke") === 1);
        settle();
        compare(actual.callsTo("ListActions") + actual.callsTo("Invoke"), 0, "the name's owner was not called");
        actual.releaseName(probeName);
        counterpart.releaseName(probeName);
    }

    function test_an_answer_of_an_owner_that_has_gone_since_is_dropped() {
        const next = createTemporaryObject(counterpartComponent, testCase);
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        counterpart.provide(path, probeActions);
        counterpart.holdListings(true);
        verify(counterpart.takeName(probeName));
        tryVerify(() => counterpart.callsTo("ListActions") === 1);
        counterpart.leaveName(probeName);
        next.provide(path, [probeActions[1]]);
        verify(next.takeName(probeName));
        tryVerify(() => providedIds().length === 1);
        counterpart.answerHeldListings();
        counterpart.nameOwner("org.freedesktop.DBus");
        settle();
        compare(providedIds(), [`${probeId}plain`], "the late answer of the first owner is not listed");
        next.releaseName(probeName);
        counterpart.holdListings(false);
        counterpart.releaseName(probeName);
    }

    function test_an_icon_that_is_no_string_and_parameters_that_are_no_schema_are_not_exported() {
        const schema = JSON.stringify({
            type: "object"
        });
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        serve([
            row("list-icon", {
                title: "List icon",
                icon: ["a", "b"]
            }),
            row("number-icon", {
                title: "Number icon",
                icon: 5
            }),
            row("empty-icon", {
                title: "Empty icon",
                icon: ""
            }),
            row("list-schema", {
                title: "List schema",
                parameters: ["a"]
            }),
            row("number-schema", {
                title: "Number schema",
                parameters: 7
            }),
            row("text-schema", {
                title: "Text schema",
                parameters: "not json"
            }),
            row("array-schema", {
                title: "Array schema",
                parameters: "[1]"
            }),
            row("null-schema", {
                title: "Null schema",
                parameters: "null"
            }),
            row("good-schema", {
                title: "Good schema",
                parameters: schema
            })
        ]);
        tryVerify(() => providedIds().length === 4);
        compare(providedIds().map(id => id.slice(probeId.length)), ["list-icon", "number-icon", "empty-icon", "good-schema"]);
        for (const id of ["list-icon", "number-icon", "empty-icon"])
            compare(action(`${probeId}${id}`).icon, "prober", id);
        compare(action(`${probeId}good-schema`).parameters, schema);
        stopProvider();
    }

    function test_an_answer_or_keywords_that_only_claim_a_length_cost_the_shell_nothing() {
        const started = Date.now();
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        counterpart.answerAt(path, [{
                length: 30000000
            }]);
        verify(counterpart.takeName(probeName));
        tryVerify(() => counterpart.callsTo("ListActions") === 1);
        settle();
        compare(providedIds(), []);
        counterpart.releaseName(probeName);
        counterpart.forgetCalls();
        serve([
            row("claims", {
                title: "Claims",
                keywords: {
                    length: 30000000
                }
            })
        ]);
        tryVerify(() => providedIds().length === 1);
        compare(counterpart.callsTo("ListActions"), 1);
        compare(action(`${probeId}claims`).keywords, undefined);
        stopProvider();
        verify(Date.now() - started < 3000, "the shell did not work through the claimed length");
    }

    function test_a_provider_lists_at_most_256_actions_and_an_action_at_most_32_keywords() {
        const many = Array.from({
            length: 300
        }, (_, k) => row(`a${k}`, {
                title: `Action ${k}`
            }));
        const words = Array.from({
            length: 40
        }, (_, k) => `word${k}`);
        many[0] = row("a0", {
            title: "Action 0",
            keywords: words
        });
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        serve(many);
        tryVerify(() => providedIds().length === 256);
        compare(providedIds()[255], `${probeId}a255`);
        compare(action(`${probeId}a0`).keywords, words.slice(0, 32));
        stopProvider();
    }

    function test_an_action_that_says_it_is_destructive_in_any_way_but_false_or_not_at_all_is_not_listed() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        serve([
            row("says-true", {
                title: "True",
                destructive: true
            }),
            row("says-text", {
                title: "Text",
                destructive: "true"
            }),
            row("says-false-text", {
                title: "False as text",
                destructive: "false"
            }),
            row("says-one", {
                title: "One",
                destructive: 1
            }),
            row("says-map", {
                title: "Map",
                destructive: {
                    yes: true
                }
            }),
            row("says-false", {
                title: "False",
                destructive: false
            }),
            row("says-zero", {
                title: "Zero",
                destructive: 0
            }),
            row("says-nothing", {
                title: "Nothing"
            })
        ]);
        tryVerify(() => providedIds().length === 3);
        compare(providedIds().map(id => id.slice(probeId.length)), ["says-false", "says-zero", "says-nothing"]);
        stopProvider();
    }

    function test_parameters_with_lists_of_words_and_empty_lists_reach_the_provider_as_they_were_sent() {
        const client = createTemporaryObject(clientComponent, testCase);
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => providedIds().length === 2);
        const parameters = {
            files: ["a", "b"],
            none: [],
            nested: {
                list: ["c"],
                empty: []
            },
            count: 3,
            on: true
        };
        let answer = null;
        client.call(service, path, iface, "Invoke", [`${probeId}open`, parameters], "sa{sv}", (error, values) => answer = {
                error,
                values
            });
        tryVerify(() => answer !== null);
        compare(answer.error, null);
        tryVerify(() => counterpart.callsTo("Invoke") === 1);
        compare(counterpart.lastCall.args, ["open", parameters]);
        stopProvider();
    }

    function test_a_provider_whose_name_has_no_owner_is_never_called_and_is_called_once_it_has_one() {
        failOnWarning(/^ActionProviders: /);
        counterpart.provide(path, probeActions);
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        settle();
        compare(providedIds(), []);
        compare(counterpart.callsTo("ListActions"), 0);
        verify(counterpart.takeName(probeName));
        tryVerify(() => counterpart.callsTo("ListActions") === 1);
        tryVerify(() => providedIds().length === 2);
        counterpart.releaseName(probeName);
        tryVerify(() => providedIds().length === 0);
        compare(counterpart.callsTo("ListActions"), 1, "a name that went is not asked again");
    }

    function test_a_provider_appearing_changing_or_going_sends_actions_changed_once_each_and_the_same_actions_again_none() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => heard.length === 1);
        counterpart.provide(path, [probeActions[1]]);
        counterpart.emitSignal(path, iface, "ActionsChanged", []);
        tryVerify(() => heard.length === 2);
        compare(providedIds(), [`${probeId}plain`]);
        counterpart.emitSignal(path, iface, "ActionsChanged", []);
        settle();
        listActions();
        compare(heard.length, 2, "actions that read the same bring none");
        counterpart.releaseName(probeName);
        tryVerify(() => heard.length === 3);
        compare(providedIds(), []);
    }

    function test_invoking_a_provider_s_action_calls_its_invoke_with_the_same_parameters() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => providedIds().length === 2);
        compare(invoke(`${probeId}open`, {
            path: "/tmp/a.txt",
            fresh: true,
            count: 3
        }), {
            signature: "a{sv}",
            values: [{
                    done: true
                }],
            error: ""
        });
        tryVerify(() => counterpart.callsTo("Invoke") === 1);
        compare(counterpart.lastCall, {
            path,
            interface: iface,
            member: "Invoke",
            args: ["open", {
                    path: "/tmp/a.txt",
                    fresh: true,
                    count: 3
                }]
        });
        compare(counterpart.lastSignature, "sa{sv}");
        stopProvider();
    }

    function test_a_provider_that_fails_an_invoke_is_logged_as_a_warning() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => providedIds().length === 2);
        counterpart.failInvokes(true);
        ignoreWarning(/^ActionProviders: org\.example\.Prober: plain: org\.rekta\.Counterpart\.Failed: the provider failed$/);
        compare(invoke(`${probeId}plain`, {}).error, "");
        tryVerify(() => counterpart.callsTo("Invoke") === 1);
        settle();
        stopProvider();
    }

    // Sends Invoke from the counterpart without waiting; the `answer` of the returned object is the reply, null while the call
    // is open. The reply of another call (a{sv} is Invoke's alone here) never lands in it.
    function invokeWithoutWaiting(id: string, parameters: var): var {
        const holder = {
            answer: null
        };
        const take = (signature, values, error) => {
            if (signature !== "a{sv}")
                return;
            holder.answer = {
                signature,
                values,
                error
            };
            counterpart.replied.disconnect(take);
        };
        counterpart.replied.connect(take);
        counterpart.call(service, path, iface, "Invoke", [id, parameters]);
        return holder;
    }

    function test_a_provider_that_fails_an_invoke_hands_its_error_to_the_caller_as_the_reason() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => providedIds().length === 2);
        counterpart.failInvokes(true);
        ignoreWarning(/^ActionProviders: org\.example\.Prober: plain: org\.rekta\.Counterpart\.Failed: the provider failed$/);
        compare(invoke(`${probeId}plain`, {}), {
            signature: "a{sv}",
            values: [{
                    done: false,
                    reason: "org.rekta.Counterpart.Failed: the provider failed"
                }],
            error: ""
        });
        stopProvider();
    }

    function test_a_provider_s_invoke_is_answered_only_when_the_provider_has_answered() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => providedIds().length === 2);
        counterpart.answerInvokesWith({
            done: true,
            state: 7
        });
        counterpart.holdInvokes(true);
        const call = invokeWithoutWaiting(`${probeId}plain`, {});
        tryVerify(() => counterpart.callsTo("Invoke") === 1);
        settle();
        compare(call.answer, null, "the provider has not answered, so neither has the shell");
        compare(listActions().length > 0, true, "the shell answers other calls meanwhile");
        counterpart.answerHeldInvokes();
        tryVerify(() => call.answer !== null);
        compare(call.answer.values, [{
                    done: true,
                    state: 7
                }]);
        counterpart.holdInvokes(false);
        stopProvider();
    }

    function test_what_a_provider_answers_to_invoke_is_passed_on_only_as_done_state_and_reason_of_the_right_type() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => providedIds().length === 2);
        const answers = [[{}, {
                    done: true
                }], [{
                    done: false
                }, {
                    done: false,
                    reason: "the app did not do it"
                }], [{
                    done: false,
                    reason: "no printer",
                    state: "idle",
                    other: 1
                }, {
                    done: false,
                    reason: "no printer",
                    state: "idle"
                }], [{
                    done: "no",
                    state: [1, 2],
                    reason: 5
                }, {
                    done: true
                }]];
        for (const [given, passed] of answers) {
            counterpart.answerInvokesWith(given);
            compare(invoke(`${probeId}plain`, {}).values, [passed], JSON.stringify(given));
        }
        stopProvider();
    }

    function test_a_provider_whose_owner_is_gone_when_invoked_answers_not_done_and_is_not_called() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => providedIds().length === 2);
        // The list drops an entry whose owner went, so this is the moment between the owner going and the list following.
        providers.owners = {
            [probeName]: ""
        };
        ignoreWarning(/^ActionProviders: org\.example\.Prober: plain: no owner$/);
        compare(providers.invoke(probeName, "plain", {}, null), {
            done: false,
            reason: "the app is not running"
        });
        compare(counterpart.callsTo("Invoke"), 0);
        stopProvider();
    }

    function test_a_provider_lists_what_it_says_of_its_actions_and_what_it_leaves_out_is_filled_in() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        serve([
            row("full", {
                title: "Full",
                description: "Prints the page.",
                consequence: "none",
                available: false,
                reason: "no printer",
                state: 3
            }),
            row("bare", {
                title: "Bare"
            }),
            row("wrong", {
                title: "Wrong",
                description: 7,
                consequence: "unheard-of",
                available: "yes",
                reason: false,
                state: [1]
            })
        ]);
        tryVerify(() => providedIds().length === 3);
        compare(action(`${probeId}full`), {
            title: "Full",
            readOnly: false,
            destructive: false,
            app: probeName,
            icon: "prober",
            description: "Prints the page.",
            consequence: "none",
            available: false,
            reason: "no printer",
            state: 3
        });
        const bare = action(`${probeId}bare`);
        compare(bare.description, `Runs the "Bare" action of Prober.`);
        compare([bare.consequence, bare.available, bare.reason, bare.state], ["undoable", true, undefined, undefined]);
        const wrong = action(`${probeId}wrong`);
        compare(wrong.description, `Runs the "Wrong" action of Prober.`);
        compare([wrong.consequence, wrong.available, wrong.reason, wrong.state], ["undoable", true, undefined, undefined]);
        stopProvider();
    }

    function test_a_provider_action_that_says_it_is_irreversible_is_not_listed() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        serve([
            row("final", {
                title: "Final",
                consequence: "irreversible"
            }),
            row("fine", {
                title: "Fine",
                consequence: "undoable"
            })
        ]);
        tryVerify(() => providedIds().length === 1);
        compare(providedIds(), [`${probeId}fine`]);
        compare(invoke(`${probeId}final`, {}).error, "org.freedesktop.DBus.Error.Failed");
        compare(counterpart.callsTo("Invoke"), 0);
        stopProvider();
    }

    function test_invoking_a_provider_action_that_says_it_is_not_available_answers_not_done_without_calling_the_provider() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        serve([
            row("print", {
                title: "Print",
                available: false,
                reason: "no printer"
            })
        ]);
        tryVerify(() => providedIds().length === 1);
        compare(invoke(`${probeId}print`, {}).values, [{
                    done: false,
                    reason: "no printer"
                }]);
        compare(counterpart.callsTo("Invoke"), 0);
        stopProvider();
    }

    function test_a_parameter_the_action_does_not_name_is_an_error_for_a_command_a_desktop_action_and_a_provider_action() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => providedIds().length === 2);
        const refusals = [
            ["dark", {
                    loud: true
                }, "dark takes no parameters, not loud"],
            ["volume", {
                    percent: 30,
                    fade: 2
                }, "volume takes only percent, not fade"],
            ["desktop/firefox/new-window", {
                    url: "x"
                }, "desktop/firefox/new-window takes no parameters, not url"],
            [`${probeId}plain`, {
                    x: 1
                }, `${probeId}plain takes no parameters, not x`]
        ];
        for (const [id, parameters, text] of refusals) {
            const refused = invoke(id, parameters);
            compare(refused.error, "org.freedesktop.DBus.Error.Failed", id);
            compare(refused.values, [text], id);
        }
        compare(calls, []);
        compare(commands.sink.audio.volume, 0.5);
        compare(counterpart.callsTo("Invoke"), 0);
        stopProvider();
    }

    function test_a_parameter_of_the_wrong_type_is_an_error_for_a_provider_action_and_for_a_command_that_cannot_run_now() {
        commands.sink = null;
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => providedIds().length === 2);
        const refused = invoke(`${probeId}open`, {
            path: 7
        });
        compare(refused.error, "org.freedesktop.DBus.Error.Failed", "a number where the schema of the provider says string");
        compare(counterpart.callsTo("Invoke"), 0, "the provider is not called");
        compare(invoke("volume", {
            percent: "dreißig"
        }).error, "org.freedesktop.DBus.Error.Failed", "a percent that is no number is an error even without an output");
        stopProvider();
    }

    function test_a_key_the_action_does_not_name_is_an_error_even_when_the_action_cannot_run_now() {
        commands.sink = null;
        exportFor("rekta");
        const refused = invoke("mute", {
            loud: true
        });
        compare(refused.error, "org.freedesktop.DBus.Error.Failed");
        compare(refused.values, ["mute takes no parameters, not loud"]);
    }

    function test_what_a_provider_says_of_itself_is_passed_on_at_most_a_thousand_characters_long() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        counterpart.provide(path, [{
                id: "long",
                properties: {
                    title: "Long",
                    description: "d".repeat(5000),
                    state: "s".repeat(5000)
                }
            }]);
        counterpart.takeName(probeName);
        tryVerify(() => providedIds().length === 1);
        const long = action(`${probeId}long`);
        compare(long.description.length, 1000);
        compare(long.state.length, 1000, "a state given as text is capped like the description");
        stopProvider();
    }

    function test_a_provider_action_may_take_any_parameter_when_its_schema_says_so() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => providedIds().length === 2);
        compare(invoke(`${probeId}open`, {
            path: "/a",
            anything: 1
        }).error, "");
        stopProvider();
    }

    function test_where_the_shell_only_logs_what_it_would_do_an_invoke_still_runs_it_and_answers_not_done_with_why() {
        apps = listedApps(desktopEntries());
        exportFor("rekta");
        commands.launcher.starts = false;
        const why = "the shell runs without REKTA_SHELL_LAUNCH=systemd and only logs what it would do";
        compare(invoke("lock", {}).values, [{
                    done: false,
                    reason: why
                }]);
        compare(invoke("dark", {}).values, [{
                    done: false,
                    reason: why
                }]);
        testCase.launcher.starts = false;
        compare(invoke("desktop/firefox/new-window", {}).values, [{
                    done: false,
                    reason: why
                }], "an app's desktop action is no different");
        testCase.launcher.starts = true;
        compare(calls.slice(0, 2), ["lock", "dark true"], "it is run, as the log shows what would happen");
        compare(calls.length, 3, "the desktop action was run too");
        compare(invoke("do-not-disturb", {}).values, [{
                    done: true,
                    state: true
                }], "a command that needs no launcher is not affected");
    }

    function test_the_state_a_toggle_answers_is_the_one_it_sets_even_when_the_system_changes_later() {
        exportFor("rekta");
        compare(invoke("do-not-disturb", {}).values, [{
                    done: true,
                    state: true
                }]);
        compare(invoke("do-not-disturb", {}).values, [{
                    done: true,
                    state: false
                }]);
        compare(invoke("mute", {}).values, [{
                    done: true,
                    state: true
                }]);
        compare(invoke("dark", {}).values, [{
                    done: true,
                    state: true
                }]);
        compare(invoke("key-map", {}).values, [{
                    done: true
                }], "an action without a state answers without one");
    }

    function test_a_caller_that_ignores_the_answer_of_invoke_still_gets_the_action_run() {
        exportFor("rekta");
        counterpart.call(service, path, iface, "Invoke", ["do-not-disturb", {}]);
        tryVerify(() => calls.length === 1);
        compare(calls, ["quiet true"]);
    }

    function test_a_provider_that_does_not_answer_in_time_gets_a_not_done_answer_from_the_shell_before_the_callers_own_timeout() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => providedIds().length === 2);
        compare(providers.invokeTimeout, 20000, "less than the 25 s of a caller that uses the defaults");
        providers.invokeTimeout = 300;
        counterpart.holdInvokes(true);
        ignoreWarning(/^ActionProviders: org\.example\.Prober: plain: org\.freedesktop\.DBus\.Error\.NoReply: .+$/);
        const answer = invoke(`${probeId}plain`, {});
        compare(answer.error, "");
        compare(answer.values[0].done, false);
        verify(answer.values[0].reason.startsWith("org.freedesktop.DBus.Error.NoReply"), answer.values[0].reason);
        counterpart.holdInvokes(false);
        stopProvider();
    }

    function test_the_error_text_of_a_provider_is_passed_on_as_the_reason_at_most_a_thousand_characters_long() {
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        startProvider();
        tryVerify(() => providedIds().length === 2);
        counterpart.failInvokes(true);
        counterpart.failInvokesWithMessage("e".repeat(5000));
        ignoreWarning(/^ActionProviders: org\.example\.Prober: plain: org\.rekta\.Counterpart\.Failed: e+$/);
        const reason = invoke(`${probeId}plain`, {}).values[0].reason;
        compare(reason.length, 1000);
        verify(reason.startsWith("org.rekta.Counterpart.Failed: eee"), reason.slice(0, 40));
        stopProvider();
    }

    function test_each_type_a_provider_schema_names_takes_what_dbus_delivers_for_it_and_refuses_any_other() {
        const client = createTemporaryObject(clientComponent, testCase);
        apps = appsWithProvider();
        exportFor("rekta");
        settle();
        counterpart.provide(path, [{
                id: "typed",
                properties: {
                    title: "Typed",
                    parameters: JSON.stringify({
                        type: "object",
                        properties: {
                            files: {
                                type: "array"
                            },
                            none: {
                                type: "array"
                            },
                            options: {
                                type: "object"
                            },
                            count: {
                                type: "integer"
                            },
                            ratio: {
                                type: "number"
                            },
                            on: {
                                type: "boolean"
                            },
                            name: {
                                type: "string"
                            }
                        }
                    })
                }
            }]);
        verify(counterpart.takeName(probeName));
        tryVerify(() => providedIds().length === 1);
        const invokeTyped = parameters => {
            let answer = null;
            client.call(service, path, iface, "Invoke", [`${probeId}typed`, parameters], "sa{sv}", error => answer = {
                    error
                });
            tryVerify(() => answer !== null);
            return answer.error;
        };
        const fitting = {
            files: ["a", "b"],
            none: [],
            options: {
                k: "v"
            },
            count: 3,
            ratio: 2.5,
            on: true,
            name: "x"
        };
        const wrong = [[{
                    files: "a"
                }, "files", "array"], [{
                    options: ["a"]
                }, "options", "object"], [{
                    count: 2.5
                }, "count", "integer"], [{
                    ratio: "1"
                }, "ratio", "number"], [{
                    on: 1
                }, "on", "boolean"], [{
                    name: 7
                }, "name", "string"]];
        const fittingError = invokeTyped(fitting);
        const fittingArgs = counterpart.lastCall?.args;
        const refusals = wrong.map(([parameters]) => invokeTyped(parameters));
        const reached = counterpart.callsTo("Invoke");
        stopProvider();
        compare(fittingError, null, "a list, an empty list, a map, a whole number, a number, a truth value and a text as D-Bus delivers them");
        compare(fittingArgs, ["typed", fitting]);
        compare(refusals, wrong.map(([, key, type]) => `org.freedesktop.DBus.Error.Failed: ${probeId}typed takes ${key} as ${type}`));
        compare(reached, 1, "no call of a wrong type reaches the provider");
    }

    function test_outside_the_rekta_session_no_provider_is_looked_up() {
        providers.sessionDesktop = "KDE";
        apps = appsWithProvider();
        startProvider();
        settle();
        compare(providers.owners, {});
        compare(providers.list, []);
        compare(counterpart.callsTo("ListActions"), 0);
        stopProvider();
    }

    function test_shell_version_is_the_one_the_shell_was_started_with_and_can_only_be_read() {
        exportFor("rekta");
        compare(callShell("org.freedesktop.DBus.Properties", "Get", [iface, "ShellVersion"]), {
            signature: "v",
            values: ["0.1.5+20261122.1830.abc1234"],
            error: ""
        });
        compare(callShell("org.freedesktop.DBus.Properties", "Set", [iface, "ShellVersion", "x"]).error, "org.freedesktop.DBus.Error.PropertyReadOnly");
    }

    function test_version_is_one_and_can_only_be_read() {
        exportFor("rekta");
        compare(callShell("org.freedesktop.DBus.Properties", "Get", [iface, "Version"]), {
            signature: "v",
            values: [1],
            error: ""
        });
        const all = callShell("org.freedesktop.DBus.Properties", "GetAll", [iface]);
        compare(all.signature, "a{sv}");
        compare(all.values, [{
                Version: 1,
                ShellVersion: "0.1.5+20261122.1830.abc1234"
            }]);
        compare(counterpart.replyVariantTypes, {
            Version: "uint",
            ShellVersion: "QString"
        });
        const xml = callShell("org.freedesktop.DBus.Introspectable", "Introspect", []).values[0];
        verify(/<property name="Version" type="u" access="read">\s*<annotation name="org.freedesktop.DBus.Property.EmitsChangedSignal" value="const"\/>/.test(xml), xml);
        compare(callShell("org.freedesktop.DBus.Properties", "Get", [iface, "Size"]).error, "org.freedesktop.DBus.Error.UnknownProperty");
        compare(callShell("org.freedesktop.DBus.Properties", "Set", [iface, "Version", 2]).error, "org.freedesktop.DBus.Error.PropertyReadOnly");
    }

    function test_outside_the_rekta_session_nothing_is_owned() {
        for (const sessionDesktop of ["", "KDE", "plasmawayland"]) {
            exportFor(sessionDesktop).destroy();
            compare(counterpart.nameOwner(service), "", sessionDesktop);
        }
    }
}
