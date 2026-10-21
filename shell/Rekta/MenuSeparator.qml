import QtQuick

// The hairline between groups of a menu, with space-xs above and below (rekta.css:798).
Item {
    width: parent ? parent.width : 0
    implicitHeight: Geometry.hairline + 2 * Tokens.spaceXs

    Hairline {
        y: Tokens.spaceXs
        width: parent.width
    }
}
