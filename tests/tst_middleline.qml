import QtQuick
import QtTest
import State

TestCase {
    id: testCase

    name: "MiddleLine"


    Component {
        id: lineComponent

        MiddleLine {
            frontTitle.interval: 100
        }
    }

    function make(front: var): var {
        const middle = createTemporaryObject(lineComponent, testCase, { front });
        verify(middle);
        return middle;
    }


    function title(middle: var): string {
        return middle.line.parts[middle.line.parts.length - 1];
    }

    // A window as the window model has it: `title` changes, the object stays.
    Component {
        id: windowComponent

        QtObject {
            property string app: "Konsole"
            property string title
        }
    }

    function windowTitled(text: string): var {
        return createTemporaryObject(windowComponent, testCase, { title: text });
    }

    function test_ten_title_changes_within_the_interval_update_the_line_at_most_twice_and_end_on_the_newest() {
        const window = windowTitled("start");
        const middle = make(window);
        let updates = 0;
        middle.lineChanged.connect(() => updates++);
        for (let i = 0; i < 10; i++)
            window.title = `step ${i}`;
        tryCompare(middle.frontTitle, "value", "step 9");
        verify(updates <= 2, `updates: ${updates}`);
        compare(title(middle), "step 9");
    }

    function test_the_first_change_after_quiet_shows_at_once() {
        const window = windowTitled("start");
        const middle = make(window);
        window.title = "changed";
        compare(title(middle), "changed");
    }

    function test_a_later_change_shows_the_newest_title_when_the_interval_ends_never_a_stale_one() {
        const window = windowTitled("start");
        const middle = make(window);
        window.title = "first";
        window.title = "second";
        window.title = "third";
        compare(title(middle), "first");
        tryCompare(middle.frontTitle, "value", "third");
    }

    function test_a_switch_of_window_shows_its_title_at_once_while_a_change_waits() {
        const window = windowTitled("start");
        const other = windowTitled("other");
        other.app = "Kate";
        const middle = make(window);
        window.title = "first";
        window.title = "second";
        middle.front = other;
        compare(title(middle), "other");
        verify(!middle.frontTitle.hold.running, "the old window's waiting title is dropped");
        compare(title(middle), "other");
    }

    function test_the_timer_stops_at_rest() {
        const window = windowTitled("start");
        const middle = make(window);
        verify(!middle.frontTitle.hold.running, "idle at the start");
        window.title = "first";
        verify(middle.frontTitle.hold.running);
        tryVerify(() => !middle.frontTitle.hold.running);
        window.title = "second";
        window.title = "third";
        tryVerify(() => middle.frontTitle.value === "third" && !middle.frontTitle.hold.running);
    }

    function test_the_music_time_follows_every_change_while_the_title_waits() {
        const window = windowTitled("start");
        const middle = make(window);
        middle.musicTitle = "Song";
        middle.musicPosition = 1;
        compare(middle.line.parts[1], "0:01");
        window.title = "first";
        middle.musicPosition = 2;
        compare(middle.line.parts[1], "0:02");
        middle.musicPosition = 3;
        compare(middle.line.parts[1], "0:03");
    }

    function test_the_window_stands_in_the_line_once_the_music_stops() {
        const window = windowTitled("start");
        const middle = make(window);
        middle.musicTitle = "Song";
        middle.musicTitle = "";
        compare(middle.line.kind, "window");
        compare(title(middle), "start");
    }

    function test_a_change_right_after_the_trailing_title_waits_a_whole_interval() {
        const window = windowTitled("start");
        const middle = make(window);
        middle.frontTitle.interval = 400;
        window.title = "first";
        window.title = "second";
        tryCompare(middle.frontTitle, "value", "second");
        verify(middle.frontTitle.hold.running, "the trailing title holds the next change for a whole interval");
        window.title = "third";
        compare(title(middle), "second");
        tryCompare(middle.frontTitle, "value", "third");
    }
}
