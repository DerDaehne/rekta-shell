import QtQuick
import QtTest
import "../shell/services"

// The shell's media keys, pressed without KWin. Quickshell, its MPRIS service with one player and plasma-workspace's
// session bus are the stand-ins on the tests' import path.
TestCase {
    id: testCase

    name: "MediaKeys"

    // Untyped: the linter reads Media against the real Quickshell, which knows nothing of the stand-ins.
    property var media
    property var player

    Component {
        id: mediaComponent

        Media {}
    }

    function init() {
        failOnWarning(/./);
        media = createTemporaryObject(mediaComponent, testCase);
        player = media.choice.player;
        player.calls = [];
    }

    function shortcuts(): var {
        return Array.from(media.children).filter(one => one instanceof GlobalShortcut);
    }

    function test_the_shell_registers_play_pause_pause_stop_next_and_previous_as_its_media_keys() {
        compare(shortcuts().map(one => one.name), ["play-pause", "pause", "stop", "next", "previous"]);
    }

    function test_each_media_key_has_kdes_key_and_acts_on_the_player_laeuft_gerade_shows_data() {
        return [
            {
                tag: "play-pause",
                key: Qt.Key_MediaPlay,
                call: "togglePlaying"
            },
            {
                tag: "pause",
                key: Qt.Key_MediaPause,
                call: "pause"
            },
            {
                tag: "stop",
                key: Qt.Key_MediaStop,
                call: "stop"
            },
            {
                tag: "next",
                key: Qt.Key_MediaNext,
                call: "next"
            },
            {
                tag: "previous",
                key: Qt.Key_MediaPrevious,
                call: "previous"
            }
        ];
    }

    function test_each_media_key_has_kdes_key_and_acts_on_the_player_laeuft_gerade_shows(data) {
        const shortcut = shortcuts().find(one => one.name === data.tag);
        compare(Array.from(shortcut.keys), [data.key]);
        shortcut.pressed();
        compare(player.calls, [data.call]);
    }
}
