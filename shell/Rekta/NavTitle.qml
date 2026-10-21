import QtQuick

// A navigation title: large and light, it names a place (typography.md, navigation titles).
Text {
    property real placeWidth: Window.width
    property bool active: true

    font.family: Tokens.fontSans
    font.pixelSize: Tokens.fluid(active ? Tokens.fontSizeNavActive : Tokens.fontSizeNavInactive, placeWidth)
    font.weight: Tokens.fontWeightLight
    lineHeightMode: Text.ProportionalHeight
    lineHeight: Tokens.lineHeightNav
    color: active ? Tokens.color.textPrimary : Tokens.color.textContrastMedium
}
