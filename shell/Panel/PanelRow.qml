import QtQuick
import Rekta

// A row of a group, a form's field rather than a list's item, so it stands on no hairline: its words at the start, its
// control at the end; where the two do not fit on one line, the control goes below them (flex-wrap, rekta.css:69).
// Words too long for the row are cut. A row without words has its control at the start.
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
    implicitHeight: lineHeight + (wraps ? controlHeight : 0)
    visible: present

    Body {
        id: words

        objectName: "words"
        y: (row.lineHeight - height) / 2
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
        y: row.wraps ? row.lineHeight : (row.lineHeight - row.controlHeight) / 2
        width: row.controlWidth
        height: row.controlHeight
    }
}
