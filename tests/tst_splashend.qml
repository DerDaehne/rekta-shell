import QtQuick
import QtTest
import Rekta
import RektaShell.DBus
import "../shell/services"

// KSplash on the tests' private bus: this test owns org.kde.KSplash and records the stages the shell reports.
TestCase {
    id: testCase

    name: "SplashEnd"

    property var stages: []

    DBusConnection {
        id: ksplash

        handler: (path, iface, member, args) => {
            testCase.stages = testCase.stages.concat([args[0]]);
        }
    }

    Component {
        id: splashComponent

        SplashEnd {}
    }

    function initTestCase() {
        verify(ksplash.own("org.kde.KSplash", "/KSplash", `
            <interface name="org.kde.KSplash">
              <method name="setStage"><arg type="s" direction="in"/></method>
            </interface>`));
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        stages = [];
    }

    function cleanup() {
        Tokens.reducedMotion = false;
    }

    function test_the_splash_stays_until_the_surfaces_under_it_have_drawn() {
        createTemporaryObject(splashComponent, testCase);
        wait(2 * Tokens.durationModerate);
        compare(stages, []);
    }

    function test_once_they_have_drawn_the_shell_reports_the_desktop_stage() {
        const splash = createTemporaryObject(splashComponent, testCase);
        splash.ready = true;
        tryVerify(() => stages.length > 0, 2000);
        compare(stages, ["desktop"]);
    }

    function test_it_reports_once() {
        const splash = createTemporaryObject(splashComponent, testCase);
        splash.ready = true;
        splash.ready = false;
        splash.ready = true;
        tryVerify(() => splash.arrived, 2000);
        wait(50);
        compare(stages, ["desktop"]);
    }

    function test_the_shell_arrives_a_duration_moderate_later_as_the_splash_has_faded() {
        const splash = createTemporaryObject(splashComponent, testCase);
        splash.ready = true;
        const reported = Date.now();
        verify(!splash.arrived);
        tryVerify(() => splash.arrived, 2000);
        verify(Date.now() - reported >= Tokens.durationModerate - 1);
    }

    function test_under_reduced_motion_it_arrives_at_once() {
        Tokens.reducedMotion = true;
        const splash = createTemporaryObject(splashComponent, testCase);
        splash.ready = true;
        tryVerify(() => splash.arrived, 50);
    }
}
