import QtQuick

// Holds a floating surface to the field that opened it, as a combobox's list is (rekta.js:4324): placed with
// Placement.float in the window's coordinates as it opens or changes size, moved with a scroller that moves the field,
// and told when a press lands outside both. It lies just under the surface, over everything else, and sees a press
// anywhere without taking it. The surface floats on `stage`: the one a host of the field keeps for floating surfaces
// (`floatLayer`, under the host's tooltip, so the tip of a cut option shows over it), else over the whole window.
Item {
    id: anchor

    required property Item field
    required property FloatSurface surface

    readonly property Item stage: {
        for (let host = field; host; host = host.parent) {
            const kept = floatLayerOf(host);
            if (kept)
                return kept;
        }
        return field.Window.window?.contentItem ?? null;
    }

    signal pressedOutside

    // Untyped, as the hosts are of any type.
    function floatLayerOf(host: var): Item {
        return host.floatLayer instanceof Item ? host.floatLayer : null;
    }

    function place() {
        if (!surface.open || !stage)
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
