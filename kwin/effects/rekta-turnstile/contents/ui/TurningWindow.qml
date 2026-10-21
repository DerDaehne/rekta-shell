import QtQuick
import org.kde.kwin as KWin
import Rekta

// One window turning as a part of a place. Leaving, it swings toward the viewer, whole for the first share of its
// time, then fading; arriving, it swings in from the other side, whole after its first share.
KWin.WindowThumbnail {
    id: part

    required property var modelData
    required property KWin.Output screen
    required property bool leaving
    required property bool back

    readonly property KWin.Window window: modelData.window
    readonly property real duration: modelData.duration
    // Forward, a leaving part swings its far side toward the viewer; the way back mirrors both turns.
    readonly property real direction: back ? 1 : -1
    readonly property real restAngle: 0
    readonly property real leftAngle: direction * Geometry.turnOutAngle
    readonly property real comingAngle: -direction * Geometry.turnInAngle

    signal landed

    client: window
    x: window.x - screen.geometry.x
    y: window.y - screen.geometry.y
    width: window.width
    height: window.height
    z: window.stackingOrder
    opacity: leaving ? 1 : 0

    transform: Rotation {
        id: turn

        axis {
            x: 0
            y: 1
            z: 0
        }
        origin.x: part.screen.geometry.x - part.window.x
        origin.y: part.modelData.originY
        distanceToPlane: part.modelData.perspective
        angle: part.leaving ? part.restAngle : part.comingAngle
    }

    SequentialAnimation {
        running: true

        PauseAnimation {
            duration: part.modelData.at
        }
        ParallelAnimation {
            NumberAnimation {
                target: turn
                property: "angle"
                to: part.leaving ? part.leftAngle : part.restAngle
                duration: part.duration
                easing.type: Easing.Bezier
                easing.bezierCurve: part.leaving ? Geometry.easeTurnOut : Geometry.easeTurnIn
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: part.leaving ? Geometry.turnOutWhole * part.duration : 0
                }
                NumberAnimation {
                    target: part
                    property: "opacity"
                    to: part.leaving ? 0 : 1
                    duration: (part.leaving ? 1 - Geometry.turnOutWhole : Geometry.turnInWhole) * part.duration
                    easing.type: Easing.Bezier
                    easing.bezierCurve: part.leaving ? Geometry.easeTurnOut : Geometry.easeTurnIn
                }
            }
        }
        ScriptAction {
            script: part.landed()
        }
    }
}
