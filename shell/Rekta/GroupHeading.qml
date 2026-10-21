import QtQuick

// A section heading inside a place (rekta.css `.rk-group`).
Text {
    property real placeWidth: Window.width

    font.family: Tokens.fontSans
    font.pixelSize: Tokens.fluid(Tokens.fontSizeGroup, placeWidth)
    font.weight: Tokens.fontWeightRegular
    lineHeightMode: Text.ProportionalHeight
    lineHeight: Tokens.lineHeightTight
    color: Tokens.color.textPrimary
}
