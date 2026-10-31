import QtQuick
import Quickshell
import Quickshell.Io
import Settings
import State

// The shell's own look at the free space, once a minute while `watching`: `checked(enough)` says whether the root and
// the home filesystem are both above the limits freespacenotifier warns at. It reads that program's config file and
// never writes it.
// ponytail: only the root and the home filesystem are looked at, not every writable disk as freespacenotifier does.
Scope {
    id: space

    property bool watching: false
    property var limits: Sources.freeSpaceLimits("")

    signal checked(bool enough)

    UserFile {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/freespacenotifierrc`
        onLoaded: space.limits = Sources.freeSpaceLimits(text())
        onLoadFailed: space.limits = Sources.freeSpaceLimits("")
    }

    Process {
        id: df

        command: ["df", "-B1", "--output=avail,size", "/", Quickshell.env("HOME")]
        stdout: StdioCollector {
            onStreamFinished: space.checked(Sources.enoughSpace(text, space.limits))
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: space.watching
        triggeredOnStart: true
        onTriggered: df.running = true
    }
}
