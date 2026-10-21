import QtQuick

// The label of a group of menu items: xs semibold in text-contrast-high (rekta.css:810).
TextRole {
    width: parent ? parent.width : implicitWidth
    topPadding: Tokens.spaceS + lineBoxTop
    bottomPadding: Tokens.spaceXs + lineBoxBottom
    leftPadding: Tokens.spaceM
    rightPadding: Tokens.spaceM
    font.pixelSize: Tokens.fontSizeXs
    font.weight: Tokens.fontWeightSemibold
    lineHeightFactor: Tokens.lineHeightCompact
    color: Tokens.color.textContrastHigh
    Accessible.role: Accessible.StaticText
}
