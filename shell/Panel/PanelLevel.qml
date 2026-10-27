pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// A deeper level of a group: a list to choose one from, which stands in the group's place while it is open (the
// group slides it in). It starts with a back row, "zurück · name"; its options are rows of a menu, the current one
// with a filled square (states.md, "Floating surfaces"). Choosing one, the back row, Escape and ← go back, and the
// focus goes back to the control that opened it. MenuItems declared in it follow the options as rows of their own:
// pressing one says so in `activated` and the level stays open.
Column {
    id: level

    property string name
    property list<string> options
    property int currentIndex: -1
    property bool open: false
    // What opened it; the focus goes back there.
    property Item opener

    signal chosen(int index)
    signal activated(MenuItem row)

    function show(from: Item) {
        opener = from;
        open = true;
        (choices()[currentIndex] ?? rows()[0] ?? back).forceActiveFocus(Qt.TabFocusReason);
    }

    function leave() {
        if (!open)
            return;
        const held = [back, ...rows()].some(row => row.activeFocus);
        open = false;
        if (held)
            opener?.forceActiveFocus(Qt.TabFocusReason);
    }

    function choose(row: Item) {
        if (!(row instanceof MenuItem) || (row as MenuItem).disabled)
            return;
        if (row === back) {
            leave();
            return;
        }
        const index = choices().indexOf(row);
        if (index < 0) {
            activated(row as MenuItem);
            return;
        }
        leave();
        chosen(index);
    }

    // The rows below the back row, the options first.
    function rows(): list<MenuItem> {
        return Array.from(children).filter(row => row instanceof MenuItem && row !== back);
    }

    function choices(): list<MenuItem> {
        return Array.from({ length: optionRows.count }, (_, index) => optionRows.itemAt(index));
    }

    width: parent ? parent.width : 0
    visible: open
    // Gone with the panel or its facet, it is closed when it comes back.
    onVisibleChanged: {
        if (!visible)
            open = false;
    }
    Accessible.role: Accessible.List
    Accessible.name: name

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Escape:
        case Qt.Key_Left:
            leave();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            // A held key chooses once.
            if (!event.isAutoRepeat)
                choose(Window.activeFocusItem);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    MenuItem {
        id: back

        objectName: "back"
        glyph: "back"
        text: `zurück · ${level.name}`
        activeFocusOnTab: true
    }

    Repeater {
        id: optionRows

        model: level.options

        MenuItem {
            required property string modelData
            required property int index

            kind: "radio"
            text: modelData
            checked: index === level.currentIndex
            activeFocusOnTab: true
        }
    }

    TapHandler {
        // A slow click is still a click.
        longPressThreshold: 0

        onTapped: eventPoint => level.choose(level.childAt(eventPoint.position.x, eventPoint.position.y))
    }
}
