import QtQuick
import Rekta

// A running window in the Start, two units wide: the window's live preview above, its app's icon and its title below
// on the tile's own surface, so no text ever stands on the window's colours. Until a preview shows, or without one, the
// upper part is the tile's surface too. A press brings the window to the front.
Tile {
    id: tile

    property string title
    // An image URL for the app's icon, empty for none.
    property string icon
    // Draws the preview; it gets `window` and fills the upper part. Null for none.
    property Component preview
    // The window it shows, handed to the preview.
    property var window
    // How many unseen notifications the window's app has.
    property int unseen: 0

    columns: 2
    opens: true
    Accessible.name: title
    Accessible.description: count.showing ? count.shown + " ungelesen" : ""
    held: hover.hovered || activeFocus

    HoverHandler {
        id: hover
    }

    // ponytail: the preview's top corners stay square under the tile's 2px radius; mask them if that shows.
    Loader {
        id: previewLoader

        objectName: "preview"
        parent: tile
        width: tile.width
        // Down to the padding above the icon and title.
        height: Math.max(0, tile.height - label.height - 2 * Geometry.tilePadding)
        active: tile.preview !== null
        sourceComponent: tile.preview
    }

    Binding {
        target: previewLoader.item
        property: "window"
        value: tile.window
        when: previewLoader.item !== null
    }

    Row {
        id: label

        objectName: "label"
        width: parent.width
        spacing: Tokens.spaceS

        Image {
            objectName: "icon"
            anchors.verticalCenter: parent.verticalCenter
            width: Geometry.appIconSize
            height: Geometry.appIconSize
            sourceSize: Qt.size(width, height)
            source: tile.icon
        }

        // A kicker names a tile (tiles.md, "Message"), in a tile's line height (rekta.css:86); one line, cut at its end.
        // Size s instead of the kicker's xs (rekta.css:50): the Start is larger than a compact panorama.
        Kicker {
            objectName: "title"
            visible: !count.showing
            font.pixelSize: Tokens.fontSizeS
            font.letterSpacing: Geometry.kickerLetterSpacing * Tokens.fontSizeS
            anchors.verticalCenter: parent.verticalCenter
            width: label.width - Geometry.appIconSize - label.spacing
            text: tile.title
            color: Tokens.color.textPrimary
            lineHeightFactor: Tokens.lineHeightCompact
            maximumLineCount: 1
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }

        // In place of the title, beside the icon.
        UnseenStat {
            id: count

            owner: tile
            app: tile.title
            count: tile.unseen
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Geometry.appIconSize - parent.spacing
        }
    }
}
