import QtQuick

// A navigation title: large and light, it names a place (typography.md, navigation titles).
TextRole {
    property real placeWidth: Window.width
    property bool active: true
    // On glass an inactive title takes text-contrast-high, nothing lower (colour.md:65–75).
    property bool onGlass: false

    font.pixelSize: Tokens.fluid(active ? Tokens.fontSizeNavActive : Tokens.fontSizeNavInactive, placeWidth)
    font.weight: Tokens.fontWeightLight
    lineHeightFactor: Tokens.lineHeightNav
    color: active ? Tokens.color.textPrimary : onGlass ? Tokens.color.textContrastHigh : Tokens.color.textContrastMedium
}
