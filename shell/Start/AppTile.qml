import QtQuick
import Rekta

// An app in the Start, pinned, in "alle apps" or found by a search, as Rekta's launch tile (tiles.md:141–156;
// rekta.css:176–187): its icon at the top leading corner, the count of its unseen notifications at the top trailing one,
// its name at the foot, and on a tile two units or more wide the app's newest line between them. It stays neutral, as a
// count is no status; a press starts the app. The best hit of a search is wide and says which key starts it
// (navigation.md, "a command shows its key").
Tile {
    id: tile

    property string name
    // An image URL for the app's icon, empty for none.
    property string icon
    // The name of a Rekta icon, drawn in place of `icon`: the shell's own apps carry one.
    property string glyph
    // The best hit of a search, which Enter starts.
    property bool best: false
    // How many unseen notifications the app has.
    property int unseen: 0
    // The count the tile shows, which follows `unseen` through the tile's news.
    property int shown: 0
    // The app's newest line, such as what its player plays; empty for none.
    property string line
    // The line the tile shows, which follows `line` through the tile's news.
    property string shownLine

    opens: true
    // The name is read first, then the count, then the line in sight (tiles.md:154–156; site/index.html:883).
    Accessible.name: [name, shown > 0 ? `${shown} ungelesen` : "", lineText.visible ? shownLine : ""].filter(part => part !== "").join(", ")
    Accessible.description: best ? "bester treffer" : ""
    held: hovered || activeFocus

    // Only a number replacing a number, or a line replacing a line, peeks; one that comes or goes has no old or new one
    // to move, and ends a peek still running. The first count and line are no news.
    onUnseenChanged: tell(count, unseen > 0 && shown > 0, () => tile.shown = tile.unseen)
    onLineChanged: tell(lineText, line !== "" && shownLine !== "", () => tile.shownLine = tile.line)
    Component.onCompleted: {
        shown = unseen;
        shownLine = line;
    }

    // A tile peeks one part, as a page marks one (rekta.js:4200): the one with the news.
    function tell(part: Body, replaces: bool, change: var) {
        peekPart = part;
        news(replaces ? "peek" : "", change);
    }

    // About a third of the tile's height, at its padding (tiles.md:147–150; rekta.css:179–180).
    PictureIcon {
        objectName: "icon"
        parent: tile
        x: Geometry.tilePadding
        y: Geometry.tilePadding
        width: tile.rows > 1 ? Tokens.tileIconLarge : Tokens.tileIcon
        height: width
        opacity: tile.contentOpacity
        source: tile.icon
        visible: tile.glyph === ""
    }

    Icon {
        objectName: "glyph"
        parent: tile
        x: Geometry.tilePadding
        y: Geometry.tilePadding
        size: tile.rows > 1 ? Tokens.tileIconLarge : Tokens.tileIcon
        opacity: tile.contentOpacity
        name: tile.glyph
        visible: tile.glyph !== ""
    }

    // None at zero (tiles.md:143–144; rekta.css:181).
    Body {
        id: count

        objectName: "count"
        parent: tile
        x: tile.width - Geometry.tilePadding - width
        y: Geometry.tilePadding
        visible: tile.shown > 0
        opacity: tile.contentOpacity
        text: String(tile.shown)
        font.pixelSize: Tokens.fontSizeM
        font.weight: Tokens.fontWeightMedium
        font.features: ({ "tnum": 1 })
        lineHeightFactor: Geometry.launchCountLineHeight
        wrapMode: Text.NoWrap
    }

    // In s, two lines at most, space-s above the name (rekta.css:89–94, :182–186). By hand, not in the tile's column: a
    // column lays out at the next polish, and a new line has to rise where it will stand.
    Body {
        id: lineText

        objectName: "line"
        parent: tile
        x: Geometry.tilePadding
        y: tile.height - Geometry.tilePadding - nameRow.height - Tokens.spaceS - height
        width: tile.width - 2 * Geometry.tilePadding
        visible: tile.columns >= 2 && text !== ""
        opacity: tile.contentOpacity
        text: tile.shownLine
        lineHeightFactor: Tokens.lineHeightCompact
        maximumLineCount: Geometry.launchLineCount
        elide: Text.ElideRight
    }

    Item {
        id: nameRow

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
