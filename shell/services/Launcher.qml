import QtQuick
import Quickshell
import Start

// Starts apps, each in a systemd scope of its own, so they outlive a restart of the shell, and runs the shell's
// commands on the session, such as locking it. Only the session's own shell does so (REKTA_SHELL_LAUNCH=systemd, which
// the package's wrapper sets): anywhere else, in the nested session or under `qs --path`, a scope would land in the
// host's user manager and a lock would lock the host's session, so there it only logs what it would do.
Scope {
    readonly property bool starts: Quickshell.env("REKTA_SHELL_LAUNCH") === "systemd"

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

    function run(command: list<string>) {
        if (!starts) {
            console.info(`Launcher: would run ${JSON.stringify(command)}`);
            return;
        }
        Quickshell.execDetached(command);
    }
}
