import QtQuick

// A navigation title: large and light, it names a place (typography.md, navigation titles).
TextRole {
    property real placeWidth: Window.width
    property bool active: true

    font.pixelSize: Tokens.fluid(active ? Tokens.fontSizeNavActive : Tokens.fontSizeNavInactive, placeWidth)
    font.weight: Tokens.fontWeightLight
    lineHeightFactor: Tokens.lineHeightNav
    color: active ? Tokens.color.textPrimary : Tokens.color.textContrastMedium
}
