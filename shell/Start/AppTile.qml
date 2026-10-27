import QtQuick
import Rekta

// An app in the Start, pinned or found by a search: its icon top left, its name along the bottom, neutral; a press
// starts it. Rekta has no app tile yet; this one follows the shell's decision for the Start (an icon top left in every
// size).
Tile {
    id: tile

    property string name
    // An image URL for the app's icon, empty for none.
    property string icon

    opens: true
    Accessible.name: name

    Image {
        objectName: "icon"
        parent: tile
        x: Geometry.tilePadding
        y: Geometry.tilePadding
        width: Geometry.appIconSize
        height: Geometry.appIconSize
        sourceSize: Qt.size(width, height)
        source: tile.icon
    }

    // A kicker names a tile (tiles.md, "Message"), in a tile's line height (rekta.css:86); one line, cut at its end.
    Kicker {
        objectName: "name"
        width: parent.width
        text: tile.name
        color: Tokens.color.textPrimary
        lineHeightFactor: Tokens.lineHeightCompact
        maximumLineCount: 1
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
    }
}
