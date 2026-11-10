import QtQuick
import "Status.js" as Status

// A stat pair (tiles.md, "Tile content patterns"; rekta.css:109): one large tabular number, medium so it reads as data,
// over the short lowercase words that name it. In a tile the words take the tile's text colour, right under the
// number; among figures on the ground they are secondary text, space-xs below (rekta.css:112).
Column {
    id: stat

    property string value
    property string label
    // An icon before the words, in their colour, space-s before them as before a menu item's words (rekta.css:1022).
    property string icon
    // The widest the stat may be among figures: past it, its number ends in an ellipsis on its one line, its words wrap.
    property real maximumWidth: Infinity
    // The width of the place that hosts the stat; the fluid number follows it, not the screen.
    property real placeWidth: Window.width
    readonly property bool inFigures: (parent as Figures) !== null

    // In a tile it is a flex item stretched to the content width, and its text wraps there (rekta.css:90); among
    // figures it is as wide as its content.
    width: inFigures ? implicitWidth : (parent ? parent.width : 0)
    spacing: inFigures ? Tokens.spaceXs : 0
    // Figures share one flow spacing; each one carries the rest of the column gap at its end (see Figures).
    rightPadding: inFigures ? Tokens.spaceXl - Tokens.spaceM : 0
    Accessible.role: Accessible.StaticText
    Accessible.name: `${value} ${label}`

    TextRole {
        objectName: "number"
        width: stat.inFigures ? Math.min(implicitWidth, stat.maximumWidth) : stat.width
        text: stat.value
        font.pixelSize: Tokens.fluid(Tokens.fontSizeXxl, stat.placeWidth)
        font.weight: Tokens.fontWeightMedium
        font.features: ({ "tnum": 1 })
        lineHeightFactor: Geometry.statLineHeight
        color: Tokens.color.textPrimary
        wrapMode: stat.inFigures ? Text.NoWrap : Text.Wrap
        elide: stat.inFigures ? Text.ElideRight : Text.ElideNone
    }

    // A tile sets its text in xs at line-height-compact (rekta.css:94); figures take the ground's line-height-body.
    TextRole {
        id: words

        objectName: "words"
        width: stat.inFigures ? Math.min(implicitWidth, stat.maximumWidth) : stat.width
        leftPadding: stat.icon !== "" ? Geometry.iconSize + Tokens.spaceS : 0
        text: stat.label
        font.pixelSize: Tokens.fontSizeXs
        lineHeightFactor: stat.inFigures ? Tokens.lineHeightBody : Tokens.lineHeightCompact
        color: stat.inFigures ? Status.secondaryInk(stat, Tokens.color) : Tokens.color.textPrimary
        wrapMode: Text.Wrap

        // Centred on the first line, as an icon stands in a line of words (`vertical-align: middle`, rekta.css:580).
        Icon {
            objectName: "wordsIcon"
            y: (words.lineHeight - height) / 2
            name: stat.icon
            size: Geometry.iconSize
            color: words.color
        }
    }
}
