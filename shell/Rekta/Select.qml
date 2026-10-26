pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// One of many from a list you know (forms.md, "Inputs"; rekta.css:265–273, :295–301): a field's box with the chosen
// option, cut where it is too long, and a caret pointing down at its end. ↓, Alt+↓, Enter, Space or a press open its
// list (forms.md, "Combobox"; rekta-core controls.c:18), a menu below the box and at least as wide, above it where
// there is no room below; the chosen option carries a check, as in a combobox's list (rekta.css:314–325). There ↑ ↓
// move, Enter chooses, Escape closes and Tab moves on (Menu). The list floats in an overlay, the window's unless the
// host names another; a press or the wheel elsewhere, the window losing the keyboard or the box going out of sight
// close it. Disabled, the box greys, stays focusable and says why below it.
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
    // Where the list floats, over everything else in it.
    property Item overlay: Window.contentItem
    readonly property alias list: menu

    // A choice made here.
    signal activated(int index)

    function open(): bool {
        if (disabled || options.length === 0 || !overlay)
            return false;
        menu.anchorRect = box.mapToItem(overlay, 0, 0, box.width, box.height);
        menu.openAt(Math.max(0, currentIndex));
        return true;
    }

    // A press on the box: the focus goes back to it only from a row the keys were on.
    function toggle() {
        if (menu.open)
            menu.close(menu.focusedIndex() >= 0);
        else
            open();
    }

    function choose(index: int) {
        if (index < 0 || index >= options.length || index === currentIndex)
            return;
        currentIndex = index;
        activated(index);
    }

    implicitWidth: menu.implicitWidth
    implicitHeight: disabled ? why.y + why.height : box.height
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: `${label} ${currentText}`.trim()
    Accessible.description: disabledReason

    onVisibleChanged: {
        if (!visible)
            menu.close(false);
    }
    Keys.onPressed: event => {
        const opens = [Qt.Key_Down, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key);
        event.accepted = opens && select.open();
    }

    Connections {
        target: select.Window.window

        function onActiveChanged() {
            if (!select.Window.active)
                menu.close(false);
        }
    }

    Rectangle {
        id: box

        objectName: "box"
        width: select.width
        height: Tokens.controlHeight
        radius: Tokens.radiusS
        color: Tokens.color.bg
        border.width: Geometry.inputBorder
        // Hover only with a pointer that hovers (rekta.css:1024).
        border.color: {
            if (select.disabled)
                return Tokens.color.disabled;
            return select.activeFocus || pointer.hovered ? Tokens.color.textPrimary : Tokens.color.textContrastMedium;
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Tokens.durationShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeBase
            }
        }

        Text {
            objectName: "chosen"
            x: Geometry.inputPadding
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, box.width - Geometry.inputPadding - Geometry.selectPaddingEnd)
            text: select.currentText
            elide: Text.ElideRight
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.fontSizeS
            color: select.disabled ? Tokens.color.disabled : Tokens.color.textPrimary
        }

        // Drawn in the padding box, as a background is.
        Shape {
            objectName: "caret"
            x: box.width - box.border.width - Geometry.selectCaretEnd - width
            y: Math.round(box.border.width + Geometry.selectCaretDown * (box.height - 2 * box.border.width - height))
            width: 2 * Geometry.selectCaretHalf
            height: Geometry.selectCaretHalf
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillColor: select.disabled ? Tokens.color.disabled : Tokens.color.textPrimary
                startX: 0
                startY: 0

                PathLine {
                    x: 2 * Geometry.selectCaretHalf
                    y: 0
                }

                PathLine {
                    x: Geometry.selectCaretHalf
                    y: Geometry.selectCaretHalf
                }
            }
        }

        FocusRing {
            objectName: "ring"
            shown: select.activeFocus
        }

        // A press gives no focus, so the ring shows only for the keyboard, like :focus-visible.
        TapHandler {
            // A slow click is still a click.
            longPressThreshold: 0

            onTapped: select.toggle()
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

    // Over the whole overlay while the list is open: a press or the wheel there closes it and goes on to what lies
    // below; a press on the box goes on to the box, which closes it.
    Item {
        parent: select.overlay
        anchors.fill: parent
        z: Tokens.layerFloat
        visible: menu.open

        MouseArea {
            objectName: "outside"
            anchors.fill: parent

            onPressed: mouse => {
                mouse.accepted = false;
                if (!box.contains(mapToItem(box, mouse.x, mouse.y)))
                    menu.close(false);
            }
            onWheel: wheel => {
                wheel.accepted = false;
                menu.close(false);
            }
        }

        Menu {
            id: menu

            // The box in the overlay, as it stood when the list opened.
            property rect anchorRect
            readonly property var place: Placement.float(anchorRect, Qt.size(width, height), area)

            objectName: "list"
            control: select
            area: Qt.size(parent.width, parent.height)
            x: place.x
            y: place.y
            side: place.side
            width: Math.max(implicitWidth, box.width)

            onChosen: item => {
                for (let k = 0; k < choices.count; k++) {
                    if (choices.itemAt(k) === item)
                        select.choose(k);
                }
            }

            Repeater {
                id: choices

                model: select.options

                MenuItem {
                    required property var modelData
                    required property int index

                    kind: "option"
                    text: modelData.text
                    checked: index === select.currentIndex
                }
            }
        }
    }
}
