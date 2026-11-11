import QtQuick

// A row that arrives in a list slides in from above and fades up (motion.md, "Arriving, leaving"); a positioner's `add`.
Transition {
    NumberAnimation {
        property: "y"
        from: ViewTransition.destination.y - Geometry.rowEnterShift
        duration: Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
    }
    NumberAnimation {
        property: "opacity"
        from: 0
        to: 1
        duration: Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
    }
}
