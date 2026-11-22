pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Panel
import Rekta
import State
import "ContactSheets.js" as ContactSheets
import "Glide.js" as Glide

TestCase {
    id: testCase

    name: "NowPlaying"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 900
    height: 720

    // A 40 × 40 picture, as a player hands its cover over.
    readonly property string cover: Qt.resolvedUrl("pictures/blue-32.png").toString()
    readonly property easingCurve easeOut: ({ type: Easing.Bezier, bezierCurve: Tokens.easeOut })
    property Item scene
    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var side
    property var controls

    // An MPRIS player as Quickshell has it. Its calls are recorded; play, pause and stop also change its state, as a
    // player answers them.
    component FakePlayer: QtObject {
        property string identity: "Elisa"
        property int playbackState: PlayerChoice.Playing
        readonly property bool isPlaying: playbackState === PlayerChoice.Playing
        property string trackTitle: "Teardrop"
        property string trackArtist: "Massive Attack"
        property string trackAlbum: "Mezzanine"
        property string trackArtUrl: ""
        property bool positionSupported: true
        property real position: 134
        property bool lengthSupported: true
        property real length: 243
        property real rate: 1
        property bool canGoPrevious: true
        property bool canGoNext: true
        property bool canTogglePlaying: true
        property bool canPause: true
        property bool canControl: true
        property var calls: []

        function previous() {
            calls = [...calls, "previous"];
        }

        function next() {
            calls = [...calls, "next"];
        }

        function togglePlaying() {
            calls = [...calls, "togglePlaying"];
            playbackState = isPlaying ? PlayerChoice.Paused : PlayerChoice.Playing;
        }

        function pause() {
            calls = [...calls, "pause"];
            playbackState = PlayerChoice.Paused;
        }

        function stop() {
            calls = [...calls, "stop"];
            playbackState = PlayerChoice.Stopped;
        }
    }

    Component {
        id: playerComponent

        FakePlayer {}
    }

    Component {
        id: sceneComponent

        Rectangle {
            property alias panel: scenePanel

            width: 760
            height: 720
            color: Tokens.color.bg

            Button {
                objectName: "opener"
                x: Tokens.spaceL
                y: Tokens.spaceL
                text: "steuerung"
            }

            SidePanel {
                id: scenePanel

                property alias controls: controlsFacet

                objectName: "panel"
                anchors.fill: parent
                titles: ["steuerung", "meldungen"]

                Controls {
                    id: controlsFacet

                    objectName: "controls"
                    sheets: scenePanel.sheets
                    levels: scenePanel.levels
                }

                Item {
                    objectName: "messages"
                }
            }
        }
    }

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        Prefs.motion = "off";
        scene = createTemporaryObject(sceneComponent, testCase);
        side = findChild(scene, "panel");
        controls = side.controls;
        findChild(scene, "opener").forceActiveFocus();
    }

    function cleanup() {
        Tips.hide();
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    function part(name: string): var {
        return findChild(controls, name);
    }

    function player(properties: var): var {
        return createTemporaryObject(playerComponent, testCase, properties ?? {});
    }

    // One player playing, handed to the controls as the host hands Quickshell's players.
    function givePlayer(properties: var): var {
        const one = player(properties);
        controls.choice.players = [one];
        return one;
    }

    function showSettled() {
        side.show(0);
        tryVerify(() => !findChild(side, "comingIn").running, Tokens.durationModerate * 4, "it has come in");
        waitForRendering(side);
    }

    function test_while_a_player_plays_laeuft_gerade_stands_at_the_top_of_steuerung_with_title_artist_album_and_progress() {
        givePlayer();
        side.show(0);
        const region = part("nowPlaying");
        verify(region.visible);
        const above = findChild(controls, "above");
        compare(above.children[0], region, "it stands first above the grid, above every group");
        compare(region.y, 0, "at the top");
        compare(findChild(region, "kicker").text, "läuft gerade · Elisa", "the kicker names the player");
        verify(!findChild(region, "tag").visible, "the region has no status tag");
        compare(part("title").text, "Teardrop");
        compare(part("title").font.weight, Tokens.fontWeightSemibold);
        compare(part("byline").text, "Massive Attack · Mezzanine");
        const progress = part("progress");
        verify(progress.visible);
        compare(progress.value, 134 / 243);
        compare(findChild(progress, "percent").text, "2:14 / 4:03", "the time played and the length stand where a percentage would");
        compare(findChild(progress, "percent").font.features.tnum, 1, "in tabular figures");
    }

    function test_as_a_status_region_it_has_no_fill_no_press_and_no_focus_and_its_parts_follow_the_regions_rhythm() {
        givePlayer();
        showSettled();
        const region = findChild(part("nowPlaying"), "region");
        verify(!region.activeFocusOnTab);
        compare(region.Accessible.name, "läuft gerade · Elisa");
        const kicker = findChild(region, "kicker");
        const track = part("track");
        const progress = part("progress");
        const previous = part("previous");
        const at = item => item.mapToItem(region, 0, 0).y;
        compare(at(track), at(kicker) + kicker.height + Tokens.spaceS, "the figures stand space-s under the kicker");
        compare(at(progress), at(track) + track.height + Tokens.spaceM, "figures stand space-m apart");
        compare(at(previous), at(progress) + progress.height + Tokens.spaceM, "the actions space-m under the figures");
        const image = grabImage(side);
        const middle = track.mapToItem(side, track.width - 2, 1);
        verify(Qt.colorEqual(image.pixel(middle.x, middle.y), Tokens.color.bg), "the ground shows through");
    }

    function test_without_a_player_the_region_is_gone_and_a_paused_one_stays_only_with_a_track() {
        side.show(0);
        verify(!part("nowPlaying").visible, "no player");
        const one = givePlayer({ playbackState: PlayerChoice.Stopped });
        verify(!part("nowPlaying").visible, "a stopped player");
        one.playbackState = PlayerChoice.Paused;
        verify(part("nowPlaying").visible, "paused with a track");
        one.trackTitle = "";
        verify(!part("nowPlaying").visible, "paused without a track");
        one.playbackState = PlayerChoice.Playing;
        verify(part("nowPlaying").visible, "playing");
        controls.choice.players = [];
        verify(!part("nowPlaying").visible, "the player gone");
    }

    function test_previous_play_pause_and_next_call_the_player() {
        const one = givePlayer();
        showSettled();
        mouseClick(part("previous"));
        mouseClick(part("playPause"));
        mouseClick(part("next"));
        compare(one.calls, ["previous", "togglePlaying", "next"]);
    }

    function test_play_pause_shows_what_a_press_does_and_follows_the_players_state() {
        const one = givePlayer();
        side.show(0);
        const button = part("playPause");
        compare(button.icon, "pause");
        compare(button.Accessible.name, "pause");
        compare(button.tip, "pause");
        one.playbackState = PlayerChoice.Paused;
        compare(button.icon, "play", "a pause from elsewhere shows at once");
        compare(button.Accessible.name, "abspielen");
        compare(button.tip, "abspielen");
    }

    function test_the_icon_buttons_are_named_and_tipped_and_use_rektas_track_glyphs() {
        givePlayer();
        side.show(0);
        compare(part("previous").icon, "previous");
        compare(part("previous").Accessible.name, "vorheriger titel");
        compare(part("previous").tip, "vorheriger titel");
        compare(part("next").icon, "next");
        compare(part("next").Accessible.name, "nächster titel");
        compare(part("next").tip, "nächster titel");
    }

    function test_a_control_the_player_cannot_use_now_is_disabled_and_the_row_says_why() {
        const one = givePlayer({ canGoPrevious: false });
        showSettled();
        verify(part("previous").disabled);
        verify(!part("next").disabled);
        compare(findChild(part("nowPlaying"), "actions").why, "Kein Titel davor.");
        mouseClick(part("previous"));
        compare(one.calls, [], "it does not act");
        one.canTogglePlaying = false;
        one.canGoNext = false;
        compare(findChild(part("nowPlaying"), "actions").why, "Kein Titel davor. Der Player lässt sich nicht steuern. Kein Titel danach.");
    }

    function test_with_two_players_a_select_picks_one_and_the_one_that_started_playing_last_is_chosen() {
        const elisa = player();
        const browser = player({ identity: "Firefox", playbackState: PlayerChoice.Paused, trackTitle: "A talk", trackArtist: "", trackAlbum: "" });
        controls.choice.players = [browser, elisa];
        side.show(0);
        const picker = part("player");
        verify(picker.visible);
        compare(findChild(part("nowPlaying"), "kicker").text, "läuft gerade", "the select names the player");
        compare(picker.options.map(option => option.text), ["Firefox", "Elisa"]);
        compare(picker.currentText, "Elisa", "the one playing");
        compare(part("title").text, "Teardrop");
        browser.playbackState = PlayerChoice.Playing;
        compare(picker.currentText, "Firefox", "the one that started last");
        compare(part("title").text, "A talk");
        compare(part("byline").visible, false, "a track without artist or album has no line for them");
        picker.forceActiveFocus();
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(picker.currentText, "Elisa", "a pick shows that player");
        compare(part("title").text, "Teardrop");
        elisa.playbackState = PlayerChoice.Paused;
        compare(picker.currentText, "Elisa", "the pick holds while it pauses");
        browser.playbackState = PlayerChoice.Paused;
        browser.playbackState = PlayerChoice.Playing;
        compare(picker.currentText, "Firefox", "until another starts");
        controls.choice.players = [elisa];
        verify(!picker.visible, "one player has no select");
        compare(findChild(part("nowPlaying"), "kicker").text, "läuft gerade · Elisa");
    }

    // Quickshell lists a player only once it has read its state, so one that comes playing never changes isPlaying.
    function test_a_player_that_comes_already_playing_is_chosen_over_a_paused_one_that_started_before() {
        const elisa = givePlayer();
        side.show(0);
        elisa.playbackState = PlayerChoice.Paused;
        elisa.playbackState = PlayerChoice.Playing;
        elisa.playbackState = PlayerChoice.Paused;
        controls.choice.players = [elisa, player({ identity: "Firefox", trackTitle: "A talk" })];
        compare(part("player").currentText, "Firefox", "the one that started playing last");
        compare(part("title").text, "A talk");
    }

    function test_a_player_that_comes_already_playing_is_chosen_over_one_that_plays_since_before() {
        const elisa = givePlayer();
        side.show(0);
        elisa.playbackState = PlayerChoice.Paused;
        elisa.playbackState = PlayerChoice.Playing;
        controls.choice.players = [elisa, player({ identity: "Firefox", trackTitle: "A talk" })];
        compare(part("player").currentText, "Firefox", "the one that started playing last");
        controls.choice.players = [...controls.choice.players];
        compare(part("player").currentText, "Firefox", "a change of the list keeps it");
        elisa.playbackState = PlayerChoice.Paused;
        elisa.playbackState = PlayerChoice.Playing;
        compare(part("player").currentText, "Elisa", "until another starts");
    }

    // The player the bar's middle shows: the shell's Media hands it on as its player.
    function barPlayer(): var {
        return controls.choice.playingPlayer;
    }

    function pickSecondPlayer() {
        part("player").forceActiveFocus();
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
    }

    function test_with_two_players_playing_the_bar_and_laeuft_gerade_show_the_same_one_the_one_that_started_last() {
        const elisa = player();
        const browser = player({ identity: "Firefox", playbackState: PlayerChoice.Paused, trackTitle: "A talk" });
        controls.choice.players = [elisa, browser];
        side.show(0);
        browser.playbackState = PlayerChoice.Playing;
        compare(part("title").text, "A talk", "läuft gerade shows the one that started last");
        compare(barPlayer(), browser, "and the bar shows it too");
        elisa.playbackState = PlayerChoice.Paused;
        elisa.playbackState = PlayerChoice.Playing;
        compare(part("title").text, "Teardrop");
        compare(barPlayer(), elisa, "both follow the next start");
    }

    function test_a_pick_in_the_select_moves_the_bar_too_while_the_picked_player_plays() {
        const elisa = player();
        const browser = player({ identity: "Firefox", trackTitle: "A talk" });
        controls.choice.players = [elisa, browser];
        side.show(0);
        compare(part("player").currentText, "Elisa");
        pickSecondPlayer();
        compare(part("title").text, "A talk", "läuft gerade shows the pick");
        compare(barPlayer(), browser, "and so does the bar");
    }

    function test_a_player_that_comes_already_playing_counts_as_started_last_for_the_bar_too() {
        const elisa = givePlayer();
        side.show(0);
        const browser = player({ identity: "Firefox", trackTitle: "A talk" });
        controls.choice.players = [elisa, browser];
        compare(part("title").text, "A talk");
        compare(barPlayer(), browser, "the bar shows the newcomer as well");
    }

    function test_a_paused_player_picked_in_the_panel_leaves_the_bar_with_the_one_that_plays() {
        const elisa = player();
        const browser = player({ identity: "Firefox", playbackState: PlayerChoice.Paused, trackTitle: "A talk" });
        controls.choice.players = [elisa, browser];
        side.show(0);
        pickSecondPlayer();
        compare(part("title").text, "A talk", "läuft gerade shows the paused pick");
        compare(barPlayer(), elisa, "the bar shows only what plays");
        elisa.playbackState = PlayerChoice.Paused;
        compare(barPlayer(), null, "with nothing playing the bar has no player");
        compare(part("title").text, "A talk");
    }

    // Every media key once, as kglobalaccel hands them to the shell's Media.
    function pressEveryMediaKey() {
        controls.choice.next();
        controls.choice.previous();
        controls.choice.togglePlaying();
        controls.choice.togglePlaying();
        controls.choice.pause();
        controls.choice.stop();
    }

    function test_the_media_keys_act_on_the_player_laeuft_gerade_shows() {
        const elisa = givePlayer();
        side.show(0);
        compare(part("title").text, "Teardrop");
        pressEveryMediaKey();
        compare(elisa.calls, ["next", "previous", "togglePlaying", "togglePlaying", "pause", "stop"]);
    }

    function test_with_two_players_playing_a_media_key_acts_on_the_one_shown_the_one_that_started_last() {
        const elisa = player();
        const browser = player({ identity: "Firefox", playbackState: PlayerChoice.Paused, trackTitle: "A talk" });
        controls.choice.players = [elisa, browser];
        side.show(0);
        browser.playbackState = PlayerChoice.Playing;
        compare(part("title").text, "A talk");
        controls.choice.togglePlaying();
        compare(browser.calls, ["togglePlaying"], "the key pauses the one shown");
        compare(elisa.calls, [], "and leaves the one that started first playing");
        verify(elisa.isPlaying);
    }

    function test_after_a_pick_in_the_panel_a_media_key_acts_on_the_picked_player() {
        const elisa = player();
        const browser = player({ identity: "Firefox", trackTitle: "A talk" });
        controls.choice.players = [elisa, browser];
        side.show(0);
        compare(part("title").text, "Teardrop");
        pickSecondPlayer();
        controls.choice.next();
        compare(browser.calls, ["next"]);
        compare(elisa.calls, []);
    }

    function test_a_media_key_acts_on_a_paused_pick_not_on_the_player_the_bar_shows() {
        const elisa = player();
        const browser = player({ identity: "Firefox", playbackState: PlayerChoice.Paused, trackTitle: "A talk" });
        controls.choice.players = [elisa, browser];
        side.show(0);
        pickSecondPlayer();
        compare(barPlayer(), elisa);
        controls.choice.togglePlaying();
        compare(browser.calls, ["togglePlaying"], "the key plays what läuft gerade shows");
        compare(elisa.calls, []);
    }

    function test_without_a_player_shown_the_media_keys_do_nothing() {
        pressEveryMediaKey();
        const stopped = givePlayer({ playbackState: PlayerChoice.Stopped });
        pressEveryMediaKey();
        compare(stopped.calls, [], "a stopped player is not shown, so the keys leave it alone");
    }

    function test_a_media_key_the_player_cannot_follow_now_is_not_sent_to_it_data() {
        return [
            {
                tag: "canTogglePlaying",
                withheld: "togglePlaying"
            },
            {
                tag: "canPause",
                withheld: "pause"
            },
            {
                tag: "canControl",
                withheld: "stop"
            },
            {
                tag: "canGoNext",
                withheld: "next"
            },
            {
                tag: "canGoPrevious",
                withheld: "previous"
            }
        ];
    }

    function test_a_media_key_the_player_cannot_follow_now_is_not_sent_to_it(data) {
        const elisa = givePlayer({
            [data.tag]: false
        });
        pressEveryMediaKey();
        const everyCall = ["next", "previous", "togglePlaying", "togglePlaying", "pause", "stop"];
        compare(elisa.calls, everyCall.filter(call => call !== data.withheld), "the other keys still reach it");
    }

    // Each step of the progress from now on, with the time it was taken: under load frames come late, never the clock.
    function stepsOf(region: var): var {
        const steps = [];
        region.playedChanged.connect(() => steps.push({ played: region.played, at: Date.now() }));
        return steps;
    }

    function test_the_progress_glides_on_between_the_players_reports_without_jumps() {
        givePlayer({ position: 10 });
        showSettled();
        const region = part("nowPlaying");
        verify(region.played >= 10 && region.played < 11);
        const steps = stepsOf(region);
        tryVerify(() => steps.length > 10 && steps[steps.length - 1].at - steps[0].at >= 300, 5000, "it moves on frame by frame");
        const first = steps[0];
        for (const [index, step] of steps.entries()) {
            const due = first.played + (step.at - first.at) / 1000;
            verify(index === 0 || step.played > steps[index - 1].played, `it moves on: ${step.played} after ${steps[index - 1]?.played}`);
            verify(Math.abs(step.played - due) < 0.1, `with the clock at the player's rate, never a jump: ${step.played}, due ${due}`);
        }
        compare(part("progress").value, region.played / 243);
    }

    function test_with_motion_the_fill_keeps_up_with_the_glide() {
        Prefs.motion = "on";
        givePlayer({ position: 134 });
        showSettled();
        const fill = findChild(part("progress"), "fill");
        const bar = findChild(part("progress"), "bar");
        for (let look = 0; look < 5; look++) {
            wait(50);
            verify(Math.abs(fill.width - part("progress").value * bar.width) < 1, `the fill stands at the value: ${fill.width} of ${bar.width} at ${part("progress").value}`);
        }
    }

    function test_the_progress_holds_while_the_panel_is_closed_and_comes_back_where_the_player_is() {
        const one = givePlayer({ position: 10 });
        showSettled();
        const region = part("nowPlaying");
        side.close();
        tryCompare(side, "open", false);
        verify(!findChild(region, "gliding").running, "no glide while closed");
        const held = region.played;
        wait(100);
        compare(region.played, held);
        one.position = 200;
        side.show(0);
        verify(region.played >= 200 && region.played < 201, "it takes up where the player is");
        verify(findChild(region, "gliding").running);
    }

    function test_a_seek_a_pause_and_another_rate_start_the_glide_again_from_the_players_report() {
        const one = givePlayer({ position: 10 });
        showSettled();
        const region = part("nowPlaying");
        one.position = 120;
        verify(region.played >= 120 && region.played < 121, "a seek");
        one.playbackState = PlayerChoice.Paused;
        verify(!findChild(region, "gliding").running, "paused, it stands");
        const held = region.played;
        wait(100);
        compare(region.played, held);
        one.rate = 2;
        one.playbackState = PlayerChoice.Playing;
        const steps = stepsOf(region);
        tryVerify(() => steps.length > 1 && steps[steps.length - 1].at - steps[0].at >= 200, 5000);
        const [first, last] = [steps[0], steps[steps.length - 1]];
        const rate = (last.played - first.played) * 1000 / (last.at - first.at);
        verify(Math.abs(rate - 2) < 0.25, `twice the rate: ${rate}`);
    }

    function test_a_length_that_comes_after_the_position_lets_the_progress_glide_to_it() {
        const one = givePlayer({ position: 10, lengthSupported: false, length: 0 });
        showSettled();
        const gliding = findChild(part("nowPlaying"), "gliding");
        verify(!gliding.running, "no length, nothing to glide to");
        one.length = 243;
        one.lengthSupported = true;
        verify(part("progress").visible);
        verify(gliding.running, "it glides once the length is known");
        compare(gliding.to, 243);
    }

    function test_a_stream_without_a_length_shows_no_progress() {
        givePlayer({ lengthSupported: false, length: 0 });
        side.show(0);
        verify(part("nowPlaying").visible);
        verify(!part("progress").visible);
    }

    function test_a_cover_at_a_web_address_is_not_fetched_and_the_words_stand_without_it() {
        givePlayer({ trackArtUrl: "https://example.org/cover.png" });
        showSettled();
        verify(!part("cover").visible);
        compare(part("cover").source.toString(), "", "nothing was asked to load");
        compare(part("title").x, 0);
    }

    function test_the_cover_stands_in_the_icons_field_at_the_start_with_the_tiles_corners_and_the_words_beside_it() {
        givePlayer({ trackArtUrl: testCase.cover });
        showSettled();
        const cover = part("cover");
        tryCompare(cover, "status", Image.Ready);
        verify(cover.visible);
        compare(cover.width, Geometry.iconSize);
        compare(cover.height, Geometry.iconSize);
        compare(cover.x, 0);
        compare(part("title").x, Geometry.iconSize + Tokens.spaceS);
        compare(part("byline").x, part("title").x);
        compare(findChild(cover, "corners").radius, 2 * Tokens.radiusTile);
        compare(findChild(cover, "corners").border.color, Tokens.color.bg, "the corners are cut in the panel's ground");
        controls.choice.players[0].trackArtUrl = "";
        verify(!cover.visible, "without a cover");
        compare(part("title").x, 0, "the words take its place");
    }

    function test_everything_works_from_the_keyboard() {
        const one = givePlayer();
        side.show(0, false);
        verify(part("previous").activeFocus, "the focus starts at previous");
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Tab);
        verify(part("playPause").activeFocus);
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Down);
        verify(part("next").activeFocus, "↓ goes on as Tab does");
        keyClick(Qt.Key_Return);
        compare(one.calls, ["previous", "togglePlaying", "next"]);
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Up);
        verify(part("previous").activeFocus, "↑ goes back");
    }

    function test_with_two_players_the_keyboard_starts_at_the_select() {
        controls.choice.players = [player({ identity: "Firefox", playbackState: PlayerChoice.Paused }), player()];
        side.show(0, false);
        verify(part("player").activeFocus);
        keyClick(Qt.Key_Return);
        verify(part("player").expanded, "Enter opens it");
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Return);
        verify(!part("player").expanded);
        compare(part("player").currentText, "Firefox");
        compare(part("title").text, "Teardrop");
        keyClick(Qt.Key_Down);
        verify(!part("player").expanded, "closed, ↓ picks the next player in place");
        compare(part("player").currentText, "Elisa");
        keyClick(Qt.Key_Tab);
        verify(part("previous").activeFocus);
    }

    function test_with_two_players_a_press_opens_the_select_in_the_panel_and_a_press_on_a_player_picks_it() {
        const browser = player({ identity: "Firefox", playbackState: PlayerChoice.Paused, trackTitle: "A talk" });
        controls.choice.players = [player(), browser];
        showSettled();
        const picker = part("player");
        mouseClick(findChild(picker, "box"));
        verify(picker.expanded);
        const list = findChild(picker, "list");
        compare(list.parent, findChild(side, "floats"), "it floats in the panel");
        compare(picker.optionRows().map(row => row.checked), [true, false]);
        waitForRendering(side);
        mouseClick(picker.optionRows()[1]);
        verify(!picker.expanded);
        compare(picker.currentText, "Firefox");
        compare(part("title").text, "A talk");
    }

    function test_the_tip_of_the_first_button_shows_when_the_keyboard_opened_the_panel_and_waits_for_it_after_a_pointer() {
        givePlayer();
        side.show(0, false);
        compare(Tips.target, findChild(part("previous"), "box"), "opened by the keyboard, the focus brings its tip");
        side.close();
        tryCompare(side, "open", false);
        Tips.hide();
        side.show(0, true);
        verify(part("previous").activeFocus);
        compare(Tips.target, null, "opened by a pointer, no ring and no tip");
        keyClick(Qt.Key_Tab);
        compare(Tips.target, findChild(part("playPause"), "box"), "the keyboard brings the next one's tip");
    }

    function test_a_tip_stays_with_its_button_when_a_second_player_brings_the_select_above_it() {
        const elisa = givePlayer();
        showSettled();
        part("previous").forceActiveFocus();
        const tip = findChild(side, "tip");
        const box = findChild(part("previous"), "box");
        const above = () => box.mapToItem(tip.parent, 0, 0).y - Tokens.tipGap - tip.height;
        verify(tip.visible);
        compare(tip.y, Math.round(above()));
        const before = tip.y;
        controls.choice.players = [player({ identity: "Firefox", playbackState: PlayerChoice.Paused }), elisa];
        waitForRendering(side);
        verify(tip.y > before, "the button moved down");
        compare(tip.y, Math.round(above()), "and its tip with it");
    }

    // The words a pointer coming to rest on a text brings up, "" for none; coming on from another tip, they show at once.
    function tipOver(text: var): string {
        mouseMove(scene, 1, 1);
        Tips.hiddenAt = Date.now();
        mouseMove(text);
        return Tips.target === text ? Tips.text : "";
    }

    function test_a_cut_title_or_byline_shows_whole_in_a_tip_and_the_keyboard_brings_only_the_buttons_tips() {
        const one = givePlayer({ trackTitle: "Teardrop (Mad Professor Remix of the Mezzanine Sessions, 1998)" });
        showSettled();
        compare(Tips.text, "vorheriger titel", "the first control's own tip, not the title's");
        compare(tipOver(part("title")), "Teardrop (Mad Professor Remix of the Mezzanine Sessions, 1998)", "the title");
        compare(tipOver(part("byline")), "", "artist · album fit");
        one.trackAlbum = "Mezzanine (Deluxe Edition, remastered with the Mad Professor Remixes)";
        compare(tipOver(part("byline")), "Massive Attack · Mezzanine (Deluxe Edition, remastered with the Mad Professor Remixes)", "the line below");
        verify(findChild(side, "tip").visible, "drawn in the panel");
        one.trackTitle = "Teardrop";
        compare(tipOver(part("title")), "", "a title that fits");
    }

    // Both themes: one player with a cover, then two with the select.
    // Starts recording how the shown item comes in.
    function entry(): var {
        const region = part("nowPlaying");
        return {
            region,
            shifts: Glide.record(region, "entryShift"),
            fades: Glide.record(region, "entryOpacity")
        };
    }

    // Waits for the item to have come in, and tells how far it strayed from sliding `from` → 0 with a fade 0 → 1 together
    // along ease-out over 0.75 × duration-moderate since `since`.
    function cameIn(recorded: var, from: real, since: real, ticks: var): real {
        tryVerify(() => recorded.shifts.length > 0 && !findChild(recorded.region, "entering").running, 1000, "it has come in");
        compare(recorded.shifts[0].value, from, "it starts from that edge");
        compare(recorded.fades[0].value, 0, "unseen");
        compare(recorded.region.entryShift, 0);
        compare(recorded.region.entryOpacity, 1);
        return Glide.strayOf([{ steps: recorded.shifts, from, to: 0 }, { steps: recorded.fades, from: 0, to: 1 }], 0.75 * Tokens.durationModerate, easeOut, since, ticks);
    }

    // A further track comes in; that it is the first slide recorded shows nothing slid before it.
    function onlyTheNextSlides(recorded: var, one: var) {
        one.trackTitle = "Black Milk";
        tryVerify(() => recorded.region.shownTrack.startsWith("Black Milk"), 1000, "it has taken the next track");
        tryVerify(() => !findChild(recorded.region, "entering").running, 1000, "the next track has come in");
        verify(recorded.shifts.length > 0, "it came in");
        compare(recorded.shifts.filter(step => step.value === Tokens.slideDistance).length, 1, "nothing slid before it");
        compare(recorded.fades.filter(step => step.value === 0).length, 1, "nothing faded before it");
    }

    // How opaque `item` shows inside `within`: its own opacity times that of every item around it.
    function seenOpacity(item: Item, within: Item): real {
        let seen = 1;
        for (let at = item; at && at !== within; at = at.parent)
            seen *= at.opacity;
        return seen;
    }

    function nextTrack(one: var) {
        one.trackTitle = "Angel";
        one.trackArtist = "Massive Attack";
        one.trackAlbum = "Mezzanine";
        one.position = 0;
    }

    function test_after_next_the_new_track_slides_in_from_the_trailing_edge_with_a_fade_over_three_quarters_of_duration_moderate() {
        const ticks = Glide.ticks(testCase);
        const one = givePlayer();
        showSettled();
        Prefs.motion = "on";
        const before = {};
        for (const name of ["kicker", "previous", "playPause", "next"])
            before[name] = findChild(part("nowPlaying"), name).mapToItem(part("nowPlaying"), 0, 0).x;
        const recorded = entry();
        mouseClick(part("next"));
        compare(one.calls, ["next"]);
        const since = Date.now();
        nextTrack(one);
        tryVerify(() => findChild(recorded.region, "entering").running, 1000, "the new track comes in");
        compare(part("title").text, "Angel", "the new track's words are in place at once");
        for (const name of ["track", "progress"]) {
            compare(part(name).opacity, recorded.region.entryOpacity, `${name} fades in`);
            compare(part(name).transform[0].x, recorded.region.entryShift, `${name} slides in`);
        }
        for (const name of ["kicker", "previous", "playPause", "next"]) {
            const still = findChild(recorded.region, name);
            compare(seenOpacity(still, recorded.region), 1, `${name} stays`);
            compare(still.mapToItem(recorded.region, 0, 0).x, before[name], `${name} stays in place`);
        }
        const stray = cameIn(recorded, Tokens.slideDistance, since, ticks);
        verify(stray < 0.06, `it slides and fades together along ease-out, off by ${stray}`);
    }

    function test_after_previous_the_track_before_slides_in_once_from_the_leading_edge_however_its_words_arrive() {
        const ticks = Glide.ticks(testCase);
        const one = givePlayer();
        showSettled();
        Prefs.motion = "on";
        const recorded = entry();
        mouseClick(part("previous"));
        compare(one.calls, ["previous"]);
        const since = Date.now();
        nextTrack(one);
        one.trackArtist = "Portishead";
        one.trackAlbum = "Dummy";
        const stray = cameIn(recorded, -Tokens.slideDistance, since, ticks);
        verify(stray < 0.06, `off by ${stray}`);
        compare(recorded.shifts.filter(step => Math.abs(step.value) === Tokens.slideDistance).length, 1, "it comes in once");
    }

    function test_a_media_key_back_also_brings_the_track_from_the_leading_edge_and_the_next_one_after_it_from_the_trailing() {
        const one = givePlayer();
        showSettled();
        Prefs.motion = "on";
        let recorded = entry();
        controls.choice.previous();
        nextTrack(one);
        tryVerify(() => recorded.shifts.length > 0, 1000);
        compare(recorded.shifts[0].value, -Tokens.slideDistance);
        tryVerify(() => !findChild(recorded.region, "entering").running, 1000);
        recorded = entry();
        one.trackTitle = "Inertia Creeps";
        tryVerify(() => recorded.shifts.length > 0, 1000, "a track that follows on its own comes forward");
        compare(recorded.shifts[0].value, Tokens.slideDistance);
    }

    function test_a_track_that_follows_on_its_own_slides_in_from_the_trailing_edge() {
        const ticks = Glide.ticks(testCase);
        const one = givePlayer();
        showSettled();
        Prefs.motion = "on";
        const recorded = entry();
        const since = Date.now();
        nextTrack(one);
        const stray = cameIn(recorded, Tokens.slideDistance, since, ticks);
        verify(stray < 0.06, `off by ${stray}`);
    }

    function test_a_pick_in_the_select_slides_the_picked_players_track_in_from_its_side_of_the_select_while_the_select_stays_still() {
        const ticks = Glide.ticks(testCase);
        const browser = player({ identity: "Firefox", playbackState: PlayerChoice.Paused, trackTitle: "A talk" });
        controls.choice.players = [browser, player()];
        showSettled();
        Prefs.motion = "on";
        const picker = part("player");
        let recorded = entry();
        const pickerX = picker.mapToItem(recorded.region, 0, 0).x;
        picker.forceActiveFocus();
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Up);
        let since = Date.now();
        keyClick(Qt.Key_Return);
        compare(picker.currentText, "Firefox");
        tryVerify(() => findChild(recorded.region, "entering").running, 1000, "the picked track comes in");
        compare(seenOpacity(picker, recorded.region), 1, "the select stays");
        compare(picker.mapToItem(recorded.region, 0, 0).x, pickerX, "the select stays in place");
        let stray = cameIn(recorded, -Tokens.slideDistance, since, ticks);
        verify(stray < 0.06, `one earlier in the select comes from the leading edge, off by ${stray}`);
        recorded = entry();
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Down);
        since = Date.now();
        keyClick(Qt.Key_Return);
        compare(picker.currentText, "Elisa");
        stray = cameIn(recorded, Tokens.slideDistance, since, ticks);
        verify(stray < 0.06, `one later in the select comes from the trailing edge, off by ${stray}`);
    }

    function test_after_a_skip_back_that_brought_no_new_track_a_skip_forward_brings_its_track_from_the_trailing_edge() {
        const one = givePlayer();
        showSettled();
        Prefs.motion = "on";
        const recorded = entry();
        mouseClick(part("previous"));
        mouseClick(part("next"));
        compare(one.calls, ["previous", "next"]);
        nextTrack(one);
        tryVerify(() => recorded.shifts.length > 0, 1000, "the new track comes in");
        compare(recorded.shifts[0].value, Tokens.slideDistance);
    }

    function test_another_artist_or_album_under_the_same_title_is_another_track_and_slides_in() {
        const one = givePlayer();
        showSettled();
        Prefs.motion = "on";
        let recorded = entry();
        one.trackArtist = "Portishead";
        tryVerify(() => recorded.shifts.length > 0, 1000, "another artist comes in");
        compare(recorded.shifts[0].value, Tokens.slideDistance);
        tryVerify(() => !findChild(recorded.region, "entering").running, 1000);
        recorded = entry();
        one.trackAlbum = "Dummy";
        tryVerify(() => recorded.shifts.length > 0, 1000, "another album comes in");
        compare(recorded.shifts[0].value, Tokens.slideDistance);
    }

    function test_the_first_display_and_new_data_of_the_same_track_stand_still() {
        const ticks = Glide.ticks(testCase);
        Prefs.motion = "on";
        side.show(0);
        tryVerify(() => !findChild(side, "comingIn").running, Tokens.durationModerate * 4, "it has come in");
        const region = part("nowPlaying");
        const shifts = Glide.record(region, "entryShift");
        const fades = Glide.record(region, "entryOpacity");
        const one = givePlayer();
        verify(region.visible);
        tryVerify(() => region.shownPlayer === one, 1000, "it shows the player");
        one.trackArtUrl = cover;
        one.position = 20;
        one.length = 250;
        one.playbackState = PlayerChoice.Paused;
        one.playbackState = PlayerChoice.Playing;
        one.trackArtist = "Massive Attack";
        const taken = ticks.length;
        tryVerify(() => ticks.length > taken + 1, 1000, "two frames pass");
        onlyTheNextSlides({ region, shifts, fades }, one);
    }

    function test_a_track_that_changes_while_the_panel_is_closed_stands_still_when_it_opens() {
        const one = givePlayer();
        showSettled();
        Prefs.motion = "on";
        side.close();
        tryVerify(() => !part("nowPlaying").visible, 1000, "the panel is closed");
        const recorded = entry();
        nextTrack(one);
        tryVerify(() => recorded.region.shownTrack.startsWith("Angel"), 1000, "it has taken the track");
        compare(recorded.shifts.length, 0, "nothing comes in while the panel is closed");
        side.show(0);
        tryVerify(() => part("nowPlaying").visible, 1000);
        compare(part("title").text, "Angel");
        onlyTheNextSlides(recorded, one);
    }

    function test_under_reduced_motion_the_next_track_stands_at_once() {
        const one = givePlayer();
        showSettled();
        const recorded = entry();
        mouseClick(part("next"));
        nextTrack(one);
        compare(part("title").text, "Angel", "at once");
        compare(part("track").opacity, 1);
        compare(part("track").transform[0].x, 0);
        tryVerify(() => recorded.region.shownTrack.startsWith("Angel"), 1000, "it has taken the track");
        Prefs.motion = "on";
        onlyTheNextSlides(recorded, one);
    }

    function test_contact_sheet_of_laeuft_gerade_in_both_themes() {
        if (!ContactSheets.wanted)
            skip("contact sheets are built on demand");
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const contact = createTemporaryObject(sceneComponent, testCase);
            const shown = player({ trackArtUrl: testCase.cover, canGoPrevious: false });
            contact.panel.controls.choice.players = [shown];
            contact.panel.show(0, true);
            tryCompare(findChild(contact, "cover"), "status", Image.Ready);
            waitForRendering(contact);
            grabImage(contact).save(`nowplaying-sheet-${theme}.png`);
            contact.panel.controls.choice.players = [player({ identity: "Firefox", playbackState: PlayerChoice.Paused, trackTitle: "A talk on type", trackArtist: "", trackAlbum: "" }), shown];
            waitForRendering(contact);
            grabImage(contact).save(`nowplaying-players-sheet-${theme}.png`);
            verify(findChild(contact, "player").visible);
        }
    }
}
