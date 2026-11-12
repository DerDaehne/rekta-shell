import QtQuick

// The grip of an item ordered by hand (collections.md, "Ordering by hand"; rekta.css:614–620, :1348): a button of six
// squares at the item's leading edge, as tall as the item, and the only place a pointer drags it from. A press that
// does not move does nothing; once the pointer has moved gripDragStart up or down, `dragged` follows it. Picked up from
// the keyboard or under the pointer it takes the primary text colour. A finger on it never scrolls what holds it
// (`touch-action: none`). A pointer gives no focus, so the ring shows only for the keyboard, like :focus-visible.
Item {
    id: grip

    // The item's name; the grip is read as moving it (rekta.js `move`).
    property string name
    // Picked up from the keyboard, like aria-pressed.
    property bool grabbed: false
    readonly property bool dragging: pointer.dragging

    // dy: how far the pointer has moved up or down since the press, in scene pixels.
    signal dragged(real dy)
    signal dropped(bool canceled)

    implicitWidth: Geometry.gripWidth
    implicitHeight: Tokens.rowHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: `${name} verschieben`
    Accessible.checkable: true
    Accessible.checked: grabbed

    Icon {
        objectName: "squares"
        anchors.centerIn: parent
        name: "grip"
        size: Geometry.gripGlyph
        color: grip.grabbed || pointer.containsMouse ? Tokens.color.textPrimary : Tokens.color.textContrastMedium
    }

    FocusRing {
        offset: -Geometry.focusRingInsetInRow
    }

    MouseArea {
        id: pointer

        property real startY
        property bool dragging: false

        function sceneY(mouse: MouseEvent): real {
            return mapToItem(null, mouse.x, mouse.y).y;
        }

        function end(canceled: bool) {
            if (!dragging)
                return;
            dragging = false;
            grip.dropped(canceled);
        }

        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onPressed: mouse => startY = sceneY(mouse)
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const dy = sceneY(mouse) - startY;
            if (!dragging && Math.abs(dy) < Geometry.gripDragStart)
                return;
            dragging = true;
            grip.dragged(dy);
        }
        onReleased: end(false)
        onCanceled: end(true)
    }
}
