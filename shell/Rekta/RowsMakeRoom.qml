import QtQuick

// The other rows of a list close the gap or make room (motion.md, "Reordering"); an arrival cut short still ends whole.
// A positioner's `move`. Rows unseen, their list hidden, move at once.
Transition {
    id: makeRoom

    readonly property int duration: ViewTransition.item?.visible ? Tokens.durationModerate : 0

    NumberAnimation {
        property: "y"
        duration: makeRoom.duration
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeBase
    }
    NumberAnimation {
        property: "opacity"
        to: 1
        duration: makeRoom.duration
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeBase
    }
}
