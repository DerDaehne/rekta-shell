pragma Singleton

import QtQml

// Quickshell's own singleton as far as the launcher reads it: the environment of the session's own shell, which acts.
QtObject {
    readonly property var environment: ({
            REKTA_SHELL_LAUNCH: "systemd"
        })

    function env(name: string): var {
        return environment[name];
    }
}
