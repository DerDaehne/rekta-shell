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

    Counterpart {
        id: counterpart
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

    function echo(args, signature) {
        return callThrough(connection(), "org.rekta.Counterpart", "/echo", "org.rekta.Echo", "Echo", args, signature);
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

    function test_a_missing_service_an_error_reply_and_a_wrong_signature_come_back_as_the_error() {
        const bus = connection();
        const missing = callThrough(bus, "org.rekta.Missing", "/", "org.rekta.Missing", "Anything", [], "");
        verify(missing.error.startsWith("org.freedesktop.DBus.Error.ServiceUnknown: "), missing.error);
        compare(missing.values, []);
        const refused = callThrough(bus, "org.rekta.Counterpart", "/echo", "org.rekta.Echo", "Fail", [], "");
        compare(refused.error, "org.rekta.Counterpart.Failed: asked to fail");
        for (const [args, signature] of [[[[1]], "a(i"], [["a", "b"], "s"], [["seven"], "i"], [["no path"], "o"], [[{}], "as"], [[[1]], "(ii)"], [[null], "v"]]) {
            const wrong = echo(args, signature);
            verify(wrong.error !== null, signature);
            compare(wrong.values, [], signature);
        }
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

    function test_a_handler_that_throws_answers_with_a_dbus_error() {
        const name = "org.rekta.Test.Throwing";
        ownJobs(name);
        const answer = callFromCounterpart(name, "/jobs", "org.rekta.Jobs", "fail", []);
        compare(answer.error, "org.freedesktop.DBus.Error.Failed");
        compare(answer.values, ["broken"]);
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

    function test_a_name_is_free_once_its_owner_is_gone() {
        const name = "org.rekta.Test.Gone";
        const only = ownWho(name, "only");
        verify(counterpart.nameOwner(name) !== "");
        only.destroy();
        tryVerify(() => counterpart.nameOwner(name) === "");
    }
}
