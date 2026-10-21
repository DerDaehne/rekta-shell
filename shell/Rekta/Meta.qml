import QtQuick
import "Status.js" as Status

// Small metadata such as times and counts, with tabular figures so numbers line up.
TextRole {
    id: role

    font.pixelSize: Tokens.fontSizeXxs
    font.weight: Tokens.fontWeightRegular
    font.features: ({ "tnum": 1 })
    color: Status.secondaryInk(role, Tokens.color)
    wrapMode: Text.Wrap
}
