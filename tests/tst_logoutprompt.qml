import QtQuick
import QtTest
import DBusCounterpart
import "../shell/services"

TestCase {
    id: testCase

    name: "LogoutPrompt"

    readonly property string service: "org.kde.LogoutPrompt"

    Counterpart {
        id: counterpart
    }

    Component {
        id: promptComponent

        LogoutPrompt {
            sessionDesktop: ""
        }
    }

    SignalSpy {
        id: requested

        signalName: "requested"
    }

    function prompt(sessionDesktop) {
        // A prompt of an earlier test may still hold the name until its deferred destruction has run.
        tryVerify(() => counterpart.nameOwner(service) === "");
        const created = createTemporaryObject(promptComponent, testCase, {
            sessionDesktop
        });
        requested.target = created;
        requested.clear();
        return created;
    }

    function callPrompt(member) {
        let error = null;
        const store = (signature, values, replyError) => error = replyError;
        counterpart.replied.connect(store);
        counterpart.call(service, "/LogoutPrompt", "org.kde.LogoutPrompt", member, []);
        tryVerify(() => error !== null);
        counterpart.replied.disconnect(store);
        return error;
    }

    function test_in_the_rekta_session_each_prompt_method_asks_for_its_kind() {
        prompt("rekta");
        verify(counterpart.nameOwner(service) !== "");
        for (const member of ["promptLogout", "promptShutDown", "promptReboot", "promptAll"])
            compare(callPrompt(member), "", member);
        compare(requested.signalArguments.map(args => args[0]), ["logout", "shutdown", "reboot", "all"]);
    }

    function test_in_the_rekta_session_an_unknown_method_gets_an_error() {
        prompt("rekta");
        compare(callPrompt("evaluateScript"), "org.freedesktop.DBus.Error.UnknownMethod");
        compare(requested.count, 0);
    }

    function test_outside_the_rekta_session_the_prompt_owns_nothing() {
        for (const sessionDesktop of ["", "KDE", "plasmawayland"]) {
            prompt(sessionDesktop);
            compare(counterpart.nameOwner(service), "", sessionDesktop);
        }
    }
}
