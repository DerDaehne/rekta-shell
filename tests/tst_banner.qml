pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "Banner"
    visible: true
    when: windowShown
    width: 1000
    height: 600

    property Item scene
    property Banner banner
    property Toaster toaster
    property var remedied: []

    Component {
        id: sceneComponent

        Item {
            width: 1000
            height: 600

            Column {
                width: parent.width

                Banner {
                    objectName: "banner"
                    width: parent.width
                    toaster: toasts
                    order: ["halted", "offline", "paused", "readonly"]
                    bannerStates: ({
                            halted: { word: "halted", status: "error", alert: true, text: "Every run has stopped.", action: "retry now", on: "The system halted", off: "The system runs again. Runs pick up where they stopped." },
                            offline: { word: "offline", text: "Changes are kept on this device.", action: "try again", on: "You are offline", off: "Back online. Changes are sent." },
                            paused: { word: "paused", status: "warning", text: "Runs wait until you resume them.", action: "resume", on: "Runs paused", off: "Runs resumed. The queue moves again." },
                            readonly: { word: "read-only", since: "until", until: "15:00", text: "Maintenance.", on: "Maintenance started", off: "Maintenance finished. Changes are open again." }
                        })
                }

                Item {
                    objectName: "place"
                    width: parent.width
                    height: 200
                }
            }

            Toaster {
                id: toasts

                objectName: "toaster"
                width: parent.width
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
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    function test_the_most_severe_state_that_is_on_holds_the_banner() {
        verify(!banner.visible);
        compare(banner.height, 0, "no state, no height");
        banner.set("paused", true, {});
        compare(banner.shown, "paused");
        banner.set("halted", true, {});
        compare(banner.shown, "halted");
        banner.set("offline", true, {});
        compare(banner.shown, "halted", "one banner at a time");
        banner.set("halted", false, {});
        compare(banner.shown, "offline");
        verify(banner.isOn("paused"));
    }

    function test_a_state_stands_on_its_status_fill_and_the_neutral_one_on_surface_above_a_hairline() {
        Prefs.theme = "dark";
        banner.set("paused", true, {});
        compare(findChild(banner, "fill").color, Tokens.color.statusWarningTile);
        compare(findChild(banner, "word").color, Tokens.color.textPrimary);
        compare(findChild(banner, "time").color, Tokens.color.textPrimary, "secondary text takes the primary colour on a fill");
        verify(!findChild(banner, "fill").children[0].visible);
        banner.set("paused", false, {});
        banner.set("offline", true, {});
        compare(findChild(banner, "fill").color, Tokens.color.surface);
        verify(findChild(banner, "fill").children[0].visible, "the neutral state parts from the ground with a hairline");
    }

    function test_a_state_comes_in_once_with_a_fade_and_8px_and_a_new_sentence_is_written_in_place() {
        Prefs.motion = "on";
        banner.set("paused", true, {});
        const coming = findChild(banner, "coming");
        compare(coming.duration, Tokens.durationShort);
        verify(coming.running);
        compare(banner.entry, 0);
        const content = findChild(banner, "live").parent;
        compare(content.opacity, 0);
        compare(content.transform[0].y, -Geometry.bannerShift);
        tryCompare(banner, "entry", 1, 1000);
        compare(content.transform[0].y, 0);
        banner.update("paused", "Runs wait until you resume them: 3 so far.");
        compare(findChild(banner, "sentence").text, "Runs wait until you resume them: 3 so far.");
        verify(!coming.running, "it does not move again");
        banner.set("paused", true, { text: "Runs wait until you resume them: 4 so far." });
        compare(findChild(banner, "sentence").text, "Runs wait until you resume them: 4 so far.");
        verify(!coming.running);
    }

    function test_its_height_grows_with_its_entry_so_the_place_below_moves_with_it() {
        Prefs.motion = "on";
        banner.set("offline", true, {});
        const place = findChild(scene, "place");
        wait(Tokens.durationShort / 2);
        verify(banner.height > 0 && banner.height < banner.contentHeight, `on its way: ${banner.height}`);
        tryCompare(banner, "height", banner.contentHeight, 1000);
        tryCompare(place, "y", banner.contentHeight, 1000);
    }

    function test_a_change_of_kind_glides_from_the_old_height_to_the_new() {
        Prefs.motion = "on";
        banner.set("offline", true, { since: false });
        tryCompare(banner, "entry", 1, 1000);
        const before = banner.height;
        banner.set("halted", true, {});
        compare(banner.height, before, "it starts where the last state stood");
        tryCompare(banner, "entry", 1, 1000);
        compare(banner.height, banner.contentHeight);
        verify(banner.height !== before, "a time line makes it higher");
    }

    function test_a_halt_is_an_alert_and_other_states_are_said_politely() {
        banner.set("halted", true, {});
        compare(findChild(banner, "live").Accessible.role, Accessible.AlertMessage);
        banner.set("halted", false, {});
        banner.set("paused", true, {});
        compare(findChild(banner, "live").Accessible.role, Accessible.Notification);
        compare(findChild(banner, "live").Accessible.name, `paused ${banner.timeLine} Runs wait until you resume them.`);
    }

    function test_the_time_line_says_since_when_or_until_when_or_nothing_when_nobody_knows() {
        const twoOClock = new Date();
        twoOClock.setHours(14, 5, 0, 0);
        banner.set("paused", true, { since: twoOClock });
        compare(findChild(banner, "time").text, `since ${twoOClock.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)}`);
        banner.set("paused", false, {});
        const yesterday = new Date(twoOClock.getTime() - 24 * 3600 * 1000);
        banner.set("paused", true, { since: yesterday });
        compare(findChild(banner, "time").text, `since ${yesterday.toLocaleString(Qt.locale(), Locale.ShortFormat)}`, "with the day");
        banner.set("paused", false, {});
        banner.set("paused", true, { since: false });
        verify(!findChild(banner, "time").visible, "no time rather than a wrong one");
        banner.set("paused", false, {});
        banner.set("readonly", true, {});
        compare(findChild(banner, "time").text, "until 15:00");
    }

    function test_a_state_that_stays_on_keeps_its_start() {
        const twoOClock = new Date();
        twoOClock.setHours(14, 5, 0, 0);
        banner.set("paused", true, { since: twoOClock });
        const line = banner.timeLine;
        banner.set("paused", true, { since: new Date(), text: "Runs wait: 4 so far." });
        compare(banner.timeLine, line);
    }

    function test_the_remedy_runs_the_state_s_remedy_or_turns_the_state_off() {
        banner.set("paused", true, {});
        const remedy = findChild(banner, "remedy");
        verify(remedy.visible);
        compare(remedy.text, "resume");
        waitForRendering(banner);
        mouseClick(findChild(remedy, "box"));
        verify(!banner.isOn("paused"), "without a remedy it turns the state off");
        banner.remedy = name => {
            testCase.remedied = [...testCase.remedied, name];
        };
        banner.set("halted", true, {});
        waitForRendering(banner);
        mouseClick(findChild(remedy, "box"));
        compare(testCase.remedied, ["halted"]);
        verify(banner.isOn("halted"));
        banner.set("halted", false, {});
        banner.set("readonly", true, {});
        verify(!remedy.visible, "a state without a remedy shows none");
    }

    function test_a_state_that_ends_is_reported_as_a_toast_once_the_banner_has_gone() {
        Prefs.motion = "on";
        banner.set("paused", true, {});
        tryCompare(banner, "entry", 1, 1000);
        banner.set("paused", false, {});
        verify(banner.leaving);
        compare(toaster.open, null, "not while the banner leaves");
        tryVerify(() => toaster.open !== null, 1000);
        compare(toaster.open.text, "Runs resumed. The queue moves again.");
        verify(!banner.visible);
    }

    function test_a_state_that_starts_or_ends_beneath_a_more_severe_one_is_reported_as_a_toast() {
        banner.set("halted", true, {});
        banner.set("paused", true, {});
        compare(toaster.open.text, "Runs paused. The banner keeps showing “halted” until that ends.");
        banner.set("paused", false, {});
        compare(toaster.open.text, "Runs resumed. The banner keeps showing “halted” until that ends.");
        banner.set("offline", true, {});
        banner.set("halted", false, {});
        compare(banner.shown, "offline");
        compare(toaster.open.text, "The system runs again. Runs pick up where they stopped.", "the state that took over the banner says the halt ended");
    }

    function test_word_sentence_and_remedy_share_a_first_baseline() {
        banner.set("paused", true, {});
        const word = findChild(banner, "word");
        const sentence = findChild(banner, "sentence");
        const remedy = findChild(banner, "remedy");
        const wordBaseline = word.mapToItem(banner, 0, word.baselineOffset).y;
        compare(sentence.mapToItem(banner, 0, sentence.baselineOffset).y, wordBaseline);
        compare(remedy.mapToItem(banner, 0, remedy.baselineOffset).y, wordBaseline);
        compare(word.mapToItem(banner, 0, 0).x, Tokens.spaceXl);
        compare(sentence.mapToItem(banner, 0, 0).x, Tokens.spaceXl + Tokens.tileUnit + Tokens.spaceS, "the sentence starts on tile column 2");
        compare(remedy.mapToItem(banner, remedy.width, 0).x, banner.width - Tokens.spaceXl, "the remedy stands at the end");
        compare(word.font.pixelSize, Tokens.fluid(Tokens.fontSizeL, banner.placeWidth));
        compare(word.font.weight, Tokens.fontWeightLight);
    }

    function test_a_narrow_banner_puts_the_sentence_and_then_the_remedy_on_lines_of_their_own() {
        banner.set("paused", true, {});
        banner.width = 2 * Tokens.spaceXl + 3 * Tokens.tileUnit + 2 * Tokens.spaceS;
        const sentence = findChild(banner, "sentence");
        const remedy = findChild(banner, "remedy");
        compare(remedy.mapToItem(banner, 0, 0).x, Tokens.spaceXl, "the remedy wraps first");
        verify(remedy.mapToItem(banner, 0, 0).y > sentence.mapToItem(banner, 0, 0).y);
        banner.width = 2 * Tokens.spaceXl + Tokens.tileUnit + Tokens.spaceS + 2 * Tokens.tileUnit;
        compare(sentence.mapToItem(banner, 0, 0).x, Tokens.spaceXl, "then the sentence goes under the word");
        verify(sentence.mapToItem(banner, 0, 0).y > findChild(banner, "word").mapToItem(banner, 0, 0).y);
    }

    function test_the_remedy_s_focus_ring_takes_the_text_colour_on_a_status_fill() {
        banner.set("paused", true, {});
        const remedy = findChild(banner, "remedy");
        remedy.forceActiveFocus();
        const ring = findChild(remedy, "ring");
        verify(ring.visible);
        compare(ring.border.color, Tokens.color.textPrimary);
        banner.set("paused", false, {});
        banner.set("offline", true, {});
        remedy.forceActiveFocus();
        compare(ring.border.color, Tokens.color.focus, "on the neutral surface it keeps the focus colour");
    }

    function test_the_app_bar_follows_the_banner() {
        compare(banner.liveWord, "live");
        banner.set("paused", true, {});
        compare(banner.appbarState, "paused");
        compare(banner.liveWord, "paused");
        banner.set("halted", true, {});
        compare(banner.appbarState, "halted");
        banner.set("halted", false, {});
        banner.set("paused", false, {});
        banner.set("offline", true, {});
        compare(banner.appbarState, "");
        compare(banner.liveWord, "offline");
    }

    function test_under_reduced_motion_the_banner_comes_and_goes_at_once() {
        banner.set("offline", true, {});
        compare(banner.entry, 1);
        compare(banner.height, banner.contentHeight);
        banner.set("offline", false, {});
        verify(!banner.visible);
        compare(banner.height, 0);
        compare(toaster.open.text, "Back online. Changes are sent.");
    }

    function test_an_unknown_state_is_refused() {
        let refused = false;
        try {
            banner.set("melting", true, {});
        } catch (error) {
            refused = true;
        }
        verify(refused);
    }

    function test_the_banner_lies_below_toasts() {
        compare(banner.z, Tokens.layerBanner);
        verify(banner.z < toaster.z);
    }
}
