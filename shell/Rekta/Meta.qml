import QtQuick

// Small metadata such as times and counts, with tabular figures so numbers line up.
Text {
    font.family: Tokens.fontSans
    font.pixelSize: Tokens.fontSizeXxs
    font.weight: Tokens.fontWeightRegular
    font.features: ({ "tnum": 1 })
    color: Tokens.color.textContrastHigh
}
