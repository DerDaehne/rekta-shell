import QtQuick

// The tooltip (navigation.md, "Tooltips"; rekta.css:416–423): a small ink strip, like a toast, xs semibold in the
// ground colour, above its control or below it where there is no room. It draws the tip Tips holds and comes in like a
// floating surface, again for each control; it leaves at once and never takes the pointer. The host floats one above
// each window and places it with Placement.tip, which also gives its side.
Rectangle {
    id: tooltip

    property Item target: Tips.target
    property string text: Tips.text
    readonly property bool open: target !== null
    // "above" or "below" its control, from Placement.tip.
    property string side: "above"
    // The window it has to fit in.
    property size area: Qt.size(Window.width, Window.height)
    // Runs from 0 to 1 as it comes in.
    property real entry: 1
    readonly property real shift: (1 - entry) * (side === "above" ? Geometry.floatShift : -Geometry.floatShift)
    readonly property real maxWidth: Math.min(Geometry.tipMaxWidth, area.width - 2 * Tokens.spaceM)

    implicitWidth: Math.min(maxWidth, words.implicitWidth + 2 * Tokens.spaceS)
    implicitHeight: words.height + 2 * Geometry.tipPaddingY
    visible: open
    z: Tokens.layerFloat
    opacity: entry
    color: Tokens.color.textPrimary
    radius: Tokens.radiusS
    transform: Translate {
        y: tooltip.shift
    }
    Accessible.role: Accessible.ToolTip
    Accessible.name: text

    onTargetChanged: {
        comingIn.stop();
        entry = 1;
        if (target)
            comingIn.start();
    }

    NumberAnimation {
        id: comingIn

        objectName: "comingIn"
        target: tooltip
        property: "entry"
        from: 0
        to: 1
        duration: Tokens.durationFloat
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
    }

    Text {
        id: words

        objectName: "words"
        x: Tokens.spaceS
        y: Geometry.tipPaddingY
        width: tooltip.width - 2 * Tokens.spaceS
        text: tooltip.text
        wrapMode: Text.Wrap
        font.family: Tokens.fontSans
        font.pixelSize: Tokens.fontSizeXs
        font.weight: Tokens.fontWeightSemibold
        // CSS line-height is a share of the font size; Qt's proportional mode would scale the font's own line height.
        lineHeightMode: Text.FixedHeight
        lineHeight: Tokens.lineHeightCompact * font.pixelSize
        color: Tokens.color.bg
    }
}
