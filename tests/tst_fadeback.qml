import QtQuick
import QtTest
import Rekta

TestCase {
    name: "FadeBack"

    readonly property easingCurve easeOut: ({ type: Easing.Bezier, bezierCurve: Tokens.easeOut })
    readonly property easingCurve easeIn: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })
    // Halfway through half a duration-moderate.
    readonly property real halfway: Tokens.durationModerate / 4

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
    }

    function cleanup() {
        Tokens.reducedMotion = false;
    }

    function test_the_windows_step_back_in_half_a_duration_moderate_with_ease_out() {
        compare(FadeBack.progress(0, 1, 0), 0);
        fuzzyCompare(FadeBack.progress(0, 1, halfway), easeOut.valueForProgress(0.5), 1e-9);
        compare(FadeBack.progress(0, 1, Tokens.durationModerate / 2), 1);
    }

    function test_they_come_forward_in_half_a_duration_moderate_with_ease_in() {
        compare(FadeBack.progress(1, 0, 0), 1);
        fuzzyCompare(FadeBack.progress(1, 0, halfway), 1 - easeIn.valueForProgress(0.5), 1e-9);
        compare(FadeBack.progress(1, 0, Tokens.durationModerate / 2), 0);
    }

    function test_the_two_ways_take_different_curves() {
        verify(Math.abs(FadeBack.progress(0, 1, halfway) - (1 - FadeBack.progress(1, 0, halfway))) > 0.05);
    }

    function test_a_change_on_the_way_turns_them_round_from_where_they_are() {
        compare(FadeBack.progress(0.4, 0, 0), 0.4);
        fuzzyCompare(FadeBack.progress(0.4, 0, halfway), 0.4 * (1 - easeIn.valueForProgress(0.5)), 1e-9);
        fuzzyCompare(FadeBack.progress(0.4, 1, halfway), 0.4 + 0.6 * easeOut.valueForProgress(0.5), 1e-9);
        compare(FadeBack.progress(0.4, 1, Tokens.durationModerate / 2), 1);
    }

    function test_they_stay_where_they_arrived() {
        compare(FadeBack.progress(0, 1, 5 * Tokens.durationModerate), 1);
        compare(FadeBack.progress(1, 1, halfway), 1);
    }

    function test_under_reduced_motion_they_are_there_at_once() {
        Tokens.reducedMotion = true;
        compare(FadeBack.progress(0, 1, 0), 1);
        compare(FadeBack.progress(1, 0, 0), 0);
    }

    function test_as_the_session_is_left_they_step_back_in_a_whole_duration_moderate_with_ease_out() {
        compare(FadeBack.leaveProgress(0, 1, 0), 0);
        fuzzyCompare(FadeBack.leaveProgress(0, 1, Tokens.durationModerate / 2), easeOut.valueForProgress(0.5), 1e-9);
        compare(FadeBack.leaveProgress(0, 1, Tokens.durationModerate), 1);
    }

    function test_after_the_session_could_not_be_left_they_come_forward_the_same_way_with_ease_in() {
        fuzzyCompare(FadeBack.leaveProgress(1, 0, Tokens.durationModerate / 2), 1 - easeIn.valueForProgress(0.5), 1e-9);
        compare(FadeBack.leaveProgress(1, 0, Tokens.durationModerate), 0);
        compare(FadeBack.leaveDuration, Tokens.durationModerate);
    }

    function test_under_reduced_motion_they_leave_at_once_too() {
        Tokens.reducedMotion = true;
        compare(FadeBack.leaveProgress(0, 1, 0), 1);
        compare(FadeBack.leaveProgress(1, 0, 0), 0);
    }

    function test_all_the_way_back_a_window_is_86_percent_and_dimmed_to_0_78() {
        compare(FadeBack.scale(0), 1);
        compare(FadeBack.brightness(0), 1);
        fuzzyCompare(FadeBack.scale(1), 0.86, 1e-9);
        fuzzyCompare(FadeBack.brightness(1), 0.78, 1e-9);
        fuzzyCompare(FadeBack.scale(0.5), 0.93, 1e-9);
        fuzzyCompare(FadeBack.brightness(0.5), 0.89, 1e-9);
    }

    // KWin's effects share one engine; Prefs there would override the turnstile's Tokens.
    function test_the_windows_keep_the_fast_tempo_whatever_pace_the_shell_has_set() {
        Prefs.startPace = "rekta";
        compare(FadeBack.duration, Geometry.startTempo * Tokens.durationModerate);
        Prefs.startPace = "fast";
    }
}
