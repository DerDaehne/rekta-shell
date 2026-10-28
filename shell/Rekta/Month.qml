pragma ComponentBehavior: Bound

import QtQuick

// A month to look at, after rekta-core's (core/src/controls.c:887–990): the month and year over the weekdays, the
// weeks the month touches below with their ISO week numbers in front, only the month's own days, today on the accent;
// the week starts on Monday. ← → go by day, ↑ ↓ by week, Page Up and Page Down by month (with Shift by year),
// Home and End to the month's first and last day; Escape asks the host to close it.
// A click on the arrows by the title turns the month.
Item {
    id: month

    property date today: new Date()
    // The day the keys are on; its month is the one shown.
    property date cursor: today
    property var locale: Qt.locale()
    // The ring shows on the keys' day once a key has moved it, as on a menu opened by a click.
    property bool showsFocus: false
    property string previousWord: "previous month"
    property string nextWord: "next month"
    property string weekWord: "woche"
    readonly property real pad: Tokens.spaceS
    readonly property date start: Calendar.gridStart(cursor)
    readonly property int weeks: Calendar.weekCount(cursor)
    readonly property real daysLeft: pad + Geometry.monthWeekColumn
    readonly property real daysTop: pad + Tokens.controlHeight + Math.ceil(Tokens.lineHeightCompact * Tokens.fontSizeXs) + Tokens.spaceXs

    signal escaped

    function dayAt(index: int): date {
        return Calendar.addDays(start, index);
    }

    function move(to: date) {
        cursor = to;
        showsFocus = true;
    }

    // Takes a KeyEvent, or anything with its key and modifiers.
    function handleKey(event): bool {
        const yearly = event.modifiers & Qt.ShiftModifier ? 12 : 1;
        switch (event.key) {
        case Qt.Key_Left:
            move(Calendar.addDays(cursor, -1));
            return true;
        case Qt.Key_Right:
            move(Calendar.addDays(cursor, 1));
            return true;
        case Qt.Key_Up:
            move(Calendar.addDays(cursor, -7));
            return true;
        case Qt.Key_Down:
            move(Calendar.addDays(cursor, 7));
            return true;
        case Qt.Key_PageUp:
            move(Calendar.addMonths(cursor, -yearly));
            return true;
        case Qt.Key_PageDown:
            move(Calendar.addMonths(cursor, yearly));
            return true;
        case Qt.Key_Home:
            move(Calendar.monthStart(cursor));
            return true;
        case Qt.Key_End:
            move(Calendar.monthEnd(cursor));
            return true;
        case Qt.Key_Escape:
            escaped();
            return true;
        }
        return false;
    }

    implicitWidth: daysLeft + 7 * Geometry.monthCell + pad
    implicitHeight: daysTop + weeks * Geometry.monthCell + pad
    activeFocusOnTab: true
    Accessible.role: Accessible.Dialog
    Accessible.name: Calendar.monthTitle(cursor, locale)
    Keys.onPressed: event => {
        event.accepted = month.handleKey(event);
    }

    IconButton {
        objectName: "previous"
        x: month.pad
        y: month.pad
        variant: "quiet"
        icon: "chevron-left"
        label: month.previousWord
        activeFocusOnTab: false

        onClicked: month.cursor = Calendar.addMonths(month.cursor, -1)
    }

    TextRole {
        objectName: "title"
        anchors.horizontalCenter: parent.horizontalCenter
        y: month.pad + (Tokens.controlHeight - height) / 2
        lineHeightFactor: Tokens.lineHeightCompact
        text: Calendar.monthTitle(month.cursor, month.locale)
        font.pixelSize: Tokens.fontSizeS
        font.weight: Tokens.fontWeightSemibold
        color: Tokens.color.textPrimary
    }

    IconButton {
        objectName: "next"
        x: month.width - month.pad - width
        y: month.pad
        variant: "quiet"
        icon: "chevron-right"
        label: month.nextWord
        activeFocusOnTab: false

        onClicked: month.cursor = Calendar.addMonths(month.cursor, 1)
    }

    Repeater {
        model: 7

        delegate: TextRole {
            required property int index

            objectName: `weekday ${index}`
            x: month.daysLeft + index * Geometry.monthCell
            y: month.pad + Tokens.controlHeight
            width: Geometry.monthCell
            horizontalAlignment: Text.AlignHCenter
            lineHeightFactor: Tokens.lineHeightCompact
            text: Calendar.word(month.locale.dayName((index + 1) % 7, Locale.ShortFormat))
            font.pixelSize: Tokens.fontSizeXs
            font.weight: Tokens.fontWeightSemibold
            color: Tokens.color.textContrastHigh
        }
    }

    Repeater {
        model: month.weeks

        delegate: TextRole {
            required property int index
            readonly property int number: Calendar.weekNumber(month.dayAt(index * 7))

            objectName: `week ${index}`
            x: month.pad
            y: month.daysTop + index * Geometry.monthCell
            width: Geometry.monthWeekColumn
            height: Geometry.monthCell
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: number
            font.pixelSize: Tokens.fontSizeXs
            font.features: ({ "tnum": 1 })
            color: Tokens.color.textContrastHigh
            Accessible.role: Accessible.StaticText
            Accessible.name: `${month.weekWord} ${number}`
        }
    }

    Repeater {
        model: 42

        delegate: Item {
            required property int index
            readonly property date day: month.dayAt(index)
            readonly property bool isToday: Calendar.sameDay(day, month.today)

            objectName: `day ${index}`
            x: month.daysLeft + index % 7 * Geometry.monthCell
            y: month.daysTop + Math.floor(index / 7) * Geometry.monthCell
            width: Geometry.monthCell
            height: Geometry.monthCell
            visible: day.getMonth() === month.cursor.getMonth()
            Accessible.role: Accessible.StaticText
            Accessible.name: day.toLocaleDateString(month.locale, Locale.LongFormat)

            Rectangle {
                objectName: "today"
                anchors.fill: parent
                anchors.margins: Geometry.monthTodayInset
                visible: parent.isToday
                color: Tokens.color.accent
                border.width: 0
            }

            Text {
                objectName: "number"
                anchors.centerIn: parent
                text: parent.day.getDate()
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.fontSizeS
                font.features: ({ "tnum": 1 })
                color: parent.isToday ? Tokens.color.textOnAccent : Tokens.color.textPrimary
            }

            // On the cell's edge, as rekta-core rings the keys' day (`rk__focus_ring(c, cell, 0)`, :933).
            FocusRing {
                offset: 0
                shown: month.activeFocus && month.showsFocus && Calendar.sameDay(parent.day, month.cursor)
            }
        }
    }
}
