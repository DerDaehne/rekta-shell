//@ pragma AppId rekta-settings

import QtQuick
import Quickshell
import Quickshell.Io
import Rekta
import Settings
import SettingsApp

ShellRoot {
    SystemMotion {}

    // Read only here: the app writes a setting only where a field changes it.
    SettingsFiles {
        id: settingsFiles
    }

    Binding {
        target: Prefs
        property: "density"
        value: settingsFiles.value("density")
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
