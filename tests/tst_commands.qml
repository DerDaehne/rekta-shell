pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Start
import "../shell/services"

TestCase {
    id: testCase

    name: "Commands"

    property var calls: []
    // What kglobalaccel replies by action name; an action not in it is not asked at all, as in a session without it.
    property var replies: ({})
    property var asked: []

    Component {
        id: commandsComponent

        Commands {
            launcher: QtObject {
                function run(command: var) {
                    testCase.calls = [...testCase.calls, `run ${command.join(" ")}`];
                }

                function lock() {
                    testCase.calls = [...testCase.calls, "lock"];
                }

                function ask(service: string, path: string, iface: string, method: string, args: var, signature: string, done: var) {
                    testCase.asked = [...testCase.asked, `${service} ${path} ${iface}.${method} ${JSON.stringify(args)} ${signature}`];
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
                }

                function setDoNotDisturb(on: bool) {
                    testCase.calls = [...testCase.calls, `quiet ${on}`];
                }
            }
            session: QtObject {
                function show(focusOn: string) {
                    testCase.calls = [...testCase.calls, `banner ${focusOn}`];
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

    property var commands

    function init() {
        calls = [];
        asked = [];
        replies = {};
        commands = createTemporaryObject(commandsComponent, testCase);
    }

    function texts(typed: string): var {
        return Rules.commandHits(commands.list, typed).map(command => command.text);
    }

    function test_the_session_commands_are_found_by_their_first_letters() {
        compare(texts("sp"), ["sperren"]);
        compare(texts("abm"), ["abmelden"]);
        compare(texts("neu"), ["neu starten"]);
        compare(texts("aus"), ["ausschalten"]);
        compare(texts("benutzer w"), ["benutzer wechseln"]);
    }

    function test_sperren_locks_the_session_and_the_ones_that_end_it_open_the_banner_on_their_action() {
        Rules.commandHits(commands.list, "sperren")[0].run();
        Rules.commandHits(commands.list, "abmelden")[0].run();
        Rules.commandHits(commands.list, "neu starten")[0].run();
        Rules.commandHits(commands.list, "ausschalten")[0].run();
        Rules.commandHits(commands.list, "benutzer wechseln")[0].run();
        compare(calls, ["lock", "banner logout", "banner reboot", "banner shutdown", "banner switchUser"]);
    }

    function test_a_command_says_what_it_will_do_now() {
        compare(texts("dun"), ["dunkel an"]);
        commands.panel.dark = true;
        compare(texts("dun"), ["dunkel aus"]);
        compare(texts("nicht"), ["nicht stören an"]);
        commands.panel.doNotDisturb = true;
        compare(texts("nicht"), ["nicht stören aus"]);
        compare(texts("stu"), ["stumm an"]);
        commands.sink.audio.muted = true;
        compare(texts("stu"), ["stumm aus"]);
    }

    function test_dunkel_nicht_stoeren_and_stumm_switch_what_they_name() {
        Rules.commandHits(commands.list, "dunkel an")[0].run();
        commands.panel.dark = true;
        Rules.commandHits(commands.list, "dunkel aus")[0].run();
        Rules.commandHits(commands.list, "nicht stören")[0].run();
        Rules.commandHits(commands.list, "stumm")[0].run();
        compare(calls, ["dark true", "dark false", "quiet true"]);
        compare(commands.sink.audio.muted, true);
        Rules.commandHits(commands.list, "stumm")[0].run();
        compare(commands.sink.audio.muted, false);
    }

    function test_ton_with_a_number_sets_the_volume_to_that_percent_and_not_above_a_hundred() {
        const thirty = Rules.commandHits(commands.list, "ton 30");
        compare(thirty.map(command => command.text), ["ton auf 30 %"]);
        thirty[0].run();
        compare(commands.sink.audio.volume, 0.3);
        Rules.commandHits(commands.list, "ton 250 %")[0].run();
        compare(commands.sink.audio.volume, 1);
    }

    function test_ton_without_a_number_sets_no_volume() {
        for (const command of Rules.commandHits(commands.list, "ton"))
            verify(!command.text.startsWith("ton auf"), command.text);
    }

    function test_nothing_is_found_for_text_that_names_no_command() {
        compare(texts("xyz"), []);
    }

    function test_without_an_audio_output_there_is_no_stumm_and_no_ton_and_the_rest_stays() {
        commands.sink = null;
        compare(texts("stu"), []);
        compare(Rules.commandHits(commands.list, "ton 30"), []);
        compare(texts("sp"), ["sperren"]);
        commands.sink = {};
        compare(texts("stu"), []);
    }

    function keyOf(typed: string): string {
        return Rules.commandHits(commands.list, typed)[0].key ?? "";
    }

    // Meta+L as kglobalaccel replies it: a list of key sequences, each a list of Qt key codes.
    readonly property var metaL: [[0x10000000 | 0x4c, 0, 0, 0]]

    function test_a_command_shows_the_key_the_session_binds_to_its_action() {
        replies = { "Lock Session": metaL, "Log Out": [[0x04000000 | 0x08000000 | 0x01000007, 0, 0, 0]] };
        commands.destroy();
        commands = createTemporaryObject(commandsComponent, testCase);
        compare(keyOf("sperren"), "Meta+L");
        compare(keyOf("abmelden"), "Ctrl+Alt+Del");
        compare(asked[0], `org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.shortcutKeys [["ksmserver","Lock Session","",""]] as`);
    }

    function test_a_command_whose_action_has_no_key_shows_none() {
        replies = { "Lock Session": [[0, 0, 0, 0]], "Reboot": [] };
        commands.destroy();
        commands = createTemporaryObject(commandsComponent, testCase);
        compare(keyOf("sperren"), "");
        compare(keyOf("neu starten"), "");
        compare(keyOf("dunkel"), "", "a command with no action of the session");
    }

    function test_without_kglobalaccel_no_command_shows_a_key_and_nothing_fails() {
        failOnWarning(/TypeError|ReferenceError/);
        compare(commands.shortcuts, {});
        compare(keyOf("sperren"), "");
    }

    function test_the_keys_are_read_again_on_request() {
        compare(keyOf("sperren"), "");
        replies = { "Lock Session": metaL };
        commands.readKeys();
        compare(keyOf("sperren"), "Meta+L");
    }
}
