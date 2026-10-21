import QtQuick

// A message (tiles.md, "Tile content patterns"; rekta.css:103–107): one plain sentence in size s, for a tile whose
// content is a statement; a kicker may name it above and a fact line carry one small value below. Past four lines, six
// on a wide tile, the sentence ends in an ellipsis; the whole of it is still read.
Column {
    id: message

    property string text
    property string kicker
    property string facts
    readonly property bool wide: ((parent?.parent ?? null) as Tile)?.columns >= 2

    width: parent ? parent.width : 0
    spacing: Tokens.spaceS

    // Text in a tile takes the tile's line-height-compact (rekta.css:86), the kicker and the fact line too.
    Kicker {
        objectName: "kicker"
        width: message.width
        visible: text !== ""
        text: message.kicker
        lineHeightFactor: Tokens.lineHeightCompact
    }

    TextRole {
        objectName: "sentence"
        width: message.width
        text: message.text
        font.pixelSize: Tokens.fontSizeS
        lineHeightFactor: Tokens.lineHeightCompact
        color: Tokens.color.textPrimary
        wrapMode: Text.Wrap
        maximumLineCount: message.wide ? Geometry.tileMessageLinesWide : Geometry.tileMessageLines
        elide: Text.ElideRight
        Accessible.role: Accessible.StaticText
        Accessible.name: message.text
    }

    Facts {
        objectName: "facts"
        width: message.width
        visible: text !== ""
        text: message.facts
        lineHeightFactor: Tokens.lineHeightCompact
    }
}
