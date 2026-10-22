pragma ComponentBehavior: Bound

import QtQuick

// The clock of the app bar: the time over the date in one control ("14:32" over "di 21. okt"), tabular figures, in
// the locale's words. It wakes once a minute, when the minute changes. A click opens the month on a floating surface;
// the host places it, as it places "more" (AppBar.floatPlace).
// ponytail: a change of the system clock or time zone shows at the next minute at the latest; listen to timedated
// once the shell has its DBus module.
AppBarButton {
    id: clock

    property date now: new Date()
    property var locale: Qt.locale()
    // The window the month has to fit in.
    property size area: Qt.size(Window.width, Window.height)
    readonly property string time: Calendar.timeWords(now, locale)
    readonly property string day: Calendar.dateWords(now, locale)
    readonly property alias calendar: surface
    readonly property alias month: monthView

    function openCalendar() {
        monthView.cursor = now;
        monthView.showsFocus = clock.activeFocus;
        surface.open = true;
        monthView.forceActiveFocus();
    }

    function closeCalendar(refocus: bool) {
        if (!surface.open)
            return;
        surface.open = false;
        if (refocus)
            clock.forceActiveFocus();
    }

    text: `${time} ${day}`
    // Two lines from the padding on, the time over the date, set by hand: a Column would size itself only at polish.
    face: Item {
        x: Geometry.appBarControlPadding
        y: (Geometry.appBarControl - implicitHeight) / 2
        implicitWidth: Math.max(timeLine.implicitWidth, dateLine.implicitWidth)
        implicitHeight: timeLine.height + dateLine.height

        TextRole {
            id: timeLine

            objectName: "time"
            lineHeightFactor: Tokens.lineHeightCompact
            text: clock.time
            font.pixelSize: Tokens.fontSizeXs
            font.weight: Tokens.fontWeightSemibold
            font.features: ({ "tnum": 1 })
            color: clock.ink
        }

        Meta {
            id: dateLine

            objectName: "date"
            y: timeLine.height
            lineHeightFactor: Tokens.lineHeightCompact
            wrapMode: Text.NoWrap
            text: clock.day
        }
    }

    onClicked: {
        if (surface.open)
            closeCalendar(false);
        else
            openCalendar();
    }

    Timer {
        id: tick

        objectName: "tick"
        interval: Calendar.untilNextMinute(clock.now)
        running: true
        // A new interval restarts it, so each wake aims at the next minute again.
        repeat: true

        onTriggered: clock.now = new Date()
    }

    FloatSurface {
        id: surface

        objectName: "calendar"
        area: clock.area

        Month {
            id: monthView

            today: clock.now
            locale: clock.locale

            onEscaped: clock.closeCalendar(true)
        }
    }
}
