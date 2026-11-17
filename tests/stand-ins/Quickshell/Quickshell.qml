pragma Singleton

import QtQml

// Quickshell's own singleton as far as the launcher and the app list read it: the environment of the session's own
// shell, which acts, and the icon theme, which holds the icons named in `themeIcons` and counts every look into it.
QtObject {
    readonly property var environment: ({
            REKTA_SHELL_LAUNCH: "systemd"
        })
    property var themeIcons: []
    property var lookedUp: []

    function env(name: string): var {
        return environment[name];
    }

    function iconPath(name: string, check: bool): string {
        lookedUp = [...lookedUp, name];
        return themeIcons.includes(name) ? `image://icon/${name}` : "";
    }
}
