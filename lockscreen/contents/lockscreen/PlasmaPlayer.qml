import QtQuick
import org.kde.plasma.private.mpris as Mpris

// NowPlaying on Plasma's MultiplexerModel; only Playing loads it.
NowPlaying {
    model: Mpris.MultiplexerModel {}
    playingStatus: Mpris.PlaybackStatus.Playing
}
