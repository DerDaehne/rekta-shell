pragma ComponentBehavior: Bound

import QtQuick

// The middle of the app bar (navigation.md, "The middle of the bar"; rekta.css:638–646): a product's own short line,
// xs in the secondary colour, no controls. Several parts stand side by side, space-s apart on one baseline, and the
// last is cut with an ellipsis. The bar gives it the room the controls leave; pinned it keeps its words up to half the
// bar and the controls make room instead.
Item {
    id: middle

    property list<string> parts
    // Feedback said nowhere else that lasts a moment, such as a key waiting for its second key.
    property bool pinned: false
    readonly property bool present: parts.length > 0
    // Where each part starts, as its words need it.
    readonly property list<real> starts: parts.reduce((list, part, i) => list.concat(i === 0 ? 0 : list[i - 1] + middle.advance(parts[i - 1]) + Tokens.spaceS), [])

    // Whole pixels, as a Text measures itself.
    function advance(words: string): real {
        return Math.ceil(metrics.advanceWidth(words));
    }

    implicitWidth: present ? starts[parts.length - 1] + advance(parts[parts.length - 1]) : 0
    implicitHeight: metrics.height
    clip: true
    Accessible.role: Accessible.StaticText
    Accessible.name: parts.join(" ")

    FontMetrics {
        id: metrics

        font.family: Tokens.fontSans
        font.pixelSize: Tokens.fontSizeXs
    }

    Repeater {
        model: middle.parts

        delegate: Text {
            required property string modelData
            required property int index
            readonly property bool last: index === middle.parts.length - 1

            objectName: `part ${index}`
            x: middle.starts[index] ?? 0
            anchors.verticalCenter: parent.verticalCenter
            width: last ? Math.max(0, middle.width - x) : implicitWidth
            text: modelData
            elide: last ? Text.ElideRight : Text.ElideNone
            font: metrics.font
            color: Tokens.color.textContrastHigh
        }
    }
}
