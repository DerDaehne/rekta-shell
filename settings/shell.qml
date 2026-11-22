//@ pragma AppId rekta-settings

import QtQuick
import Quickshell
import Quickshell.Io
import Rekta
import Settings
import SettingsApp
import Start

ShellRoot {
    id: root

    property string kdeglobalsText

    // Only the rekta session's own programs switch Plasma's scheme; anywhere else it logs what it would do, as the
    // shell's launcher does, so a run from a checkout never changes the desktop.
    function runCommand(command: var) {
        if (Quickshell.env("REKTA_SHELL_LAUNCH") !== "systemd") {
            console.info(`rekta-settings: would run ${JSON.stringify(command)}`);
            return;
        }
        Quickshell.execDetached(command);
    }

    SystemMotion {}

    // The gate is open: the app is the one place that writes every setting, and only where a field changes one.
    SettingsFiles {
        id: settingsFiles

        writable: true
    }

    // start.json, the same file the Start reads and writes, live both ways.
    StartFile {
        id: startJson
    }

    // The apps "alle apps" lists, to pin from; the app starts none.
    Apps {
        id: installed
    }

    Binding {
        target: Prefs
        property: "contrast"
        value: settingsFiles.value("contrast")
    }

    Binding {
        target: Prefs
        property: "transparency"
        value: settingsFiles.value("transparency")
    }

    Binding {
        target: Prefs
        property: "density"
        value: settingsFiles.value("density")
    }

    Binding {
        target: Prefs
        property: "ground"
        value: settingsFiles.value("ground")
    }

    // Plasma's global themes, which the colour scheme switch names.
    FileView {
        id: kdeglobals

        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/kdeglobals`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.kdeglobalsText = text()
        onLoadFailed: root.kdeglobalsText = ""
    }

    FloatingWindow {
        id: window

        title: view.windowTitle
        minimumSize: Qt.size(view.minimumWidth, view.minimumHeight)
        implicitWidth: view.minimumWidth
        implicitHeight: view.minimumHeight + Tokens.tileUnit
        color: Tokens.color.bg

        // Quickshell does not quit when its last window closes.
        onClosed: Qt.quit()

        SettingsView {
            id: view

            anchors.fill: parent
            settings: settingsFiles
            startFile: startJson
            apps: installed.list
            kdeglobals: root.kdeglobalsText
            onRun: command => root.runCommand(command)
            onCloseRequested: Qt.quit()
        }
    }

    // A second launch asks the open window to come forward (rekta-settings).
    IpcHandler {
        target: "settings"

        function raise(): void {
            view.Window.window.requestActivate();
        }
    }
}
