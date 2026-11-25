import QtQml
import Rekta

// After an update KWin keeps the rekta effects it loaded at login. While the one it runs is not the shell's, a plain
// toast says so once per shell start and offers to log out, as Rekta's own update toast offers to reload: it takes over
// only when asked, never under someone mid-task (shell.md:114–116, rekta.js:4035). It waits while notifications are
// quiet (a full-screen window, "nicht stören") and until the shell has arrived, and takes the place of a toast that
// stands (states.md:68–70). Nothing outlives the start: the next start asks again.
QtObject {
    id: hint

    required property Toaster toaster
    // KWin's fade-back is not the shell's (FadeBackEffect.stale).
    required property bool stale
    // Only critical notifications toast now (Notifications.quiet).
    required property bool quiet
    // The splash has faded; the toast never stands over it or ahead of the bar.
    required property bool arrived
    property bool shown: false
    readonly property bool due: stale && !quiet && arrived

    // "abmelden" was pressed: the session bar opens with the focus on `focusOn` and never counts down by itself.
    signal sessionAsked(string focusOn)

    function showWhenDue() {
        if (!due || shown)
            return;
        shown = true;
        toaster.show("neu anmelden für alle neuen funktionen", {
            act: {
                label: "abmelden",
                run: () => hint.sessionAsked("logout")
            }
        });
    }

    onDueChanged: showWhenDue()
}
