import QtQuick
import Rekta

// A running window in the Start as Rekta's preview tile (tiles.md:123–132; rekta.css:132–136), two units wide: the
// window's live preview fills the top, and the foot holds its app's icon and its title on the tile's surface, so no text
// ever stands on the window's colours. Until a preview shows, or without one, the top is the tile's surface too. A press
// brings the window to the front.
Tile {
    id: tile

    property string title
    // An image URL for the app's icon, empty for none.
    property string icon
    // Draws the preview; it gets `window`, fills the item the tile sizes for it and reports the size of its picture as
    // `pictureSize`, 0 × 0 before the first one. Null for none.
    property Component preview
    // The window it shows, handed to the preview.
    property var window

    columns: 2
    opens: true
    Accessible.name: title

    // The whole width down to the foot, without padding (rekta.css:132–133).
    // ponytail: the preview's top corners stay square under the tile's 2px radius; mask them if that shows.
    Item {
        id: upper

        objectName: "upper"
        parent: tile
        width: tile.width
        height: Math.max(0, tile.height - foot.height)
        clip: true

        // Cropped to fill (tiles.md:126; rekta.css:134, `object-fit: cover`): in its picture's proportions, as large as
        // covers the top, in its middle; what stands out is cut off. Before its first picture it covers the top.
        Loader {
            id: previewLoader

            // Untyped, as each preview is of its caller's type.
            readonly property var drawn: item
            readonly property size picture: drawn?.pictureSize ?? Qt.size(0, 0)
            readonly property bool pictured: picture.width > 0 && picture.height > 0
            readonly property real cover: pictured ? Math.max(upper.width / picture.width, upper.height / picture.height) : 1

            objectName: "preview"
            anchors.centerIn: parent
            // Rounded up, as kpipewire fits its picture into the item's size in whole pixels
            // (pipewiresourceitem.cpp:513–523).
            width: pictured ? Math.ceil(picture.width * cover) : upper.width
            height: pictured ? Math.ceil(picture.height * cover) : upper.height
            active: tile.preview !== null
            sourceComponent: tile.preview
        }
    }

    Binding {
        target: previewLoader.item
        property: "window"
        value: tile.window
        when: previewLoader.item !== null
    }

    // On the tile's surface: the app's icon and the title, one line cut at its end (rekta.css:135–136).
    Row {
        id: foot

        objectName: "foot"
        parent: tile
        y: tile.height - height
        width: tile.width
        leftPadding: Geometry.tilePadding
        rightPadding: Geometry.tilePadding
        topPadding: Tokens.spaceS
        bottomPadding: Tokens.spaceS
        spacing: Tokens.spaceS

        PictureIcon {
            id: footIcon

            objectName: "icon"
            anchors.verticalCenter: parent.verticalCenter
            source: tile.icon
        }

        Body {
            objectName: "title"
            anchors.verticalCenter: parent.verticalCenter
            width: foot.width - foot.leftPadding - foot.rightPadding - footIcon.width - foot.spacing
            text: tile.title
            lineHeightFactor: Tokens.lineHeightCompact
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }
    }
}
