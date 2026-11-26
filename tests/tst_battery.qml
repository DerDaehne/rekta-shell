import QtQuick
import QtTest
import State

// What the display battery says in words, for each state UPower reports: the bar's neutral word, the tile's word, the
// level's rows and the speech.
TestCase {
    id: testCase

    name: "Battery"

    readonly property int charging: 1
    readonly property int discharging: 2
    readonly property int empty: 3
    readonly property int fullyCharged: 4
    readonly property int pendingCharge: 5
    readonly property int lowWarning: 3
    readonly property int criticalWarning: 4

    Component {
        id: batteryComponent

        Battery {
            present: true
            kind: 2
        }
    }

    function make(values) {
        return createTemporaryObject(batteryComponent, testCase, values);
    }

    function test_on_battery_the_bar_says_the_stand_in_a_neutral_word() {
        const battery = make({ percentage: 63.6, state: discharging });
        compare(battery.note, "akku 64 %");
        compare(battery.tileWord, "64 %");
        compare(battery.stateWord, "entlädt");
        verify(!battery.low);
    }

    function test_while_charging_below_ninety_the_bar_says_it_charges() {
        const battery = make({ percentage: 64, state: charging });
        compare(battery.note, "akku 64 % · lädt");
        compare(battery.tileWord, "64 % · lädt");
        compare(battery.stateWord, "lädt");
    }

    function test_charging_at_eighty_nine_still_says_it_and_at_ninety_stops() {
        compare(make({ percentage: 89.4, state: charging }).note, "akku 89 % · lädt");
        compare(make({ percentage: 89.6, state: charging }).note, "", "rounded, it is ninety");
        compare(make({ percentage: 90, state: charging }).note, "");
        compare(make({ percentage: 97, state: charging }).tileWord, "97 % · lädt", "the tile keeps saying it");
    }

    function test_a_full_battery_says_voll_on_the_tile_and_nothing_in_the_bar() {
        const battery = make({ percentage: 100, state: fullyCharged });
        compare(battery.note, "");
        compare(battery.tileWord, "voll");
        compare(battery.stateWord, "voll");
    }

    function test_below_ninety_a_full_report_shows_no_word_in_the_bar() {
        compare(make({ percentage: 60, state: fullyCharged }).note, "", "UPower says full at a charge limit too");
    }

    function test_a_charge_held_at_its_limit_shows_nothing_in_the_bar_and_the_tile_the_stand() {
        const battery = make({ percentage: 80, state: pendingCharge });
        compare(battery.note, "");
        compare(battery.tileWord, "80 %");
        compare(battery.stateWord, "lädt nicht");
    }

    function test_low_and_critical_leave_the_bar_to_the_error_word_and_make_the_tile_an_error() {
        for (const level of [lowWarning, criticalWarning]) {
            const battery = make({ percentage: 9, state: discharging, warningLevel: level });
            verify(battery.low, `level ${level}`);
            compare(battery.note, "", `level ${level}: no neutral word beside the error word`);
        }
        verify(!make({ percentage: 9, state: discharging, warningLevel: 2 }).low, "a level under low is no warning yet");
    }

    function test_only_critical_is_critical_and_low_is_spoken_with_its_word() {
        verify(!make({ percentage: 9, state: discharging, warningLevel: lowWarning }).critical);
        verify(make({ percentage: 4, state: discharging, warningLevel: criticalWarning }).critical);
        compare(make({ percentage: 9, state: discharging, warningLevel: lowWarning }).tileName, "9 %, knapp");
        compare(make({ percentage: 9, state: discharging, warningLevel: lowWarning }).tileWord, "9 %");
    }

    function test_without_a_battery_there_is_nothing() {
        for (const values of [{ present: false }, { kind: 0 }, { kind: 3 }]) {
            const battery = make(Object.assign({ percentage: 50, state: discharging, warningLevel: lowWarning, timeToEmpty: 600 }, values));
            verify(!battery.exists, JSON.stringify(values));
            compare(battery.note, "");
            compare(battery.tileWord, "");
            compare(battery.estimate, "");
            verify(!battery.low, "no low without a battery");
            verify(!battery.critical, "no critical without a battery");
        }
    }

    function test_the_time_left_on_battery_and_until_full_when_charging_follow_the_state() {
        compare(make({ state: discharging, timeToEmpty: 12000, timeToFull: 4200 }).estimate, "noch 3 h 20 min");
        compare(make({ state: charging, timeToEmpty: 12000, timeToFull: 4200 }).estimate, "bis voll 1 h 10 min");
        compare(make({ state: fullyCharged, timeToEmpty: 12000, timeToFull: 4200 }).estimate, "");
        compare(make({ state: pendingCharge, timeToEmpty: 12000, timeToFull: 4200 }).estimate, "");
    }

    function test_without_an_estimate_there_is_no_time() {
        compare(make({ state: discharging, timeToEmpty: 0 }).estimate, "");
        compare(make({ state: charging, timeToFull: 0 }).estimate, "");
    }

    function test_a_duration_is_written_in_whole_minutes_and_hours() {
        const battery = make({});
        compare(battery.duration(20), "1 min", "never none");
        compare(battery.duration(2520), "42 min");
        compare(battery.duration(3600), "1 h");
        compare(battery.duration(7380), "2 h 3 min");
        compare(battery.duration(3570), "1 h", "59 min 30 s rounds up to the hour");
    }

    function test_the_tile_is_spoken_without_the_dot() {
        compare(make({ percentage: 64, state: charging }).tileName, "64 %, lädt");
        compare(make({ percentage: 64, state: discharging }).tileName, "64 %");
        compare(make({ percentage: 100, state: fullyCharged }).tileName, "voll");
    }

    function test_an_empty_battery_counts_as_on_battery() {
        const battery = make({ percentage: 0, state: empty });
        compare(battery.stateWord, "entlädt");
        verify(battery.onBattery);
    }

    function test_a_state_unknown_says_the_stand_and_no_state() {
        const battery = make({ percentage: 50, state: 0 });
        compare(battery.stateWord, "");
        compare(battery.note, "");
        compare(battery.tileWord, "50 %");
    }
}
