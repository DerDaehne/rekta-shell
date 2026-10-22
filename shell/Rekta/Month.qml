pragma ComponentBehavior: Bound

import QtQuick

// A month to look at, after rekta-core's (core/src/controls.c:887–990): the month and year over the weekdays, six
// weeks of days below, today in a frame; the week starts on the locale's first day, and each week leads with its ISO
// number. ← → go by day, ↑ ↓ by week, Page Up and Page Down by month (with Shift by year), Home back to today; Escape
// asks the host to close it. A click on the arrows by the title turns the month.
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
    readonly property real pad: Tokens.spaceS
    readonly property date start: Calendar.gridStart(cursor, locale.firstDayOfWeek)
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
            move(today);
            return true;
        case Qt.Key_Escape:
            escaped();
            return true;
        }
        return false;
    }

    implicitWidth: 2 * pad + 8 * Geometry.monthCell
    implicitHeight: daysTop + 6 * Geometry.monthCell + pad
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
            x: month.pad + (index + 1) * Geometry.monthCell
            y: month.pad + Tokens.controlHeight
            width: Geometry.monthCell
            horizontalAlignment: Text.AlignHCenter
            lineHeightFactor: Tokens.lineHeightCompact
            text: Calendar.word(month.locale.dayName((month.locale.firstDayOfWeek + index) % 7, Locale.ShortFormat))
            font.pixelSize: Tokens.fontSizeXs
            font.weight: Tokens.fontWeightSemibold
            color: Tokens.color.textContrastHigh
        }
    }

    Repeater {
        model: 6

        delegate: Meta {
            required property int index
            readonly property date first: month.dayAt(index * 7)
            readonly property bool inMonth: first.getMonth() === month.cursor.getMonth() || month.dayAt(index * 7 + 6).getMonth() === month.cursor.getMonth()

            objectName: `week ${index}`
            x: month.pad
            y: month.daysTop + index * Geometry.monthCell + (Geometry.monthCell - height) / 2
            width: Geometry.monthCell
            visible: inMonth
            horizontalAlignment: Text.AlignHCenter
            lineHeightFactor: Tokens.lineHeightCompact
            wrapMode: Text.NoWrap
            text: Calendar.rowWeek(first)
        }
    }

    Repeater {
        model: 42

        delegate: Item {
            required property int index
            readonly property date day: month.dayAt(index)
            readonly property bool isToday: Calendar.sameDay(day, month.today)

            objectName: `day ${index}`
            x: month.pad + (index % 7 + 1) * Geometry.monthCell
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
                color: "transparent"
                border.width: Geometry.monthTodayFrame
                border.color: Tokens.color.textPrimary
            }

            Text {
                objectName: "number"
                anchors.centerIn: parent
                text: parent.day.getDate()
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.fontSizeS
                font.features: ({ "tnum": 1 })
                color: Tokens.color.textPrimary
            }

            // On the cell's edge, as rekta-core rings the keys' day (`rk__focus_ring(c, cell, 0)`, :933).
            FocusRing {
                offset: 0
                shown: month.activeFocus && month.showsFocus && Calendar.sameDay(parent.day, month.cursor)
            }
        }
    }
}
