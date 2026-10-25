import QtQuick
import QtTest
import Rekta

TestCase {
    name: "Match"

    readonly property string konsoleKeywords: "Terminal shell prompt command commandline cmd"

    function test_a_name_that_starts_with_the_text_scores_three() {
        compare(Match.score("Konsole", konsoleKeywords, "kon"), 3);
    }

    function test_every_typed_word_starting_a_word_of_the_name_or_keywords_scores_two() {
        compare(Match.score("Konsole", konsoleKeywords, "term"), 2);
        compare(Match.score("Konsole", konsoleKeywords, "sh kon"), 2, "in any order");
        compare(Match.score("System Settings", "", "set"), 2);
    }

    function test_a_name_that_only_contains_the_text_scores_one() {
        compare(Match.score("Konsole", konsoleKeywords, "sole"), 1);
    }

    function test_text_found_nowhere_scores_nothing() {
        compare(Match.score("Konsole", konsoleKeywords, "xyz"), 0);
        compare(Match.score("Konsole", konsoleKeywords, "kon xyz"), 0, "every word must match");
    }

    function test_case_never_counts() {
        compare(Match.score("Konsole", konsoleKeywords, "KON"), 3);
        compare(Match.score("konsole", "TERMINAL", "Term"), 2);
        compare(Match.score("Konsole", "", "SOLE"), 1);
    }

    function test_words_are_runs_of_letters_and_digits() {
        compare(Match.words("Rekta-Shell 2, Ölfarbe"), ["rekta", "shell", "2", "ölfarbe"]);
        compare(Match.score("Inkscape 1.4", "", "4"), 2, "a digit starts a word after a dot");
    }

    function test_nothing_typed_matches_everything() {
        compare(Match.score("Konsole", "", ""), 1);
    }

    function test_the_best_match_comes_first_and_equals_keep_their_order() {
        const apps = ["Kate", "Konsole", "Okular", "Telegram"];
        const ranked = Match.ranked(apps, name => ({
                    Kate: 2,
                    Konsole: 3,
                    Okular: 0,
                    Telegram: 2
                })[name]);
        compare(ranked, ["Konsole", "Kate", "Telegram"]);
    }
}
