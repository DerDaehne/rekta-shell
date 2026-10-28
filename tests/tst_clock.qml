pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Rekta

TestCase {
    id: testCase

    name: "Clock"
    // Objects created inside an invisible test case are never rendered, so contact sheets would stay empty.
    visible: true
    when: windowShown
    width: 1200
    height: 600

    // The clock in the centre of a bar along the bottom, its month placed by the bar as the shell does.
    Component {
        id: sceneComponent

        Item {
            id: scene

            property alias bar: appBar
            property alias clock: appClock

            width: 1200
            height: 600

            AppBar {
                id: appBar

                y: scene.height - height
                width: scene.width
                centre: appClock

                AppBarButton { objectName: "back"; icon: "window"; text: "back" }
                AppBarMiddle { parts: ["konsole", "~/projects"] }

                AppBarClock {
                    id: appClock

                    objectName: "clock"
                    locale: Qt.locale("de_DE")
                    now: new Date(2026, 9, 20, 14, 32, 15, 250)
                    calendar.x: appBar.floatPlace(appClock, Qt.size(calendar.width, calendar.height), "centre").x - x
                    calendar.y: appBar.floatPlace(appClock, Qt.size(calendar.width, calendar.height), "centre").y - y
                    calendar.side: appBar.floatPlace(appClock, Qt.size(calendar.width, calendar.height), "centre").side
                }

                AppBarButton { objectName: "controls"; icon: "tune"; text: "controls" }
            }
        }
    }

    // Untyped: qmllint stops without a word on members an Item-typed value lacks.
    property var scene
    property var clock

    function init() {
        failOnWarning(/TypeError|ReferenceError|Binding loop/);
        scene = createTemporaryObject(sceneComponent, testCase);
        clock = scene.clock;
    }

    function cleanup() {
        Prefs.density = "auto";
        Prefs.theme = "system";
    }

    function cell(index: int): var {
        return findChild(clock.month, `day ${index}`);
    }

    function cellOf(day: date): var {
        for (let i = 0; i < 42; i++) {
            if (Calendar.sameDay(cell(i).day, day))
                return cell(i);
        }
        return null;
    }

    function test_time_and_date_follow_the_locale() {
        const tuesday = new Date(2026, 9, 20, 14, 32);
        compare(Calendar.timeWords(tuesday, Qt.locale("de_DE")), "14:32");
        compare(Calendar.dateWords(tuesday, Qt.locale("de_DE")), "di 20. okt");
        compare(Calendar.timeWords(tuesday, Qt.locale("en_US")), "2:32 PM");
        compare(Calendar.dateWords(tuesday, Qt.locale("en_US")), "tue oct 20");
        compare(Calendar.timeWords(tuesday, Qt.locale("en_GB")), "14:32");
        compare(Calendar.dateWords(tuesday, Qt.locale("en_GB")), "tue 20 oct");
        compare(clock.text, "14:32 di 20. okt", "the clock reads both");
    }

    function test_the_time_stands_over_the_date_in_the_48px_control() {
        const time = findChild(clock, "time");
        const day = findChild(clock, "date");
        compare(time.text, "14:32");
        compare(day.text, "di 20. okt");
        compare(time.font.pixelSize, Tokens.fontSizeXs);
        compare(time.font.weight, Tokens.fontWeightSemibold);
        compare(time.font.features.tnum, 1);
        compare(day.font.pixelSize, Tokens.fontSizeXxs);
        compare(day.font.weight, Tokens.fontWeightRegular);
        compare(day.color, Tokens.color.textContrastHigh);
        compare(day.y, time.height, "the date right under the time");
        compare(time.x, day.x, "both from the same edge");
        const face = time.parent;
        compare(face.x, Geometry.appBarControlPadding);
        compare(findChild(clock, "box").height, Geometry.appBarControl);
        verify(face.y >= 0 && face.y + face.height <= Geometry.appBarControl, "two lines inside the control");
    }

    function test_the_clock_wakes_when_the_minute_changes_and_not_before() {
        const tick = findChild(clock, "tick");
        verify(tick.running);
        verify(tick.repeat);
        compare(tick.interval, 44750, "14:32:15.250 waits for 14:33");
        clock.now = new Date(2026, 9, 20, 14, 33, 0, 0);
        compare(tick.interval, 60000, "on the minute it waits a whole one");
        clock.now = new Date(2026, 9, 20, 14, 33, 59, 999);
        compare(tick.interval, 1);
        const before = Date.now();
        tick.triggered();
        verify(clock.now.getTime() >= before && clock.now.getTime() <= Date.now(), "it reads the time when it wakes");
        compare(tick.interval, Calendar.untilNextMinute(clock.now));
        verify(tick.running && tick.repeat, "and keeps waking, each time at the next minute");
    }

    function test_the_week_starts_on_monday_whatever_the_locale() {
        clock.openCalendar();
        clock.month.cursor = new Date(2026, 9, 22);
        compare(findChild(clock.month, "weekday 0").text, "mo");
        compare(findChild(clock.month, "weekday 6").text, "so");
        compare(cellOf(new Date(2026, 9, 1)).x, cell(3).x, "Thursday 1 October in the fourth column");
        compare(clock.month.width, 2 * clock.month.pad + Geometry.monthWeekColumn + 7 * Geometry.monthCell);
        clock.locale = Qt.locale("en_US");
        compare(findChild(clock.month, "weekday 0").text, "mon");
        compare(cellOf(new Date(2026, 9, 1)).x, cell(3).x, "a locale starting on Sunday does not move it");
        compare(findChild(clock.month, "title").text, "october 2026");
    }

    function test_the_month_shows_as_many_rows_as_it_touches_weeks() {
        clock.openCalendar();
        for (const [month, weeks] of [[new Date(2027, 1, 10), 4], [new Date(2026, 9, 10), 5], [new Date(2026, 7, 10), 6]]) {
            clock.month.cursor = month;
            compare(clock.month.weeks, weeks, month.toDateString());
            compare(clock.month.height, clock.month.daysTop + weeks * Geometry.monthCell + clock.month.pad);
            verify(findChild(clock.month, `week ${weeks - 1}`), "the last row has its week number");
            verify(!findChild(clock.month, `week ${weeks}`), "and no row follows");
        }
    }

    function test_week_numbers_stand_in_front_of_each_row_named_woche_n() {
        clock.openCalendar();
        clock.month.cursor = new Date(2026, 9, 10);
        const first = findChild(clock.month, "week 0");
        compare(first.text, "40", "Thursday 1 October 2026 is in week 40");
        compare(first.Accessible.name, "woche 40");
        verify(first.x + first.width <= cell(0).x, "in front of the days");
        compare(first.color, Tokens.color.textContrastHigh);
        compare(first.font.features.tnum, 1);
        compare(findChild(clock.month, "week 4").text, "44");
    }

    function test_days_of_the_neighbouring_months_are_not_shown() {
        clock.openCalendar();
        clock.month.cursor = new Date(2026, 9, 22);
        verify(!cell(0).visible, "Monday 28 September is left empty");
        verify(!cell(2).visible);
        verify(cell(3).visible, "1 October");
        verify(cell(33).visible, "31 October");
        verify(!cell(34).visible, "1 November");
        verify(!cell(41).visible);
    }

    function test_only_today_is_on_the_accent_without_a_frame() {
        clock.openCalendar();
        clock.month.cursor = Calendar.addDays(clock.now, 1);
        const today = cellOf(clock.now);
        const frame = findChild(today, "today");
        verify(frame.visible);
        compare(frame.color, Tokens.color.accent);
        compare(frame.border.width, 0);
        compare(findChild(today, "number").color, Tokens.color.textOnAccent);
        compare(frame.x, Geometry.monthTodayInset);
        compare(frame.width, Geometry.monthCell - 2 * Geometry.monthTodayInset);
        for (let i = 0; i < 42; i++) {
            if (cell(i) !== today)
                verify(!findChild(cell(i), "today").visible, `${cell(i).day}`);
        }
        compare(findChild(today, "number").font.features.tnum, 1);
    }

    function test_the_same_day_of_another_month_or_year_is_not_on_the_accent() {
        clock.openCalendar();
        for (const month of [new Date(2026, 10, 20), new Date(2026, 8, 20), new Date(2027, 9, 20)]) {
            clock.month.cursor = month;
            for (let i = 0; i < 42; i++)
                verify(!findChild(cell(i), "today").visible, `${month.toDateString()} cell ${i}`);
        }
    }

    function test_a_click_opens_the_month_above_the_clock_and_another_closes_it() {
        mouseClick(clock, 20, 20);
        const calendar = clock.calendar;
        verify(calendar.open);
        verify(!clock.activeFocus, "a click gives the clock no focus");
        verify(clock.month.activeFocus, "the month holds the keys");
        verify(!clock.month.showsFocus, "without a ring until a key moves");
        compare(calendar.side, "above");
        compare(calendar.y + calendar.height, -Geometry.floatGap, "space-xs above the clock");
        compare(Calendar.monthTitle(clock.month.cursor, clock.locale), "oktober 2026");
        mouseClick(clock, 20, 20);
        verify(!calendar.open);
    }

    function test_the_open_month_is_centred_over_the_clock_in_both_densities() {
        for (const density of ["compact", "comfortable"]) {
            Prefs.density = density;
            clock.openCalendar();
            const calendar = clock.calendar;
            const month = calendar.mapToItem(scene, calendar.width / 2, 0).x;
            const centre = clock.mapToItem(scene, clock.width / 2, 0).x;
            verify(Math.abs(month - centre) <= 0.5, `${density}: month at ${month}, clock at ${centre}`);
            clock.closeCalendar(false);
        }
    }

    function test_keys_move_by_day_week_month_and_year_and_home_and_end_go_to_the_months_edges() {
        clock.forceActiveFocus();
        keyClick(Qt.Key_Space);
        verify(clock.calendar.open);
        verify(clock.month.activeFocus);
        verify(clock.month.showsFocus, "opened from the keyboard, the ring shows");
        const at = () => clock.month.cursor;
        keyClick(Qt.Key_Right);
        verify(Calendar.sameDay(at(), new Date(2026, 9, 21)));
        keyClick(Qt.Key_Left);
        keyClick(Qt.Key_Left);
        verify(Calendar.sameDay(at(), new Date(2026, 9, 19)));
        keyClick(Qt.Key_Down);
        verify(Calendar.sameDay(at(), new Date(2026, 9, 26)));
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Up);
        verify(Calendar.sameDay(at(), new Date(2026, 9, 12)));
        keyClick(Qt.Key_PageDown);
        verify(Calendar.sameDay(at(), new Date(2026, 10, 12)));
        compare(findChild(clock.month, "title").text, "november 2026");
        keyClick(Qt.Key_PageUp);
        keyClick(Qt.Key_PageUp);
        verify(Calendar.sameDay(at(), new Date(2026, 8, 12)));
        keyClick(Qt.Key_PageDown, Qt.ShiftModifier);
        verify(Calendar.sameDay(at(), new Date(2027, 8, 12)), "with Shift a year");
        keyClick(Qt.Key_Home);
        verify(Calendar.sameDay(at(), new Date(2027, 8, 1)), "home is the month's first day");
        keyClick(Qt.Key_End);
        verify(Calendar.sameDay(at(), new Date(2027, 8, 30)), "end is its last");
        const focused = cellOf(at());
        verify(focused.children.some(child => child instanceof FocusRing && child.visible), "the keys' day shows the ring");
    }

    function test_iso_week_numbers_turn_with_the_year() {
        compare(Calendar.weekNumber(new Date(2026, 11, 28)), 53);
        compare(Calendar.weekNumber(new Date(2027, 0, 3)), 53, "Sunday still ends week 53");
        compare(Calendar.weekNumber(new Date(2027, 0, 4)), 1);
        compare(Calendar.weekNumber(new Date(2024, 11, 30)), 1, "Monday 30 December 2024 starts week 1 of 2025");
        compare(Calendar.weekNumber(new Date(2026, 0, 1)), 1);
        compare(Calendar.weekNumber(new Date(2021, 0, 1)), 53, "Friday 1 January 2021 is in week 53 of 2020");
    }

    function test_the_week_count_is_four_to_six() {
        compare(Calendar.weekCount(new Date(2027, 1, 15)), 4);
        compare(Calendar.weekCount(new Date(2026, 9, 15)), 5);
        compare(Calendar.weekCount(new Date(2026, 7, 15)), 6);
    }

    function test_a_short_month_keeps_the_day_within_it() {
        compare(Calendar.addMonths(new Date(2026, 0, 31), 1).getDate(), 28);
        compare(Calendar.addMonths(new Date(2028, 0, 31), 1).getDate(), 29);
    }

    function test_escape_closes_the_month_and_gives_the_focus_back_to_the_clock() {
        clock.forceActiveFocus();
        keyClick(Qt.Key_Return);
        verify(clock.calendar.open);
        keyClick(Qt.Key_Escape);
        verify(!clock.calendar.open);
        verify(clock.activeFocus);
    }

    function test_contact_sheet() {
        for (const theme of ["light", "dark"]) {
            Prefs.theme = theme;
            const sheet = createTemporaryObject(sheetComponent, testCase);
            const sheetClock = findChild(sheet, "clock");
            sheetClock.forceActiveFocus();
            keyClick(Qt.Key_Space);
            keyClick(Qt.Key_Right);
            waitForRendering(sheet);
            wait(Tokens.durationFloat + 50);
            grabImage(sheet).save(`clock-sheet-${theme}.png`);
            sheetClock.month.cursor = new Date(2026, 7, 21);
            sheetClock.month.today = new Date(2026, 7, 21);
            waitForRendering(sheet);
            grabImage(sheet).save(`clock-sheet-six-weeks-${theme}.png`);
        }
    }

    // The bar with the clock in its centre and the month open above it from the keyboard, one day on from today.
    Component {
        id: sheetComponent

        Rectangle {
            width: 1200
            height: 520
            color: Tokens.color.bg

            AppBar {
                id: sheetBar

                y: parent.height - height
                width: parent.width
                centre: sheetClock

                AppBarButton { icon: "window"; text: "back" }
                AppBarMiddle { parts: ["konsole", "~/projects: build the shell"] }

                AppBarClock {
                    id: sheetClock

                    objectName: "clock"
                    locale: Qt.locale("de_DE")
                    now: new Date(2026, 9, 21, 14, 32)
                    calendar.x: sheetBar.floatPlace(sheetClock, Qt.size(calendar.width, calendar.height), "centre").x - x
                    calendar.y: sheetBar.floatPlace(sheetClock, Qt.size(calendar.width, calendar.height), "centre").y - y
                    calendar.side: sheetBar.floatPlace(sheetClock, Qt.size(calendar.width, calendar.height), "centre").side
                }

                AppBarButton { icon: "bell"; text: "messages" }
            }
        }
    }
}
