pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import org.kde.plasma.workspace.dbus as DBus
import org.kde.plasma.workspace.keyboardlayout
import Readout

// Feeds the key readout from the system: the default audio devices from PipeWire, the volume and microphone keys from
// kglobalaccel's component "kmix", the brightness keys from powerdevil and the layout from KWin. The shell registers none
// of these keys; kded6 and powerdevil act on them, and this only listens. The side panel shares the bound devices and
// the displays.
// ponytail: the kmix keys go through plasma-workspace's DBus module, whose fixed names and paths suffice; move them to the
// shell's own DBus module (as the displays do) once that is worth the change.
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
                model.layoutSwitched();
        }
    }
}
