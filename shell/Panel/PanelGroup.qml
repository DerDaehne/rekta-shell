pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// A group of rows under its heading, a section of a compact place: space-l above and below, its parts space-m apart,
// and a hairline between it and the group before (rekta.css:854–856). Its rows stand on hairlines, the last with one
// below too (rekta.css:68–70). A group without a row present falls away.
Column {
    id: group

    property string title
    // The width of the place, which sets the heading's fluid size.
    property real placeWidth: width
    default property alias rows: list.data
    readonly property bool hasRows: Array.from(list.children).some(row => (row as PanelRow)?.present ?? false)

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

        Column {
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
    }
}
