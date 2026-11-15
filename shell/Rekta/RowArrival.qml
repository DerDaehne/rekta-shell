import QtQuick

// A row that arrives in a list slides in from above and fades up (motion.md, "Arriving, leaving"); a positioner's `add`.
// One that comes before rows that stay waits unseen at its start while they make room (RowsMakeRoom), the mirror of
// leaving, as a bar control waits for its neighbours, so nothing lies over anything. A row that arrives unseen, its list
// hidden, stands at once.
// ponytail: it waits for the glide its own arrival starts; a row coming after it within duration-moderate glides the
// rows below on a little longer.
Transition {
    id: arrival

    readonly property int duration: ViewTransition.item?.visible ? Tokens.durationShort : 0
    // Set as each arrival starts: a binding would wake on the neighbours too and read the row after it has gone.
    property int wait

    ViewTransition.onItemChanged: wait = rowsAfterStay() ? Tokens.durationModerate : 0

    // Whether a row shown after the arriving one was there before: it glides out of the arriving one's place. In a
    // hidden list none shows.
    function rowsAfterStay(): bool {
        const row = ViewTransition.item;
        const positioned = Array.from(row.parent.children).filter(child => child.visible && child.width > 0 && child.height > 0);
        const arriving = Array.from(ViewTransition.targetItems);
        return positioned.slice(positioned.indexOf(row) + 1).some(after => !arriving.includes(after));
    }

    SequentialAnimation {
        PropertyAction {
            property: "opacity"
            value: 0
        }
        PropertyAction {
            property: "y"
            // Only the Transition's ViewTransition is set: unqualified, it would be this action's own, at 0.
            value: arrival.ViewTransition.destination.y - Geometry.rowEnterShift
        }
        PauseAnimation {
            duration: arrival.wait
        }
        RowSlidesIn {
            duration: arrival.duration
        }
    }
}
