import QtQuick
import "Status.js" as Status

// A stat pair (tiles.md, "Tile content patterns"; rekta.css:95): one large tabular number, medium so it reads as data,
// over the short lowercase words that name it. In a tile the words take the tile's text colour, right under the
// number; among figures on the ground they are secondary text, space-xs below (rekta.css:98).
Column {
    id: stat

    property string value
    property string label
    // The width of the place that hosts the stat; the fluid number follows it, not the screen.
    property real placeWidth: Window.width
    readonly property bool inFigures: (parent as Figures) !== null

    // In a tile it is a flex item stretched to the content width, and its text wraps there (rekta.css:82); among
    // figures it is as wide as its content.
    width: inFigures ? implicitWidth : (parent ? parent.width : 0)
    spacing: inFigures ? Tokens.spaceXs : 0
    // Figures share one flow spacing; each one carries the rest of the column gap at its end (see Figures).
    rightPadding: inFigures ? Tokens.spaceXl - Tokens.spaceM : 0
    Accessible.role: Accessible.StaticText
    Accessible.name: `${value} ${label}`

    TextRole {
        objectName: "number"
        width: stat.inFigures ? implicitWidth : stat.width
        text: stat.value
        font.pixelSize: Tokens.fluid(Tokens.fontSizeXxl, stat.placeWidth)
        font.weight: Tokens.fontWeightMedium
        font.features: ({ "tnum": 1 })
        lineHeightFactor: Geometry.statLineHeight
        color: Tokens.color.textPrimary
        wrapMode: Text.Wrap
    }

    // A tile sets its text in xs at line-height-compact (rekta.css:86); figures take the ground's line-height-body.
    TextRole {
        objectName: "words"
        width: stat.inFigures ? implicitWidth : stat.width
        text: stat.label
        font.pixelSize: Tokens.fontSizeXs
        lineHeightFactor: stat.inFigures ? Tokens.lineHeightBody : Tokens.lineHeightCompact
        color: stat.inFigures ? Status.secondaryInk(stat, Tokens.color) : Tokens.color.textPrimary
        wrapMode: Text.Wrap
    }
}
