import QtQuick
import QtTest
import Rekta

// KWin's engine: the turnstile effect binds Tokens.reducedMotion to KDE's animation speed, then the fadeback effect takes
// FadeBack from the same engine. Prefs, if FadeBack created it, would override that binding. It shows only where no
// earlier test has created Prefs (run this file alone); tst_fadeback covers FadeBack not following Prefs.
TestCase {
    name: "FadeBackEngine"

    Binding {
        target: Tokens
        property: "reducedMotion"
        value: true
    }

    function test_loading_fadeback_leaves_the_tokens_of_the_engine_it_shares_with_the_turnstile_alone() {
        compare(Tokens.reducedMotion, true, "before FadeBack");
        const duration = FadeBack.duration;
        compare(Tokens.reducedMotion, true, "after FadeBack, duration " + duration);
    }
}
