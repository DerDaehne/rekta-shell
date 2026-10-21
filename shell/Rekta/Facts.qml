import QtQuick

// The fact line below a title or statement: supporting detail in secondary colour (typography.md, level 3).
Text {
    font.family: Tokens.fontSans
    font.pixelSize: Tokens.fontSizeXs
    font.weight: Tokens.fontWeightRegular
    lineHeightMode: Text.ProportionalHeight
    lineHeight: Tokens.lineHeightBody
    color: Tokens.color.textContrastHigh
    wrapMode: Text.Wrap
}
