import QtQuick
import Quickshell
import RektaShell.DBus
import Start

// Starts apps, each in a systemd scope of its own, so they outlive a restart of the shell, and runs the shell's
// commands and calls on the session, such as locking it or logging out. Only the session's own shell does so
// (REKTA_SHELL_LAUNCH=systemd, which the package's wrapper sets): anywhere else, in the nested session or under
// `qs --path`, a scope would land in the host's user manager, a lock would lock the host's session and the system bus
// is the host's, so there it only logs what it would do.
Scope {
    id: launcher

    readonly property bool starts: Quickshell.env("REKTA_SHELL_LAUNCH") === "systemd"
    readonly property DBusConnection sessionBus: DBusConnection {}
    readonly property DBusConnection systemBus: DBusConnection {
        bus: DBusConnection.System
    }

    function launch(entry: DesktopEntry) {
        const command = Rules.scopeCommand(entry.id, entry.command, Date.now());
        if (!starts) {
            console.info(`Launcher: would start ${JSON.stringify(command)}`);
            return;
        }
        const context = { command: command };
        if (entry.workingDirectory !== "")
            context.workingDirectory = entry.workingDirectory;
        Quickshell.execDetached(context);
    }

    // A JS array of words: Quickshell.execDetached() takes no QML list<string>, it would start an empty command.
    function run(command: var) {
        if (!starts) {
            console.info(`Launcher: would run ${JSON.stringify(command)}`);
            return;
        }
        Quickshell.execDetached(command);
    }

    function lock() {
        run(["loginctl", "lock-session"]);
    }

    // A method without arguments on the session's or the system's bus; done(error, values), if given, follows its reply,
    // with error null on success and values the reply's. Where the shell does not act, it follows at once as if the call
    // had succeeded without values.
    function call(onSystemBus: bool, service: string, path: string, iface: string, method: string, done: var) {
        const what = `${onSystemBus ? "system" : "session"} bus ${service} ${path} ${iface}.${method}`;
        if (!starts) {
            console.info(`Launcher: would call ${what}`);
            done?.(null, []);
            return;
        }
        (onSystemBus ? systemBus : sessionBus).call(service, path, iface, method, [], "", (error, values) => {
            if (error)
                console.warn(`Launcher: ${what}: ${error}`);
            done?.(error, values);
        });
    }
}
