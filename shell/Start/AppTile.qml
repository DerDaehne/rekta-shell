import QtQuick
import Rekta

// An app in the Start, pinned or found by a search: its icon top left, its name along the bottom, neutral; a press
// starts it. Rekta has no app tile yet; this one follows the shell's decision for the Start (an icon top left in every
// size). The best hit of a search is wide and says which key starts it (navigation.md, "a command shows its key").
Tile {
    id: tile

    property string name
    // An image URL for the app's icon, empty for none.
    property string icon
    // The best hit of a search, which Enter starts.
    property bool best: false

    opens: true
    Accessible.name: name
    Accessible.description: best ? "bester treffer" : ""

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

    Item {
        width: parent.width
        height: nameText.height

        // A kicker names a tile (tiles.md, "Message"), in a tile's line height (rekta.css:86); one line, cut at its end.
        // Size s instead of the kicker's xs (rekta.css:50): the Start is larger than a compact panorama.
        Kicker {
            id: nameText

            objectName: "name"
            font.pixelSize: Tokens.fontSizeS
            font.letterSpacing: Geometry.kickerLetterSpacing * Tokens.fontSizeS
            width: Math.min(implicitWidth, parent.width - (tile.best ? hint.width + Tokens.spaceS : 0))
            text: tile.name
            color: Tokens.color.textPrimary
            lineHeightFactor: Tokens.lineHeightCompact
            maximumLineCount: 1
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }

        // By hand, not a Row: a Row lays out at the next polish.
        Item {
            id: hint

            objectName: "bestHit"
            x: nameText.width + Tokens.spaceS
            width: word.x + word.implicitWidth
            height: parent.height
            visible: tile.best

            KeyHint {
                id: key

                objectName: "key"
                anchors.verticalCenter: parent.verticalCenter
                text: "enter"
            }

            Kicker {
                id: word

                x: key.width + Tokens.spaceXs
                text: "bester treffer"
                color: Tokens.color.textContrastHigh
                font.pixelSize: Tokens.fontSizeXs
                lineHeightFactor: Tokens.lineHeightCompact
                wrapMode: Text.NoWrap
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
