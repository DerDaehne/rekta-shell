import QtQuick
import QtTest
import State

TestCase {
    name: "FrontWindow"

    readonly property var primary: ({ name: "primary" })
    readonly property var portrait: ({ name: "portrait" })

    // A window as the shell's window model has it: on `screen`, on desktop "one", activated at `lastActivated` (ms).
    function window(title, screen, lastActivated, overrides) {
        return Object.assign({
            title: title,
            fullScreen: false,
            minimized: false,
            onAllDesktops: false,
            desktops: ["one"],
            lastActivated: lastActivated,
            isOn: other => other === screen
        }, overrides ?? {});
    }

    // A game in full screen on the primary screen, a launcher and a browser behind it, a chat on the portrait screen.
    function desk(overrides) {
        return [
            window("launcher", primary, 1000),
            window("game", primary, 3000, Object.assign({ fullScreen: true }, overrides ?? {})),
            window("browser", primary, 2000),
            window("chat", portrait, 500)
        ];
    }

    function frontTitle(windows, screen, desktop) {
        return Front.windowOn(windows, screen, desktop ?? "one")?.title ?? "";
    }

    function test_the_full_screen_window_stays_in_front_while_no_window_has_the_keyboard() {
        compare(frontTitle(desk(), primary), "game");
    }

    function test_a_window_activated_after_it_on_the_same_screen_comes_in_front() {
        const windows = desk();
        windows[2].lastActivated = 4000;
        compare(frontTitle(windows, primary), "browser");
    }

    function test_a_window_activated_on_another_screen_leaves_it_in_front() {
        const windows = desk();
        windows[3].lastActivated = 4000;
        compare(frontTitle(windows, primary), "game");
        compare(frontTitle(windows, portrait), "chat");
    }

    function test_a_minimised_window_is_never_in_front() {
        compare(frontTitle(desk({ minimized: true }), primary), "browser");
    }

    function test_a_window_on_another_desktop_is_never_in_front() {
        compare(frontTitle(desk({ desktops: ["two"] }), primary), "browser");
        compare(frontTitle(desk(), primary, "two"), "", "the other desktop has no window");
    }

    function test_a_window_on_every_desktop_is_in_front_on_each() {
        compare(frontTitle(desk({ onAllDesktops: true, desktops: [] }), primary, "two"), "game");
    }

    function test_a_window_never_seen_activated_comes_after_one_that_was() {
        const windows = [window("restored", primary, 0), window("used", primary, 1000)];
        compare(frontTitle(windows, primary), "used");
    }

    function test_a_screen_without_windows_has_none_in_front() {
        verify(Front.windowOn(desk(), { name: "third" }, "one") === null);
    }
}
