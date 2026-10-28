import QtQuick
import QtTest
import State

TestCase {
    name: "StatusSources"

    readonly property int shell: 4242

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

    function test_the_battery_is_low_from_the_warning_level_low_on() {
        compare([undefined, 0, 1, 2, 3, 4, 5].map(level => Sources.batteryLow(level)), [false, false, false, false, true, true, true]);
    }

    function test_only_no_connectivity_is_offline() {
        const none = 1;
        compare([0, 1, 2, 3, 4].map(connectivity => Sources.offline(connectivity, none)), [false, true, false, false, false]);
    }
}
