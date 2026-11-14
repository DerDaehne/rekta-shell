pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The side panel, the shell's own surface: two tile units wide with a sheet's padding (rekta.css:1067), the full height
// of its host at the trailing edge, on the ground with a hairline along its leading edge. It slides all the way in from
// the trailing edge over duration-moderate with ease-out and leaves the way it came in 0.8 × that, as a sheet leaves
// (motion.md, "Sheets"); unlike Rekta's side panel (`.rk-sheet--side`, rekta.css:1095–1106) nothing beside it is shaded
// or blocked and it arrives on ease-out. Its pivot picks a facet. Escape, its close button at the top trailing corner
// (states.md:243–247), a touch swipe towards the trailing edge and close() send it away; a tip that shows takes Escape
// first. A swipe from its host (drawIn(), drawOut()) moves it as a finger on it does. Focus starts at the first control of the facet in sight, Tab and ↑ ↓ move through the controls, and
// once the panel has gone the focus goes back. A sheet a facet opens lies over the panel's ground (`sheets`); while one
// is open the panel keeps still. A press anywhere in it hides a tip, as scrolling does.
// What a facet keeps at hand stands at the panel's edge nearest the app bar (`edge`), below its scroll: the app bar is
// at the bottom, so that is the bottom edge.
FocusScope {
    id: sidePanel

    property list<string> titles
    readonly property alias currentIndex: pivot.currentIndex
    // From show() until it has gone; a host shows its surface while this holds.
    property bool open: false
    // Opened by a pointer: no focus ring shows until a key is pressed (`:focus-visible`).
    property bool ringsHidden: false
    // A text cut short in it shows whole in its tip (states.md:179–180), which its own tooltip draws.
    readonly property bool overflowTips: true
    // Where the lists of its selects float (FloatAnchor).
    readonly property Item floatLayer: floats
    // The item of the facet that stays at the top of the view, until a hand moves it.
    property Item revealed: null
    property real settledHeight: 0
    property int quietFrames: 0
    // Runs from 0 to 1 as it comes in, and back to 0 as it leaves.
    property real entry: 1
    // A swipe draws it in from away, or out from open, until it lets go.
    property bool drawingIn: false
    property bool drawingOut: false
    readonly property real contentWidth: 2.5 * Tokens.tileUnit + Tokens.spaceS
    readonly property real panelWidth: Geometry.hairline + 2 * Tokens.spaceM + contentWidth
    readonly property real shift: (1 - entry) * panelWidth
    default property alias facets: facetHolder.content
    // Where a facet's sheets stand: over the whole ground, pivot included.
    readonly property Item sheets: sheetHolder
    // Where a facet's quick settings stand: out of its scroll, at the edge nearest the app bar.
    readonly property Item edge: edgeHolder
    readonly property bool sheetOpen: Array.from(sheetHolder.children).some(child => child.open === true)

    // It has gone.
    signal closed

    // Opens on a facet, or turns to it while open; while it leaves, or a swipe draws it in, it comes in.
    function show(index: int, byPointer: bool) {
        if (!open) {
            appear(index);
        } else {
            pivot.select(index);
            ringsHidden = byPointer;
            if (!going.running && !drawingIn)
                return;
        }
        drawingIn = false;
        going.stop();
        comingIn.restart();
        ringsHidden = byPointer;
        focusFirst();
    }

    // Scrolls the facet so an item of it stands at the top, or to the top without one, and puts the focus on the item's
    // first control. The facet lays itself out when it first shows, which moves the item and grows the content: the item
    // is kept at the top through the frames that change the content, and let go after two frames without a change or when
    // a hand moves the view. An item that does not show leaves the view at the top; one at the edge is always in view and
    // only takes the focus.
    function reveal(item: Item) {
        const shown = item?.visible ?? false;
        revealed = shown && within(scroller, item) ? item : null;
        settledHeight = scroller.contentHeight;
        quietFrames = 0;
        keepRevealed();
        if (shown)
            focusIn(item);
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

    // The item itself where it is a control, else the first control inside it, if it has one.
    function focusIn(item: Item) {
        const first = item.activeFocusOnTab ? item : item.nextItemInFocusChain(true);
        if (first && within(item, first))
            first.forceActiveFocus(Qt.TabFocusReason);
    }

    // Shows on a facet from wholly beyond the trailing edge, keeping where the focus was to give it back.
    function appear(index: int) {
        standOn(index);
        memo.focused = Window.activeFocusItem;
        open = true;
        entry = 0;
    }

    function close() {
        if (!open || going.running)
            return;
        drawingIn = false;
        drawingOut = false;
        comingIn.stop();
        going.start();
    }

    // A swipe draws it in on "steuerung", `share` of its width, while it is away or this swipe draws it; a swipe that
    // has not come in yet opens nothing. It follows the swipe also under reduced motion, as it is moved by hand.
    function drawIn(share: real) {
        if (!drawingIn && (open || share <= 0))
            return;
        if (!open) {
            appear(0);
            ringsHidden = true;
            drawingIn = true;
        }
        entry = Math.min(Math.max(0, share), 1);
    }

    // Let go at half its width or more (the half as at pull()), it comes in all the way with the focus on its first
    // control; before, it goes and gives the focus back.
    function letGoIn() {
        if (!drawingIn)
            return;
        drawingIn = false;
        if (entry < 0.5) {
            close();
            return;
        }
        comingIn.restart();
        focusFirst();
    }

    // A swipe draws the open panel out, `share` of its width, as a finger on it does; not over an open sheet.
    function drawOut(share: real) {
        if (!drawingOut && (!open || drawingIn || going.running || sheetOpen))
            return;
        drawingOut = true;
        pull(share * panelWidth);
    }

    function letGoOut() {
        if (!drawingOut)
            return;
        drawingOut = false;
        letGo();
    }

    // A finger pulls it towards the trailing edge; let go past half its width it goes on out, else it comes back.
    // ponytail: Rekta has no swipe for a side panel; the half is its row dragged away (behaviour.md:1143–1147,
    // motion.md:25), the way back the panel's own way in, and no flick speed counts. Take Rekta's rule once it has one.
    function pull(by: real) {
        comingIn.stop();
        entry = 1 - Math.min(Math.max(0, by), panelWidth) / panelWidth;
    }

    function letGo() {
        if (entry <= 0.5)
            close();
        else
            comingIn.restart();
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
        (first && holds(first) && first !== closeButton ? first : pivot).forceActiveFocus(Qt.TabFocusReason);
    }

    // The control that holds the focus tells the panel of every key before its own handlers see it, also one it takes.
    function watchKeysOf(item: Item) {
        item.Keys.forwardTo = [keyHook];
    }

    // Focus that lands in the facet's scroll brings its control whole into view, ring included (rekta.css:46: focus
    // scrolls clear of what is pinned; the scroll ends space-m above the edge).
    function revealFocus(item: Item) {
        if (within(scroller, item))
            Reveal.intoView(item, item.height, Geometry.focusRingOffset + Geometry.focusRingWidth);
    }

    function moveFocus(forward: bool) {
        const next = Window.activeFocusItem?.nextItemInFocusChain(forward);
        if (next && holds(next))
            next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
    }

    function gone() {
        open = false;
        revealed = null;
        // The focus goes back only to something that still shows (rekta.js:2887).
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

    // Controls take their keys first; the rest go to the key layers (a tip's or a sheet's Escape, Ctrl+Z for an open
    // undo toast), and what no layer takes is the panel's.
    Keys.onPressed: event => {
        if (!open || KeyLayers.dispatch(event, Window.activeFocusItem))
            return;
        if (sheetOpen) {
            // The arrows do not walk the panel behind a sheet, and Tab stays the sheet's own.
            event.accepted = event.key === Qt.Key_Up || event.key === Qt.Key_Down;
            return;
        }
        if (event.key === Qt.Key_Escape)
            close();
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up)
            moveFocus(event.key === Qt.Key_Down);
        else
            return;
        event.accepted = true;
    }

    // Whichever control holds the focus is watched for keys, also after the window's activation moves the focus to it,
    // and kept in view.
    Connections {
        target: sidePanel.open ? sidePanel.Window.window : null

        function onActiveFocusItemChanged() {
            const now = sidePanel.Window.window.activeFocusItem;
            if (!now)
                return;
            sidePanel.watchKeysOf(now);
            sidePanel.revealFocus(now);
        }
    }

    Item {
        id: keyHook

        Keys.onPressed: event => {
            sidePanel.ringsHidden = false;
            event.accepted = false;
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

    // The hairline along its leading edge shows under the ground, as a sheet's does along its bottom (rekta.css:1068).
    Rectangle {
        id: panel

        objectName: "panel"
        x: sidePanel.width - sidePanel.panelWidth + sidePanel.shift
        width: sidePanel.panelWidth
        height: sidePanel.height
        color: Tokens.color.textContrastLow
        Accessible.role: Accessible.Pane
        Accessible.name: sidePanel.titles[sidePanel.currentIndex] ?? ""

        // Touch only: a mouse drag selects or scrolls, it never sends the panel away.
        DragHandler {
            objectName: "swipe"
            target: null
            acceptedDevices: PointerDevice.TouchScreen
            yAxis.enabled: false
            enabled: sidePanel.open && !going.running && !sidePanel.sheetOpen
            onActiveTranslationChanged: {
                if (active)
                    sidePanel.pull(activeTranslation.x);
            }
            onActiveChanged: {
                if (!active)
                    sidePanel.letGo();
            }
        }

        Rectangle {
            objectName: "ground"
            x: Geometry.hairline
            width: parent.width - Geometry.hairline
            height: parent.height
            color: Tokens.color.bg
            // Nothing in it paints over the hairline, as a sheet cuts its content off at its padding box (rekta.css:1066,
            // :1101), not even the quick settings at the edge on their way in with a facet.
            clip: true

            // A place's strip, the nav level; at this width it takes the facet sizes (Pivot, compact).
            Pivot {
                id: pivot

                objectName: "pivot"
                x: Tokens.spaceM
                y: Tokens.spaceL
                // Clear of the close button, as a sheet's kicker is (rekta.css:1092).
                width: sidePanel.contentWidth - Tokens.touchTarget
                level: "nav"
                titles: sidePanel.titles
                placeWidth: sidePanel.contentWidth
                viewportHeight: sidePanel.height
            }

            // A compact place's strip has a hairline below it (rekta.css:1135–1139).
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
                // Above the edge's quick settings, space-m from them as a sheet's parts are (rekta.css:1076).
                height: (edgeHolder.height > 0 ? edgeHolder.y - Tokens.spaceM : parent.height - Tokens.spaceL) - y
                contentWidth: width
                contentHeight: facetHolder.height
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                onContentHeightChanged: sidePanel.keepRevealedIfAny()
                onContentYChanged: Tips.hide()
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

            // On the sheet's padding at the bottom (rekta.css:1100); as tall as what shows in it. What stands here belongs to
            // the facet in sight, so it comes in with it.
            Item {
                id: edgeHolder

                readonly property Item shown: Array.from(children).find(child => child.visible) ?? null

                objectName: "edge"
                x: Tokens.spaceM
                y: parent.height - Tokens.spaceL - height
                width: sidePanel.contentWidth
                height: shown?.implicitHeight ?? 0
                opacity: facetHolder.entryOpacity
                transform: Translate {
                    objectName: "edgeShift"
                    x: facetHolder.entryShift
                }
            }

            // `.rk-sheet-close { position: absolute; top: space-xs; right: space-xs }` (rekta.css:1091); last in the
            // focus chain, as in a sheet's form (forms.md:246), and under the facet's sheets.
            IconButton {
                id: closeButton

                objectName: "close"
                x: parent.width - Tokens.spaceXs - width
                y: Tokens.spaceXs
                icon: "close"
                label: "schließen"
                variant: "quiet"
                onClicked: sidePanel.close()
            }

            Item {
                id: sheetHolder

                objectName: "sheets"
                anchors.fill: parent
            }

            // The lists of the panel's selects, over its sheets and under its tip.
            Item {
                id: floats

                objectName: "floats"
                anchors.fill: parent
                z: Tokens.layerFloat
            }

            // The tip of any control in the panel's window, its sheets' and lists' included, over them all; it slides
            // with the panel. The view scrolling hides it, as a press does (rekta.js tips()).
            Tooltip {
                id: tip

                // Placed again when the facet's content changes its height (a branch unfolds, a second player comes),
                // which moves the controls in it.
                readonly property var place: target && facetHolder.height >= 0 ? Placement.tip(parent.mapFromItem(target, 0, 0, target.width, target.height), Qt.size(width, height), area) : null

                objectName: "tip"
                area: Qt.size(parent.width, parent.height)
                x: place?.x ?? 0
                y: place?.y ?? 0
                side: place?.side ?? "above"
            }
        }
    }

    PressHidesTips {}
}
