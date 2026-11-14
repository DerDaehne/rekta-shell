import QtQuick
import QtTest
import Rekta

TestCase {
    name: "Prefs"

    // What the platform said before any test set the system source by hand.
    property bool systemContrastAtStart

    Component.onCompleted: systemContrastAtStart = Prefs.systemMoreContrast

    function cleanup() {
        Prefs.theme = "system";
        Prefs.density = "auto";
        Prefs.motion = "system";
        Prefs.contrast = "system";
        Prefs.systemColorScheme = Qt.ColorScheme.Light;
        Prefs.systemReducedMotion = false;
        Prefs.systemMoreContrast = false;
        Prefs.systemHasTouch = false;
    }

    function test_theme_follows_the_system_live() {
        Prefs.systemColorScheme = Qt.ColorScheme.Dark;
        compare(Tokens.theme, "dark");
        Prefs.systemColorScheme = Qt.ColorScheme.Light;
        compare(Tokens.theme, "light");
    }

    function test_a_theme_override_wins_over_the_system() {
        Prefs.systemColorScheme = Qt.ColorScheme.Dark;
        Prefs.theme = "light";
        compare(Tokens.theme, "light");
        Prefs.systemColorScheme = Qt.ColorScheme.Light;
        Prefs.theme = "dark";
        compare(Tokens.theme, "dark");
    }

    function test_reduced_motion_follows_the_system_live() {
        Prefs.systemReducedMotion = true;
        verify(Tokens.reducedMotion);
        compare(Tokens.durationShort, 0);
        Prefs.systemReducedMotion = false;
        verify(!Tokens.reducedMotion);
    }

    function test_motion_on_and_off_win_over_the_system() {
        Prefs.systemReducedMotion = true;
        Prefs.motion = "on";
        verify(!Tokens.reducedMotion);
        Prefs.systemReducedMotion = false;
        Prefs.motion = "off";
        verify(Tokens.reducedMotion);
    }

    function test_the_system_contrast_comes_from_the_platform_accessibility_hints() {
        const preference = Application.styleHints.accessibility.contrastPreference;
        compare(typeof preference, "number");
        compare(systemContrastAtStart, preference === Qt.ContrastPreference.HighContrast);
    }

    function test_contrast_follows_the_system_live() {
        Prefs.systemMoreContrast = true;
        verify(Tokens.moreContrast);
        verify(Tokens.color === Tokens.lightContrast);
        Prefs.systemMoreContrast = false;
        verify(!Tokens.moreContrast);
        verify(Tokens.color === Tokens.light);
    }

    function test_contrast_more_and_normal_win_over_the_system() {
        Prefs.systemMoreContrast = false;
        Prefs.contrast = "more";
        verify(Tokens.moreContrast);
        Prefs.systemMoreContrast = true;
        Prefs.contrast = "normal";
        verify(!Tokens.moreContrast);
    }

    function test_a_contrast_that_is_none_of_the_two_follows_the_system() {
        Prefs.contrast = "high";
        verify(!Tokens.moreContrast);
        Prefs.systemMoreContrast = true;
        verify(Tokens.moreContrast);
    }

    function test_density_is_compact_for_a_fine_pointer_and_comfortable_for_touch() {
        compare(Tokens.density, "compact");
        Prefs.systemHasTouch = true;
        compare(Tokens.density, "comfortable");
    }

    function test_a_density_override_wins_over_the_pointer() {
        Prefs.systemHasTouch = true;
        Prefs.density = "compact";
        compare(Tokens.density, "compact");
        Prefs.systemHasTouch = false;
        Prefs.density = "comfortable";
        compare(Tokens.density, "comfortable");
    }

    function test_a_density_that_is_none_of_the_two_counts_as_automatic() {
        Prefs.density = "huge";
        compare(Tokens.density, "compact");
        Prefs.systemHasTouch = true;
        compare(Tokens.density, "comfortable");
    }

    function test_a_place_is_sideways_from_the_breakpoint_on_and_above_the_short_height() {
        compare(Prefs.sizeClass(Tokens.bpSidewaysScrollMin - 1, 900), "compact");
        compare(Prefs.sizeClass(Tokens.bpSidewaysScrollMin, 900), "sideways");
        compare(Prefs.sizeClass(1200, Tokens.bpShortHeight), "compact");
        compare(Prefs.sizeClass(1200, Tokens.bpShortHeight + 1), "sideways");
    }

    function test_there_is_no_start_tempo_to_prefer() {
        verify(!("startPace" in Prefs));
        verify(!("startTempo" in Prefs));
    }
}
