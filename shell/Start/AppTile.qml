import QtQuick
import Rekta

// An app pinned to the Start: its icon top left, its name along the bottom, neutral; a press starts it. Rekta has no
// app tile yet; this one follows the shell's decision for the Start (an icon top left in every size).
Tile {
    id: tile

    property string name
    // An image URL for the app's icon, empty for none.
    property string icon

    opens: true
    Accessible.name: name

    // The icon at the size of Rekta's icons (rekta.css:425), as Rekta has none for an app's own.
    Image {
        objectName: "icon"
        parent: tile
        x: Geometry.tilePadding
        y: Geometry.tilePadding
        width: Geometry.iconSize
        height: Geometry.iconSize
        sourceSize: Qt.size(width, height)
        source: tile.icon
    }

    // A kicker names a tile (tiles.md, "Message"), in a tile's line height (rekta.css:86); one line, cut at its end.
    Kicker {
        objectName: "name"
        width: parent.width
        text: tile.name
        lineHeightFactor: Tokens.lineHeightCompact
        maximumLineCount: 1
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
    }
}
