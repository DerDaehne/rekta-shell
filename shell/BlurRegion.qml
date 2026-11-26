import QtQuick
import Quickshell
import Rekta

// What a surface blurs behind its glass or shading. Under less transparency nothing blurs (colour.md, "More contrast,
// less transparency"; rekta.css:1619–1625). On the black ground glass is the ground, so nothing blurs behind it; a
// shading lies over the page and keeps its blur (colour.md:153–157; rekta.css:1612–1617).
Region {
    // The item to blur behind, or null for none.
    property Item behind
    // Whether the item is a shading, not glass.
    property bool shading: false

    item: Tokens.reducedTransparency || (Prefs.black && !shading) ? null : behind
}
