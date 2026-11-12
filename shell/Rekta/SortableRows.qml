pragma ComponentBehavior: Bound

import QtQuick

// A list ordered by hand (collections.md, "Ordering by hand"; behaviour.md, `sortable()`; rekta.js:3388–3470). Each row
// is a SortableRow and moves only by its grip: dragged by a pointer it follows it up and down while the others make
// room, and on release everything settles (FLIP); from the keyboard Space or Enter picks it up, ↑ ↓ move it, Space or
// Enter puts it down, Escape puts it back, Alt+↑ ↓ moves it at once. Every step is announced.
// The list only says what moved: `moved(from, to)`; the owner moves its model, in place (ListModel.move), so a moved
// row keeps its grip's focus and glides from where it showed. A model that rebuilds its rows shows the new order at once.
Item {
    id: rows

    property alias model: repeater.model
    // A SortableRow.
    property alias delegate: repeater.delegate
    readonly property alias count: repeater.count
    // Where each row rests, by index.
    property var tops: []
    property SortableRow draggedRow: null
    property SortableRow grabbedRow: null
    // The last thing announced.
    property string spoken

    property var drag: null
    property int grabbedFrom: -1

    signal moved(int from, int to)

    Accessible.role: Accessible.List

    function rowAt(index: int): SortableRow {
        return repeater.itemAt(index) as SortableRow;
    }

    function all(): var {
        return Array.from({ length: count }, (_, index) => rowAt(index)).filter(row => row !== null);
    }

    function layout() {
        let top = 0;
        const next = [];
        for (let index = 0; index < count; index++) {
            next.push(top);
            top += rowAt(index)?.height ?? 0;
        }
        tops = next;
        implicitHeight = top;
    }

    function say(text: string) {
        spoken = text;
        Accessible.announce(text, Accessible.Polite);
    }

    // Moves `from` to `to` through the owner and lets every row glide from where it showed (rekta.js `flip`).
    function moveRow(from: int, to: int): bool {
        if (to === from || to < 0 || to >= count)
            return false;
        const shown = new Map(all().map(row => [row, row.y]));
        moved(from, to);
        layout();
        shown.forEach((y, row) => row.settleFrom(y));
        return true;
    }

    // The place a dragged row takes: the furthest row down whose middle its middle has passed, or the first one up
    // whose middle it has passed (rekta.js:3429–3433).
    function dropIndex(from: int, dy: real): int {
        const middle = index => drag.tops[index] + drag.heights[index] / 2;
        const at = middle(from) + dy;
        for (let index = count - 1; index > from; index--) {
            if (at > middle(index))
                return index;
        }
        for (let index = 0; index < from; index++) {
            if (at < middle(index))
                return index;
        }
        return from;
    }

    function makeRoom(from: int, to: int) {
        const room = drag.heights[from];
        for (const row of all()) {
            if (row === draggedRow)
                continue;
            const i = row.index;
            row.offset = from < to && i > from && i <= to ? -room : to < from && i >= to && i < from ? room : 0;
        }
    }

    function dragTo(row: SortableRow, dy: real) {
        if (grabbedRow)
            return;
        if (!drag) {
            drag = { from: row.index, to: row.index, tops: tops.slice(), heights: all().map(other => other.height) };
            draggedRow = row;
        }
        row.offset = dy;
        drag.to = dropIndex(drag.from, dy);
        makeRoom(drag.from, drag.to);
    }

    // A cancel (the pointer taken away) puts the row back.
    function drop(canceled: bool) {
        if (!drag)
            return;
        const { from, to } = drag;
        const row = draggedRow;
        const shown = new Map(all().map(other => [other, other.y]));
        drag = null;
        draggedRow = null;
        for (const other of all())
            other.offset = 0;
        const moves = !canceled && to !== from;
        if (moves)
            moved(from, to);
        layout();
        shown.forEach((y, other) => other.settleFrom(y));
        if (moves)
            say(`${row.name}: platz ${to + 1} von ${count}.`);
    }

    function pickUp(row: SortableRow) {
        grabbedRow = row;
        grabbedFrom = row.index;
        say(`${row.name} aufgenommen, platz ${row.index + 1} von ${count}. ↑ ↓ zum bewegen, leertaste zum ablegen, escape zum zurücklegen.`);
    }

    function putDownInPlace() {
        grabbedRow = null;
    }

    function putDown(row: SortableRow) {
        grabbedRow = null;
        say(`${row.name} abgelegt auf platz ${row.index + 1} von ${count}.`);
    }

    function putBack(row: SortableRow) {
        moveRow(row.index, grabbedFrom);
        grabbedRow = null;
        say(`${row.name} zurückgelegt.`);
    }

    // While picked up a move says only the place, the name was said on picking up (rekta.js `position('', …)`).
    function step(row: SortableRow, by: int, named: bool) {
        if (moveRow(row.index, row.index + by))
            say(named ? `${row.name}: platz ${row.index + 1} von ${count}.` : `platz ${row.index + 1} von ${count}`);
    }

    function key(row: SortableRow, event: KeyEvent) {
        const by = { [Qt.Key_Up]: -1, [Qt.Key_Down]: 1 }[event.key] ?? 0;
        const toggles = [Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].includes(event.key);
        if (drag)
            return;
        if (grabbedRow === row) {
            event.accepted = by !== 0 || toggles || event.key === Qt.Key_Escape;
            if (by !== 0)
                step(row, by, false);
            else if (toggles && !event.isAutoRepeat)
                putDown(row);
            else if (event.key === Qt.Key_Escape)
                putBack(row);
            return;
        }
        if (by !== 0 && event.modifiers & Qt.AltModifier) {
            event.accepted = true;
            step(row, by, true);
        } else if (toggles && !event.isAutoRepeat) {
            event.accepted = true;
            pickUp(row);
        }
    }

    Repeater {
        id: repeater

        onItemAdded: rows.layout()
        onItemRemoved: rows.layout()
    }
}
