import QtQuick
import QtTest
import DBusCounterpart
import "../shell/services"

TestCase {
    id: testCase

    name: "ScreenBrightness"

    // powerdevil as a stand-in on the private bus, with a laptop panel and an external monitor.
    Component {
        id: powerdevilComponent

        FakeScreenBrightness {
            Component.onCompleted: {
                addDisplay("display0", "Built-in Screen", 51, 255, false);
                addDisplay("display1", "Monitor", 30, 100, false);
            }
        }
    }

    Component {
        id: sourceComponent

        ScreenBrightness {}
    }

    SignalSpy {
        id: setCalls

        signalName: "setBrightnessCalled"
    }

    SignalSpy {
        id: changes

        signalName: "changed"
    }

    function powerdevil() {
        const fake = createTemporaryObject(powerdevilComponent, testCase);
        setCalls.target = fake;
        setCalls.clear();
        return fake;
    }

    function source() {
        const created = createTemporaryObject(sourceComponent, testCase);
        changes.target = created;
        changes.clear();
        return created;
    }

    function rows(model) {
        return Array.from({ length: model.count }, (_, row) => {
            const { name, title, brightness, max } = model.get(row);
            return { name, title, brightness, max };
        });
    }

    function test_every_display_powerdevil_lists_is_known_with_its_label_brightness_and_maximum() {
        powerdevil();
        const displays = source().displays;
        tryCompare(displays, "count", 2);
        compare(rows(displays), [
            { name: "display0", title: "Built-in Screen", brightness: 51, max: 255 },
            { name: "display1", title: "Monitor", brightness: 30, max: 100 }
        ]);
    }

    function test_setting_a_display_calls_powerdevil_silently_for_that_display() {
        powerdevil();
        const brightness = source();
        tryCompare(brightness.displays, "count", 2);
        brightness.setBrightness("display1", 64);
        tryCompare(setCalls, "count", 1);
        compare(Array.from(setCalls.signalArguments[0]), ["display1", 64, 1], "name, value and the flag that keeps powerdevil's indicator away");
    }

    function test_a_change_from_elsewhere_moves_that_display_and_is_passed_on_with_its_context() {
        const fake = powerdevil();
        const brightness = source();
        tryCompare(brightness.displays, "count", 2);
        fake.changeBrightness("display0", 102, "brightness_key");
        tryCompare(changes, "count", 1);
        compare(changes.signalArguments[0][0], "display0");
        compare(changes.signalArguments[0][1], 102);
        compare(changes.signalArguments[0][3], "brightness_key");
        compare(brightness.displays.get(0).brightness, 102, "the row is current when the signal arrives");
        compare(brightness.displays.get(1).brightness, 30, "the other display stays");
        compare(brightness.maxOf("display0"), 255);
    }

    function test_a_changed_range_replaces_the_maximum_and_the_brightness() {
        const fake = powerdevil();
        const brightness = source();
        tryCompare(brightness.displays, "count", 2);
        fake.changeRange("display1", 200, 150);
        tryCompare(brightness.displays.get(1), "max", 200);
        compare(brightness.displays.get(1).brightness, 150);
    }

    function test_a_display_that_comes_and_goes_adds_and_removes_its_row() {
        const fake = powerdevil();
        const brightness = source();
        tryCompare(brightness.displays, "count", 2);
        fake.addDisplay("display2", "Tablet", 5, 10);
        tryCompare(brightness.displays, "count", 3);
        compare(brightness.displays.get(2).title, "Tablet");
        fake.removeDisplay("display0");
        tryCompare(brightness.displays, "count", 2);
        compare(rows(brightness.displays).map(row => row.name), ["display1", "display2"]);
        compare(brightness.maxOf("display0"), 0, "a display that has gone has no range");
    }

    function test_without_powerdevil_there_are_no_displays_and_nothing_is_reported() {
        const fake = powerdevil();
        fake.running = false;
        const brightness = source();
        wait(200);
        compare(brightness.displays.count, 0);
        brightness.setBrightness("display0", 10);
        wait(100);
        compare(setCalls.count, 0);
    }

    function test_powerdevil_appearing_later_fills_the_list_and_leaving_empties_it() {
        const fake = powerdevil();
        fake.running = false;
        const brightness = source();
        wait(100);
        compare(brightness.displays.count, 0);
        fake.running = true;
        tryCompare(brightness.displays, "count", 2);
        fake.running = false;
        tryCompare(brightness.displays, "count", 0);
    }
}
