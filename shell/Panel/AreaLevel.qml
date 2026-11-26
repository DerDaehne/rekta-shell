pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The level of an area of the panel, which the area's opener tile opens (states.md:298–313; rekta.css:1150–1158). It
// stands in the panel's `levels`, over the facet below the panel's head, and scrolls when it is longer than that room.
// It starts with the back row "zurück · name", then the area's rows space-m apart, without the group's heading, as in
// Rekta's own panel (site/index.html:1029–1032). The focus goes in as it opens, to its first control, and back to its
// tile as it leaves: by the back row here, by Escape and ← through the panel. Choosing in place works inside it
// (states.md:241–252, :302–303): a list it opens (a PanelLevel among its `levels`) stands in place of its rows below its
// back row and slides in as the next item of a place.
Flickable {
    id: level

    property string name
    // The tile that opens it, where the focus goes back.
    property Item tile
    property bool open: false
    default property alias rows: list.data
    // Its lists chosen in place, one open at a time.
    property alias levels: chosenHolder.data
    readonly property PanelLevel chosen: Array.from(chosenHolder.children).find(child => (child as PanelLevel)?.open) ?? null

    function show() {
        open = true;
        contentY = 0;
        focusFirst();
    }

    function leave() {
        if (!open)
            return;
        open = false;
        tile?.forceActiveFocus(Qt.TabFocusReason);
    }

    // Its first control after the back row, else the back row (rekta.js:1998).
    function focusFirst() {
        const first = back.nextItemInFocusChain(true);
        (first && isMine(first) ? first : back).forceActiveFocus(Qt.TabFocusReason);
    }

    function isMine(item: Item): bool {
        for (let inside = item; inside; inside = inside.parent) {
            if (inside === level)
                return true;
        }
        return false;
    }

    // Places its rows now rather than at the next frame, so a change can be measured where it lands.
    function layOutNow() {
        list.forceLayout();
        column.forceLayout();
    }

    anchors.fill: parent
    visible: open
    contentWidth: width
    contentHeight: column.y + column.height + Tokens.spaceL
    interactive: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    onContentYChanged: Tips.hide()
    Accessible.role: Accessible.Pane
    Accessible.name: name

    Keys.onPressed: event => {
        const backKey = event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space;
        if (!backKey || !back.activeFocus)
            return;
        event.accepted = true;
        // A held key goes back once.
        if (!event.isAutoRepeat)
            leave();
    }

    // At the panel's content edge, space-m below its head as a sheet's parts stand (rekta.css:1110, :1158).
    Column {
        id: column

        x: Tokens.spaceM
        y: Tokens.spaceM
        width: level.width - 2 * Tokens.spaceM
        spacing: Tokens.spaceM

        // `.rk-in-back { padding: 0 }` (rekta.css:1144–1148): at the rows' edge.
        MenuItem {
            id: back

            objectName: "back"
            isBack: true
            inset: 0
            text: `zurück · ${level.name}`
            activeFocusOnTab: true
        }

        Facets {
            objectName: "parts"
            width: column.width
            height: level.chosen?.implicitHeight ?? list.implicitHeight
            currentIndex: level.chosen ? 1 : 0

            Column {
                id: list

                objectName: "rows"
                width: parent.width
                spacing: Tokens.spaceM
            }

            Item {
                id: chosenHolder

                width: parent.width
                height: level.chosen?.implicitHeight ?? 0
            }
        }

        TapHandler {
            // A slow click is still a click.
            longPressThreshold: 0

            onTapped: eventPoint => {
                if (column.childAt(eventPoint.position.x, eventPoint.position.y) === back)
                    level.leave();
            }
        }
    }
}
