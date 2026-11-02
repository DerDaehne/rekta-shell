import QtQuick
import Rekta

// The lock screen's clock: the time as the place's large light title (typography.md, navigation titles), at the display
// size, twice a navigation title, so it reads across a room (typography.md:94–102). On a monitor that is not the
// active one it is the inactive title, smaller by the navigation titles' ratio around its baseline, and it grows as a
// pivot title does when the monitor becomes the active one (motion.md, pivot strip).
NavTitle {
    id: clock

    readonly property real activeSize: Tokens.fluid(Tokens.fontSizeNavActive, placeWidth)
    // How far the inactive title is scaled down from the active one, as Pivot does it.
    readonly property real ratio: Tokens.fluid(Tokens.fontSizeNavInactive, placeWidth) / activeSize
    property real shrink: active ? 1 : ratio

    font.pixelSize: Tokens.fluid(Tokens.fontSizeDisplay, placeWidth)
    font.features: ({ "tnum": 1 })
    wrapMode: Text.NoWrap
    transform: Scale {
        origin.y: clock.baselineOffset
        xScale: clock.shrink
        yScale: clock.shrink
    }

    Behavior on shrink {
        NumberAnimation {
            duration: Tokens.durationPivotSize
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeInOut
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Tokens.durationShort
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeBase
        }
    }
}
