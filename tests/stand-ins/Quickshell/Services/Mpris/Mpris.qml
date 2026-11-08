pragma Singleton

import QtQml

// Quickshell's MPRIS service with one player, playing.
QtObject {
    readonly property QtObject players: QtObject {
        id: players

        readonly property MprisPlayer player: MprisPlayer {}
        readonly property var values: [players.player]
    }
}
