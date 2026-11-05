import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import State

// What plays, for every surface that shows it: one choice among the MPRIS players for the bar's middle and
// "läuft gerade". `player` is the bar's, none while all are paused or stopped.
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
}
