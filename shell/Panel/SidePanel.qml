pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The side panel, the shell's own surface (Rekta has no side panel yet): two tile units wide with a sheet's padding
// (rekta.css:827), the full height of its host at the trailing edge, on the ground with a hairline along its leading
// edge. It slides all the way in from the trailing edge over duration-moderate with ease-out and leaves the way it came
// in 0.8 × that, as a sheet leaves (motion.md, "Sheets"); nothing beside it is shaded or blocked. Its pivot picks a
// facet. Escape and close() send it away. Focus starts at the first control of the facet in sight, Tab and ↑ ↓ move
// through the controls, and once the panel has gone the focus goes back. A sheet a facet opens lies over the panel's
// ground (`sheets`); while one is open the panel keeps still.
FocusScope {
    id: sidePanel

    property list<string> titles
    readonly property alias currentIndex: pivot.currentIndex
    // From show() until it has gone; a host shows its surface while this holds.
    property bool open: false
    // Opened by a pointer: no focus ring shows until the focus moves (`:focus-visible`).
    property bool ringsHidden: false
    // The item of the facet that stays at the top of the view, until a hand moves it.
    property Item revealed: null
    property real settledHeight: 0
    property int quietFrames: 0
    // Runs from 0 to 1 as it comes in, and back to 0 as it leaves.
    property real entry: 1
    readonly property real contentWidth: 2.5 * Tokens.tileUnit + Tokens.spaceS
    readonly property real panelWidth: Geometry.hairline + 2 * Tokens.spaceM + contentWidth
    readonly property real shift: (1 - entry) * panelWidth
    default property alias facets: facetHolder.content
    // Where a facet's sheets stand: over the whole ground, pivot included.
    readonly property Item sheets: sheetHolder
    readonly property bool sheetOpen: Array.from(sheetHolder.children).some(child => child.open === true)

    // It has gone.
    signal closed

    // Opens on a facet, or turns to it while open; while it leaves, it comes back.
    function show(index: int, byPointer: bool) {
        if (!open) {
            standOn(index);
            memo.focused = Window.activeFocusItem;
            open = true;
            entry = 0;
        } else {
            pivot.select(index);
            ringsHidden = byPointer;
            if (!going.running)
                return;
        }
        going.stop();
        comingIn.restart();
        focusFirst();
        ringsHidden = byPointer;
    }

    // Scrolls the facet so an item of it stands at the top, or to the top without one, and puts the focus on the item's
    // first control. The facet lays itself out when it first shows, which moves the item and grows the content: the item
    // is kept at the top through the frames that change the content, and let go after two frames without a change or when
    // a hand moves the view. An item that does not show leaves the view at the top.
    function reveal(item: Item) {
        revealed = item?.visible ? item : null;
        settledHeight = scroller.contentHeight;
        quietFrames = 0;
        keepRevealed();
        if (revealed)
            focusIn(revealed);
    }

    // A frame has been drawn: content that changed takes the place again; two frames in a row without a change end the
    // hold (one may be a frame from before the panel showed, which reaches this thread late).
    function settle() {
        if (scroller.contentHeight !== settledHeight) {
            settledHeight = scroller.contentHeight;
            quietFrames = 0;
            keepRevealed();
        } else if (++quietFrames >= 2) {
            revealed = null;
            return;
        }
        Window.window.update();
    }

    function keepRevealedIfAny() {
        if (revealed)
            keepRevealed();
    }

    function keepRevealed() {
        scroller.contentY = revealed ? Math.max(0, Math.min(revealed.mapToItem(scroller.contentItem, 0, 0).y, scroller.contentHeight - scroller.height)) : 0;
    }

    // The first control inside an item, if it has one.
    function focusIn(item: Item) {
        const first = item.nextItemInFocusChain(true);
        if (first && within(item, first))
            first.forceActiveFocus(Qt.TabFocusReason);
    }

    function close() {
        if (!open || going.running)
            return;
        comingIn.stop();
        going.start();
    }

    // Closes when that facet shows already, else shows it.
    function toggle(index: int, byPointer: bool) {
        if (open && !going.running && currentIndex === index)
            close();
        else
            show(index, byPointer);
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
        memo.chosen = first && holds(first) ? first : pivot;
        memo.chosen.forceActiveFocus(Qt.TabFocusReason);
    }

    function moveFocus(forward: bool) {
        const next = Window.activeFocusItem?.nextItemInFocusChain(forward);
        if (next && holds(next))
            next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
    }

    function gone() {
        open = false;
        revealed = null;
        // The focus goes back only to something that still shows (rekta.js:2424).
        if (memo.focused?.visible)
            memo.focused.forceActiveFocus();
        closed();
    }

    function holds(item: Item): bool {
        return within(panel, item);
    }

    function within(ancestor: Item, item: Item): bool {
        for (let inside = item; inside; inside = inside.parent) {
            if (inside === ancestor)
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
        ringsHidden = false;
        if (sheetOpen) {
            // The sheet's own keys (Escape) go to the layers; the arrows do not walk the panel behind it, Tab stays its own.
            event.accepted = KeyLayers.dispatch(event, Window.activeFocusItem) || event.key === Qt.Key_Up || event.key === Qt.Key_Down;
            return;
        }
        if (event.key === Qt.Key_Escape)
            close();
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up)
            moveFocus(event.key === Qt.Key_Down);
        else
            return KeyLayers.dispatch(event, Window.activeFocusItem);
        event.accepted = true;
    }

    // Focus that moves to another control is the keyboard's (a pointer press gives none). The window's own activation
    // hands the focus to the control the panel chose, which is no move.
    Connections {
        target: sidePanel.open ? sidePanel.Window.window : null

        function onActiveFocusItemChanged() {
            const now = sidePanel.Window.window.activeFocusItem;
            if (now && now !== memo.chosen)
                sidePanel.ringsHidden = false;
        }
    }

    Connections {
        target: pivot

        function onKeyed() {
            sidePanel.ringsHidden = false;
        }
    }

    Connections {
        target: sidePanel.revealed ? sidePanel.Window.window : null

        function onFrameSwapped() {
            sidePanel.settle();
        }
    }

    QtObject {
        id: memo

        property Item focused
        // The control the panel put the focus on when it opened.
        property Item chosen
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
                onContentHeightChanged: sidePanel.keepRevealedIfAny()
                onMovementStarted: sidePanel.revealed = null
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

            Item {
                id: sheetHolder

                objectName: "sheets"
                anchors.fill: parent
            }
        }
    }
}
