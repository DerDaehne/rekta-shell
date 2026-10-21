import QtQuick
import "Status.js" as Status

// Small, secondary info above everything else on a screen (typography.md, level 1).
TextRole {
    id: role

    font.pixelSize: Tokens.fontSizeXs
    font.weight: Tokens.fontWeightSemibold
    font.letterSpacing: Geometry.kickerLetterSpacing * Tokens.fontSizeXs
    color: Status.secondaryInk(role, Tokens.color)
    wrapMode: Text.Wrap
}
