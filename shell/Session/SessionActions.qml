import QtQuick
import Rekta

// What the session banner offers, in its order, and what each action does, as Plasma does it: a lock through logind,
// a switch of user as a lock and then the display manager's greeter (libkworkspace sessionmanagement.cpp), logging out,
// restarting and shutting down through ksmserver, which asks nothing more (plasma-shutdown shutdown.cpp). Another action
// is another entry in the list.
QtObject {
    id: session

    // Runs commands, starts apps and calls D-Bus methods on the session (the shell's Launcher), only in the session's
    // own shell.
    required property var launcher
    // XDG_SEAT_PATH: the session's seat at the display manager, "" without one.
    required property string seatPath
    // The system monitor's desktop entry, null while it is not installed.
    property var systemMonitor: null
    // Says why the user was not switched (the shell's Toaster).
    property var toaster: null
    // From "benutzer wechseln" until the session is locked, or until the windows have come forward again after it could
    // not be: a host shows a clear surface meanwhile, which holds the keyboard while windowsBack, so KWin's fade-back
    // steps the windows on every screen back behind it.
    property bool leaving: false
    property bool windowsBack: false

    readonly property PauseAnimation steppingBack: PauseAnimation {
        duration: FadeBack.leaveDuration
        onFinished: session.lock()
    }
    readonly property PauseAnimation comingForward: PauseAnimation {
        duration: FadeBack.leaveDuration
        onFinished: session.leaving = false
    }

    // An app has started, whose window is to come to the front.
    signal launched

    // { name, text, group, primary, endsSession, disabledReason, clearsShading, run }; the primary one takes the focus as
    // the banner opens; one that clears the shading leaves the screen behind unshaded and unblurred at once as it is
    // chosen; one that ends the session waits out the banner's undo window first. Groups stand apart in the banner.
    readonly property var actions: [
        {
            name: "lock",
            text: "sperren",
            group: 0,
            primary: true,
            run: () => session.launcher.lock()
        },
        {
            name: "switchUser",
            text: "benutzer wechseln",
            group: 0,
            disabledReason: seatPath === "" ? "Der Anmeldemanager bietet keinen Wechsel an." : "",
            clearsShading: true,
            run: () => session.switchUser()
        },
        {
            name: "logout",
            text: "abmelden",
            group: 1,
            endsSession: true,
            run: () => session.leave("logout")
        },
        {
            name: "reboot",
            text: "neu starten",
            group: 1,
            endsSession: true,
            run: () => session.leave("logoutAndReboot")
        },
        {
            name: "shutdown",
            text: "ausschalten",
            group: 1,
            endsSession: true,
            run: () => session.leave("logoutAndShutdown")
        },
        {
            name: "systemMonitor",
            text: "systemmonitor",
            group: 2,
            disabledReason: systemMonitor ? "" : "Der Systemmonitor ist nicht installiert.",
            run: () => {
                session.launcher.launch(session.systemMonitor);
                session.launched();
            }
        }
    ]

    function leave(method: string) {
        launcher.call(false, "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", method, null);
    }

    // The windows step back while the session is still open, since nothing shows once it is locked; then it locks.
    function switchUser() {
        comingForward.stop();
        leaving = true;
        windowsBack = true;
        steppingBack.restart();
    }

    function askScreenSaver(method: string, done: var) {
        launcher.call(false, "org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", method, done);
    }

    // Lock answers without an error also where it locks nothing (kscreenlocker interface.cpp), so the greeter comes
    // only once the screen saver says the session is locked; it stays locked behind it.
    function lock() {
        askScreenSaver("Lock", error => error ? stay() : checkLocked());
    }

    function checkLocked() {
        askScreenSaver("GetActive", (error, values) => values?.[0] === true ? greet() : stay());
    }

    // Under the lock nobody sees the windows come forward; whoever comes back finds the desktop as it was.
    function greet() {
        leaving = false;
        windowsBack = false;
        launcher.call(true, "org.freedesktop.DisplayManager", seatPath, "org.freedesktop.DisplayManager.Seat", "SwitchToGreeter", null);
    }

    function stay() {
        windowsBack = false;
        comingForward.restart();
        toaster?.show("nicht gewechselt: die sitzung ließ sich nicht sperren.", {
            status: "error"
        });
    }
}
