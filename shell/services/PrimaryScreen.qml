import QtQuick
import Quickshell
import Quickshell.Io
import Start

// The primary screen, as KWin orders the screens; Quickshell knows no primary. kscreen-doctor asks KWin whenever the
// screens change; until it answers, the first screen.
// ponytail: a primary chosen anew in System Settings, with the same screens, shows after the next change of screens or
// a restart; follow kde_output_order_v1 once the shell has a Wayland module of its own.
Scope {
    id: primary

    property string name: ""
    readonly property ShellScreen screen: {
        const screens = Quickshell.screens;
        for (const shellScreen of screens) {
            if (shellScreen.name === name)
                return shellScreen;
        }
        return screens.length > 0 ? screens[0] : null;
    }

    Process {
        id: doctor

        command: ["kscreen-doctor", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: primary.name = Rules.primaryOutput(text)
        }
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            doctor.running = true;
        }
    }
}
