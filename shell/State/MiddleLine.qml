import QtQuick
import Rekta

// What the bar's middle says (Middle.barLine). The active window's title follows at most once a second and a switch of
// window shows its title at once; the music's time is never held back.
QtObject {
    id: middle

    property var quietParts: []
    property string musicTitle
    property string musicArtist
    property real musicPosition
    property real musicLength
    // The active window on this screen, with `app` and `title`, or null.
    property var front: null

    readonly property Throttled frontTitle: Throttled {
        source: middle.front?.title ?? ""
        owner: middle.front
    }
    readonly property var line: Middle.barLine(
        quietParts,
        Middle.musicParts(musicTitle, musicArtist, musicPosition, musicLength),
        front ? Middle.windowParts(front.app, frontTitle.value) : [])
}
