import QtQml

// Quickshell's desktop action, as a type the launcher's functions name, with what the action registry reads of one.
QtObject {
    property string id
    property string name
    property string icon
    property var command: []
}
