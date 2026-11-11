import QtQuick

// The other rows of a list close the gap or make room (motion.md, "Reordering"); an arrival cut short still ends whole.
// A positioner's `move`.
Transition {
    NumberAnimation {
        property: "y"
        duration: Tokens.durationModerate
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeBase
    }
    NumberAnimation {
        property: "opacity"
        to: 1
        duration: Tokens.durationModerate
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeBase
    }
}
