import QtQuick
import Quickshell
import Start

// Starts apps, each in a systemd scope of its own, so they outlive a restart of the shell. Only the session's own shell
// starts them (REKTA_SHELL_LAUNCH=systemd, which the package's wrapper sets): anywhere else, in the nested session or
// under `qs --path`, the scope would land in the host's user manager, so there it only logs what it would start.
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
}
