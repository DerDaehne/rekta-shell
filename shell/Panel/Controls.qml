pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The facet "steuerung": the session's settings that act at once, as rows of toggles, segments and buttons, never as
// tiles (tiles.md: a tile never changes data). The groups stand in a fixed order, ton, verbindungen, anzeige, sitzung;
// one without rows falls away. The host runs what the rows ask for and feeds back the state they show. In ton each
// device row opens its list in place of the group, to choose the default device of its kind.
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
    // The default output and input as PipeWire has them, or null: nodes with a description and their audio's volume
    // (1 for 100%) and muted. The rows set those two on the node itself.
    property var output: null
    property var input: null
    // The devices of each kind to choose from, nodes as above.
    property var outputs: []
    property var inputs: []

    // A command for the host to run on the session.
    signal run(var command)
    signal powerProfileChosen(int profile)
    // A device to make the default of its kind.
    signal deviceChosen(var node)

    function deviceName(node: var): string {
        return node?.description || node?.name || "";
    }

    width: parent ? parent.width : 0

    PanelGroup {
        objectName: "sound"
        title: "ton"
        levels: [
            DeviceLevel {
                id: outputLevel

                objectName: "outputs"
                kind: "output"
                name: "ausgang"
                devices: controls.outputs
                current: controls.output
            },
            DeviceLevel {
                id: inputLevel

                objectName: "inputs"
                kind: "input"
                name: "eingang"
                devices: controls.inputs
                current: controls.input
            }
        ]

        DeviceRow {
            node: controls.output
            level: outputLevel
        }

        VolumeRow {
            node: controls.output
            level: outputLevel
        }

        MuteRow {
            node: controls.output
            level: outputLevel
        }

        DeviceRow {
            node: controls.input
            level: inputLevel
        }

        VolumeRow {
            node: controls.input
            level: inputLevel
        }

        MuteRow {
            node: controls.input
            level: inputLevel
        }
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

    // The devices of one kind, in place of the group's rows; choosing one makes it the default.
    component DeviceLevel: PanelLevel {
        // output or input, which names its controls.
        property string kind
        property var devices: []
        property var current: null

        options: devices.map(node => controls.deviceName(node))
        currentIndex: devices.indexOf(current)
        onChosen: index => controls.deviceChosen(devices[index])
    }

    // The default device of one kind by its name, and a button to choose another: a row's action is a button with a
    // verb (tiles.md, "Rows follow the same split").
    component DeviceRow: PanelRow {
        id: deviceRow

        required property var node
        required property DeviceLevel level

        label: `${level.name} · ${controls.deviceName(node)}`
        present: node !== null

        Button {
            id: opener

            objectName: `${deviceRow.level.kind}Device`
            text: "wählen"
            Accessible.name: `${deviceRow.level.name} wählen`
            onClicked: deviceRow.level.show(opener)
        }
    }

    // ponytail: a volume raised above 100% shows as 100%, and moving the slider brings it back onto the scale; widen the
    // scale once a raised maximum is wanted.
    component VolumeRow: PanelRow {
        id: volumeRow

        required property var node
        required property DeviceLevel level
        readonly property real volume: Math.min(1, node?.audio?.volume ?? 0)

        label: "lautstärke"
        present: node !== null
        // A change from elsewhere (a key, an app) moves the slider, as moving it ends its binding.
        onVolumeChanged: volumeSlider.value = volume

        Slider {
            id: volumeSlider

            objectName: `${volumeRow.level.kind}Volume`
            // As wide as the row, so it stands below the words (rekta.css:367, a range is 100% wide).
            implicitWidth: volumeRow.width
            value: volumeRow.volume
            valueText: `${Math.round(value * 100)}%`
            label: `lautstärke ${volumeRow.level.name}`
            onMoved: volumeRow.node.audio.volume = value
        }
    }

    component MuteRow: PanelRow {
        id: muteRow

        required property var node
        required property DeviceLevel level
        readonly property bool muted: node?.audio?.muted ?? false

        label: "stumm"
        present: node !== null
        onMutedChanged: muteToggle.checked = muted

        Toggle {
            id: muteToggle

            objectName: `${muteRow.level.kind}Muted`
            onWord: "an"
            offWord: "aus"
            checked: muteRow.muted
            Accessible.name: `stumm ${muteRow.level.name}`
            onToggled: muteRow.node.audio.muted = checked
        }
    }
}
