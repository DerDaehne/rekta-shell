pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models

// Which media player the shell shows, one choice for the bar's middle and "läuft gerade": the one that started playing
// last, or the one picked since. "läuft gerade" shows it while it plays or holds a track paused; the bar shows only
// what plays, so it keeps to a playing one when the choice pauses.
QtObject {
    id: choice

    // Quickshell's MprisPlaybackState, as this module goes without Quickshell.
    enum PlaybackState {
        Stopped = 0,
        Playing = 1,
        Paused = 2
    }

    // The MPRIS players as Quickshell has them (see NowPlaying for what they carry).
    property var players: []
    // The player that started playing last, or the one picked since.
    property var latest: null
    // The players as they were before their last change, to tell one that has just come.
    property var known: []
    // The players playing or holding a track paused.
    readonly property var present: players.filter(player => player.isPlaying || (player.playbackState === PlayerChoice.Paused && player.trackTitle !== ""))
    // What "läuft gerade" shows.
    readonly property var player: present.includes(latest) ? latest : present.find(player => player.isPlaying) ?? present[0] ?? null
    // What the bar's middle shows.
    readonly property var playingPlayer: player?.isPlaying ? player : players.find(player => player.isPlaying) ?? null

    // Each player that starts playing becomes the one shown.
    readonly property Instantiator starts: Instantiator {
        model: choice.players

        delegate: Connections {
            required property var modelData

            target: modelData

            function onIsPlayingChanged() {
                if (modelData.isPlaying)
                    choice.latest = modelData;
            }
        }
    }

    function pick(player: var) {
        latest = player;
    }

    // The media keys act on what "läuft gerade" shows, as far as that player lets itself be controlled so.
    function togglePlaying() {
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }

    function pause() {
        if (player?.canPause)
            player.pause();
    }

    function stop() {
        if (player?.canControl)
            player.stop();
    }

    function next() {
        if (player?.canGoNext)
            player.next();
    }

    function previous() {
        if (player?.canGoPrevious)
            player.previous();
    }

    // Quickshell lists a player only once it has read its state, so one that comes playing never changes isPlaying:
    // its coming is its start.
    onPlayersChanged: {
        const newcomer = players.find(player => player.isPlaying && !known.includes(player));
        known = players;
        if (newcomer)
            latest = newcomer;
    }
}
