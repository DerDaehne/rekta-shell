import QtQuick

// A menu on a floating surface (states.md, "Floating surfaces"; behaviour.md, `menu()`; rekta.js menu(), :1671–1741):
// MenuItem rows, MenuSeparator and MenuLabel between groups. Keys: ↑ ↓ wrap, Home End, a letter jumps to the next item
// starting with it, Enter or Space chooses, Escape closes and gives the focus back to the control, Tab closes and moves
// on. A checkbox item toggles and leaves the menu open; any other choice closes it; `chosen` follows either way. A
// click outside closes it too: the host sees that click and calls close(false).
FloatSurface {
    id: menu

    // What opened it; the focus goes back there.
    property Item control

    signal chosen(MenuItem item)

    // Opened from a focused control (the keyboard, as a click gives no focus) a row takes the focus and shows it. Opened
    // by a click, the menu holds the keys without a ring until one moves to a row.
    function openAt(index: int) {
        const fromKeys = control ? control.activeFocus : true;
        open = true;
        if (fromKeys)
            focusAt(index);
        else
            menu.forceActiveFocus();
    }

    function close(refocus: bool) {
        if (!open)
            return;
        open = false;
        if (refocus && control)
            control.forceActiveFocus();
    }

    function choose(item: MenuItem) {
        if (item.disabled)
            return;
        if (item.kind === "checkbox") {
            item.checked = !item.checked;
            chosen(item);
            return;
        }
        if (item.kind === "radio")
            pick(item);
        // A pointer choice leaves the focus alone: the control never had it, and focus brings the ring.
        close(focusedIndex() >= 0);
        chosen(item);
    }

    function pick(radio: MenuItem) {
        for (const item of items()) {
            if (item.kind === "radio")
                item.checked = item === radio;
        }
    }

    function items(): list<MenuItem> {
        return Array.from(rows).filter(row => row instanceof MenuItem && row.visible);
    }

    function focusedIndex(): int {
        return items().findIndex(item => item.activeFocus);
    }

    // Wraps around both ends: -1 is the last.
    function focusAt(index: int) {
        const list = items();
        if (list.length === 0)
            return;
        const item = list[(index % list.length + list.length) % list.length];
        item.forceActiveFocus();
        reveal(item);
    }

    // Takes a KeyEvent, or anything with its key, text, modifiers and isAutoRepeat.
    function handleKey(event): bool {
        const index = focusedIndex();
        switch (event.key) {
        case Qt.Key_Down:
            focusAt(index + 1);
            return true;
        case Qt.Key_Up:
            focusAt(index < 0 ? -1 : index - 1);
            return true;
        case Qt.Key_Home:
            focusAt(0);
            return true;
        case Qt.Key_End:
            focusAt(-1);
            return true;
        case Qt.Key_Escape:
            close(true);
            return true;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            moveOn(event.key === Qt.Key_Tab);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            // A held key chooses once.
            if (index >= 0 && !event.isAutoRepeat)
                choose(items()[index]);
            return true;
        }
        return jump(event, index);
    }

    // A letter jumps to the next item that starts with it, after the focused one and around.
    function jump(event, from: int): bool {
        const letter = event.text.toLowerCase();
        const modified = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
        if (letter.length !== 1 || !/\S/.test(letter) || modified)
            return false;
        const list = items();
        const hit = [...list.slice(from + 1), ...list.slice(0, from + 1)].find(item => item.text.toLowerCase().startsWith(letter));
        if (!hit)
            return false;
        hit.forceActiveFocus();
        reveal(hit);
        return true;
    }

    // The menu follows its control in the focus order, as a popover does its invoker: Tab goes on to what comes after
    // the control, Shift+Tab back to the control.
    function moveOn(forward: bool) {
        close(false);
        const next = control && forward ? control.nextItemInFocusChain(true) : control;
        if (next)
            next.forceActiveFocus(Qt.TabFocusReason);
    }

    Accessible.role: Accessible.PopupMenu
    Keys.onPressed: event => {
        event.accepted = menu.handleKey(event);
    }

    // Declared here it lands in the rows' column (the default property), so a tap finds its row.
    TapHandler {
        // A slow click is still a click.
        longPressThreshold: 0

        onTapped: eventPoint => {
            const row = parent.childAt(eventPoint.position.x, eventPoint.position.y);
            if (row instanceof MenuItem)
                menu.choose(row);
        }
    }
}
