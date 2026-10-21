import QtQuick

// A surface that floats next to the control that opened it (states.md, "Floating surfaces"; rekta.css:779–787): bg, a
// 1px text-contrast-medium edge, radius-s, no shadow. As wide as its widest row, from 12rem up to 24rem (less in a
// narrow window); at most 24rem or 60% of the window high, scrolling the rest. It comes in with a fade and a 4px shift
// away from its control and leaves at once. The host floats it above the window (an overlay, or a popup of its own
// where it must reach past the window) and places it with Placement.float, which also gives its side.
Rectangle {
    id: surface

    property bool open: false
    // "below" or "above" its control, from Placement.float.
    property string side: "below"
    // The window it has to fit in.
    property size area: Qt.size(Window.width, Window.height)
    // Runs from 0 to 1 as it comes in.
    property real entry: 1
    readonly property real shift: (1 - entry) * (side === "above" ? Geometry.floatShift : -Geometry.floatShift)
    default property alias content: column.data
    readonly property alias rows: column.children
    readonly property real maxWidth: Math.min(Geometry.floatMaxSize, area.width - 2 * Tokens.spaceM)
    readonly property real maxHeight: Math.min(Geometry.floatMaxSize, Geometry.floatMaxHeightShare * area.height)
    readonly property real widestRow: Array.from(rows).reduce((widest, row) => row.visible ? Math.max(widest, row.implicitWidth) : widest, 0)

    // Scrolls a row into view, as focus does on the web.
    function reveal(row: Item) {
        column.forceLayout();
        const top = row.mapToItem(column, 0, 0).y;
        scroller.contentY = Math.min(top, Math.max(scroller.contentY, top + row.height - scroller.height));
    }

    // The minimum wins over the maximum, as min-width does over max-width.
    implicitWidth: Math.max(Geometry.floatMinWidth, Math.min(maxWidth, widestRow + 2 * border.width))
    implicitHeight: Math.min(maxHeight, column.implicitHeight + 2 * border.width)
    visible: open
    z: Tokens.layerFloat
    opacity: entry
    color: Tokens.color.bg
    radius: Tokens.radiusS
    border.width: Geometry.floatBorder
    border.color: Tokens.color.textContrastMedium
    transform: Translate {
        y: surface.shift
    }

    onOpenChanged: {
        comingIn.stop();
        entry = 1;
        if (open) {
            KeyLayers.opened(surface);
            comingIn.start();
        } else {
            KeyLayers.closed(surface);
        }
    }
    Component.onDestruction: KeyLayers.closed(surface)

    NumberAnimation {
        id: comingIn

        objectName: "comingIn"
        target: surface
        property: "entry"
        from: 0
        to: 1
        duration: Tokens.durationFloat
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
    }

    Flickable {
        id: scroller

        objectName: "scroller"
        anchors.fill: parent
        anchors.margins: surface.border.width
        contentWidth: width
        contentHeight: column.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: column

            width: scroller.width
            topPadding: Tokens.spaceXs
            bottomPadding: Tokens.spaceXs
        }
    }
}
