import QtQuick

// One row of a SortableRows, its delegate: a Grip at the leading edge, then the row's own content. Dragged or picked up,
// it lifts as a floating surface, bg and a 1px edge inside, no shadow, above the others (rekta.css:618).
Item {
    id: row

    required property int index
    // What the row is called, in the grip's name and every announcement.
    property string name
    // Why it cannot be moved now; its grip greys and moves nothing.
    property string disabledReason
    default property alias content: body.data

    readonly property SortableRows rows: parent as SortableRows
    readonly property bool lifted: rows !== null && (rows.draggedRow === row || rows.grabbedRow === row)
    readonly property real restingY: rows?.tops[index] ?? 0
    readonly property alias grip: grip
    // Where the row shows, from where it rests: following the pointer, making room, or settling.
    property real offset: 0

    // FLIP's invert and play: from where the row showed before a move to where it rests now, over duration-moderate
    // (motion.md, "Reordering (FLIP)"; rekta.js:3400, :3444).
    function settleFrom(shownY: real) {
        settle.stop();
        offset = shownY - restingY;
        if (offset !== 0)
            settle.start();
    }

    function holds(item: Item): bool {
        for (let at = item; at; at = at.parent) {
            if (at === row)
                return true;
        }
        return false;
    }

    width: rows?.width ?? implicitWidth
    implicitHeight: Math.max(Tokens.rowHeight, body.childrenRect.height)
    y: restingY + offset
    z: lifted ? 2 : 0

    onHeightChanged: rows?.layout()
    onIndexChanged: rows?.layout()

    // The others make room in duration-short · ease-base while one is dragged (rekta.css:617).
    Behavior on offset {
        enabled: row.rows?.draggedRow !== null && row.rows.draggedRow !== row

        NumberAnimation {
            duration: Tokens.durationShort
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeBase
        }
    }

    NumberAnimation {
        id: settle

        target: row
        property: "offset"
        to: 0
        duration: Tokens.durationModerate
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeBase
    }

    Rectangle {
        objectName: "lift"
        anchors.fill: parent
        visible: row.lifted
        color: Tokens.color.bg
    }

    Grip {
        id: grip

        height: row.height
        name: row.name
        disabledReason: row.disabledReason
        grabbed: row.rows?.grabbedRow === row
        onDragged: dy => row.rows.dragTo(row, dy)
        onDropped: canceled => row.rows.drop(canceled)
        Keys.onPressed: event => row.rows.key(row, event)
    }

    Item {
        id: body

        x: grip.width
        width: row.width - grip.width
        height: row.height
    }

    Rectangle {
        objectName: "edge"
        anchors.fill: parent
        visible: row.lifted
        z: 1
        color: "transparent"
        border.width: Geometry.liftedEdge
        border.color: Tokens.color.textContrastMedium
    }
}
