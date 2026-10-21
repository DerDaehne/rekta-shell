import QtQuick

// A pivot's facet title: light like a navigation title, one level smaller.
Text {
    property real placeWidth: Window.width
    property bool active: true

    font.family: Tokens.fontSans
    font.pixelSize: Tokens.fluid(active ? Tokens.fontSizePivotActive : Tokens.fontSizePivotInactive, placeWidth)
    font.weight: Tokens.fontWeightLight
    lineHeightMode: Text.ProportionalHeight
    lineHeight: Tokens.lineHeightNav
    color: active ? Tokens.color.textPrimary : Tokens.color.textContrastMedium
}
