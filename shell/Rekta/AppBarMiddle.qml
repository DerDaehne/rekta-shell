pragma ComponentBehavior: Bound

import QtQuick

// The middle of the app bar (navigation.md, "The middle of the bar"; rekta.css:638–646): a product's own short line,
// xs in the secondary colour. Rekta gives it no controls; here a press on it signals `tapped`. Several parts stand
// side by side, space-s apart on one baseline, and the last is cut with an ellipsis. The bar gives it the room the
// controls leave; pinned it keeps its words up to half the bar and the controls make room instead.
Item {
    id: middle

    property list<string> parts
    // Feedback said nowhere else that lasts a moment, such as a key waiting for its second key.
    property bool pinned: false
    // The part set in tabular figures, such as a time; -1 for none.
    property int figuresPart: -1
    // What the line is about, such as "window" or "music"; a change fades the new line in (motion.md, "State changes").
    property string kind
    signal tapped
    readonly property bool present: parts.length > 0
    property real shown: 1
    // Where each part starts, as its words need it.
    readonly property list<real> starts: parts.reduce((list, part, i) => list.concat(i === 0 ? 0 : list[i - 1] + middle.advance(parts[i - 1], i - 1) + Tokens.spaceS), [])

    // Whole pixels, as a Text measures itself.
    function advance(words: string, index: int): real {
        return Math.ceil((index === figuresPart ? figureMetrics : metrics).advanceWidth(words));
    }

    implicitWidth: present ? starts[parts.length - 1] + advance(parts[parts.length - 1], parts.length - 1) : 0
    implicitHeight: metrics.height
    clip: true
    Accessible.role: Accessible.StaticText
    Accessible.name: parts.join(" ")

    onKindChanged: arrive.restart()

    FontMetrics {
        id: metrics

        font.family: Tokens.fontSans
        font.pixelSize: Tokens.fontSizeXs
    }

    FontMetrics {
        id: figureMetrics

        font.family: metrics.font.family
        font.pixelSize: metrics.font.pixelSize
        font.features: ({ "tnum": 1 })
    }

    TapHandler {
        // A slow click is still a click.
        longPressThreshold: 0

        onTapped: middle.tapped()
    }

    NumberAnimation {
        id: arrive
        objectName: "arrive"

        target: middle
        property: "shown"
        from: 0
        to: 1
        duration: Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeBase
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
            font: index === middle.figuresPart ? figureMetrics.font : metrics.font
            opacity: middle.shown
            color: Tokens.color.textContrastHigh
        }
    }
}
