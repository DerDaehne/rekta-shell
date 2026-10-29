import QtQuick
import Rekta

// An app tile's unseen notifications as a stat pair (tiles.md, "Tile content patterns"): the count large, "ungelesen"
// and the app's name under it. At 0 it is gone and the tile shows its name. A new count peeks in through the tile's
// news and waits while the pointer or the focus is on the tile (live.md, "Holding still"); the first count is no news.
Stat {
    id: stat

    required property Tile owner
    required property int count
    property string app
    // The count the tile shows, which follows `count` through the tile's news.
    property int shown: 0
    readonly property bool showing: shown > 0

    visible: showing
    value: String(shown)
    label: `ungelesen · ${app}`

    // Only a number replacing a number peeks; one that comes or goes has no old or new number to move, and ends a peek
    // still running.
    onCountChanged: owner.news(count > 0 && shown > 0 ? "peek" : "", () => stat.shown = stat.count)
    Component.onCompleted: shown = count
}
