import QtQuick
import Rekta

// A row on a hairline (rekta.css:68–70): its words at the start, its control at the end, space-s above and below; where
// the two do not fit on one line, the control goes below them (flex-wrap). Words too long for the row are cut. A row
// without words has its control at the start.
Item {
    id: row

    property string label
    // False while the row has nothing to offer, such as when its service is missing: it is gone from its group.
    property bool present: true
    default property alias content: holder.data
    readonly property Item control: holder.children.length > 0 ? holder.children[0] : null
    readonly property real controlWidth: control?.implicitWidth ?? 0
    readonly property real controlHeight: control?.implicitHeight ?? 0
    readonly property bool wraps: label !== "" && words.implicitWidth + Tokens.spaceM + controlWidth > width
    readonly property real lineHeight: Math.max(label !== "" ? words.height : 0, wraps ? 0 : controlHeight)

    width: parent ? parent.width : 0
    implicitHeight: Geometry.hairline + 2 * Tokens.spaceS + lineHeight + (wraps ? controlHeight : 0)
    visible: present

    Hairline {
        width: row.width
    }

    Body {
        id: words

        objectName: "words"
        y: Geometry.hairline + Tokens.spaceS + (row.lineHeight - height) / 2
        width: row.wraps ? row.width : row.width - row.controlWidth - Tokens.spaceM
        visible: row.label !== ""
        text: row.label
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
    }

    Item {
        id: holder

        objectName: "holder"
        x: row.label === "" || row.wraps ? 0 : row.width - row.controlWidth
        y: Geometry.hairline + Tokens.spaceS + (row.wraps ? row.lineHeight : (row.lineHeight - row.controlHeight) / 2)
        width: row.controlWidth
        height: row.controlHeight
    }
}
