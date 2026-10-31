import QtQuick

// How the lock screen unlocks through kscreenlocker 6.8's authenticator. A heartbeat keeps PAM asking while the screen
// shows. What was typed goes to PAM only on sending, and only once PAM waits for a secret and its delay after a failed
// try is over: an answer sent earlier would reach no question and be lost. A failure of the password (not of a
// fingerprint or smartcard reader) shows at the field, PAM's own messages too; success stops all asking.
Item {
    id: unlock

    // kscreenlocker's Authenticators, or a stand-in with its signals and calls.
    required property var authenticator
    // The greeter shows the lock screen; only then does PAM keep asking.
    property bool viewVisible: false
    property bool capsLock: false
    // From sending until PAM says yes or no.
    property bool checking: false
    // Why the last try failed, as cause and remedy in one sentence (forms.md, "Check late, correct early"), or PAM's
    // own words.
    property string error
    // What PAM tells the user meanwhile, in its own words.
    property string info
    // A question of PAM waits for its answer.
    property bool asked: false
    // What was sent and waits for PAM's question or the end of its delay.
    property string held
    property bool holding: false
    property string pamError

    // Shown words, product words in German (strings.de.js has none for signing in).
    readonly property string wrongPassword: "Das Passwort stimmt nicht – bitte noch einmal eingeben."
    readonly property string wrongWithCapsLock: "Das Passwort stimmt nicht – die Feststelltaste ist an."

    signal rejected
    signal unlocked

    function submit(secret: string) {
        if (checking)
            return;
        checking = true;
        error = "";
        pamError = "";
        held = secret;
        holding = true;
        answer();
    }

    function answer() {
        if (!holding || !asked || authenticator.inPasswordDelay)
            return;
        holding = false;
        asked = false;
        authenticator.respond(held);
        held = "";
    }

    function fail() {
        checking = false;
        asked = false;
        error = pamError !== "" ? pamError : capsLock ? wrongWithCapsLock : wrongPassword;
        rejected();
        authenticator.startAuthenticating();
    }

    // PAM may have asked before the lock screen was loaded; its question then still waits.
    Component.onCompleted: asked = authenticator.promptForSecret !== "" || authenticator.prompt !== ""

    Timer {
        objectName: "heartbeat"
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: unlock.viewVisible && !unlock.authenticator.unlocked
        onTriggered: unlock.authenticator.startAuthenticating()
    }

    Connections {
        target: unlock.authenticator

        function onPromptForSecretChanged() {
            if (unlock.authenticator.promptForSecret === "")
                return;
            unlock.asked = true;
            unlock.answer();
        }

        function onPromptChanged() {
            if (unlock.authenticator.prompt === "")
                return;
            unlock.asked = true;
            unlock.answer();
        }

        function onInPasswordDelayChanged() {
            unlock.answer();
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
