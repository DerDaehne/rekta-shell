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
    // The screens the surfaces show on, never Qt's placeholder while no output is left: Quickshell takes the move of a
    // shown surface for a close and keeps its window once KWin closes the surface as the outputs return, then shows that
    // window again as a normal window.
    readonly property list<ShellScreen> screens: Rules.realScreens(Array.from(Quickshell.screens))
    // null while no output is left. The surfaces on it hide meanwhile, so each comes back as a new layer surface.
    // ponytail: a surface moved while shown to another real screen is such a window too, should KWin close it there
    // (only its output gone); fix the move in Quickshell's ProxyWindowBase::setScreen if that shows.
    readonly property ShellScreen screen: Rules.primaryScreen(screens, name)

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
