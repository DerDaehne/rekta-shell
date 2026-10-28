import QtQuick

// A section heading inside a place (rekta.css `.rk-group`).
TextRole {
    property real placeWidth: Window.width
    // The fluid size token; a place may set a larger one.
    property var sizeToken: Tokens.fontSizeGroup

    font.pixelSize: Tokens.fluid(sizeToken, placeWidth)
    font.weight: Tokens.fontWeightRegular
    lineHeightFactor: Tokens.lineHeightTight
    color: Tokens.color.textPrimary
    wrapMode: Text.Wrap
}
