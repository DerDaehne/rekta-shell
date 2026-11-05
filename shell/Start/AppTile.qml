import QtQuick
import Rekta

// An app in the Start, pinned, in "alle apps" or found by a search, as Rekta's launch tile (tiles.md:141–156;
// rekta.css:176–187): its icon at the top leading corner, the count of its unseen notifications at the top trailing one,
// its name at the foot. It stays neutral, as a count is no status; a press starts the app. The best hit of a search is
// wide and says which key starts it (navigation.md, "a command shows its key").
Tile {
    id: tile

    property string name
    // An image URL for the app's icon, empty for none.
    property string icon
    // The best hit of a search, which Enter starts.
    property bool best: false
    // How many unseen notifications the app has.
    property int unseen: 0
    // The count the tile shows, which follows `unseen` through the tile's news.
    property int shown: 0

    opens: true
    peekPart: count
    // The name is read first, then the count (tiles.md:154–156).
    Accessible.name: shown > 0 ? `${name}, ${shown} ungelesen` : name
    Accessible.description: best ? "bester treffer" : ""
    held: hovered || activeFocus

    // Only a number replacing a number peeks; one that comes or goes has no old or new number to move, and ends a peek
    // still running. The first count is no news.
    onUnseenChanged: news(unseen > 0 && shown > 0 ? "peek" : "", () => tile.shown = tile.unseen)
    Component.onCompleted: shown = unseen

    // About a third of the tile's height, at its padding (tiles.md:147–150; rekta.css:179–180).
    PictureIcon {
        objectName: "icon"
        parent: tile
        x: Geometry.tilePadding
        y: Geometry.tilePadding
        width: tile.rows > 1 ? Tokens.tileIconLarge : Tokens.tileIcon
        height: width
        source: tile.icon
    }

    // None at zero (tiles.md:143–144; rekta.css:181).
    Body {
        id: count

        objectName: "count"
        parent: tile
        x: tile.width - Geometry.tilePadding - width
        y: Geometry.tilePadding
        visible: tile.shown > 0
        text: String(tile.shown)
        font.pixelSize: Tokens.fontSizeM
        font.weight: Tokens.fontWeightMedium
        font.features: ({ "tnum": 1 })
        lineHeightFactor: Geometry.launchCountLineHeight
        wrapMode: Text.NoWrap
    }

    Item {
        width: parent.width
        height: nameText.height

        // As the app writes it, in the tile's type and semibold (rekta.css:94, :187); one line, cut at its end.
        Body {
            id: nameText

            objectName: "name"
            width: Math.min(implicitWidth, parent.width - (tile.best ? hint.width + Tokens.spaceS : 0))
            text: tile.name
            font.pixelSize: Tokens.fontSizeXs
            font.weight: Tokens.fontWeightSemibold
            lineHeightFactor: Tokens.lineHeightCompact
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
