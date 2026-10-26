import QtQuick

// The word of a banner, large and light (rekta.css `.rk-banner-word`).
TextRole {
    // The width of the place the banner spans; the size follows it.
    property real placeWidth: Window.width

    font.pixelSize: Tokens.fluid(Tokens.fontSizeL, placeWidth)
    font.weight: Tokens.fontWeightLight
    lineHeightFactor: Tokens.lineHeightTight
    color: Tokens.color.textPrimary
}
