import QtQml

// Quickshell's StdioCollector, which the stand-in Process never fills.
QtObject {
    property string text
    signal streamFinished
}
