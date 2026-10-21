import QtQuick

// The facets a pivot picks between, one in sight at a time (motion.md, "Facet change"). The chosen facet comes in
// from the trailing edge going forward, from the leading edge going back, by slide-distance with a fade, over
// 0.75 × duration-moderate; the one left goes at once.
Item {
    id: facets

    property int currentIndex: 0
    property int previousIndex: 0
    // The first display stands still; only a change of facet slides (motion.md, "Next item, same place").
    property bool shown: false
    default property alias content: holder.data

    function showChosen() {
        for (let k = 0; k < holder.children.length; k++)
            holder.children[k].visible = k === currentIndex;
    }

    onCurrentIndexChanged: {
        showChosen();
        if (!shown)
            return;
        shift.x = (currentIndex > previousIndex ? 1 : -1) * Tokens.slideDistance;
        holder.opacity = 0;
        enter.restart();
        previousIndex = currentIndex;
    }
    Component.onCompleted: {
        previousIndex = currentIndex;
        showChosen();
        shown = true;
    }

    Item {
        id: holder

        objectName: "holder"
        width: facets.width
        height: facets.height
        transform: Translate {
            id: shift

            objectName: "shift"
        }

        onChildrenChanged: facets.showChosen()
    }

    ParallelAnimation {
        id: enter

        objectName: "enter"
        readonly property real duration: 0.75 * Tokens.durationModerate

        NumberAnimation {
            target: shift
            property: "x"
            to: 0
            duration: enter.duration
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeOut
        }
        NumberAnimation {
            target: holder
            property: "opacity"
            to: 1
            duration: enter.duration
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeOut
        }
    }
}
