pragma ComponentBehavior: Bound

import QtQuick
import Notices
import Rekta

// The facet "meldungen", the notification centre: the board's list, newest first, a row each (live.md, "A growing
// list"). In sight, it has seen them all. A press on a row does what a press on its toast does, and the panel goes.
// A row pulled away past half its width, or Delete on it, is removed, and the focus goes to the next row; "alle
// entfernen", a quiet button at the end, removes them all. The board offers undo for each removal. Rows that leave
// drift and fade, then the rest close the gap; rows that arrive or come back slide in from above while the rest make
// room (motion.md, "Arriving, leaving", "Reordering"). Home and End go to the first and the last row.
// ponytail: a row arriving on top pushes the rows down also while the panel is scrolled away from the top; hold the
// rows read in place (or hold new ones back behind a count) once lists that long show up.
Column {
    id: messages

    required property NoticeBoard board
    property var locale: Qt.locale()
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
            time: Calendar.timeWords(row.time, locale)
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
        if (row.activeFocus) {
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

    function focusBefore() {
        messages.nextItemInFocusChain(false)?.forceActiveFocus(Qt.BacktabFocusReason);
    }

    width: parent ? parent.width : 0
    topPadding: Tokens.spaceL
    bottomPadding: Tokens.spaceL
    spacing: Tokens.spaceM

    onVisibleChanged: {
        if (visible)
            board.seen();
    }
    Component.onCompleted: sync()

    Keys.onPressed: event => {
        const rows = rowsInPlace();
        if (rows.length === 0 || (event.key !== Qt.Key_Home && event.key !== Qt.Key_End))
            return;
        (event.key === Qt.Key_Home ? rows[0] : rows[rows.length - 1]).forceActiveFocus(Qt.TabFocusReason);
        event.accepted = true;
    }

    Connections {
        target: messages.board

        function onRowsChanged() {
            messages.sync();
        }
    }

    ListModel {
        id: shown
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

    Column {
        width: messages.width
        visible: messages.hasRows
        x: messages.allLeaving * Geometry.rowLeaveDrift
        opacity: 1 - messages.allLeaving

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

                    onPressed: {
                        messages.board.press(messages.recordOf(order));
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

    Button {
        objectName: "clear"
        variant: "quiet"
        text: "alle entfernen"
        visible: messages.hasRows
        onClicked: messages.removeAll()
    }
}
