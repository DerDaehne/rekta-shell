import QtQml

// An MPRIS player as Quickshell has it, playing and open to every control. It records the calls it gets.
QtObject {
    property string identity: ""
    property string desktopEntry: ""
    readonly property bool isPlaying: true
    readonly property bool canTogglePlaying: true
    readonly property bool canPause: true
    readonly property bool canControl: true
    readonly property bool canGoNext: true
    readonly property bool canGoPrevious: true
    property var calls: []

    function togglePlaying() {
        calls = [...calls, "togglePlaying"];
    }

    function pause() {
        calls = [...calls, "pause"];
    }

    function stop() {
        calls = [...calls, "stop"];
    }

    function next() {
        calls = [...calls, "next"];
    }

    function previous() {
        calls = [...calls, "previous"];
    }
}
