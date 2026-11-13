import QtQuick

// Holds a floating surface to the field that opened it, as a combobox's list is (rekta.js:4324): placed with
// Placement.float in the window's coordinates as it opens or changes size, moved with a scroller that moves the field,
// and told when a press lands outside both. It lies just under the surface, over everything else, and sees a press
// anywhere without taking it.
Item {
    id: anchor

    required property Item field
    required property FloatSurface surface

    signal pressedOutside

    function place() {
        if (!surface.open || !field.Window.window)
            return;
        const at = field.mapToItem(surface.parent, 0, 0);
        const spot = Placement.float(Qt.rect(at.x, at.y, field.width, field.height), Qt.size(surface.width, surface.height), surface.area);
        surface.x = spot.x;
        surface.y = spot.y;
        surface.side = spot.side;
    }

    function holds(scenePosition: point): bool {
        return field.contains(field.mapFromItem(null, scenePosition)) || surface.contains(surface.mapFromItem(null, scenePosition));
    }

    parent: surface.parent
    anchors.fill: parent
    z: surface.z - 1
    visible: surface.open

    PointHandler {
        onActiveChanged: {
            if (active && !anchor.holds(point.scenePosition))
                anchor.pressedOutside();
        }
    }

    Connections {
        target: anchor.surface

        function onOpenChanged() {
            anchor.place();
        }

        function onWidthChanged() {
            anchor.place();
        }

        function onHeightChanged() {
            anchor.place();
        }

        function onAreaChanged() {
            anchor.place();
        }
    }

    Connections {
        target: anchor.surface.open ? Reveal.scrollerOf(anchor.field) : null
        ignoreUnknownSignals: true

        function onContentYChanged() {
            anchor.place();
        }
    }
}
