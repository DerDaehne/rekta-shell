import QtQuick
import QtTest
import Rekta

TestCase {
    name: "Middle"

    function test_an_app_name_the_title_already_holds_stands_once() {
        compare(Middle.windowParts("KCharSelect", "KCharSelect"), ["KCharSelect"]);
        compare(Middle.windowParts("konsole", "Konsole — ~/projects"), ["Konsole — ~/projects"], "case never counts");
    }

    function test_a_title_without_the_app_name_keeps_both() {
        compare(Middle.windowParts("Dolphin", "Downloads"), ["Dolphin", "Downloads"]);
        compare(Middle.windowParts("KTimer", "Einstellungen für Stoppuhr — KTimer"), ["Einstellungen für Stoppuhr — KTimer"]);
    }

    function test_the_app_name_counts_only_as_whole_words() {
        compare(Middle.windowParts("Term", "Terminal"), ["Term", "Terminal"]);
        compare(Middle.windowParts("System Settings", "System and Settings"), ["System Settings", "System and Settings"]);
    }

    function test_a_window_lacking_name_or_title_shows_the_other() {
        compare(Middle.windowParts("Dolphin", ""), ["Dolphin"]);
        compare(Middle.windowParts("", "Untitled"), ["Untitled"]);
        compare(Middle.windowParts("", ""), []);
    }

    function test_times_run_in_minutes_and_seconds_and_hours_from_an_hour_on() {
        compare(Middle.clock(134), "2:14");
        compare(Middle.clock(5.9), "0:05");
        compare(Middle.clock(3734), "1:02:14");
    }

    function test_music_shows_title_and_artist_with_the_time_played_of_the_length() {
        compare(Middle.musicParts("Titel", "Interpret", 134, 243), ["Titel · Interpret", "2:14 / 4:03"]);
        compare(Middle.musicParts("Titel", "", 134, 243), ["Titel", "2:14 / 4:03"]);
        compare(Middle.musicParts("Radio", "", 134, 0), ["Radio", "2:14"]);
        compare(Middle.musicParts("", "", 0, 0), []);
    }

    function test_the_first_source_with_parts_wins_over_the_window() {
        compare(Middle.firstRunning([[], ["a"], ["b"]], ["window"]), ["a"]);
        compare(Middle.firstRunning([[]], ["window"]), ["window"]);
    }
}
