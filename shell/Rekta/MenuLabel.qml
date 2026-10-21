import QtQuick

// The label of a group of menu items: xs semibold in text-contrast-high (rekta.css:810).
Text {
    width: parent ? parent.width : implicitWidth
    topPadding: Tokens.spaceS
    bottomPadding: Tokens.spaceXs
    leftPadding: Tokens.spaceM
    rightPadding: Tokens.spaceM
    font.family: Tokens.fontSans
    font.pixelSize: Tokens.fontSizeXs
    font.weight: Tokens.fontWeightSemibold
    // CSS line-height is a share of the font size; Qt's proportional mode would scale the font's own line height.
    lineHeightMode: Text.FixedHeight
    lineHeight: Tokens.lineHeightCompact * font.pixelSize
    color: Tokens.color.textContrastHigh
    Accessible.role: Accessible.StaticText
}
