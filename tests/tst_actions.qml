pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import DBusCounterpart
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

    Counterpart {
        id: counterpart

        onHeard: sender => testCase.heardAll = [...testCase.heardAll, sender]
    }

    Component {
        id: commandsComponent

        Commands {
            launcher: QtObject {
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
        }
    }

    Component {
        id: exporterComponent

        ActionsInterface {
            sessionDesktop: ""
            entries: testCase.registry?.list ?? []
        }
    }

    // The shell's launcher, as the session's own shell has it: it calls on the bus.
    Launcher {
        id: shellLauncher
    }

    // Starts what a desktop action asks for as the shell's launcher does, at a fixed time, and notes what it would run;
    // an action of an app that runs over D-Bus goes to the shell's launcher.
    readonly property QtObject launcher: QtObject {
        function launchAction(entry: var, action: var) {
            testCase.calls = [...testCase.calls, Rules.launchContext(entry, action.command, 1234)];
        }

        function activateAction(busName: string, actionId: string) {
            shellLauncher.activateAction(busName, actionId);
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
        return [desktopEntry("org.gnome.TextEditor", "Text Editor", "org.gnome.TextEditor", [desktopAction("new-window", "New Window", "", ["gnome-text-editor", "--new-window"])]), desktopEntry("gnome-org.gnome.font-viewer", "Fonts", "org.gnome.font-viewer", [desktopAction("install-font", "Install Font", "font-x-generic", [])])];
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
        replies = {};
        owner = "";
        apps = null;
        commands = createTemporaryObject(commandsComponent, testCase);
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

    function test_list_actions_names_each_command_with_what_it_does_now() {
        exportFor("rekta");
        const plain = (title, keywords) => ({
                title,
                keywords,
                readOnly: false,
                destructive: false
            });
        compare(listActions(), [["lock", plain("sperren", ["lock"])], ["switch-user", plain("benutzer wechseln", ["switch", "user"])], ["logout", Object.assign(plain("abmelden", ["logout"]), {
                    destructive: true
                })], ["reboot", Object.assign(plain("neu starten", ["reboot", "restart"]), {
                    destructive: true
                })], ["shutdown", Object.assign(plain("ausschalten", ["shutdown", "power", "off"]), {
                    destructive: true
                })], ["dark", plain("dunkel an", ["dark", "theme"])], ["do-not-disturb", plain("nicht stören an", ["quiet", "dnd"])], ["key-map", {
                    title: "tastenkürzel",
                    keywords: ["shortcuts", "keys", "tasten", "hilfe"],
                    key: "?",
                    readOnly: true,
                    destructive: false
                }], ["mute", plain("stumm an", ["mute", "ton"])], ["volume", {
                    title: "ton",
                    parameters: JSON.stringify(amountSchema),
                    readOnly: false,
                    destructive: false
                }]]);
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
            values: [{}],
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
        }).error, "");
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
        const plain = (title, keywords, app) => ({
                title,
                keywords,
                app,
                readOnly: false,
                destructive: false
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
            values: [{}],
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
        compare(listActions().map(entry => entry[0]).filter(id => id.startsWith("desktop/")), ["desktop/org.kde.dolphin/home", "desktop/firefox/new-window", "desktop/firefox/new-private-window", "desktop/gnome-org.gnome.font-viewer/install-font", "desktop/org.example.notes/new-note", "desktop/org.gnome.TextEditor/new-window"], "Dolphin's action without Exec stays out, as Dolphin does not run over D-Bus");
        compare(action("desktop/gnome-org.gnome.font-viewer/install-font"), {
            title: "Install Font",
            keywords: ["Fonts"],
            app: "gnome-org.gnome.font-viewer",
            icon: "font-x-generic",
            readOnly: false,
            destructive: false
        });
    }

    function test_invoking_an_action_of_an_app_that_runs_over_dbus_calls_activate_action_on_its_file_name_and_path_and_starts_no_exec() {
        apps = listedApps(dbusEntries());
        exportFor("rekta");
        verify(counterpart.takeName("org.gnome.font-viewer"));
        verify(counterpart.takeName("org.gnome.TextEditor"));
        counterpart.answerAt("/org/gnome/font_viewer", []);
        counterpart.answerAt("/org/gnome/TextEditor", []);
        for (const [id, path, actionId] of [["desktop/gnome-org.gnome.font-viewer/install-font", "/org/gnome/font_viewer", "install-font"], ["desktop/org.gnome.TextEditor/new-window", "/org/gnome/TextEditor", "new-window"]]) {
            compare(invoke(id, {}), {
                signature: "a{sv}",
                values: [{}],
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

    function test_an_action_whose_app_cannot_be_reached_is_logged_as_a_warning_and_invoke_still_answers_at_once() {
        apps = listedApps(dbusEntries());
        exportFor("rekta");
        compare(counterpart.nameOwner("org.gnome.TextEditor"), "");
        ignoreWarning(/^Launcher: session bus org\.gnome\.TextEditor \/org\/gnome\/TextEditor org\.freedesktop\.Application\.ActivateAction \["new-window",\[\],\{\}\]: org\.freedesktop\.DBus\.Error\.ServiceUnknown: .+$/);
        compare(invoke("desktop/org.gnome.TextEditor/new-window", {}), {
            signature: "a{sv}",
            values: [{}],
            error: ""
        });
        // A round trip on the launcher's own connection: the bus has answered the call before it by now.
        let answered = false;
        shellLauncher.sessionBus.call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetId", [], "", () => answered = true);
        tryVerify(() => answered);
        compare(calls, []);
    }

    function test_a_session_call_without_arguments_that_fails_is_logged_without_any() {
        ignoreWarning(/^Launcher: session bus org\.freedesktop\.ScreenSaver \/ScreenSaver org\.freedesktop\.ScreenSaver\.GetActive: org\.freedesktop\.DBus\.Error\.ServiceUnknown: .+$/);
        let answer = null;
        shellLauncher.call(false, "org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", "GetActive", [], "", error => answer = error);
        tryVerify(() => answer !== null);
        verify(String(answer).startsWith("org.freedesktop.DBus.Error.ServiceUnknown"), answer);
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
                Version: 1
            }]);
        compare(counterpart.replyVariantTypes, {
            Version: "uint"
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
