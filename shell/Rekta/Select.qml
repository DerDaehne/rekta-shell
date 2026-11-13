pragma ComponentBehavior: Bound

import QtQuick

// One of many from a list you know, where Rekta draws the list (forms.md:76–93; rekta.css:425–437; rekta-core
// controls.c, "Select"): a field's box with the chosen option, cut where it is too long, and the combobox's chevron at
// its end. Enter, Space, Alt+↓ or a press open the combobox's list: a menu that floats under the field (above it when
// there is no room below), at least as wide as it, the chosen option marked by a tick without a box; nothing below it
// moves. In it the keys of every floating surface: ↑ ↓ wrap, Home End, a letter, Enter or Space chooses, Escape closes
// and the focus stays on the field, Tab closes and moves on; a press outside closes it. Closed, ↑ ↓ Home End and a
// letter change the choice without opening it, as a platform's select does. The chevron turns up while the list is
// open. Disabled, the box greys, stays focusable and says why below it.
Item {
    id: select

    // Each with its text and value.
    property var options: []
    property int currentIndex: -1
    readonly property var currentValue: options[currentIndex]?.value
    readonly property string currentText: options[currentIndex]?.text ?? ""
    // What it chooses, for the screen reader.
    property string label
    property string disabledReason
    readonly property bool disabled: disabledReason !== ""
    readonly property bool expanded: list.open
    // Where the focus was as the list opened, so a list closed by a pointer leaves it where it was.
    property Item focusBefore: null

    // A choice made here.
    signal activated(int index)

    // Opened from the keys the chosen option takes the focus; opened by a press the list holds the keys without a ring.
    function open() {
        if (disabled || options.length === 0 || list.open)
            return;
        focusBefore = Window.activeFocusItem;
        list.openAt(Math.max(0, currentIndex));
    }

    function close() {
        list.close(false);
    }

    function choose(index: int) {
        if (index < 0 || index >= options.length || index === currentIndex)
            return;
        currentIndex = index;
        activated(index);
    }

    function optionRows(): var {
        return Array.from(list.rows).filter(row => row.objectName === "option");
    }

    // Closed, the keys change the choice in place; ↑ ↓ stop at the ends (rekta-core select_event()). A held key opens
    // only once. Untyped, so a test can hand it a held key.
    function handleKey(event: var): bool {
        if (disabled || options.length === 0)
            return false;
        const opens = [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key) || (event.key === Qt.Key_Down && (event.modifiers & Qt.AltModifier));
        if (opens) {
            if (!event.isAutoRepeat)
                open();
            return true;
        }
        const last = options.length - 1;
        const moves = new Map([[Qt.Key_Down, Math.min(last, currentIndex + 1)], [Qt.Key_Up, Math.max(0, currentIndex - 1)], [Qt.Key_Home, 0], [Qt.Key_End, last]]);
        if (moves.has(event.key)) {
            choose(moves.get(event.key));
            return true;
        }
        return jump(event);
    }

    // A letter chooses the next option that starts with it, after the chosen one and around; a letter that starts none
    // is still used up, as rekta-core does.
    function jump(event: var): bool {
        const letter = event.text.toLowerCase();
        const modified = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
        if (letter.length !== 1 || !/\S/.test(letter) || modified)
            return false;
        for (let step = 1; step <= options.length; ++step) {
            const index = (Math.max(currentIndex, -1) + step) % options.length;
            if (options[index].text.toLowerCase().startsWith(letter)) {
                choose(index);
                break;
            }
        }
        return true;
    }

    // The focus is on the select or in its list.
    function holdsFocus(): bool {
        for (let item = Window.activeFocusItem; item; item = item.parent) {
            if (item === select || item === list)
                return true;
        }
        return false;
    }

    implicitHeight: disabled ? why.y + why.height : box.height
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: `${label} ${currentText}`.trim()
    Accessible.description: disabledReason

    ExpandedState {
        target: select
        expanded: list.open
    }

    onVisibleChanged: {
        if (!visible)
            close();
    }
    // Focus the keyboard gives shows the whole of a cut choice at once; focus a pointer gave does not (`:focus-visible`,
    // rekta.js:3081).
    onActiveFocusChanged: {
        if (activeFocus && !ring.hiddenByHost)
            choiceTip.show();
        else
            Tips.leave(choice);
    }
    Keys.onPressed: event => event.accepted = handleKey(event)

    Rectangle {
        id: box

        objectName: "box"
        width: select.width
        height: Tokens.controlHeight
        radius: Tokens.radiusS
        color: Tokens.color.bg
        border.width: Geometry.inputBorder
        // Hover only with a pointer that hovers (rekta.css:1335); dark while its list is open, as rekta-core draws it.
        border.color: {
            if (select.disabled)
                return Tokens.color.disabled;
            return select.activeFocus || list.open || pointer.hovered ? Tokens.color.textPrimary : Tokens.color.textContrastMedium;
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Tokens.durationShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeBase
            }
        }

        Text {
            id: choice

            objectName: "chosen"
            x: Geometry.inputPadding
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, box.width - Geometry.inputPadding - Geometry.selectPaddingEnd)
            text: select.currentText
            elide: Text.ElideRight
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.fontSizeS
            color: select.disabled ? Tokens.color.disabled : Tokens.color.textPrimary

            OverflowTip {
                id: choiceTip

                enabled: !list.open
            }
        }

        FieldChevron {
            objectName: "chevron"
            // Its point, the middle of its width, the given distance before the end of the padding box.
            x: box.width - box.border.width - Geometry.selectChevronEnd - width / 2
            anchors.verticalCenter: parent.verticalCenter
            open: list.open
            disabled: select.disabled
        }

        FocusRing {
            id: ring

            objectName: "ring"
            shown: select.activeFocus
        }

        // A press gives no focus, so the ring shows only for the keyboard, like :focus-visible.
        TapHandler {
            // A slow click is still a click.
            longPressThreshold: 0

            onTapped: {
                if (list.open)
                    select.close();
                else
                    select.open();
            }
        }

        HoverHandler {
            id: pointer

            cursorShape: select.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
        }
    }

    Hint {
        id: why

        objectName: "why"
        y: box.height + Tokens.spaceXs
        width: select.width
        visible: select.disabled
        text: select.disabledReason
    }

    FloatAnchor {
        field: box
        surface: list

        onPressedOutside: select.close()
    }

    // The focus leaving for anything else, or the window losing it, closes the list.
    Connections {
        target: list.open ? select.Window.window : null

        function onActiveFocusItemChanged() {
            if (!select.holdsFocus())
                select.close();
        }
    }

    // Above everything in its window, as wide as the field at least (forms.md:81–82).
    Menu {
        id: list

        objectName: "list"
        parent: select.Window.window?.contentItem ?? select
        control: select
        width: Math.max(implicitWidth, select.width)
        height: implicitHeight
        Accessible.role: Accessible.List
        Accessible.name: select.label

        onChosen: item => select.choose(select.optionRows().indexOf(item))
        onOpenChanged: {
            if (!open)
                select.focusBefore?.forceActiveFocus();
        }

        Repeater {
            model: select.options

            MenuItem {
                required property var modelData
                required property int index

                objectName: "option"
                kind: "option"
                text: modelData.text
                checked: index === select.currentIndex
            }
        }
    }
}
