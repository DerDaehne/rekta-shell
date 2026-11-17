import QtQml

// Quickshell's Process as the app list runs one: it never starts, so a test hands the list what grep would print.
QtObject {
    property var command: []
    property bool running: false
    property QtObject stdout: null
}
