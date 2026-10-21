import QtQuick
import "Status.js" as Status

// Small metadata such as times and counts, with tabular figures so numbers line up.
Text {
    id: role

    font.family: Tokens.fontSans
    font.pixelSize: Tokens.fontSizeXxs
    font.weight: Tokens.fontWeightRegular
    font.features: ({ "tnum": 1 })
    lineHeightMode: Text.ProportionalHeight
    lineHeight: Tokens.lineHeightBody
    color: Status.secondaryInk(role, Tokens.color)
    wrapMode: Text.Wrap
}
