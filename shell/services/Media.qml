import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import State

// What plays, for every surface that shows it: one choice among the MPRIS players for the bar's middle, "läuft gerade"
// and the media keys. `player` is the bar's, none while all are paused or stopped.
Scope {
    id: media

    // Untyped: the linter sees no `values` on the model.
    readonly property var players: Mpris.players
    readonly property PlayerChoice choice: PlayerChoice {
        players: media.players.values
    }
    readonly property MprisPlayer player: choice.playingPlayer
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    // In seconds; MPRIS sends no change of position while a track plays, so it is asked once a second.
    readonly property real position: player?.positionSupported ? player.position : 0
    readonly property real length: player?.lengthSupported ? player.length : 0

    Timer {
        interval: 1000
        repeat: true
        running: media.player?.positionSupported ?? false
        onTriggered: media.player.positionChanged()
    }

    // The media keys, for what "läuft gerade" shows. They reach the shell alone, as the rekta session keeps KDE's media
    // controller in kded6 unloaded; as there, Play plays or pauses.
    GlobalShortcut {
        name: "play-pause"
        text: "Play or pause media"
        keys: [Qt.Key_MediaPlay]
        onPressed: media.choice.togglePlaying()
    }

    GlobalShortcut {
        name: "pause"
        text: "Pause media"
        keys: [Qt.Key_MediaPause]
        onPressed: media.choice.pause()
    }

    GlobalShortcut {
        name: "stop"
        text: "Stop media"
        keys: [Qt.Key_MediaStop]
        onPressed: media.choice.stop()
    }

    GlobalShortcut {
        name: "next"
        text: "Next track"
        keys: [Qt.Key_MediaNext]
        onPressed: media.choice.next()
    }

    GlobalShortcut {
        name: "previous"
        text: "Previous track"
        keys: [Qt.Key_MediaPrevious]
        onPressed: media.choice.previous()
    }
}
