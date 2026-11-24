pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Notices
import Rekta
import "../shell/services"

TestCase {
    id: testCase

    name: "StaleEffectHint"
    visible: true
    when: windowShown
    width: 900
    height: 640

    readonly property string words: "neu anmelden für alle neuen funktionen"
    property Toaster toaster
    property NoticeBoard board
    property SignalSpy asked

    FakeNotifications {
        id: fakes
    }

    Component {
        id: sceneComponent

        Rectangle {
            width: 900
            height: 640
            color: Tokens.color.bg

            Toaster {
                objectName: "toaster"
                width: parent.width
            }
        }
    }

    Component {
        id: boardComponent

        NoticeBoard {}
    }

    Component {
        id: hintComponent

        StaleEffectHint {
            toaster: testCase.toaster
            stale: false
            quiet: false
        }
    }

    Component {
        id: spyComponent

        SignalSpy {}
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "off";
        fakes.calls = [];
        toaster = findChild(createTemporaryObject(sceneComponent, testCase), "toaster");
        board = createTemporaryObject(boardComponent, testCase, { toaster: toaster });
    }

    function cleanup() {
        Prefs.motion = "system";
    }

    // One shell start's hint.
    function start(properties: var): var {
        const hint = createTemporaryObject(hintComponent, testCase, properties);
        asked = createTemporaryObject(spyComponent, testCase, { target: hint, signalName: "sessionAsked" });
        return hint;
    }

    function hintShows(): bool {
        return toaster.open?.text === words;
    }

    function test_a_running_effect_that_is_not_the_shells_brings_a_plain_toast_with_abmelden() {
        start({ stale: true });
        verify(hintShows());
        compare(toaster.open.actionLabel, "abmelden");
        compare(toaster.open.status, "", "plain, in ink");
        verify(!toaster.open.stays, "it runs out as any toast");
        verify(!toaster.open.notification, "the shell's own, rising from the bar");
    }

    function test_the_shells_own_effect_brings_no_toast() {
        const hint = start({ stale: false });
        compare(toaster.open, null);
        hint.quiet = true;
        hint.quiet = false;
        compare(toaster.open, null);
    }

    function test_a_mismatch_found_after_the_start_brings_the_toast_then() {
        const hint = start({ stale: false });
        hint.stale = true;
        verify(hintShows());
    }

    function test_it_shows_once_per_start_also_when_the_effect_comes_anew_and_still_differs() {
        const hint = start({ stale: true });
        verify(hintShows());
        toaster.dismiss();
        tryVerify(() => toaster.open === null && toaster.leaving === 0);
        hint.stale = false;
        hint.stale = true;
        compare(toaster.open, null, "not a second time this start");
        start({ stale: true });
        verify(hintShows(), "the next start asks again");
    }

    function test_abmelden_asks_once_for_the_session_bar_with_the_focus_on_logging_out() {
        start({ stale: true });
        const toast = toaster.open;
        mouseClick(findChild(toast, "action"));
        compare(asked.count, 1);
        compare(asked.signalArguments[0][0], "logout");
        tryVerify(() => toaster.open === null, 1000, "the toast goes as it acts");
    }

    function test_it_takes_the_place_of_a_notification_that_stands_which_stays_unseen_in_the_list() {
        const anna = fakes.make({ summary: "Book club at seven", body: "Bring the second chapter" });
        board.arrive(anna);
        compare(toaster.open.title, "Book club at seven");
        start({ stale: true });
        verify(hintShows());
        compare(board.rows.map(row => [row.summary, row.unseen]), [["Book club at seven", true]]);
        compare(board.rows[0].notification, anna, "still open in the list");
        compare(fakes.calls, [], "nothing closed it");
    }

    function test_it_waits_while_notifications_are_quiet_and_comes_once_they_are_not() {
        const hint = start({ stale: true, quiet: true });
        compare(toaster.open, null, "not over a full-screen window or while nicht stören");
        hint.quiet = false;
        verify(hintShows());
    }
}
