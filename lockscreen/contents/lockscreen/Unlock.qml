pragma Singleton

import QtQuick

// How the lock screen unlocks through kscreenlocker 6.8's authenticator: one conversation with PAM, shared by every
// monitor. A heartbeat keeps PAM asking while the lock screen shows. What was typed goes to PAM only on sending, and
// only once PAM asks: an answer without an open question is lost. Every check ends, with PAM's yes or no, with a further
// question of PAM, or after a while without either; the field then takes input again.
Item {
    id: unlock

    // kscreenlocker's Authenticators, or a stand-in with its signals and calls; a new one starts a new conversation.
    property var authenticator: null
    // A monitor shows the lock screen; from then on PAM keeps being asked.
    property bool shown: false
    // From sending until PAM says yes or no, or asks again.
    property bool checking: false
    // Why the last try failed, as cause and remedy in one sentence (forms.md, "Check late, correct early"), or PAM's
    // own words.
    property string error
    // What PAM tells the user meanwhile, or asks next, in its own words.
    property string info
    // A question of PAM waits for its answer.
    property bool asked: false
    // What was sent and waits for PAM's question.
    property string held
    property bool holding: false
    property bool capsLockWhenSent: false
    property string pamError
    readonly property bool locked: authenticator !== null && !authenticator.unlocked

    // Shown words, product words in German (strings.de.js has none for signing in).
    readonly property string wrongPassword: "Das Passwort stimmt nicht – bitte noch einmal eingeben."
    readonly property string wrongWithCapsLock: "Das Passwort stimmt nicht – die Feststelltaste ist an."
    readonly property string notChecked: "Das Passwort wurde nicht geprüft – bitte noch einmal eingeben."

    signal unlocked

    function submit(secret: string, capsLock: bool) {
        if (checking)
            return;
        checking = true;
        error = "";
        info = "";
        pamError = "";
        capsLockWhenSent = capsLock;
        held = secret;
        holding = true;
        answer();
    }

    function answer() {
        if (!holding || !asked || pause.running)
            return;
        holding = false;
        asked = false;
        authenticator.respond(held);
        held = "";
    }

    // kscreenlocker 6.8 signals a question before the question can take an answer, so the answer comes after the
    // handler. A question while the answer is out asks for more (a one-time code), or the answer reached no question.
    function question(text: string) {
        if (text === "")
            return;
        if (checking && !holding) {
            endCheck();
            info = text;
        }
        asked = true;
        Qt.callLater(answer);
    }

    function fail() {
        asked = false;
        pause.restart();
        if (checking) {
            endCheck();
            error = pamError !== "" ? pamError : capsLockWhenSent ? wrongWithCapsLock : wrongPassword;
        }
        authenticator.startAuthenticating();
    }

    // Whatever became of the answer, the field takes input again, and the next answer goes straight to a question PAM
    // may still hold.
    function giveUp() {
        endCheck();
        asked = true;
        error = pamError !== "" ? pamError : notChecked;
    }

    function endCheck() {
        checking = false;
        holding = false;
        held = "";
    }

    onAuthenticatorChanged: {
        endCheck();
        pause.stop();
        error = "";
        info = "";
        pamError = "";
        // PAM may have asked before the lock screen was loaded; its question then still waits.
        asked = authenticator !== null && (authenticator.promptForSecret !== "" || authenticator.prompt !== "");
    }

    Timer {
        objectName: "heartbeat"
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: unlock.shown && unlock.locked
        onTriggered: unlock.authenticator.startAuthenticating()
    }

    // kscreenlocker 6.8 gives up on PAM for good once failures follow each other within 2 s four times in a row (as a
    // held Enter would send them), so after a failure PAM gets the next answer no sooner than 2 s later.
    Timer {
        id: pause

        objectName: "pause"
        interval: 2000
        onTriggered: unlock.answer()
    }

    // Longer than any check takes: PAM's delay after a failed try is 2 s, randomised by up to half.
    Timer {
        objectName: "watchdog"
        interval: 10000
        running: unlock.checking && unlock.locked
        onTriggered: unlock.giveUp()
    }

    Connections {
        target: unlock.authenticator

        function onPromptForSecretChanged() {
            unlock.question(unlock.authenticator.promptForSecret);
        }

        function onPromptChanged() {
            unlock.question(unlock.authenticator.prompt);
        }

        function onErrorMessageChanged() {
            unlock.pamError = unlock.authenticator.errorMessage;
            if (!unlock.checking)
                unlock.error = unlock.pamError;
        }

        function onInfoMessageChanged() {
            unlock.info = unlock.authenticator.infoMessage;
        }

        // A reader that is not the password (kind other than 0) fails on its own, often at every start.
        function onFailed(kind: int) {
            if (kind === 0)
                unlock.fail();
        }

        function onSucceeded() {
            unlock.authenticator.stopAuthenticating();
            unlock.unlocked();
        }
    }
}
