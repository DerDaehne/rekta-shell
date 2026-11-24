import QtQuick
import QtTest
import DBusCounterpart
import RektaShell.DBus

TestCase {
    id: testCase

    name: "DBus"

    readonly property string jobsXml: `
        <interface name="org.rekta.Jobs">
          <method name="requestView">
            <arg name="name" type="s" direction="in"/>
            <arg name="job" type="o" direction="out"/>
          </method>
          <method name="count">
            <arg type="u" direction="out"/>
          </method>
          <method name="describe">
            <arg type="s" direction="out"/>
            <arg type="i" direction="out"/>
          </method>
          <method name="whereAmI">
            <arg type="s" direction="out"/>
          </method>
          <method name="fail"/>
          <signal name="changed">
            <arg type="s"/>
          </signal>
        </interface>`

    // The signals the counterpart heard since the test began, as { path, member, signature, values }.
    property var heardByCounterpart: []

    Counterpart {
        id: counterpart

        onHeard: (sender, path, member, signature, values) => testCase.heardByCounterpart.push({
                path,
                member,
                signature,
                values
            })
    }

    function initTestCase() {
        verify(counterpart.listen("org.rekta.Events", "Counted"));
        // A round trip on the counterpart's own connection: its subscription has reached the bus.
        counterpart.nameOwner("org.freedesktop.DBus");
    }

    function init() {
        heardByCounterpart = [];
    }

    Component {
        id: connectionComponent

        DBusConnection {}
    }

    function connection(properties) {
        return createTemporaryObject(connectionComponent, testCase, properties ?? {});
    }

    function callThrough(bus, service, path, iface, method, args, signature) {
        let answer = null;
        bus.call(service, path, iface, method, args, signature, (error, values) => answer = {
                error,
                values
            });
        tryVerify(() => answer !== null);
        return answer;
    }

    function callFromCounterpart(service, path, iface, member, args) {
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

    function echo(args, signature, bus) {
        return callThrough(bus ?? connection(), "org.rekta.Counterpart", "/echo", "org.rekta.Echo", "Echo", args, signature);
    }

    function inLists(value, depth) {
        for (let i = 0; i < depth; ++i)
            value = [value];
        return value;
    }

    // A round trip to the bus: what the connection sent before, such as its subscriptions, has reached the bus.
    function settle(bus) {
        callThrough(bus, "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetId", [], "");
    }

    function heardBy(bus) {
        const heard = [];
        bus.received.connect((sender, path, iface, member, args) => heard.push({
                path,
                iface,
                member,
                args
            }));
        return heard;
    }

    function answerJobs(path, member, args) {
        switch (member) {
        case "requestView":
            return "/jobs/" + args[0];
        case "count":
            return 2;
        case "describe":
            return ["copy", 40];
        case "whereAmI":
            return path;
        default:
            throw new Error("broken");
        }
    }

    function ownJobs(name) {
        const bus = connection({
            handler: (path, iface, member, args) => answerJobs(path, member, args)
        });
        verify(bus.own(name, "/jobs", jobsXml));
        return bus;
    }

    function ownWho(name, answer) {
        const bus = connection({
            handler: () => answer
        });
        verify(bus.own(name, "/who", `
            <interface name="org.rekta.Who">
              <method name="who">
                <arg type="s" direction="out"/>
              </method>
            </interface>`));
        return bus;
    }

    function who(name) {
        return callFromCounterpart(name, "/who", "org.rekta.Who", "who", []).values[0];
    }

    function test_a_listener_without_service_and_path_hears_every_sender_and_path() {
        const bus = connection();
        const heard = heardBy(bus);
        verify(bus.listen("com.canonical.Unity.LauncherEntry", "Update"));
        settle(bus);
        counterpart.emitSignal("/one", "com.canonical.Unity.LauncherEntry", "Update", ["application://a.desktop", {
                    count: 3
                }]);
        counterpart.emitSignal("/two", "com.canonical.Unity.LauncherEntry", "Update", ["application://b.desktop", {
                    progress: 0.5
                }]);
        tryVerify(() => heard.length === 2);
        compare(heard.map(signal => signal.path), ["/one", "/two"]);
        compare(heard[0].iface, "com.canonical.Unity.LauncherEntry");
        compare(heard[0].member, "Update");
        compare(heard[0].args, ["application://a.desktop", {
                count: 3
            }]);
        compare(heard[1].args, ["application://b.desktop", {
                progress: 0.5
            }]);
    }

    function test_a_listener_with_service_and_path_hears_only_that_sender_at_that_path() {
        const bus = connection();
        const heard = heardBy(bus);
        verify(bus.listen("org.rekta.Events", "Changed", "org.rekta.Counterpart", "/fixed"));
        settle(bus);
        counterpart.emitSignal("/elsewhere", "org.rekta.Events", "Changed", ["elsewhere"]);
        counterpart.emitSignal("/fixed", "org.rekta.Events", "Changed", ["fixed"]);
        tryVerify(() => heard.length > 0);
        compare(heard.map(signal => signal.args[0]), ["fixed"]);
    }

    function test_signals_of_another_interface_or_member_do_not_arrive() {
        const bus = connection();
        const heard = heardBy(bus);
        verify(bus.listen("org.rekta.Events", "Changed"));
        settle(bus);
        counterpart.emitSignal("/events", "org.rekta.Events", "Removed", ["other member"]);
        counterpart.emitSignal("/events", "org.rekta.OtherEvents", "Changed", ["other interface"]);
        counterpart.emitSignal("/events", "org.rekta.Events", "Changed", ["this one"]);
        tryVerify(() => heard.length > 0);
        compare(heard.map(signal => signal.args[0]), ["this one"]);
    }

    function test_a_call_sends_each_argument_typed_by_the_signature() {
        const keys = [[[1, 2]], [[3]]];
        const args = [["a", "b"], [1, -2], 7, {
                name: "x",
                count: 3,
                ratio: 0.5,
                on: true
            }, keys];
        const answer = echo(args, "asaiua{sv}a(ai)");
        compare(answer.error, null);
        compare(counterpart.lastSignature, "asaiua{sv}a(ai)");
        compare(counterpart.variantTypes, {
            name: "QString",
            count: "int",
            ratio: "double",
            on: "bool"
        });
        compare(answer.values, args);
    }

    function test_every_basic_type_and_a_variant_go_out_as_the_signature_says() {
        const args = [255, true, -3, 3, -4, 4, -5, 5, 0.25, "text", "/a/path", "a{sv}", "in a variant"];
        const answer = echo(args, "ybnqiuxtdsogv");
        compare(answer.error, null);
        compare(counterpart.lastSignature, "ybnqiuxtdsogv");
        compare(answer.values, args);
    }

    function test_a_list_of_words_in_a_variant_goes_out_as_strings_and_any_other_list_as_variants() {
        const args = [{
                words: ["a", "b"],
                mixed: ["a", 1],
                none: []
            }];
        const answer = echo(args, "a{sv}");
        compare(answer.error, null);
        compare(counterpart.variantTypes, {
            words: "QStringList",
            mixed: "QDBusArgument",
            none: "QDBusArgument"
        });
        compare(answer.values, args);
    }

    function test_a_decoded_list_of_words_or_an_empty_list_goes_out_again_in_a_variant_as_it_came() {
        const bus = connection();
        const first = echo([["a", "b"], [], [], {
                    words: ["c"],
                    none: []
                }], "asavasa{sv}", bus);
        compare(first.error, null);
        const [words, none, noWords, map] = first.values;
        for (const value of [words, none, noWords, map.words, map.none]) {
            const again = echo([{
                        value
                    }], "a{sv}", bus);
            compare(again.error, null, JSON.stringify(value));
            compare(again.values, [{
                        value: Array.from(value)
                    }]);
        }
        compare(counterpart.variantTypes, {
            value: "QDBusArgument"
        });
        const wordsAgain = echo([{
                    value: words
                }], "a{sv}", bus);
        compare(counterpart.variantTypes, {
            value: "QStringList"
        });
        compare(wordsAgain.values, [{
                    value: ["a", "b"]
                }]);
    }

    function test_a_missing_service_an_error_reply_and_a_wrong_signature_come_back_as_the_error() {
        const bus = connection();
        const missing = callThrough(bus, "org.rekta.Missing", "/", "org.rekta.Missing", "Anything", [], "");
        verify(missing.error.startsWith("org.freedesktop.DBus.Error.ServiceUnknown: "), missing.error);
        compare(missing.values, []);
        const refused = callThrough(bus, "org.rekta.Counterpart", "/echo", "org.rekta.Echo", "Fail", [], "");
        compare(refused.error, "org.rekta.Counterpart.Failed: asked to fail");
        ignoreWarning('QDBusObjectPath: invalid path "no path"');
        for (const [args, signature] of [[["a", "b"], "s"], [["seven"], "i"], [["no path"], "o"], [[{}], "as"], [[[1]], "(ii)"], [[null], "v"]]) {
            const wrong = echo(args, signature, bus);
            verify(wrong.error !== null, signature);
            compare(wrong.values, [], signature);
        }
        for (const [args, signature] of [[[[1]], "a(i"], [[{}], "a{vs}"], [[{}], "a{sss}"], [[[]], "()"]]) {
            const invalid = echo(args, signature, bus);
            verify(invalid.error?.includes("is not a valid D-Bus signature"), `${signature}: ${invalid.error}`);
        }
        compare(echo(["still connected"], "s", bus).values, ["still connected"]);
    }

    function test_signatures_hold_to_the_limits_of_the_specification() {
        const bus = connection();
        const arrays = depth => "a".repeat(depth) + "i";
        const structs = depth => "(".repeat(depth) + "i" + ")".repeat(depth);
        // Each level opens a dictionary entry and a struct: two of the 32 brackets.
        const entries = depth => "a{s(".repeat(depth) + "i" + ")}".repeat(depth);
        const inEntries = depth => {
            let value = 1;
            for (let i = 0; i < depth; ++i)
                value = {
                    key: [value]
                };
            return value;
        };
        for (const signature of [arrays(32), structs(32)]) {
            const deepest = inLists(1, 32);
            const answer = echo([deepest], signature, bus);
            compare(answer.error, null, signature);
            compare(counterpart.lastSignature, signature);
            compare(answer.values, [deepest], signature);
        }
        const entryAnswer = echo([inEntries(16)], entries(16), bus);
        compare(entryAnswer.error, null, entries(16));
        compare(counterpart.lastSignature, entries(16));
        compare(entryAnswer.values, [inEntries(16)]);
        const strings = count => Array(count).fill("text");
        const longest = echo(strings(255), "s".repeat(255), bus);
        compare(longest.error, null);
        compare(counterpart.lastSignature.length, 255);
        for (const [args, signature] of [[[inLists(1, 33)], arrays(33)], [[inLists(1, 33)], structs(33)], [[inEntries(17)], entries(17)], [strings(256), "s".repeat(256)]]) {
            const beyond = echo(args, signature, bus);
            verify(beyond.error?.includes("is not a valid D-Bus signature"), `${signature.length}: ${beyond.error}`);
        }
        compare(echo(["still connected"], "s", bus).values, ["still connected"]);
    }

    function test_a_value_too_deep_inside_variants_is_refused_and_the_connection_lives_on() {
        const bus = connection();
        const refused = echo([inLists("bottom", 70)], "v", bus);
        verify(refused.error?.includes("containers"), refused.error);
        compare(echo(["still connected"], "s", bus).values, ["still connected"]);
    }

    function test_an_instance_without_a_bus_calls_back_with_the_error_and_refuses_to_listen_or_own() {
        const bus = connection({
            bus: DBusConnection.System
        });
        const answer = callThrough(bus, "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetId", [], "");
        verify(answer.error?.startsWith("org.freedesktop.DBus.Error.Disconnected: "), answer.error);
        compare(answer.values, []);
        verify(!bus.listen("org.rekta.Events", "Changed"));
        ignoreWarning(/no bus to own/);
        verify(!bus.own("org.rekta.Test.NoBus", "/nobus", `<interface name="org.rekta.NoBus"/>`));
    }

    function test_own_refuses_introspection_with_a_type_beyond_the_specification() {
        ignoreWarning(/not a valid D-Bus signature/);
        verify(!connection().own("org.rekta.Test.Invalid", "/invalid", `
            <interface name="org.rekta.Invalid">
              <method name="keys">
                <arg type="a{vs}" direction="out"/>
              </method>
            </interface>`));
    }

    function test_structs_arrive_as_lists_and_dictionaries_as_objects() {
        const layouts = [["us", "English (US)", "English"], ["de", "German", "German"]];
        const matches = [["id", "Text", "icon", 30, 0.8, {
                    urls: ["file:///a"],
                    subtext: "b"
                }]];
        const answer = echo([layouts, matches], "a(sss)a(sssida{sv})");
        compare(counterpart.lastSignature, "a(sss)a(sssida{sv})");
        compare(answer.values, [layouts, matches]);
    }

    function test_an_owned_object_answers_typed_by_its_out_arguments() {
        const name = "org.rekta.Test.Typed";
        ownJobs(name);
        const view = callFromCounterpart(name, "/jobs", "org.rekta.Jobs", "requestView", ["copy"]);
        compare(view.signature, "o");
        compare(view.values, ["/jobs/copy"]);
        const count = callFromCounterpart(name, "/jobs", "org.rekta.Jobs", "count", []);
        compare(count.signature, "u");
        compare(count.values, [2]);
        const described = callFromCounterpart(name, "/jobs", "org.rekta.Jobs", "describe", []);
        compare(described.signature, "si");
        compare(described.values, ["copy", 40]);
    }

    function test_the_objects_below_an_owned_path_answer_too() {
        const name = "org.rekta.Test.Below";
        ownJobs(name);
        compare(callFromCounterpart(name, "/jobs/1", "org.rekta.Jobs", "whereAmI", []).values, ["/jobs/1"]);
        compare(callFromCounterpart(name, "/jobs/2", "org.rekta.Jobs", "whereAmI", []).values, ["/jobs/2"]);
    }

    function test_introspection_describes_the_owned_interfaces() {
        const name = "org.rekta.Test.Introspected";
        ownJobs(name);
        for (const path of ["/jobs", "/jobs/1"]) {
            const xml = callFromCounterpart(name, path, "org.freedesktop.DBus.Introspectable", "Introspect", []);
            compare(xml.error, "", path);
            verify(xml.values[0].includes(`<interface name="org.rekta.Jobs">`), xml.values[0]);
            verify(xml.values[0].includes(`<method name="requestView">`), xml.values[0]);
        }
    }

    readonly property string gaugeXml: `
        <interface name="org.rekta.Gauge">
          <property name="Level" type="u" access="read"/>
          <property name="Names" type="as" access="read"/>
          <property name="Secret" type="s" access="write"/>
          <property name="Broken" type="u" access="read"/>
        </interface>`
    readonly property string properties: "org.freedesktop.DBus.Properties"

    function ownGauge(name, asked) {
        const bus = connection({
            handler: (path, iface, member, args) => {
                asked?.push([path, iface, member, args]);
                if (member === "Broken")
                    throw new Error("no level");
                return member === "Level" ? 7 : ["a", "b"];
            }
        });
        verify(bus.own(name, "/gauge", gaugeXml));
        return bus;
    }

    function test_a_property_is_read_through_the_handler_as_a_method_of_its_name_and_typed_as_declared() {
        const name = "org.rekta.Test.Gauge";
        const asked = [];
        ownGauge(name, asked);
        compare(callFromCounterpart(name, "/gauge", properties, "Get", ["org.rekta.Gauge", "Level"]), {
            signature: "v",
            values: [7],
            error: ""
        });
        compare(asked, [["/gauge", "org.rekta.Gauge", "Level", []]]);
        compare(callFromCounterpart(name, "/gauge/1", properties, "Get", ["org.rekta.Gauge", "Names"]).values, [["a", "b"]]);
        compare(asked[1].slice(0, 3), ["/gauge/1", "org.rekta.Gauge", "Names"]);
    }

    function test_reading_all_properties_gives_each_readable_one_typed_as_declared() {
        const name = "org.rekta.Test.GaugeAll";
        const bus = ownGauge(name);
        bus.handler = (path, iface, member) => member === "Names" ? ["a", "b"] : 7;
        const all = callFromCounterpart(name, "/gauge", properties, "GetAll", ["org.rekta.Gauge"]);
        compare(all.signature, "a{sv}");
        compare(all.values, [{
                Level: 7,
                Names: ["a", "b"],
                Broken: 7
            }]);
        compare(counterpart.replyVariantTypes, {
            Level: "uint",
            Names: "QStringList",
            Broken: "uint"
        });
    }

    function test_unknown_write_only_failing_and_written_properties_are_answered_with_dbus_errors() {
        const name = "org.rekta.Test.GaugeErrors";
        ownGauge(name);
        const get = (iface, property) => callFromCounterpart(name, "/gauge", properties, "Get", [iface, property]);
        compare(get("org.rekta.Gauge", "Secret").error, "org.freedesktop.DBus.Error.UnknownProperty");
        compare(get("org.rekta.Gauge", "Missing").error, "org.freedesktop.DBus.Error.UnknownProperty");
        compare(get("org.rekta.Missing", "Level").error, "org.freedesktop.DBus.Error.UnknownProperty");
        compare(get("org.rekta.Gauge", "Broken"), {
            signature: "s",
            values: ["no level"],
            error: "org.freedesktop.DBus.Error.Failed"
        });
        compare(callFromCounterpart(name, "/gauge", properties, "GetAll", ["org.rekta.Gauge"]).error, "org.freedesktop.DBus.Error.Failed");
        compare(callFromCounterpart(name, "/gauge", properties, "GetAll", ["org.rekta.Missing"]).error, "org.freedesktop.DBus.Error.UnknownInterface");
        compare(callFromCounterpart(name, "/gauge", properties, "Set", ["org.rekta.Gauge", "Level", 3]).error, "org.freedesktop.DBus.Error.PropertyReadOnly");
        compare(callFromCounterpart(name, "/gauge", properties, "Get", ["org.rekta.Gauge"]).error, "org.freedesktop.DBus.Error.UnknownMethod");
        compare(get("org.rekta.Gauge", "Level").values, [7], "the object answers on");
    }

    function test_a_property_whose_handler_throws_an_error_without_a_message_is_answered_with_a_dbus_error() {
        const name = "org.rekta.Test.GaugeSilent";
        const bus = ownGauge(name);
        bus.handler = () => {
            throw new Error();
        };
        compare(callFromCounterpart(name, "/gauge", properties, "Get", ["org.rekta.Gauge", "Level"]), {
            signature: "s",
            values: ["the handler of Level threw"],
            error: "org.freedesktop.DBus.Error.Failed"
        });
        compare(callFromCounterpart(name, "/gauge", properties, "GetAll", ["org.rekta.Gauge"]).error, "org.freedesktop.DBus.Error.Failed");
    }

    function test_own_refuses_a_property_whose_type_is_not_one_complete_type() {
        const bus = connection();
        ignoreWarning(/is not XML or has a type that is not a valid D-Bus signature/);
        verify(!bus.own("org.rekta.Test.TwoTypes", "/gauge", `<interface name="org.rekta.Gauge"><property name="Pair" type="uu" access="read"/></interface>`));
        ignoreWarning(/is not XML or has a type that is not a valid D-Bus signature/);
        verify(!bus.own("org.rekta.Test.NoType", "/gauge", `<interface name="org.rekta.Gauge"><property name="None" type="" access="read"/></interface>`));
    }

    function test_a_handler_that_throws_answers_with_a_dbus_error() {
        const name = "org.rekta.Test.Throwing";
        ownJobs(name);
        const answer = callFromCounterpart(name, "/jobs", "org.rekta.Jobs", "fail", []);
        compare(answer.error, "org.freedesktop.DBus.Error.Failed");
        compare(answer.values, ["broken"]);
    }

    function test_a_method_whose_handler_throws_an_error_without_a_message_answers_with_a_dbus_error() {
        const name = "org.rekta.Test.ThrowingSilently";
        const bus = ownJobs(name);
        bus.handler = () => {
            throw new Error();
        };
        compare(callFromCounterpart(name, "/jobs", "org.rekta.Jobs", "count", []), {
            signature: "s",
            values: ["the handler of count threw"],
            error: "org.freedesktop.DBus.Error.Failed"
        });
    }

    // A handler that holds on to the responder it is given (the fifth argument) and answers when the test says.
    function ownLater(name) {
        const held = [];
        const bus = connection({
            handler: (path, iface, member, args, reply) => {
                if (member === "describe")
                    held.push({
                        reply,
                        args
                    });
                return member === "describe" ? reply : answerJobs(path, member, args);
            }
        });
        verify(bus.own(name, "/jobs", jobsXml));
        return {
            bus,
            held
        };
    }

    // Calls without waiting for the answer; the `answer` of the result is the reply of the signature given, null until it comes.
    function callWithoutWaiting(service, member, args, answerSignature) {
        const holder = {
            answer: null
        };
        counterpart.replied.connect((signature, values, error) => {
            if (signature === answerSignature)
                holder.answer = {
                    signature,
                    values,
                    error
                };
        });
        counterpart.call(service, "/jobs", "org.rekta.Jobs", member, args);
        return holder;
    }

    function test_a_handler_that_returns_its_responder_answers_later_with_what_it_sends() {
        const name = "org.rekta.Test.Later";
        const owner = ownLater(name);
        const call = callWithoutWaiting(name, "describe", [], "si");
        tryVerify(() => owner.held.length === 1);
        settle(owner.bus);
        compare(call.answer, null, "no answer while the handler holds the responder");
        compare(callFromCounterpart(name, "/jobs", "org.rekta.Jobs", "count", []).values, [2], "other calls are answered meanwhile");
        owner.held[0].reply.send(null, ["copy", 40]);
        tryVerify(() => call.answer !== null);
        compare(call.answer, {
            signature: "si",
            values: ["copy", 40],
            error: ""
        });
    }

    function test_a_responder_that_sends_an_error_answers_with_a_dbus_error() {
        const name = "org.rekta.Test.LaterError";
        const owner = ownLater(name);
        const call = callWithoutWaiting(name, "describe", [], "s");
        tryVerify(() => owner.held.length === 1);
        owner.held[0].reply.send("it went wrong", null);
        tryVerify(() => call.answer !== null);
        compare(call.answer.error, "org.freedesktop.DBus.Error.Failed");
        compare(call.answer.values, ["it went wrong"]);
    }

    function test_a_responder_answers_once_and_a_value_that_does_not_fit_is_an_error() {
        const name = "org.rekta.Test.LaterOnce";
        const owner = ownLater(name);
        const call = callWithoutWaiting(name, "describe", [], "si");
        tryVerify(() => owner.held.length === 1);
        owner.held[0].reply.send(null, ["copy", 40]);
        owner.held[0].reply.send("too late", null);
        tryVerify(() => call.answer !== null);
        settle(owner.bus);
        compare(call.answer.values, ["copy", 40], "a second send does nothing");

        const wrong = callWithoutWaiting(name, "describe", [], "s");
        tryVerify(() => owner.held.length === 2);
        owner.held[1].reply.send(null, "not a pair");
        tryVerify(() => wrong.answer !== null);
        compare(wrong.answer.error, "org.freedesktop.DBus.Error.Failed", "a value of the wrong shape is an error reply");
    }

    // A held call whose connection goes away (a reload of the shell) is answered by the bus at once, not after the
    // caller's timeout, and the name passes on.
    function test_a_call_still_held_when_its_connection_goes_away_is_answered_at_once_with_an_error_and_frees_the_name() {
        const name = "org.rekta.Test.HeldGone";
        const held = [];
        goingAway = connectionComponent.createObject(testCase, {
            handler: (path, iface, member, args, reply) => {
                held.push(reply);
                return reply;
            }
        });
        verify(goingAway.own(name, "/jobs", jobsXml));
        let answer = null;
        const store = (signature, values, error) => answer = {
            values,
            error
        };
        counterpart.replied.connect(store);
        counterpart.call(name, "/jobs", "org.rekta.Jobs", "describe", []);
        tryVerify(() => held.length === 1);
        goingAway.destroy();
        tryVerify(() => goingAway === null);
        tryVerify(() => answer !== null, 3000, "answered well before the caller's own timeout");
        counterpart.replied.disconnect(store);
        compare(answer.error, "org.freedesktop.DBus.Error.NoReply");
        tryVerify(() => counterpart.nameOwner(name) === "");
    }

    function test_a_responder_is_freed_once_it_has_sent_and_at_once_when_the_handler_does_not_return_it() {
        const name = "org.rekta.Test.Freed";
        const owner = ownLater(name);
        const call = callWithoutWaiting(name, "describe", [], "si");
        tryVerify(() => owner.held.length === 1);
        const sent = owner.held[0].reply;
        compare(sent.objectName, "", "alive while it holds the call");
        sent.send(null, ["copy", 40]);
        tryVerify(() => call.answer !== null);
        tryVerify(() => sent.objectName === undefined, 2000, "the responder that answered is freed");

        let kept = null;
        const now = connection({
            handler: (path, iface, member, args, reply) => {
                kept = reply;
                return 2;
            }
        });
        verify(now.own("org.rekta.Test.FreedAtOnce", "/jobs", jobsXml));
        compare(callFromCounterpart("org.rekta.Test.FreedAtOnce", "/jobs", "org.rekta.Jobs", "count", []).values, [2]);
        verify(kept !== null);
        compare(kept.objectName, undefined, "a responder the handler does not return is freed before the answer goes out");
    }

    function test_a_method_call_is_given_a_responder_and_a_property_read_is_not_and_a_handler_that_does_not_return_it_answers_at_once() {
        const given = {};
        const jobs = connection({
            handler: (path, iface, member, args, reply) => {
                given[member] = reply !== undefined && reply !== null;
                return 2;
            }
        });
        verify(jobs.own("org.rekta.Test.GivenMethod", "/jobs", jobsXml));
        compare(callFromCounterpart("org.rekta.Test.GivenMethod", "/jobs", "org.rekta.Jobs", "count", []).values, [2]);
        compare(given.count, true);
        const gauge = connection({
            handler: (path, iface, member, args, reply) => {
                given[member] = reply !== undefined && reply !== null;
                return 7;
            }
        });
        verify(gauge.own("org.rekta.Test.GivenProperty", "/gauge", gaugeXml));
        compare(callFromCounterpart("org.rekta.Test.GivenProperty", "/gauge", properties, "Get", ["org.rekta.Gauge", "Level"]).values, [7]);
        compare(given.Level, false);
    }

    function test_unknown_methods_interfaces_and_argument_types_are_answered_with_dbus_errors() {
        const name = "org.rekta.Test.Unknown";
        ownJobs(name);
        compare(callFromCounterpart(name, "/jobs", "org.rekta.Jobs", "vanish", []).error, "org.freedesktop.DBus.Error.UnknownMethod");
        compare(callFromCounterpart(name, "/jobs", "org.rekta.Missing", "count", []).error, "org.freedesktop.DBus.Error.UnknownInterface");
        compare(callFromCounterpart(name, "/jobs", "org.rekta.Jobs", "requestView", [5]).error, "org.freedesktop.DBus.Error.InvalidArgs");
    }

    function test_a_second_owner_waits_and_takes_the_name_over_without_a_gap() {
        const name = "org.rekta.Test.Handover";
        const watcher = connection();
        const owners = [];
        watcher.received.connect((sender, path, iface, member, args) => {
            if (args[0] === name)
                owners.push([args[1], args[2]]);
        });
        verify(watcher.listen("org.freedesktop.DBus", "NameOwnerChanged"));
        settle(watcher);
        const first = ownWho(name, "first");
        ownWho(name, "second");
        compare(who(name), "first");
        first.destroy();
        tryVerify(() => owners.length === 2);
        compare(owners[0][0], "");
        verify(owners[1][0] !== "" && owners[1][1] !== "", owners[1]);
        compare(who(name), "second");
    }

    function test_a_signal_goes_out_from_its_path_with_each_argument_typed_by_the_signature() {
        const heard = heardByCounterpart;
        const bus = connection();
        verify(bus.emitSignal("/events", "org.rekta.Events", "Counted", [3], "u"));
        verify(bus.emitSignal("/events/2", "org.rekta.Events", "Counted", ["copy", 40, true], "sxb"));
        tryVerify(() => heard.length === 2);
        compare(heard[0], {
            path: "/events",
            member: "Counted",
            signature: "u",
            values: [3]
        });
        compare(heard[1].path, "/events/2");
        compare(heard[1].signature, "sxb");
        compare(heard[1].values, ["copy", 40, true]);
    }

    function test_a_signal_whose_values_do_not_fit_its_signature_is_not_sent() {
        const heard = heardByCounterpart;
        const bus = connection();
        ignoreWarning(/cannot send Counted the signature u needs 1 values, not 2/);
        verify(!bus.emitSignal("/events", "org.rekta.Events", "Counted", [1, 2], "u"));
        ignoreWarning(/cannot send Counted .*not a valid D-Bus signature/);
        verify(!bus.emitSignal("/events", "org.rekta.Events", "Counted", [1], "a{vs}"));
        verify(bus.emitSignal("/events", "org.rekta.Events", "Counted", [7], "u"));
        tryVerify(() => heard.length > 0);
        compare(heard.map(signal => signal.values[0]), [7]);
    }

    function test_a_signal_with_a_name_d_bus_does_not_take_or_arguments_that_are_no_list_is_not_sent() {
        const heard = heardByCounterpart;
        const bus = connection();
        for (const [path, iface, member] of [["no path", "org.rekta.Events", "Counted"], ["", "org.rekta.Events", "Counted"],
                ["/events", "not an interface", "Counted"], ["/events", "org.rekta.Events", "1bad"]])
            verify(!bus.emitSignal(path, iface, member, [1], "u"), `${path} ${iface} ${member}`);
        ignoreWarning(/cannot send Counted the signature u needs 1 values, not 0/);
        verify(!bus.emitSignal("/events", "org.rekta.Events", "Counted", 5, "u"));
        ignoreWarning(/cannot send Counted the signature u needs 1 values, not 0/);
        verify(!bus.emitSignal("/events", "org.rekta.Events", "Counted", null, "u"));
        verify(bus.emitSignal("/events", "org.rekta.Events", "Counted", [], ""), "a signal without arguments");
        verify(bus.emitSignal("/events", "org.rekta.Events", "Counted", [8], "u"));
        tryVerify(() => heard.length === 2);
        compare(heard.map(signal => signal.signature), ["", "u"]);
    }

    // An instance gone in the middle of a flood: QtDBus must have stopped handing it messages before its connection goes.
    property DBusConnection goingAway: null

    function test_an_instance_that_goes_away_while_the_signals_it_hears_still_pour_in_leaves_the_process_running() {
        for (let round = 0; round < 30; ++round) {
            goingAway = connectionComponent.createObject(testCase);
            let heard = 0;
            goingAway.received.connect(() => ++heard);
            verify(goingAway.listen("org.rekta.Events", "Flood"));
            settle(goingAway);
            counterpart.flood("/flood", "org.rekta.Events", "Flood", 2000);
            tryVerify(() => heard > 0, 5000, `round ${round}`);
            goingAway.destroy();
            tryVerify(() => goingAway === null, 5000, `round ${round}`);
        }
    }

    // Gone right after the calls went out, never after an answer: waiting for one lets the calls drain first.
    function test_an_owner_that_goes_away_while_calls_to_it_still_pour_in_leaves_the_process_running() {
        for (let round = 0; round < 400; ++round) {
            // A name of its own each round, so no round queues behind the one before.
            const name = "org.rekta.Test.Flood" + round;
            goingAway = connectionComponent.createObject(testCase, {
                handler: () => 1
            });
            verify(goingAway.own(name, "/flood", `
                <interface name="org.rekta.Flood">
                  <method name="ping">
                    <arg type="u" direction="out"/>
                  </method>
                </interface>`));
            counterpart.callFlood(name, "/flood", "org.rekta.Flood", "ping", 200);
            goingAway.destroy();
            tryVerify(() => goingAway === null, 5000, `round ${round}`);
        }
    }

    function test_a_name_is_free_once_its_owner_is_gone() {
        const name = "org.rekta.Test.Gone";
        const only = ownWho(name, "only");
        verify(counterpart.nameOwner(name) !== "");
        only.destroy();
        tryVerify(() => counterpart.nameOwner(name) === "");
    }
}
