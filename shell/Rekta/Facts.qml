import QtQuick
import "Status.js" as Status

// The fact line below a title or statement: supporting detail in secondary colour (typography.md, level 3).
TextRole {
    id: role

    font.pixelSize: Tokens.fontSizeXs
    font.weight: Tokens.fontWeightRegular
    color: Status.secondaryInk(role, Tokens.color)
    wrapMode: Text.Wrap
}
