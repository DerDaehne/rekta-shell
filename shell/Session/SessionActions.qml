import QtQuick

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

    // { name, text, primary, disabledReason, run }; the primary one takes the focus as the banner opens.
    readonly property var actions: [
        {
            name: "lock",
            text: "sperren",
            primary: true,
            run: () => session.launcher.run(["loginctl", "lock-session"])
        },
        {
            name: "switchUser",
            text: "benutzer wechseln",
            disabledReason: seatPath === "" ? "Der Anmeldemanager bietet keinen Wechsel an." : "",
            run: () => session.switchUser()
        },
        {
            name: "logout",
            text: "abmelden",
            run: () => session.leave("logout")
        },
        {
            name: "reboot",
            text: "neu starten",
            run: () => session.leave("logoutAndReboot")
        },
        {
            name: "shutdown",
            text: "ausschalten",
            run: () => session.leave("logoutAndShutdown")
        },
        {
            name: "systemMonitor",
            text: "systemmonitor",
            disabledReason: systemMonitor ? "" : "Der Systemmonitor ist nicht installiert.",
            run: () => session.launcher.launch(session.systemMonitor)
        }
    ]

    function leave(method: string) {
        launcher.call(false, "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", method, null);
    }

    // The greeter comes only once the session is locked, so the session stays locked behind it.
    function switchUser() {
        launcher.call(false, "org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", "Lock", error => {
            if (!error)
                launcher.call(true, "org.freedesktop.DisplayManager", seatPath, "org.freedesktop.DisplayManager.Seat", "SwitchToGreeter", null);
        });
    }
}
