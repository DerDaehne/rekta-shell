pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The side panel, the shell's own surface (Rekta has no side panel yet): two tile units wide with a sheet's padding
// (rekta.css:827), the full height of its host at the trailing edge, on the ground with a hairline along its leading
// edge. It slides all the way in from the trailing edge over duration-moderate with ease-out and leaves the way it came
// in 0.8 × that, as a sheet leaves (motion.md, "Sheets"); nothing beside it is shaded or blocked. Its pivot picks a
// facet. Escape and close() send it away. Focus starts at the first control of the facet in sight, Tab and ↑ ↓ move
// through the controls, and once the panel has gone the focus goes back.
FocusScope {
    id: sidePanel

    property list<string> titles
    readonly property alias currentIndex: pivot.currentIndex
    // From show() until it has gone; a host shows its surface while this holds.
    property bool open: false
    // Runs from 0 to 1 as it comes in, and back to 0 as it leaves.
    property real entry: 1
    readonly property real contentWidth: 2.5 * Tokens.tileUnit + Tokens.spaceS
    readonly property real panelWidth: Geometry.hairline + 2 * Tokens.spaceM + contentWidth
    readonly property real shift: (1 - entry) * panelWidth
    default property alias facets: facetHolder.content

    // It has gone.
    signal closed

    // Opens on a facet, or turns to it while open; while it leaves, it comes back.
    function show(index: int) {
        if (!open) {
            standOn(index);
            memo.focused = Window.activeFocusItem;
            open = true;
            entry = 0;
        } else {
            pivot.select(index);
            if (!going.running)
                return;
        }
        going.stop();
        comingIn.restart();
        focusFirst();
    }

    // Scrolls the facet so an item of it stands at the top, or to the top without one. The facet lays itself out at its
    // next polish, so the place is taken again once that has run.
    function reveal(item: Item) {
        const scroll = () => scroller.contentY = item ? Math.max(0, Math.min(item.mapToItem(scroller.contentItem, 0, 0).y, scroller.contentHeight - scroller.height)) : 0;
        scroll();
        Qt.callLater(scroll);
    }

    function close() {
        if (!open || going.running)
            return;
        comingIn.stop();
        going.start();
    }

    // Closes when that facet shows already, else shows it.
    function toggle(index: int) {
        if (open && !going.running && currentIndex === index)
            close();
        else
            show(index);
    }

    // While the panel is away a new facet is simply there as it comes: the facet does not slide in.
    function standOn(index: int) {
        facetHolder.shown = false;
        pivot.currentIndex = index;
        facetHolder.previousIndex = index;
        facetHolder.shown = true;
        pivot.rest();
    }

    // The first control of the facet in sight, else the pivot.
    function focusFirst() {
        const first = pivot.nextItemInFocusChain(true);
        (first && holds(first) ? first : pivot).forceActiveFocus(Qt.TabFocusReason);
    }

    function moveFocus(forward: bool) {
        const next = Window.activeFocusItem?.nextItemInFocusChain(forward);
        if (next && holds(next))
            next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
    }

    function gone() {
        open = false;
        // The focus goes back only to something that still shows (rekta.js:2424).
        if (memo.focused?.visible)
            memo.focused.forceActiveFocus();
        closed();
    }

    function holds(item: Item): bool {
        for (let inside = item; inside; inside = inside.parent) {
            if (inside === panel)
                return true;
        }
        return false;
    }

    visible: open

    // Controls take their keys first; the rest come here, and what the panel leaves goes to the key layers, such as
    // Ctrl+Z for an open undo toast.
    Keys.onPressed: event => {
        if (!open)
            return;
        if (event.key === Qt.Key_Escape)
            close();
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up)
            moveFocus(event.key === Qt.Key_Down);
        else
            return KeyLayers.dispatch(event, Window.activeFocusItem);
        event.accepted = true;
    }

    QtObject {
        id: memo

        property Item focused
    }

    NumberAnimation {
        id: comingIn

        objectName: "comingIn"
        target: sidePanel
        property: "entry"
        to: 1
        duration: Tokens.durationModerate
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeOut
    }

    NumberAnimation {
        id: going

        objectName: "goingOut"
        target: sidePanel
        property: "entry"
        to: 0
        duration: 0.8 * Tokens.durationModerate
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeOut
        onFinished: sidePanel.gone()
    }

    // The hairline along its leading edge shows under the ground, as a sheet's does along its bottom (rekta.css:828).
    Rectangle {
        id: panel

        objectName: "panel"
        x: sidePanel.width - sidePanel.panelWidth + sidePanel.shift
        width: sidePanel.panelWidth
        height: sidePanel.height
        color: Tokens.color.textContrastLow
        Accessible.role: Accessible.Pane
        Accessible.name: sidePanel.titles[sidePanel.currentIndex] ?? ""

        Rectangle {
            objectName: "ground"
            x: Geometry.hairline
            width: parent.width - Geometry.hairline
            height: parent.height
            color: Tokens.color.bg

            // A place's strip, the nav level; at this width it takes the facet sizes (Pivot, compact).
            Pivot {
                id: pivot

                objectName: "pivot"
                x: Tokens.spaceM
                y: Tokens.spaceL
                width: sidePanel.contentWidth
                level: "nav"
                titles: sidePanel.titles
                placeWidth: sidePanel.contentWidth
                viewportHeight: sidePanel.height
            }

            // A compact place's strip has a hairline below it (rekta.css:864–868).
            Hairline {
                objectName: "underPivot"
                x: Tokens.spaceM
                y: pivot.y + pivot.height
                width: sidePanel.contentWidth
            }

            // As wide as the ground, so the focus ring of a control at the content's edge is not cut off.
            Flickable {
                id: scroller

                objectName: "scroller"
                y: pivot.y + pivot.height + Geometry.hairline
                width: parent.width
                height: parent.height - y - Tokens.spaceL
                contentWidth: width
                contentHeight: facetHolder.height
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Facets {
                    id: facetHolder

                    objectName: "facets"
                    x: Tokens.spaceM
                    width: sidePanel.contentWidth
                    height: (sidePanel.facets[currentIndex] as Item)?.implicitHeight ?? 0
                    currentIndex: pivot.currentIndex
                }
            }
        }
    }
}
