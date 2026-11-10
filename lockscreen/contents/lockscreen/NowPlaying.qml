import QtQuick

// What is playing, for the lock screen's status area (shell.md, "The lock and sign-in screen"): the title and artist
// of the player the model follows, only while it plays; paused, stopped or without a player it tells of nothing. The
// model is Plasma's MultiplexerModel: at most one player, with the roles track, artist and playbackStatus.
Instantiator {
    id: nowPlaying

    // The model's own value for "playing".
    required property int playingStatus
    property Player player: null
    readonly property bool playing: player !== null && player.playbackStatus === playingStatus
    readonly property string title: playing ? player.track : ""
    readonly property string artist: playing ? player.artist : ""

    component Player: QtObject {
        required property string track
        required property string artist
        required property int playbackStatus
    }

    delegate: Player {}
    onObjectAdded: (index, object) => player = object as Player
    onObjectRemoved: (index, object) => {
        if (player === object)
            player = null;
    }
}
