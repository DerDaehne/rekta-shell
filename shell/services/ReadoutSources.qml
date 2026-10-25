pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import org.kde.plasma.workspace.dbus as DBus
import org.kde.plasma.workspace.keyboardlayout
import Readout

// Feeds the key readout from the system: the default audio devices from PipeWire, the volume and microphone keys from
// kglobalaccel's component "kmix", the brightness keys from powerdevil and the layout from KWin. The shell registers none
// of these keys; kded6 and powerdevil act on them, and this only listens.
// ponytail: through plasma-workspace's DBus module, whose fixed names and paths suffice; move it to the shell's own DBus
// module once there is one.
Scope {
    id: sources

    readonly property KeyReadout readout: model
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [sources.sink, sources.source]
    }

    KeyReadout {
        id: model

        volume: sources.sink?.audio?.volume ?? 0
        muted: sources.sink?.audio?.muted ?? false
        micVolume: sources.source?.audio?.volume ?? 0
        micMuted: sources.source?.audio?.muted ?? false
        brightnessMax: (range.item as DisplayRange)?.max ?? 0
        layoutName: keyboard.name
    }

    DBus.SignalWatcher {
        service: "org.kde.kglobalaccel"
        path: "/component/kmix"
        iface: "org.kde.kglobalaccel.Component"

        function dbusglobalShortcutPressed(component: string, action: string, timestamp: real) {
            model.shortcutPressed(component, action);
        }

        // kglobalaccel tells the release too; without a handler the watcher warns.
        function dbusglobalShortcutReleased(component: string, action: string, timestamp: real) {
        }
    }

    DBus.SignalWatcher {
        service: "org.kde.ScreenBrightness"
        path: "/org/kde/ScreenBrightness"
        iface: "org.kde.ScreenBrightness"

        function dbusBrightnessChanged(display: string, brightness: int, source: string, context: string) {
            model.brightnessReported(display, brightness, source, context);
        }
    }

    // The range of the display a brightness key last changed; its path is known only at run time.
    Loader {
        id: range

        active: model.brightnessDisplay !== ""
        sourceComponent: DisplayRange {
            display: model.brightnessDisplay
        }
    }

    component DisplayRange: DBus.Properties {
        required property string display
        readonly property real max: properties.MaxBrightness ?? 0

        service: "org.kde.ScreenBrightness"
        path: `/org/kde/ScreenBrightness/${display}`
        iface: "org.kde.ScreenBrightness.Display"
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
                model.layoutSwitched();
        }
    }
}
