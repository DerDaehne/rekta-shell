import QtQuick
import "Status.js" as Status

// The fact line below a title or statement: supporting detail in secondary colour (typography.md, level 3).
Text {
    id: role

    font.family: Tokens.fontSans
    font.pixelSize: Tokens.fontSizeXs
    font.weight: Tokens.fontWeightRegular
    lineHeightMode: Text.ProportionalHeight
    lineHeight: Tokens.lineHeightBody
    color: Status.secondaryInk(role, Tokens.color)
    wrapMode: Text.Wrap
}
