pragma ComponentBehavior: Bound

import QtQuick
import Notices
import Rekta

// The facet "meldungen", the notification centre: the board's list, newest first, a row each (live.md, "A growing
// list"). In sight, it has seen them all. A press on a row does what a press on its toast does, and the panel goes.
// A row pulled away past half its width, Delete on it, or its "entfernen" button is removed, and the focus goes to the
// next row; "alle entfernen", a quiet button in the head above the rows beside their count, removes them all. The board
// offers undo for each removal. Rows that leave drift and fade, then the rest close the gap; rows that arrive or come
// back slide in from above while the rest make room (motion.md, "Arriving, leaving", "Reordering"). Home and End go to
// the first and the last row. The times in the rows are told against `now`, which is renewed once a minute, and only while the list is in sight.
// ponytail: a row arriving on top pushes the rows down also while the panel is scrolled away from the top; hold the
// rows read in place (or hold new ones back behind a count) once lists that long show up.
Column {
    id: messages

    required property NoticeBoard board
    property var locale: Qt.locale()
    // The wall clock, replaceable for tests.
    property var clock: () => new Date()
    property var now: clock()
    readonly property bool hasRows: shown.count > 0
    // Runs from 0 to 1 as all rows leave at once.
    property real allLeaving: 0

    // A row was pressed: its notification acted, or its app came forward.
    signal acted

    // The model follows the board's rows by their order of arrival, so rows that stay keep their item and its focus.
    // Both lists run newest first, and rows only come and go: drop the ones gone, then insert the ones new in place.
    function sync() {
        const orders = board.rows.map(row => row.order);
        for (let k = shown.count - 1; k >= 0; k--) {
            if (!orders.includes(shown.get(k).order))
                shown.remove(k);
        }
        board.rows.forEach((row, k) => {
            if (k < shown.count && shown.get(k).order === row.order)
                shown.set(k, fields(row));
            else
                shown.insert(k, fields(row));
        });
    }

    function fields(row: var): var {
        return {
            order: row.order,
            app: row.appName || row.desktopEntry,
            summary: row.summary,
            body: row.body,
            icon: row.icon.toString(),
            stamp: row.time.getTime(),
            actions: JSON.stringify(board.actionsOf(row))
        };
    }

    function recordOf(order: int): var {
        return board.rows.find(row => row.order === order) ?? null;
    }

    function rowAt(index: int): MessageRow {
        return rowItems.itemAt(index) as MessageRow;
    }

    function rowsInPlace(): list<MessageRow> {
        return Array.from({ length: rowItems.count }, (_, k) => rowAt(k)).filter(row => row && !row.going);
    }

    // The next row takes the focus, else the one before, else what comes before the list.
    function remove(row: MessageRow) {
        if (row.holdsFocus) {
            const others = rowsInPlace();
            const at = others.indexOf(row);
            const next = others[at + 1] ?? others[at - 1];
            if (next)
                next.forceActiveFocus(Qt.TabFocusReason);
            else
                focusBefore();
        }
        row.leave();
    }

    function removeAll() {
        if (allGoing.running)
            return;
        focusBefore();
        allGoing.start();
    }

    // Home and End go to the ends; Up and Down go to the row before or after the one holding the focus, also from its
    // buttons. Down from the last row goes on to "alle entfernen", Up from the first is left to the panel.
    function focusTargetFor(key: int, rows: list<MessageRow>): Item {
        if (key === Qt.Key_Home)
            return rows[0] ?? null;
        if (key === Qt.Key_End)
            return rows[rows.length - 1] ?? null;
        const step = key === Qt.Key_Up ? -1 : key === Qt.Key_Down ? 1 : 0;
        const at = rows.findIndex(row => row.holdsFocus);
        if (step === 0 || at < 0)
            return null;
        return rows[at + step] ?? (step > 0 ? clearAll : null);
    }

    function renewNow() {
        now = clock();
    }

    function focusBefore() {
        messages.nextItemInFocusChain(false)?.forceActiveFocus(Qt.BacktabFocusReason);
    }

    width: parent ? parent.width : 0
    topPadding: Tokens.spaceL
    bottomPadding: Tokens.spaceL
    spacing: Tokens.spaceM

    Component.onCompleted: sync()

    Keys.onPressed: event => {
        const target = focusTargetFor(event.key, rowsInPlace());
        if (!target)
            return;
        target.forceActiveFocus(Qt.TabFocusReason);
        event.accepted = true;
    }

    Connections {
        target: messages.board

        function onRowsChanged() {
            messages.sync();
        }
    }

    Binding {
        target: messages.board
        property: "listInSight"
        value: messages.visible
    }

    ListModel {
        id: shown
    }

    // Once a minute while in sight; coming into sight it catches up at once.
    Timer {
        objectName: "tick"
        interval: Calendar.untilNextMinute(messages.now)
        running: messages.visible
        repeat: true
        onTriggered: messages.renewNow()
        onRunningChanged: {
            if (running)
                messages.renewNow();
        }
    }

    // All rows leave together, as one row would (motion.md, "Arriving, leaving").
    NumberAnimation {
        id: allGoing

        target: messages
        property: "allLeaving"
        to: 1
        duration: Geometry.rowLeaveShare * Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeOut
        onFinished: {
            messages.board.remove(messages.board.rows);
            messages.allLeaving = 0;
        }
    }

    // What is empty, in a sentence on the first hairline (states.md, "Data states"; rekta.css:675).
    Item {
        objectName: "empty"
        width: messages.width
        implicitHeight: Geometry.hairline + 2 * Tokens.spaceM + emptyWords.height
        visible: !messages.hasRows

        Hairline {
            width: parent.width
        }

        Body {
            id: emptyWords

            y: Geometry.hairline + Tokens.spaceM
            width: parent.width
            text: "keine meldungen"
            color: Tokens.color.textContrastHigh
        }
    }

    Item {
        id: filled

        width: messages.width
        height: head.height + Tokens.spaceM + stack.height
        visible: messages.hasRows
        x: messages.allLeaving * Geometry.rowLeaveDrift
        opacity: 1 - messages.allLeaving

        Column {
            id: stack

            y: head.height + Tokens.spaceM
            width: parent.width

            Column {
                id: list

                objectName: "rows"
                width: parent.width

                // A row that comes slides in from above and fades up.
                add: Transition {
                    NumberAnimation {
                        property: "y"
                        from: ViewTransition.destination.y - Geometry.rowEnterShift
                        duration: Tokens.durationShort
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Tokens.easeIn
                    }
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Tokens.durationShort
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Tokens.easeIn
                    }
                }

                // The rest close the gap or make room; an arrival cut short still ends whole.
                move: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: Tokens.durationModerate
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Tokens.easeBase
                    }
                    NumberAnimation {
                        property: "opacity"
                        to: 1
                        duration: Tokens.durationModerate
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Tokens.easeBase
                    }
                }

                Repeater {
                    id: rowItems

                    model: shown

                    delegate: MessageRow {
                        id: row

                        now: messages.now
                        locale: messages.locale

                        onPressed: {
                            messages.board.press(messages.recordOf(order));
                            messages.acted();
                        }
                        onActionPressed: identifier => {
                            messages.board.invokeAction(messages.recordOf(order), identifier);
                            messages.acted();
                        }
                        onRemoving: messages.remove(row)
                        // Unless its notification closed meanwhile.
                        onGone: {
                            const record = messages.recordOf(order);
                            if (record)
                                messages.board.remove([record]);
                        }
                    }
                }
            }

            Hairline {
                width: parent.width
            }
        }

        // Declared after the rows, so the first focus stays on the newest row and not on "alle entfernen".
        Item {
            id: head

            objectName: "head"
            width: parent.width
            height: Tokens.controlHeight

            Body {
                objectName: "count"
                anchors.verticalCenter: parent.verticalCenter
                text: messages.board.rows.length === 1 ? "1 meldung" : `${messages.board.rows.length} meldungen`
                color: Tokens.color.textContrastHigh
            }

            Button {
                id: clearAll

                objectName: "clear"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                variant: "quiet"
                text: "alle entfernen"
                onClicked: messages.removeAll()
            }
        }
    }
}
