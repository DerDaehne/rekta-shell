import QtQuick

// Small, secondary info above everything else on a screen (typography.md, level 1).
Text {
    font.family: Tokens.fontSans
    font.pixelSize: Tokens.fontSizeXs
    font.weight: Tokens.fontWeightSemibold
    font.letterSpacing: Geometry.kickerLetterSpacing * Tokens.fontSizeXs
    lineHeightMode: Text.ProportionalHeight
    lineHeight: Tokens.lineHeightBody
    color: Tokens.color.textContrastHigh
    wrapMode: Text.Wrap
}
