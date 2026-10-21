import QtQuick

// A pivot's facet title: light like a navigation title, one level smaller.
TextRole {
    property real placeWidth: Window.width
    property bool active: true

    font.pixelSize: Tokens.fluid(active ? Tokens.fontSizePivotActive : Tokens.fontSizePivotInactive, placeWidth)
    font.weight: Tokens.fontWeightLight
    lineHeightFactor: Tokens.lineHeightNav
    color: active ? Tokens.color.textPrimary : Tokens.color.textContrastMedium
}
