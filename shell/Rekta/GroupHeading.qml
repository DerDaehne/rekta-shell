import QtQuick

// A section heading inside a place (rekta.css `.rk-group`).
TextRole {
    property real placeWidth: Window.width

    font.pixelSize: Tokens.fluid(Tokens.fontSizeGroup, placeWidth)
    font.weight: Tokens.fontWeightRegular
    lineHeightFactor: Tokens.lineHeightTight
    color: Tokens.color.textPrimary
    wrapMode: Text.Wrap
}
