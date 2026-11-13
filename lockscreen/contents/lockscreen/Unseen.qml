import QtQuick

// How many notifications the rekta shell holds unseen. The D-Bus module is loaded on its own: missing or broken, it
// costs this and never the lock screen, which then could not be unlocked at all.
Loader {
    readonly property int count: (item as UnseenCount)?.count ?? 0

    source: Qt.resolvedUrl("ShellUnseenCount.qml")
}
