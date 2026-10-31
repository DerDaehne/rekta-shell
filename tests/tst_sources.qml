import QtQuick
import QtTest
import State

TestCase {
    name: "StatusSources"

    readonly property int shell: 4242
    // The shell's own previews as SystemState holds them, a QML list rather than a script array.
    readonly property list<int> previews: [64, 65]

    function stream(properties) {
        return { isStream: true, properties: Object.assign({ "media.class": "Stream/Input/Audio" }, properties) };
    }

    function test_a_program_recording_from_a_microphone_is_in_use() {
        verify(Sources.microphoneInUse([stream({ "application.process.id": "100" })], shell));
    }

    function test_without_a_capture_stream_the_microphone_is_not_in_use() {
        verify(!Sources.microphoneInUse([], shell));
    }

    function test_a_stream_listening_to_the_monitor_of_an_output_is_not_a_microphone() {
        verify(!Sources.microphoneInUse([stream({ "stream.capture.sink": "true" })], shell));
    }

    function test_a_playing_stream_is_not_a_microphone() {
        verify(!Sources.microphoneInUse([{ isStream: true, properties: { "media.class": "Stream/Output/Audio" } }], shell));
    }

    function test_a_device_node_is_not_a_stream() {
        verify(!Sources.microphoneInUse([{ isStream: false, properties: { "media.class": "Stream/Input/Audio" } }], shell));
    }

    function test_the_shells_own_capture_stream_never_counts() {
        verify(!Sources.microphoneInUse([stream({ "application.process.id": String(shell) })], shell));
        verify(Sources.microphoneInUse([stream({ "application.process.id": String(shell) }), stream({ "application.process.id": "7" })], shell), "another program still does");
    }

    // A link from a source node; without a media name its properties have not arrived yet.
    function link(sourceId, mediaName) {
        return { source: { id: sourceId, properties: mediaName === undefined ? {} : { "media.name": mediaName } } };
    }

    function test_a_program_receiving_a_screencast_of_kwin_shares_the_screen() {
        verify(Sources.screenShared([link(70, "kwin-screencast-Virtual-1")], []));
    }

    function test_the_shells_own_preview_never_counts() {
        verify(!Sources.screenShared([link(64, "kwin-screencast-org.kde.konsole")], previews));
        verify(Sources.screenShared([link(64, "kwin-screencast-org.kde.konsole"), link(70, "kwin-screencast-Virtual-1")], previews), "another source still does");
    }

    function test_a_source_counts_only_once_its_properties_are_there() {
        verify(!Sources.screenShared([link(70)], []));
    }

    function test_a_camera_or_an_audio_link_is_not_a_shared_screen() {
        verify(!Sources.screenShared([link(30, "Integrated Camera")], []));
        verify(!Sources.screenShared([link(31, "Playback")], []));
    }

    function test_without_a_link_the_screen_is_not_shared() {
        verify(!Sources.screenShared([], []));
    }

    function test_a_running_preview_is_the_shells_own_before_its_link_appears() {
        compare(Sources.ownScreencasts(previews, [], []), [64, 65]);
    }

    function test_the_running_previews_are_the_shells_own_once_each() {
        compare(Sources.ownScreencasts(previews, previews, [link(64, "kwin-screencast-org.kde.konsole"), link(65, "kwin-screencast-org.kde.dolphin")]), [64, 65]);
    }

    function test_an_ended_preview_stays_the_shells_own_while_its_link_remains() {
        compare(Sources.ownScreencasts([], previews, [link(64, "kwin-screencast-org.kde.konsole")]), [64]);
    }

    function test_the_battery_is_low_from_the_warning_level_low_on() {
        compare([undefined, 0, 1, 2, 3, 4, 5].map(level => Sources.batteryLow(level)), [false, false, false, false, true, true, true]);
    }

    function test_only_no_connectivity_is_offline() {
        const none = 1;
        compare([0, 1, 2, 3, 4].map(connectivity => Sources.offline(connectivity, none)), [false, true, false, false, false]);
    }
}
