import QtQuick

// A row that arrives in a list slides in from above and fades up (motion.md, "Arriving, leaving"); a positioner's `add`.
// A row that arrives unseen, its list hidden, stands at once.
Transition {
    id: arrival

    readonly property int duration: ViewTransition.item?.visible ? Tokens.durationShort : 0

    NumberAnimation {
        property: "y"
        from: ViewTransition.destination.y - Geometry.rowEnterShift
        duration: arrival.duration
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
    }
    NumberAnimation {
        property: "opacity"
        from: 0
        to: 1
        duration: arrival.duration
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
    }
}
