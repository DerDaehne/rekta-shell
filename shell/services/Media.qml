import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// What plays, for every surface that shows it: the first MPRIS player that is playing, none while all are paused or
// stopped.
Scope {
    id: media

    // Untyped: the linter sees no `values` on the model.
    readonly property var players: Mpris.players
    readonly property MprisPlayer player: {
        for (const candidate of media.players.values) {
            if (candidate.isPlaying)
                return candidate;
        }
        return null;
    }
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
