import QtQuick
import QtQuick.Shapes
import "IconData.js" as IconData

// One of Rekta's icons, drawn on its 20 grid in the given colour; the stroke scales with the size. No name draws nothing.
Item {
    id: icon

    property string name
    property real size: IconData.grid
    property color color: Tokens.color.textPrimary

    readonly property var paths: IconData.icons[name] ?? null

    implicitWidth: size
    implicitHeight: size

    function warnIfUnknown() {
        if (!paths && name !== "")
            console.warn(`Icon: no icon named "${name}"`);
    }

    onPathsChanged: warnIfUnknown()
    Component.onCompleted: warnIfUnknown()

    Shape {
        width: IconData.grid
        height: IconData.grid
        scale: icon.size / IconData.grid
        transformOrigin: Item.TopLeft
        visible: icon.paths !== null
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            objectName: "stroke"
            strokeColor: icon.color
            strokeWidth: IconData.strokeWidth
            fillColor: "transparent"
            capStyle: ({ butt: ShapePath.FlatCap, square: ShapePath.SquareCap, round: ShapePath.RoundCap })[IconData.lineCap]
            joinStyle: ({ miter: ShapePath.MiterJoin, bevel: ShapePath.BevelJoin, round: ShapePath.RoundJoin })[IconData.lineJoin]

            PathSvg {
                path: icon.paths?.stroke ?? ""
            }
        }

        ShapePath {
            objectName: "fill"
            strokeColor: "transparent"
            fillColor: icon.color

            PathSvg {
                path: icon.paths?.fill ?? ""
            }
        }
    }
}
