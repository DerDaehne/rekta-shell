import QtQuick
import Rekta

// The lock screen's clock: the time in Rekta's display step, light, with the title's line height (typography.md:94–101).
// On a monitor that is not the active one it is the inactive title (pivot-inactive, text-contrast-high), scaled down
// around its baseline, and it grows as a pivot title does when the monitor becomes the active one (motion.md, pivot strip).
NavTitle {
    id: clock

    // How far the inactive title is scaled down from the display step, as Pivot does it.
    readonly property real ratio: Tokens.fluid(Tokens.fontSizePivotInactive, placeWidth) / Tokens.fluid(Tokens.fontSizeDisplay, placeWidth)
    property real shrink: active ? 1 : ratio

    font.pixelSize: Tokens.fluid(Tokens.fontSizeDisplay, placeWidth)
    font.features: ({ "tnum": 1 })
    lineHeightFactor: Tokens.lineHeightTitle
    color: active ? Tokens.color.textPrimary : Tokens.color.textContrastHigh
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
