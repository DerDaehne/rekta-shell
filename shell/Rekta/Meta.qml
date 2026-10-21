import QtQuick

// Small metadata such as times and counts, with tabular figures so numbers line up.
Text {
    font.family: Tokens.fontSans
    font.pixelSize: Tokens.fontSizeXxs
    font.weight: Tokens.fontWeightRegular
    font.features: ({ "tnum": 1 })
    lineHeightMode: Text.ProportionalHeight
    lineHeight: Tokens.lineHeightBody
    color: Tokens.color.textContrastHigh
    wrapMode: Text.Wrap
}
