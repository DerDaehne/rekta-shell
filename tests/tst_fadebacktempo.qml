import QtQuick
import QtTest
import Rekta
import RektaShell.DBus
import "../shell/services"

// KWin's fade-back on the tests' private bus: this test owns org.kde.KWin and records what the shell tells it.
TestCase {
    id: testCase

    name: "FadeBackTempo"

    property var told: []

    DBusConnection {
        id: kwin

        handler: (path, iface, member, args) => {
            testCase.told = testCase.told.concat([args[0]]);
        }
    }

    Component {
        id: tempoComponent

        FadeBackTempo {}
    }

    function initTestCase() {
        verify(kwin.own("org.kde.KWin", "/RektaFadeBack", `
            <interface name="org.rekta.FadeBack">
              <method name="setStartTempo"><arg type="d" direction="in"/></method>
            </interface>`));
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        told = [];
    }

    function cleanup() {
        Prefs.startPace = "fast";
    }

    function lastTold(): real {
        return told[told.length - 1];
    }

    function test_the_shell_tells_kwin_the_start_s_tempo_as_it_starts() {
        createTemporaryObject(tempoComponent, testCase);
        tryVerify(() => told.length > 0, 2000);
        compare(lastTold(), Geometry.startTempo);
    }

    function test_a_change_of_the_setting_reaches_kwin_and_the_shell_s_own_timers() {
        createTemporaryObject(tempoComponent, testCase);
        tryVerify(() => told.length > 0, 2000);
        Prefs.startPace = "rekta";
        tryVerify(() => lastTold() === 1, 2000);
        compare(FadeBack.duration, Tokens.durationModerate, "waitForWindows and glassOut take this duration");
        Prefs.startPace = "fast";
        tryVerify(() => lastTold() === Geometry.startTempo, 2000);
        compare(FadeBack.duration, Geometry.startTempo * Tokens.durationModerate);
    }
}
