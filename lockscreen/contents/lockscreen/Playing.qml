import QtQuick

// What is playing, from the player Plasma's multiplexer follows, while the lock screen settings show media (as Breeze
// does). Plasma's private module is loaded on its own: missing or changed, it costs this and never the lock screen,
// which then could not be unlocked at all.
Loader {
    property bool shown: true
    readonly property string title: (item as NowPlaying)?.title ?? ""
    readonly property string artist: (item as NowPlaying)?.artist ?? ""

    active: shown
    source: Qt.resolvedUrl("PlasmaPlayer.qml")
}
