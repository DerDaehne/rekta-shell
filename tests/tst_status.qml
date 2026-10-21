pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "DataAndStatus"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1000
    height: 600

    Component {
        id: tagComponent

        StatusTag {}
    }

    Component {
        id: meterComponent

        Meter {
            width: 300
            label: "disk"
            value: 0.81
            valueText: "81%"
        }
    }

    Component {
        id: progressComponent

        Progress {
            width: 300
        }
    }

    Component {
        id: busyComponent

        BusyLine {
            width: 300
        }
    }

    Component {
        id: dotsComponent

        Dots {
            width: 400
            text: "signing in"
        }
    }

    Component {
        id: sheetComponent

        // Every data and status element on the current theme's ground; the moving ones stand still for a stable image.
        Rectangle {
            width: 480
            height: column.height + 2 * Tokens.spaceL
            color: Tokens.color.bg

            Column {
                id: column

                x: Tokens.spaceL
                y: Tokens.spaceL
                width: parent.width - 2 * Tokens.spaceL
                spacing: Tokens.spaceL

                Row {
                    spacing: Tokens.spaceM

                    Repeater {
                        model: ["info", "success", "warning", "error", ""]

                        delegate: StatusTag {
                            required property string modelData

                            status: modelData
                        }
                    }
                }

                Meter { width: parent.width; label: "storage"; value: 0.42; valueText: "42%" }
                Meter { width: parent.width; label: "disk"; value: 0.93; valueText: "93%"; status: "warning" }
                Progress { width: parent.width; value: 0.6; label: "copying" }
                Progress { width: parent.width }
                BusyLine { width: parent.width; shown: true }
                Dots { width: parent.width; text: "installing" }
            }
        }
    }

    function cleanup() {
        Prefs.motion = "system";
        Prefs.theme = "system";
    }

    function test_a_tag_shows_each_status_square_and_word() {
        const expected = [
            ["info", Tokens.color.statusInfoFull, "active"],
            ["success", Tokens.color.statusSuccessFull, "done"],
            ["warning", Tokens.color.statusWarningFull, "waiting"],
            ["error", Tokens.color.statusErrorFull, "failed"],
            ["", Tokens.color.textContrastMedium, "idle"]
        ];
        for (const [status, mark, word] of expected) {
            const tag = createTemporaryObject(tagComponent, testCase, { status: status });
            compare(tag.mark, mark, status);
            compare(tag.word, word, status);
            compare(tag.Accessible.name, word, status);
        }
    }

    function test_a_meter_fills_in_ink_or_in_the_status_it_means() {
        const meter = createTemporaryObject(meterComponent, testCase);
        const fill = findChild(meter, "fill");
        tryCompare(fill, "width", 300 * 0.81);
        compare(fill.color, Tokens.color.textPrimary);
        meter.status = "warning";
        meter.valueWords = "81%, nearly full";
        compare(fill.color, Tokens.color.statusWarningFull);
        compare(meter.Accessible.description, "81%, nearly full");
    }

    function test_a_known_progress_fills_to_its_value_under_its_label_and_percentage() {
        const progress = createTemporaryObject(progressComponent, testCase, { value: 0.25, label: "copying" });
        verify(progress.known);
        tryCompare(findChild(progress, "fill"), "width", 75);
        const percent = findChild(progress, "percent");
        compare(percent.text, "25%");
        verify(percent.parent.visible);
        compare(progress.Accessible.description, "25%");
    }

    function test_an_unknown_progress_runs_and_stands_still_under_reduced_motion() {
        const progress = createTemporaryObject(progressComponent, testCase);
        verify(!progress.known);
        const segment = findChild(progress, "segment");
        const before = segment.x;
        wait(Tokens.durationBusy / 4);
        verify(segment.x !== before, "the segment moves");
        compare(segment.width, 300 * Geometry.busySegment);
        Prefs.motion = "off";
        compare(segment.width, 300);
        compare(segment.x, 0);
    }

    function test_the_busy_line_waits_for_busy_delay_and_stays_for_busy_min() {
        const line = createTemporaryObject(busyComponent, testCase);
        line.busy = true;
        wait(Tokens.durationBusyDelay / 2);
        verify(!line.shown, "not before busy-delay");
        tryCompare(line, "shown", true, Tokens.durationBusyDelay * 2);
        line.busy = false;
        verify(line.shown, "still there right after the work ended");
        wait(Tokens.durationBusyMin / 2);
        verify(line.shown, "stays for busy-min");
        tryCompare(line, "shown", false, Tokens.durationBusyMin * 2);
    }

    function test_quick_work_never_shows_the_busy_line() {
        const line = createTemporaryObject(busyComponent, testCase);
        line.busy = true;
        wait(Tokens.durationBusyDelay / 3);
        line.busy = false;
        wait(Tokens.durationBusyDelay);
        verify(!line.shown);
    }

    function test_under_reduced_motion_the_busy_line_stands_at_full_width_in_medium_contrast() {
        Prefs.motion = "off";
        const line = createTemporaryObject(busyComponent, testCase);
        const segmentTrack = findChild(line, "busySegment");
        const segment = findChild(line, "segment");
        compare(segmentTrack.ink, Tokens.color.textContrastMedium);
        compare(segment.width, 300);
        compare(segment.x, 0);
    }

    function test_the_dots_fly_one_after_another() {
        const dots = createTemporaryObject(dotsComponent, testCase);
        const all = Array.from(dots.children).filter(child => child.position !== undefined);
        compare(all.length, Geometry.dotCount);
        wait(Tokens.durationDots * Geometry.dotStagger * 2);
        verify(all[0].position > all[4].position, "the first dot leads");
        verify(all[0].opacity > 0, "the first dot is visible");
    }

    function test_under_reduced_motion_the_dots_stand_still_in_the_middle_with_words() {
        Prefs.motion = "off";
        const dots = createTemporaryObject(dotsComponent, testCase);
        const all = Array.from(dots.children).filter(child => child.position !== undefined);
        for (const dot of all) {
            compare(dot.x, 200 - Geometry.dotRestOffset + dot.index * Geometry.dotRestSpacing);
            compare(dot.opacity, 1);
        }
        const words = Array.from(dots.children).find(child => child.text === "signing in");
        verify(words.visible);
    }

    // The elements follow the one current theme, so the sheet is drawn once per theme.
    function test_contact_sheet_of_data_and_status_in_both_themes() {
        Prefs.motion = "off";
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const sheet = createTemporaryObject(sheetComponent, testCase);
            waitForRendering(sheet);
            grabImage(sheet).save(`status-sheet-${theme}.png`);
            verify(sheet.height > 0, theme);
            sheet.destroy();
        }
    }
}
