pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import RektaShell.DBus
import org.kde.plasma.workspace.keyboardlayout
import Readout

// Feeds the key readout from the system: the default audio devices from PipeWire, the volume and microphone keys from
// kglobalaccel's component "kmix" with the most they raise a volume to from the user's plasmaparc, the brightness keys
// from powerdevil and the layout from KWin. The shell registers none of these keys; kded6 and powerdevil act on them,
// and this only listens. The side panel shares the bound devices and the displays.
Scope {
    id: sources

    readonly property KeyReadout readout: model
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property ScreenBrightness brightness: screenBrightness

    PwObjectTracker {
        objects: [sources.sink, sources.source]
    }

    KeyReadout {
        id: model

        volume: sources.sink?.audio?.volume ?? 0
        muted: sources.sink?.audio?.muted ?? false
        micVolume: sources.source?.audio?.volume ?? 0
        micMuted: sources.source?.audio?.muted ?? false
    }

    // Only the press: kglobalaccel also tells repeats and releases, which the shell never acts on.
    DBusConnection {
        Component.onCompleted: listen("org.kde.kglobalaccel.Component", "globalShortcutPressed", "org.kde.kglobalaccel", "/component/kmix")
        onReceived: (sender, path, interfaceName, member, args) => model.shortcutPressed(args[0], args[1])
    }

    // ponytail: only the user's plasmaparc, its first entry, without system-wide defaults or `[$i]` locks; read
    // KConfig's cascade over XDG_CONFIG_DIRS once a system sets the maximum for its users.
    FileView {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/plasmaparc`
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onLoaded: model.volumeMax = model.raisesAboveFull(text()) ? 1.5 : 1
        onLoadFailed: model.volumeMax = 1
    }

    ScreenBrightness {
        id: screenBrightness

        onChanged: (display, brightness, source, context) => model.brightnessReported(brightness, screenBrightness.maxOf(display), context)
    }

    KeyboardLayout {
        id: keyboard

        property string seen
        readonly property string name: layoutsList[layout]?.longName ?? ""

        // The first name is the layout the session starts with, not a switch.
        onNameChanged: {
            const switched = seen !== "" && name !== "";
            seen = name;
            if (switched)
                model.layoutSwitched(name);
            else
                model.layoutName = name;
        }
    }
}
