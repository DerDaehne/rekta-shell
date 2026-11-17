pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import DBusCounterpart
import "../shell/services"

TestCase {
    id: testCase

    name: "FadeBackSignals"

    // What the handlers were called with, as "member(values)".
    property var ran: []
    // How many signals reached the connection, handled or not.
    property int received: 0

    readonly property var handlers: ({
            fingerMoved: distance => testCase.ran.push(`fingerMoved(${distance})`),
            fingerLetGo: () => testCase.ran.push("fingerLetGo()"),
            touchpadUp: progress => testCase.ran.push(`touchpadUp(${progress})`)
        })

    // KWin as a stand-in on the private bus.
    Counterpart {
        id: kwin
    }

    Component {
        id: signalsComponent

        FadeBackSignals {
            handlers: testCase.handlers
        }
    }

    function init() {
        ran = [];
        failOnWarning(/No signal handler|TypeError|ReferenceError/);
        verify(kwin.takeName("org.kde.KWin"));
    }

    function cleanup() {
        kwin.releaseName("org.kde.KWin");
    }

    function listening() {
        const bus = createTemporaryObject(signalsComponent, testCase);
        received = 0;
        bus.received.connect(() => testCase.received++);
        // A round trip on the new connection: its subscriptions have reached the bus.
        let settled = false;
        bus.call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetId", [], "", () => settled = true);
        tryVerify(() => settled);
        return bus;
    }

    function emit(member, args) {
        kwin.emitSignal("/RektaFadeBack", "org.rekta.FadeBack", member, args ?? []);
    }

    function test_each_signal_of_the_effect_runs_its_handler_with_the_values_it_carries() {
        listening();
        emit("fingerMoved", [12.5]);
        emit("touchpadUp", [0.25]);
        emit("fingerLetGo");
        tryVerify(() => ran.length === 3);
        compare(ran, ["fingerMoved(12.5)", "touchpadUp(0.25)", "fingerLetGo()"]);
    }

    function test_a_signal_without_a_handler_reaches_nothing_and_logs_nothing() {
        listening();
        emit("edgeFingerMoved", [3.0]);
        emit("touchpadDownLetGo");
        emit("fingerLetGo");
        tryVerify(() => ran.length > 0);
        compare(ran, ["fingerLetGo()"]);
        // Only the one signal was delivered; the others were never subscribed to.
        compare(received, 1);
    }

    function test_signals_of_another_interface_or_path_reach_no_handler() {
        listening();
        kwin.emitSignal("/RektaFadeBack", "org.rekta.Other", "fingerLetGo", []);
        kwin.emitSignal("/elsewhere", "org.rekta.FadeBack", "fingerLetGo", []);
        emit("fingerMoved", [1.0]);
        tryVerify(() => ran.length > 0);
        compare(ran, ["fingerMoved(1)"]);
        compare(received, 1);
    }
}
