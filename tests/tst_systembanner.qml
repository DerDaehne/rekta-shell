pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta
import State

TestCase {
    id: testCase

    name: "SystemBanner"
    visible: true
    when: windowShown
    width: 1000
    height: 700

    property var remedied: []
    property Item scene
    property Banner banner
    property Toaster toaster
    property SystemBanners model

    Component {
        id: sceneComponent

        Item {
            width: 1000
            height: 700

            SystemBanners {
                id: states

                objectName: "model"
                batteryPercent: 4
                storageText: "Root is running out of space (180 MiB free)."
            }

            Banner {
                objectName: "banner"
                width: parent.width
                toaster: toasts
                order: states.order
                bannerStates: states.states
                sinceWord: "seit"
                stillText: (event, word) => `${event}. Das Banner zeigt weiter „${word}“, bis das endet.`
                remedy: name => testCase.remedied = [...testCase.remedied, name]
            }

            Toaster {
                id: toasts

                objectName: "toaster"
                width: parent.width
                y: 300
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "off";
        remedied = [];
        scene = createTemporaryObject(sceneComponent, testCase);
        banner = findChild(scene, "banner");
        toaster = findChild(scene, "toaster");
        model = findChild(scene, "model");
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    function flags(flags) {
        Object.assign(model, flags);
        model.apply(banner);
    }

    function test_nothing_shows_while_no_state_stands() {
        model.apply(banner);
        compare(banner.shown, "");
        verify(!banner.visible);
    }

    function test_the_battery_comes_before_offline_and_offline_before_storage() {
        flags({ storageFull: true });
        compare(banner.shown, "storage");
        flags({ offline: true });
        compare(banner.shown, "offline");
        flags({ batteryCritical: true });
        compare(banner.shown, "battery");
    }

    function test_each_state_speaks_german_in_its_status_colour() {
        flags({ batteryCritical: true });
        compare(banner.word, "akku");
        compare(banner.sentence, "Noch 4 %. Schließ das Netzteil an.");
        compare(banner.status, "error");
        compare(banner.actionLabel, "energieprofil");
        flags({ batteryCritical: false, offline: true });
        compare([banner.word, banner.sentence, banner.status, banner.actionLabel], ["offline", "Keine Verbindung zum Netz.", "error", "verbindungen"]);
        flags({ offline: false, storageFull: true });
        compare([banner.word, banner.sentence, banner.status, banner.actionLabel], ["speicher", "Root is running out of space (180 MiB free).", "warning", "aufräumen"]);
    }

    function test_the_time_line_says_seit() {
        flags({ offline: true });
        verify(findChild(banner, "time").text.startsWith("seit "));
    }

    function test_a_state_under_a_heavier_one_is_told_in_a_toast_that_says_the_banner_keeps_showing() {
        flags({ batteryCritical: true });
        flags({ offline: true });
        compare(toaster.open.text, "Verbindung verloren. Das Banner zeigt weiter „akku“, bis das endet.");
        flags({ offline: false });
        compare(toaster.open.text, "Wieder verbunden. Das Banner zeigt weiter „akku“, bis das endet.");
        compare(banner.shown, "battery");
    }

    function test_a_state_that_ends_stays_in_the_banner_until_it_ends_and_is_then_told_by_a_toast() {
        flags({ storageFull: true });
        flags({ storageFull: false });
        compare(banner.shown, "");
        compare(toaster.open.text, "Wieder genug Speicher frei.");
    }

    function test_the_lighter_state_takes_over_when_the_heavier_one_ends() {
        flags({ batteryCritical: true, offline: true });
        flags({ batteryCritical: false });
        compare(banner.shown, "offline");
        compare(toaster.open.text, "Akku nicht mehr kritisch.");
    }

    function test_the_battery_sentence_follows_the_percentage_in_place() {
        flags({ batteryCritical: true });
        const started = findChild(banner, "time").text;
        flags({ batteryPercent: 3 });
        compare(banner.sentence, "Noch 3 %. Schließ das Netzteil an.");
        compare(findChild(banner, "time").text, started, "its start stays");
    }

    function test_the_remedy_calls_its_target_and_leaves_the_state_on() {
        flags({ batteryCritical: true });
        banner.runRemedy();
        compare(remedied, ["battery"]);
        verify(banner.isOn("battery"));
        compare(banner.shown, "battery");
    }

    function test_the_places_the_remedies_open_are_in_the_controls_panel() {
        compare(model.places, { battery: "power", offline: "connections" });
    }

    function test_over_a_full_screen_window_only_the_battery_shows() {
        flags({ offline: true });
        verify(!model.mayShow(banner.word, true));
        verify(model.mayShow(banner.word, false));
        flags({ batteryCritical: true });
        verify(model.mayShow(banner.word, true));
        flags({ batteryCritical: false });
        verify(!model.mayShow(banner.word, true), "offline waits again");
    }

    function test_contact_sheet() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const sheet = createTemporaryObject(sheetComponent, testCase);
            waitForRendering(sheet);
            wait(Tokens.durationShort + 100);
            grabImage(sheet).save(`systembanner-sheet-${theme}.png`);
        }
    }

    Component {
        id: sheetComponent

        Rectangle {
            width: 1000
            height: 700
            color: Tokens.color.bg

            readonly property date since: new Date(2026, 9, 30, 14, 5)

            SystemBanners {
                id: sheetStates

                batteryPercent: 4
                storageText: "Root is running out of space (180 MiB free)."
            }

            Column {
                width: parent.width
                spacing: Tokens.spaceXl

                Repeater {
                    model: sheetStates.order

                    Banner {
                        required property string modelData

                        width: parent.width
                        order: sheetStates.order
                        bannerStates: sheetStates.states
                        sinceWord: "seit"
                        Component.onCompleted: set(modelData, true, { since: new Date(2026, 9, 30, 14, 5), text: sheetStates.sentences[modelData] })
                    }
                }
            }
        }
    }
}
