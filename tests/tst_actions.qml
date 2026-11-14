pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import DBusCounterpart
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
        id: exporterComponent

        ActionsInterface {
            sessionDesktop: ""
            commands: testCase.commands?.list ?? []
        }
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
        commands = createTemporaryObject(commandsComponent, testCase);
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
