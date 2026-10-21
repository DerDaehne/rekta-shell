import QtQuick
import "Status.js" as Status

// Small, secondary info above everything else on a screen (typography.md, level 1).
Text {
    id: role

    font.family: Tokens.fontSans
    font.pixelSize: Tokens.fontSizeXs
    font.weight: Tokens.fontWeightSemibold
    font.letterSpacing: Geometry.kickerLetterSpacing * Tokens.fontSizeXs
    lineHeightMode: Text.ProportionalHeight
    lineHeight: Tokens.lineHeightBody
    color: Status.secondaryInk(role, Tokens.color)
    wrapMode: Text.Wrap
}
