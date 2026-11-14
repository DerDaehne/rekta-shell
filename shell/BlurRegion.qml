import QtQuick
import Quickshell
import Rekta

// What a surface blurs behind its glass or shading. Under less transparency nothing blurs (colour.md, "More contrast,
// less transparency"; rekta.css:1560–1566).
Region {
    // The item to blur behind, or null for none.
    property Item behind

    item: Tokens.reducedTransparency ? null : behind
}
