import QtQml

// Quickshell's Scope as the shell's services build on it: an object that holds others.
QtObject {
    default property list<QtObject> children
}
