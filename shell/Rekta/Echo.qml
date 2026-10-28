pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// The shell's background mark, a faint print of six tiles whose strength fades out from the bottom right corner. The
// cells are the real tile unit (layout.md:105, :134), with space-s between them. Rekta
// has no ground for a whole workspace; the mix, the pattern and the fade are the shell's own choice,
// proposed to Rekta Design, and stay here as literals until Rekta names them.
Item {
    id: echo

    readonly property real cell: Tokens.tileUnit
    readonly property real gap: Tokens.spaceS
    readonly property int columns: 4
    readonly property int rows: 3
    // The tiles in reading order as grid cells: a wide one, two, a tall one, one, a wide one.
    readonly property var pattern: [
        { column: 0, row: 0, columns: 2, rows: 1 },
        { column: 2, row: 0, columns: 1, rows: 1 },
        { column: 3, row: 0, columns: 1, rows: 1 },
        { column: 0, row: 1, columns: 1, rows: 2 },
        { column: 1, row: 1, columns: 1, rows: 1 },
        { column: 2, row: 1, columns: 2, rows: 1 }
    ]
    // The surface colour mixed 70% into the ground (sRGB).
    readonly property color tint: Qt.tint(Tokens.color.bg, Qt.rgba(Tokens.color.surface.r, Tokens.color.surface.g, Tokens.color.surface.b, 0.7))
    // The fade as a CSS mask would say it: a circle at the bottom right corner, opaque to 15% of its radius, clear from 80%, the radius reaching the farthest corner.
    readonly property real fadeFull: 0.15
    readonly property real fadeGone: 0.8

    function tileRect(tile: var): rect {
        return Qt.rect(tile.column * (cell + gap), tile.row * (cell + gap), tile.columns * cell + (tile.columns - 1) * gap, tile.rows * cell + (tile.rows - 1) * gap);
    }

    width: columns * cell + (columns - 1) * gap
    height: rows * cell + (rows - 1) * gap
    Repeater {
        model: echo.pattern

        Rectangle {
            id: tile

            required property var modelData
            readonly property rect box: echo.tileRect(modelData)

            x: box.x
            y: box.y
            width: box.width
            height: box.height
            radius: Tokens.radiusTile
            color: echo.tint
        }
    }

    // The fade is a veil in the colour of the ground behind, clear up to fadeFull and solid from fadeGone, which shows the
    // same as masking the tiles while the ground stays plain.
    Shape {
        anchors.fill: parent

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: echo.width
                centerY: echo.height
                centerRadius: Math.hypot(echo.width, echo.height)
                focalX: centerX
                focalY: centerY
                GradientStop { position: echo.fadeFull; color: Qt.alpha(Tokens.color.bg, 0) }
                GradientStop { position: echo.fadeGone; color: Tokens.color.bg }
            }
            PathRectangle { x: 0; y: 0; width: echo.width; height: echo.height }
        }
    }
}
