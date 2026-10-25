pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// A group of rows under its heading, a section of a compact place: space-l above and below, its parts space-m apart,
// and a hairline between it and the group before (rekta.css:854–856). Its rows stand on hairlines, the last with one
// below too (rekta.css:68–70). A group without a row present falls away. An open level stands in place of the rows:
// it comes in from the trailing edge and the rows come back from the leading edge (motion.md, "Next item, same place").
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

    // The first group in sight stands at the top of its column and has no group before it.
    Hairline {
        objectName: "between"
        width: group.width
        visible: group.y > 0
    }

    Column {
        width: group.width
        topPadding: Tokens.spaceL
        bottomPadding: Tokens.spaceL
        spacing: Tokens.spaceM

        GroupHeading {
            objectName: "heading"
            width: parent.width
            text: group.title
            placeWidth: group.placeWidth
        }

        Facets {
            objectName: "parts"
            width: parent.width
            height: group.level?.implicitHeight ?? rowsPart.implicitHeight
            currentIndex: group.level ? 1 : 0

            Column {
                id: rowsPart

                width: parent.width

                Column {
                    id: list

                    objectName: "rows"
                    width: parent.width
                }

                Hairline {
                    width: parent.width
                }
            }

            Item {
                id: levelHolder

                width: parent.width
                height: group.level?.implicitHeight ?? 0
            }
        }
    }
}
