import QtQuick

// The other rows of a list close the gap or make room (motion.md, "Reordering"); an arrival cut short still ends whole.
// One still waiting unseen for room (RowArrival) glides on unseen at its start, just above its new place, and arrives
// once the rows after it have landed with it, so it never shows before they have made room. A positioner's `move`.
// Rows unseen, their list hidden, move at once.
Transition {
    id: makeRoom

    readonly property int duration: ViewTransition.item?.visible ? Tokens.durationModerate : 0
    // Set as each glide starts, as RowArrival's wait is.
    property bool waiting

    ViewTransition.onItemChanged: waiting = ViewTransition.item.opacity === 0

    SequentialAnimation {
        ParallelAnimation {
            NumberAnimation {
                property: "y"
                // Only the Transition's ViewTransition is set: unqualified, it would be this animation's own, at 0.
                to: makeRoom.ViewTransition.destination.y - (makeRoom.waiting ? Geometry.rowEnterShift : 0)
                duration: makeRoom.duration
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeBase
            }
            NumberAnimation {
                property: "opacity"
                to: makeRoom.waiting ? 0 : 1
                duration: makeRoom.duration
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeBase
            }
        }
        RowSlidesIn {
            duration: makeRoom.waiting && makeRoom.duration > 0 ? Tokens.durationShort : 0
        }
    }
}
