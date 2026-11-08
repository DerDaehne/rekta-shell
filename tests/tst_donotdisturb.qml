pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import State

TestCase {
    id: testCase

    name: "DoNotDisturb"

    // The fake clock: ms since the epoch, and the zone's offset in minutes. Berlin in November is UTC+1.
    property real time: 0
    property int zone: 60

    Component {
        id: quietComponent

        DoNotDisturb {
            clock: () => testCase.time
            zoneOffset: () => testCase.zone
        }
    }

    function make(): var {
        return createTemporaryObject(quietComponent, testCase);
    }

    // A time on the Berlin wall clock in November 2026.
    function berlin(date: int, hours: int, minutes: int): real {
        return Date.UTC(2026, 10, date, hours - 1, minutes);
    }

    function at(quiet: var, time: real) {
        testCase.time = time;
        quiet.tick();
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        zone = 60;
        time = berlin(8, 14, 0);
    }

    function test_one_hour_shows_its_end_then_the_minutes_left_and_is_off_when_it_has_run_out() {
        const quiet = make();
        quiet.choose("hour");
        verify(quiet.on);
        compare(quiet.endWord, "bis 15:00");
        compare(quiet.middleParts, ["nicht stören", "bis 15:00"], "from an hour on, its end");
        at(quiet, berlin(8, 14, 0) + 1000);
        compare(quiet.middleParts, ["nicht stören", "bis 15:00"], "a minute begun still counts whole");
        at(quiet, berlin(8, 14, 1));
        compare(quiet.middleParts, ["nicht stören", "noch 59 min"], "under an hour, the minutes left");
        at(quiet, berlin(8, 14, 59) + 30000);
        compare(quiet.middleParts, ["nicht stören", "noch 1 min"]);
        at(quiet, berlin(8, 15, 0));
        verify(!quiet.on, "it has run out");
        compare(quiet.middleParts, []);
        compare(quiet.endWord, "");
        compare(quiet.chosen, -1);
    }

    function test_until_the_morning_switched_on_in_the_evening_ends_at_seven_the_next_morning_across_midnight() {
        const quiet = make();
        at(quiet, berlin(8, 22, 0));
        quiet.choose("morning");
        compare(quiet.endWord, "bis 07:00");
        compare(quiet.endsAt, berlin(9, 7, 0));
        at(quiet, berlin(9, 0, 30));
        verify(quiet.on, "past midnight it still holds");
        compare(quiet.middleParts, ["nicht stören", "bis 07:00"]);
        at(quiet, berlin(9, 6, 30));
        compare(quiet.middleParts, ["nicht stören", "noch 30 min"]);
        at(quiet, berlin(9, 7, 0));
        verify(!quiet.on, "off at seven");
    }

    function test_until_the_morning_switched_on_before_seven_ends_at_seven_the_same_morning() {
        const quiet = make();
        at(quiet, berlin(9, 5, 0));
        quiet.choose("morning");
        compare(quiet.endsAt, berlin(9, 7, 0));
        compare(quiet.middleParts, ["nicht stören", "bis 07:00"]);
        at(quiet, berlin(9, 6, 15));
        compare(quiet.middleParts, ["nicht stören", "noch 45 min"]);
    }

    function test_until_the_morning_switched_on_at_seven_ends_the_next_morning() {
        const quiet = make();
        at(quiet, berlin(9, 7, 0));
        quiet.choose("morning");
        compare(quiet.endsAt, berlin(10, 7, 0));
    }

    function test_until_the_morning_follows_a_change_of_time_zone_to_seven_on_the_new_wall_clock() {
        const quiet = make();
        at(quiet, berlin(8, 22, 0));
        quiet.choose("morning");
        zone = -300;
        at(quiet, berlin(9, 7, 0));
        verify(quiet.on, "seven in Berlin is one at night in New York");
        compare(quiet.endWord, "bis 07:00");
        compare(quiet.endsAt, Date.UTC(2026, 10, 9, 12, 0));
        at(quiet, Date.UTC(2026, 10, 9, 12, 0));
        verify(!quiet.on, "off at seven in New York");
    }

    function test_until_the_morning_ends_at_seven_on_the_wall_clock_after_a_night_that_changes_it() {
        const quiet = make();
        // Berlin goes from UTC+1 to UTC+2 at 01:00 UTC on 29 March 2026.
        quiet.zoneOffset = instant => instant < Date.UTC(2026, 2, 29, 1) ? 60 : 120;
        at(quiet, Date.UTC(2026, 2, 28, 21, 0));
        quiet.choose("morning");
        compare(quiet.endsAt, Date.UTC(2026, 2, 29, 5, 0));
        compare(quiet.endWord, "bis 07:00");
    }

    function test_switched_on_without_an_end_it_holds_and_shows_no_time_left() {
        const quiet = make();
        quiet.choose("open");
        verify(quiet.on);
        compare(quiet.endsAt, 0);
        compare(quiet.middleParts, [], "the status word says it already");
        compare(quiet.endWord, "");
        at(quiet, berlin(20, 14, 0));
        verify(quiet.on, "days later still");
        quiet.stop();
        verify(!quiet.on);
    }

    function test_a_restart_keeps_the_end_and_one_that_has_passed_meanwhile_is_off() {
        const before = make();
        before.choose("hour");
        const saved = before.saved;
        const after = make();
        at(after, berlin(8, 14, 30));
        after.restore(saved);
        verify(after.on);
        compare(after.endsAt, berlin(8, 15, 0));
        compare(after.middleParts, ["nicht stören", "noch 30 min"]);
        const later = make();
        at(later, berlin(8, 16, 0));
        later.restore(saved);
        verify(!later.on, "the hour has passed");
    }

    function test_a_restart_keeps_the_morning_and_no_end() {
        const before = make();
        at(before, berlin(8, 22, 0));
        before.choose("morning");
        const after = make();
        after.restore(before.saved);
        compare(after.endsAt, berlin(9, 7, 0));
        before.choose("open");
        after.restore(before.saved);
        verify(after.on);
        compare(after.endsAt, 0);
    }

    function test_a_file_that_is_not_its_own_leaves_it_off() {
        const quiet = make();
        quiet.choose("open");
        ignoreWarning(/kept nothing/);
        quiet.restore("{ broken");
        verify(!quiet.on);
        quiet.restore(JSON.stringify({ choice: "forever" }));
        verify(!quiet.on, "an unknown choice");
        quiet.choose("open");
        quiet.restore("null");
        verify(!quiet.on, "a file holding null");
    }

    function test_an_hour_ends_by_itself_when_the_clock_passes_it() {
        const quiet = make();
        at(quiet, berlin(9, 12, 0));
        quiet.choose("hour");
        verify(quiet.on);
        testCase.time = berlin(9, 13, 1);
        tryVerify(() => !quiet.on, 3000);
    }

    function test_the_timer_runs_only_while_an_end_is_pending() {
        const quiet = make();
        verify(!quiet.ticker.running, "off");
        quiet.choose("open");
        verify(!quiet.ticker.running, "on with no end");
        quiet.choose("hour");
        verify(quiet.ticker.running, "on with an end");
    }
}
