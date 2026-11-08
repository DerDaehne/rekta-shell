import QtQuick
import QtTest
import "../shell/services"

// The app of what plays, whose launch tile in the Start shows it. Quickshell's desktop entries and its MPRIS service with
// one player are the stand-ins on the tests' import path.
TestCase {
    id: testCase

    name: "MediaApp"

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
        player = media.player;
        player.identity = "";
        player.desktopEntry = "";
    }

    function test_a_known_desktop_entry_gives_that_entrys_id() {
        player.desktopEntry = "elisa";
        compare(media.appId, "org.kde.elisa");
    }

    function test_an_unknown_desktop_entry_is_taken_as_the_id() {
        player.identity = "Elisa";
        player.desktopEntry = "mpv";
        compare(media.appId, "mpv");
    }

    function test_without_a_desktop_entry_the_players_name_finds_its_app() {
        player.identity = "Elisa";
        compare(media.appId, "org.kde.elisa");
    }

    function test_a_player_without_a_desktop_entry_or_a_known_name_has_no_app() {
        player.identity = "Some Player";
        compare(media.appId, "");
    }
}
