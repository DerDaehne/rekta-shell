import QtQml

// Quickshell's desktop entry, as a type the launcher's functions name, with what the app list reads of one.
QtObject {
    property string id
    property string name
    property string genericName
    property var keywords: []
    property var command: []
    property string icon
    property string workingDirectory
    property var actions: []
}
