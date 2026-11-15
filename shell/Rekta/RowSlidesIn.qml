import QtQuick

// The end of a row's arrival in a list: from its start just above its place it slides in and fades up (motion.md,
// "Arriving, leaving"). A step of a positioner's transition, which set the row at its start before.
ParallelAnimation {
    id: slidesIn

    property int duration

    NumberAnimation {
        property: "y"
        duration: slidesIn.duration
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
    }
    NumberAnimation {
        property: "opacity"
        to: 1
        duration: slidesIn.duration
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
    }
}
