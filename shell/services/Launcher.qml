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
        start(entry, entry.command);
    }

    function launchAction(entry: DesktopEntry, action: DesktopAction) {
        start(entry, action.command);
    }

    function start(entry: DesktopEntry, command: var) {
        const context = Rules.launchContext(entry, command, Date.now());
        if (!starts) {
            console.info(`Launcher: would start ${JSON.stringify(context.command)}`);
            return;
        }
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

    // A web page in the user's browser, in a scope of its own as an app gets, so a browser it starts outlives a restart of
    // the shell.
    function open(url: string) {
        run(Rules.scopeCommand("xdg-open", ["xdg-open", url], Date.now()));
    }

    function lock() {
        run(["loginctl", "lock-session"]);
    }

    // Asks the session bus a read-only question; done(values) follows its reply, and nothing follows an error. Where the
    // shell does not act, the nested session, it asks nothing: that bus is the host's.
    function ask(service: string, path: string, iface: string, method: string, args: var, signature: string, done: var) {
        if (!starts)
            return;
        sessionBus.call(service, path, iface, method, args, signature, (error, values) => {
            if (!error)
                done(values);
        });
    }

    // A desktop action of an app that runs over D-Bus, as the desktop-entry spec has a launcher run it: ActivateAction on
    // the app's name and path, without a parameter or platform data. An error the app replies is only logged.
    function activateAction(appId: string, actionId: string) {
        call(false, appId, Rules.applicationPath(appId), "org.freedesktop.Application", "ActivateAction", [actionId, [], {}], "sava{sv}", null);
    }

    // A method on the session's or the system's bus, its arguments typed by a full D-Bus signature ("" for none);
    // done(error, values), if given, follows its reply, with error null on success and values the reply's. Where the
    // shell does not act, it follows at once as if the call had succeeded without values.
    function call(onSystemBus: bool, service: string, path: string, iface: string, method: string, args: var, signature: string, done: var) {
        const what = `${onSystemBus ? "system" : "session"} bus ${service} ${path} ${iface}.${method}${args.length > 0 ? ` ${JSON.stringify(args)}` : ""}`;
        if (!starts) {
            console.info(`Launcher: would call ${what}`);
            done?.(null, []);
            return;
        }
        (onSystemBus ? systemBus : sessionBus).call(service, path, iface, method, args, signature, (error, values) => {
            if (error)
                console.warn(`Launcher: ${what}: ${error}`);
            done?.(error, values);
        });
    }
}
