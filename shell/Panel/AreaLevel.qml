pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The level of an area of the panel, which the area's opener tile opens (states.md:260–275; rekta.css:1135–1143). It
// stands in the panel's `levels`, over the facet below the panel's head, and scrolls when it is longer than that room.
// It starts with the back row "zurück · name", then the area's rows space-m apart, without the group's heading, as in
// Rekta's own panel (site/index.html:1008–1011). The focus goes in as it opens, to its first control, and back to its
// tile as it leaves: by the back row here, by Escape and ← through the panel.
Flickable {
    id: level

    property string name
    // The tile that opens it, where the focus goes back.
    property Item tile
    property bool open: false
    default property alias rows: list.data

    function show() {
        open = true;
        contentY = 0;
        const first = back.nextItemInFocusChain(true);
        (first && isMine(first) ? first : back).forceActiveFocus(Qt.TabFocusReason);
    }

    function leave() {
        if (!open)
            return;
        open = false;
        tile?.forceActiveFocus(Qt.TabFocusReason);
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
    }

    anchors.fill: parent
    visible: open
    contentWidth: width
    contentHeight: list.y + list.height + Tokens.spaceL
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

    // At the panel's content edge, space-m below its head as a sheet's parts stand (rekta.css:1095, :1143).
    Column {
        id: list

        objectName: "rows"
        x: Tokens.spaceM
        y: Tokens.spaceM
        width: level.width - 2 * Tokens.spaceM
        spacing: Tokens.spaceM

        // `.rk-in-back { padding: 0 }` (rekta.css:1129–1133): at the rows' edge.
        MenuItem {
            id: back

            objectName: "back"
            isBack: true
            inset: 0
            text: `zurück · ${level.name}`
            activeFocusOnTab: true
        }

        TapHandler {
            // A slow click is still a click.
            longPressThreshold: 0

            onTapped: eventPoint => {
                if (list.childAt(eventPoint.position.x, eventPoint.position.y) === back)
                    level.leave();
            }
        }
    }
}
