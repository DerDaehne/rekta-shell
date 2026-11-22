import QtQuick

// A tile that opens an area's level in a side panel (states.md:224–275; tiles.md:167–172, :184–196; rekta.css:194–197):
// the area's icon at the top leading corner, its name in semibold at the foot and its state word right under it, each
// one line cut with an ellipsis, the whole words in their tip. It opens and never switches: no pressed state and no
// accent fill, so a tile that says "aus" looks like one that says "an"; a status fills it only for a real status. A
// press nudges it back as every tile that opens. It reads as a button "name, state".
Tile {
    id: tile

    property string name
    // The name of a Rekta icon.
    property string glyph
    property string stateWord

    opens: true
    Accessible.name: stateWord !== "" ? `${name}, ${stateWord}` : name

    Icon {
        objectName: "glyph"
        parent: tile
        x: Geometry.tilePadding
        y: Geometry.tilePadding
        size: Tokens.tileIcon
        opacity: tile.contentOpacity
        name: tile.glyph
    }

    // Name and state word with no gap between them (`.rk-opener { gap: 0 }`), in the tile's type (rekta.css:98).
    Column {
        width: parent.width

        OpenerWords {
            objectName: "name"
            text: tile.name
            font.weight: Tokens.fontWeightSemibold
        }

        OpenerWords {
            objectName: "state"
            text: tile.stateWord
            visible: text !== ""
        }
    }

    component OpenerWords: Body {
        width: parent.width
        font.pixelSize: Tokens.fontSizeXs
        lineHeightFactor: Tokens.lineHeightCompact
        wrapMode: Text.NoWrap
        elide: Text.ElideRight

        OverflowTip {}
    }
}
