pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import Rekta

// "läuft gerade": what a media player plays, as a status region at the top of the controls (tiles.md, "Status region"),
// a part of the facet as a group is. The kicker names the player; with several a select picks one, and the one that
// started playing last is chosen until another is picked or starts. The figures are the track's cover in the icon's
// field, its title in semibold and "artist · album" below, as a toast holds a picture beside its title and text
// (states.md:89–98); then its progress with the time played and its length. Below stand previous, play or pause, and
// next. It shows while a player plays or holds a track paused, and is gone without one.
// The progress glides on from what the player last reported at its rate, and only while it is in sight.
Column {
    id: nowPlaying

    // Quickshell's MprisPlaybackState, as this module goes without Quickshell.
    enum PlaybackState {
        Stopped = 0,
        Playing = 1,
        Paused = 2
    }

    // The MPRIS players as Quickshell has them: identity, playbackState, isPlaying, the track's title, artist, album and
    // art, position and length in seconds (each only where supported), rate, what it can do, and its calls.
    property var players: []
    // The player that started playing last, or the one picked since.
    property var latest: null
    // The players as they were before their last change, to tell one that has just come.
    property var known: []
    readonly property var present: players.filter(player => player.isPlaying || (player.playbackState === NowPlaying.Paused && player.trackTitle !== ""))
    readonly property var player: present.includes(latest) ? latest : present.find(player => player.isPlaying) ?? present[0] ?? null
    readonly property real length: player?.lengthSupported ? player.length : 0
    // Seconds into the track.
    property real played: 0

    // Takes where the player stands; while it plays in sight, it glides on to the track's end at the player's rate.
    function follow() {
        gliding.stop();
        played = player?.positionSupported ? player.position : 0;
        if (!visible || !player?.isPlaying || player.rate <= 0 || played >= length)
            return;
        gliding.from = played;
        gliding.to = length;
        gliding.duration = (length - played) / player.rate * 1000;
        gliding.start();
    }

    width: parent ? parent.width : 0
    visible: player !== null
    topPadding: Tokens.spaceXl
    bottomPadding: Tokens.spaceL
    onPlayerChanged: follow()
    onVisibleChanged: follow()
    onLengthChanged: follow()
    // Quickshell lists a player only once it has read its state, so one that comes playing never changes isPlaying:
    // its coming is its start.
    onPlayersChanged: {
        const newcomer = players.find(player => player.isPlaying && !known.includes(player));
        known = players;
        if (newcomer)
            latest = newcomer;
    }

    NumberAnimation {
        id: gliding

        objectName: "gliding"
        target: nowPlaying
        property: "played"
    }

    // Each player that starts playing becomes the one shown.
    Instantiator {
        model: nowPlaying.players

        delegate: Connections {
            required property var modelData

            target: modelData

            function onIsPlayingChanged() {
                if (modelData.isPlaying)
                    nowPlaying.latest = modelData;
            }
        }
    }

    // A seek, a new track, a pause or another rate: the player's report is where the glide starts again.
    Connections {
        target: nowPlaying.player

        function onPositionChanged() {
            nowPlaying.follow();
        }

        function onIsPlayingChanged() {
            nowPlaying.follow();
        }

        function onRateChanged() {
            nowPlaying.follow();
        }
    }

    StatusRegion {
        objectName: "region"
        width: nowPlaying.width
        kicker: nowPlaying.present.length > 1 || !nowPlaying.player?.identity ? "läuft gerade" : `läuft gerade · ${nowPlaying.player.identity}`
        word: ""
        figures: [
            Select {
                id: picker

                objectName: "player"
                width: nowPlaying.width
                visible: nowPlaying.present.length > 1
                label: "player"
                options: nowPlaying.present.map(player => ({ text: player.identity, value: player }))
                currentIndex: nowPlaying.present.indexOf(nowPlaying.player)
                // The pick ends that binding: it comes back, so the select shows whichever player is shown.
                onActivated: index => {
                    nowPlaying.latest = nowPlaying.present[index];
                    currentIndex = Qt.binding(() => nowPlaying.present.indexOf(nowPlaying.player));
                }
            },
            Track {
                width: nowPlaying.width
            },
            Progress {
                objectName: "progress"
                width: nowPlaying.width
                visible: nowPlaying.length > 0
                value: visible ? Math.min(1, nowPlaying.played / nowPlaying.length) : -1
                valueText: `${Middle.clock(nowPlaying.played)} / ${Middle.clock(nowPlaying.length)}`
                eased: false
                Accessible.name: "fortschritt"
            }
        ]

        IconButton {
            objectName: "previous"
            icon: "previous"
            label: "vorheriger titel"
            disabledReason: nowPlaying.player?.canGoPrevious ? "" : "Kein Titel davor."
            onClicked: nowPlaying.player.previous()
        }

        IconButton {
            objectName: "playPause"
            icon: nowPlaying.player?.isPlaying ? "pause" : "play"
            label: nowPlaying.player?.isPlaying ? "pause" : "abspielen"
            disabledReason: nowPlaying.player?.canTogglePlaying ? "" : "Der Player lässt sich nicht steuern."
            onClicked: nowPlaying.player.togglePlaying()
        }

        IconButton {
            objectName: "next"
            icon: "next"
            label: "nächster titel"
            disabledReason: nowPlaying.player?.canGoNext ? "" : "Kein Titel danach."
            onClicked: nowPlaying.player.next()
        }
    }

    // The cover where the player has one, cut square at the start; the title and "artist · album" beside it, each one
    // line, cut where it is too long.
    component Track: Item {
        id: track

        readonly property string artUrl: nowPlaying.player?.trackArtUrl ?? ""
        readonly property bool covered: artUrl !== "" && cover.status !== Image.Error
        readonly property real wordsX: covered ? Geometry.iconSize + Tokens.spaceS : 0

        objectName: "track"
        implicitHeight: title.height + (byline.visible ? byline.height : 0)
        Accessible.role: Accessible.StaticText
        Accessible.name: [title.text, byline.text].filter(part => part !== "").join(", ")

        Picture {
            id: cover

            objectName: "cover"
            y: (track.height - height) / 2
            visible: track.covered
            source: track.artUrl
        }

        Body {
            id: title

            objectName: "title"
            x: track.wordsX
            width: track.width - x
            text: nowPlaying.player?.trackTitle ?? ""
            textFormat: Text.PlainText
            font.weight: Tokens.fontWeightSemibold
            wrapMode: Text.NoWrap
            elide: Text.ElideRight

            OverflowTip {}
        }

        Body {
            id: byline

            objectName: "byline"
            x: track.wordsX
            y: title.height
            width: track.width - x
            visible: text !== ""
            text: [nowPlaying.player?.trackArtist ?? "", nowPlaying.player?.trackAlbum ?? ""].filter(part => part !== "").join(" · ")
            textFormat: Text.PlainText
            wrapMode: Text.NoWrap
            elide: Text.ElideRight

            OverflowTip {}
        }
    }
}
