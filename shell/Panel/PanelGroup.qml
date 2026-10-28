pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// A group of rows under its heading, a section of a compact place: space-xl above and space-l below (rekta.css:854 says
// space-l on both sides; the panel sets its blocks further apart), its parts space-m apart (rekta.css:856).
// Its rows are a form's fields, not a list's items: each is a part of its own, space-m from the next, on no hairline,
// and groups stand apart by their headings and that space. A group without a row present falls away. An open level
// stands in place of the rows: it comes in from the trailing edge and the rows come back from the leading edge
// (motion.md, "Next item, same place").
Column {
    id: group

    property string title
    // The width of the place, which sets the heading's fluid size.
    property real placeWidth: width
    default property alias rows: list.data
    // Its PanelLevels, one open at a time.
    property alias levels: levelHolder.data
    readonly property bool hasRows: Array.from(list.children).some(row => (row as PanelRow)?.present ?? false)
    readonly property PanelLevel level: Array.from(levelHolder.children).find(child => (child as PanelLevel)?.open) ?? null

    width: parent ? parent.width : 0
    visible: hasRows
    topPadding: Tokens.spaceXl
    bottomPadding: Tokens.spaceL
    spacing: Tokens.spaceM

    GroupHeading {
        objectName: "heading"
        width: group.width
        text: group.title
        placeWidth: group.placeWidth
    }

    Facets {
        objectName: "parts"
        width: group.width
        height: group.level?.implicitHeight ?? list.implicitHeight
        currentIndex: group.level ? 1 : 0

        Column {
            id: list

            objectName: "rows"
            width: parent.width
            spacing: Tokens.spaceM
        }

        Item {
            id: levelHolder

            width: parent.width
            height: group.level?.implicitHeight ?? 0
        }
    }
}
