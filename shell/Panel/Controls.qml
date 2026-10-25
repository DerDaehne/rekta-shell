pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The facet "steuerung": the session's settings that act at once, as rows of toggles, segments and buttons, never as
// tiles (tiles.md: a tile never changes data). The groups stand in a fixed order, ton, verbindungen, anzeige, sitzung;
// one without rows falls away. The host runs what the rows ask for and feeds back the state they show.
Column {
    id: controls

    // The text of kdeglobals, which names Plasma's pair of light and dark global themes.
    property string kdeglobals
    readonly property bool dark: Prefs.resolvedTheme === "dark"
    readonly property alias doNotDisturb: quietToggle.checked
    // The power profile daemon: whether it runs, its profile (0 power saver, 1 balanced, 2 performance), and whether it
    // offers performance on this machine.
    property bool hasPowerProfiles: false
    property int powerProfile: 1
    property bool hasPerformanceProfile: false

    // A command for the host to run on the session.
    signal run(var command)
    signal powerProfileChosen(int profile)

    width: parent ? parent.width : 0

    PanelGroup {
        objectName: "sound"
        title: "ton"
    }

    PanelGroup {
        objectName: "connections"
        title: "verbindungen"
    }

    PanelGroup {
        objectName: "display"
        title: "anzeige"

        PanelRow {
            label: "dunkel"

            Toggle {
                id: darkToggle

                objectName: "dark"
                onWord: "an"
                offWord: "aus"
                checked: controls.dark
                Accessible.name: "dunkel"
                onToggled: controls.run(LookAndFeel.command(checked, controls.kdeglobals))
            }
        }

        // ponytail: kept in memory only, so a restart of the shell turns it off; keep it once the shell has a config.
        PanelRow {
            label: "nicht stören"

            Toggle {
                id: quietToggle

                objectName: "doNotDisturb"
                onWord: "an"
                offWord: "aus"
                Accessible.name: "nicht stören"
            }
        }
    }

    PanelGroup {
        objectName: "session"
        title: "sitzung"

        PanelRow {
            label: "energieprofil"
            present: controls.hasPowerProfiles

            Segments {
                id: profiles

                objectName: "powerProfile"
                options: controls.hasPerformanceProfile ? ["sparen", "ausgewogen", "leistung"] : ["sparen", "ausgewogen"]
                currentIndex: controls.powerProfile
                onActivated: index => controls.powerProfileChosen(index)
            }
        }

        PanelRow {
            Button {
                objectName: "lock"
                text: "sperren"
                onClicked: controls.run(["loginctl", "lock-session"])
            }
        }
    }

    // A choice made here shows at once; a change from elsewhere (System Settings, another tool) shows as it comes.
    // ponytail: a command that fails leaves the choice showing until the system changes next; follow the command's
    // exit once the host reports it.
    Connections {
        target: controls

        function onDarkChanged() {
            darkToggle.checked = controls.dark;
        }

        function onPowerProfileChanged() {
            profiles.currentIndex = controls.powerProfile;
        }
    }
}
