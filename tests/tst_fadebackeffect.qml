pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import DBusCounterpart
import RektaShell.DBus
import "../shell/services"

TestCase {
    id: testCase

    name: "FadeBackEffect"

    readonly property string build: "0.1.5+20261124.1200.abc1234"
    // The effect of this build, as QtDBus describes it.
    readonly property string currentXml: `
        <interface name="org.rekta.FadeBack">
          <method name="setStartAt">
            <arg name="elapsed" type="d" direction="in"/>
            <arg name="pace" type="i" direction="in"/>
          </method>
          <method name="showWindowMenu">
            <arg name="window" type="s" direction="in"/>
            <arg name="x" type="i" direction="in"/>
            <arg name="y" type="i" direction="in"/>
          </method>
          <method name="version">
            <arg type="s" direction="out"/>
          </method>
          <signal name="loaded"/>
        </interface>`
    // An effect from before the window menu and the version.
    readonly property string olderXml: `
        <interface name="org.rekta.FadeBack">
          <method name="setStartAt">
            <arg name="elapsed" type="d" direction="in"/>
            <arg name="pace" type="i" direction="in"/>
          </method>
          <signal name="fingerLetGo"/>
        </interface>`

    // What the stand-in's version answers.
    property string effectVersion: build
    // The members of org.rekta.FadeBack the stand-in was called with, in order.
    property var asked: []

    // Asks the bus who owns a name.
    Counterpart {
        id: bus
    }

    // KWin with its fade-back, as a stand-in on the private bus; setStartAt fails while failing is set, and version while
    // versionGone is, as when the effect goes between being introspected and asked.
    Component {
        id: kwinComponent

        DBusConnection {
            property bool failing: false
            property bool versionGone: false

            handler: (path, interfaceName, member, args) => {
                testCase.asked.push(member);
                if (member === "setStartAt" && failing)
                    throw new Error("the windows stand still");
                if (member === "version" && versionGone)
                    throw new Error("the effect has gone");
                return member === "version" ? testCase.effectVersion : undefined;
            }
        }
    }

    Component {
        id: effectComponent

        FadeBackEffect {
            buildVersion: testCase.build
        }
    }

    function init() {
        effectVersion = build;
        asked = [];
        failOnWarning(/FadeBackEffect|TypeError|ReferenceError/);
        // The stand-in of the test before may still be giving the name up.
        tryVerify(() => bus.nameOwner("org.kde.KWin") === "");
    }

    function kwin(xml: string): var {
        const standIn = createTemporaryObject(kwinComponent, testCase);
        verify(standIn.own("org.kde.KWin", "/RektaFadeBack", xml));
        return standIn;
    }

    function effect(properties: var): var {
        return createTemporaryObject(effectComponent, testCase, properties ?? {});
    }

    // Answered in order by whoever answers for KWin (the stand-in, or the bus while nobody owns the name), so every
    // earlier call there has its reply when this one returns.
    function roundTrip(effect: var) {
        let back = false;
        effect.call("org.kde.KWin", "/RektaFadeBack", "org.rekta.FadeBack", "version", [], "", () => back = true);
        tryVerify(() => back);
    }

    function staleLine(running: string): string {
        return `FadeBackEffect: KWin runs ${running}, the shell is ${build}: log out and back in to load the shell's`;
    }

    function test_the_methods_of_the_effect_kwin_runs_are_known_once_it_has_answered() {
        kwin(currentXml);
        const running = effect();
        tryVerify(() => running.methods.length > 0);
        compare(running.methods, ["setStartAt", "showWindowMenu", "version"]);
    }

    function test_an_effect_of_the_shells_own_version_writes_nothing() {
        kwin(currentXml);
        const running = effect();
        tryVerify(() => asked.includes("version"));
        roundTrip(running);
    }

    function test_an_older_effect_without_window_menu_or_version_is_named_once_and_offers_no_window_menu() {
        kwin(olderXml);
        ignoreWarning(staleLine("an older rekta-fadeback without a version"));
        const running = effect();
        tryVerify(() => running.methods.length > 0);
        compare(running.methods, ["setStartAt"]);
        verify(!running.methods.includes("showWindowMenu"));
    }

    function test_an_effect_of_another_version_is_named_once_with_both_versions() {
        effectVersion = "0.1.5+20261123.1951.1b45490";
        kwin(currentXml);
        ignoreWarning(staleLine("rekta-fadeback 0.1.5+20261123.1951.1b45490"));
        const running = effect();
        tryVerify(() => asked.includes("version"));
        roundTrip(running);
        compare(asked.filter(member => member === "version").length, 2, "asked once by the effect, once by the round trip");
    }

    function test_without_a_known_build_only_a_missing_version_is_named() {
        effectVersion = "0.1.5+20261123.1951.1b45490";
        kwin(currentXml);
        const running = effect({
            buildVersion: ""
        });
        tryVerify(() => asked.includes("version"));
        roundTrip(running);
    }

    function test_without_an_effect_in_kwin_the_journal_says_so_and_nothing_is_offered() {
        ignoreWarning(staleLine("no rekta-fadeback"));
        const running = effect();
        roundTrip(running);
        compare(running.methods, []);
    }

    function test_the_effect_coming_anew_makes_the_shell_ask_again() {
        effectVersion = "0.1.5+20261123.1951.1b45490";
        const standIn = kwin(currentXml);
        ignoreWarning(staleLine("rekta-fadeback 0.1.5+20261123.1951.1b45490"));
        const running = effect();
        tryVerify(() => asked.includes("version"));
        effectVersion = "0.1.6+20261201.0900.def5678";
        ignoreWarning(staleLine("rekta-fadeback 0.1.6+20261201.0900.def5678"));
        standIn.emitSignal("/RektaFadeBack", "org.rekta.FadeBack", "loaded", [], "");
        tryVerify(() => asked.filter(member => member === "version").length === 2);
        roundTrip(running);
    }

    function test_a_failing_call_is_named_once_per_method_until_the_effect_comes_anew() {
        const standIn = kwin(currentXml);
        const running = effect();
        tryVerify(() => asked.includes("version"));
        standIn.failing = true;
        const line = "FadeBackEffect: setStartAt failed: org.freedesktop.DBus.Error.Failed: the windows stand still";
        ignoreWarning(line);
        running.tell("setStartAt", [120, 1], "di");
        running.tell("setStartAt", [240, 1], "di");
        running.tell("showWindowMenu", ["{0}", 10, 20], "sii");
        roundTrip(running);
        compare(asked.filter(member => member === "setStartAt").length, 2);
        compare(asked.filter(member => member === "showWindowMenu").length, 1, "a method that answers writes nothing");

        standIn.emitSignal("/RektaFadeBack", "org.rekta.FadeBack", "loaded", [], "");
        tryVerify(() => asked.filter(member => member === "version").length === 3);
        ignoreWarning(line);
        running.tell("setStartAt", [360, 1], "di");
        roundTrip(running);
    }

    function test_a_method_that_answered_before_is_named_once_it_fails() {
        const standIn = kwin(currentXml);
        const running = effect();
        tryVerify(() => asked.includes("version"));
        running.tell("setStartAt", [120, 1], "di");
        roundTrip(running);
        standIn.failing = true;
        ignoreWarning("FadeBackEffect: setStartAt failed: org.freedesktop.DBus.Error.Failed: the windows stand still");
        running.tell("setStartAt", [240, 1], "di");
        roundTrip(running);
    }

    function test_an_effect_gone_before_it_names_its_version_is_named_of_an_unknown_version() {
        const standIn = kwin(currentXml);
        standIn.versionGone = true;
        ignoreWarning(staleLine("a rekta-fadeback of an unknown version"));
        const running = effect();
        tryVerify(() => asked.includes("version"));
        roundTrip(running);
    }
}
