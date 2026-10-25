pragma ComponentBehavior: Bound

import QtQuick

// A long list (collections.md, "Long lists"; rekta.css:463–476; rekta.js virtual()): rows of any number on hairlines
// in a bounded scroller, where only the rows in view and a few either side exist. It is one tab stop; ↑ ↓ PageUp
// PageDown Home End move the active row, which shows the focus ring inside. A click, Enter or Space chooses a row the
// Metro way and shows it (`shown`); the choice stays until clear(). Its data states (states.md, "Data states"): while
// `loading`, the loading line runs on its first hairline over still placeholders; without rows it says `empty`.
FocusScope {
    id: list

    // {text, icon} for each row; icon is an image URL, empty for none.
    property var rows: []
    property bool loading: false
    // What is empty and why, said when there are no rows.
    property string empty
    // The chosen row, -1 for none.
    property int chosen: -1
    // The row the keys are on, -1 until the list first has the focus.
    property int active: -1
    // A scroller lets its rows turn one by one in a place change.
    readonly property bool turnsWhole: false

    signal shown(int index)

    function choose(index: int) {
        chosen = index;
        active = index;
        shown(index);
    }

    function clear() {
        chosen = -1;
        active = -1;
    }

    // Moves the active row there and scrolls just far enough to show it whole.
    function moveTo(index: int) {
        active = Math.max(0, Math.min(rows.length - 1, index));
        view.positionViewAtIndex(active, ListView.Contain);
    }

    // Where a key moves the active row, a page being the rows in view less one (rekta.js:2994–2995); undefined for a
    // key that does not.
    function target(key: int): var {
        const page = Math.max(1, Math.floor(view.height / Tokens.rowHeight) - 1);
        const moves = {
            [Qt.Key_Down]: active + 1,
            [Qt.Key_Up]: active - 1,
            [Qt.Key_PageDown]: active + page,
            [Qt.Key_PageUp]: active - page,
            [Qt.Key_Home]: 0,
            [Qt.Key_End]: rows.length - 1
        };
        return moves[key];
    }

    // The keyboard presses the row in its centre, and it lets go once the sink has played (rekta.js:321).
    function chooseActive() {
        const row = view.itemAtIndex(active) as ListRow;
        if (row) {
            row.press(0, 0);
            row.release(false);
        }
        choose(active);
    }

    activeFocusOnTab: true
    Accessible.role: Accessible.List

    // On focus the keys start from the first row in view (rekta.js:3006).
    onActiveFocusChanged: {
        if (activeFocus && active < 0 && rows.length > 0)
            active = Math.max(0, view.indexAt(0, view.contentY));
    }

    Keys.onPressed: event => {
        if (rows.length === 0 || (event.modifiers & Qt.AltModifier))
            return;
        const to = target(event.key);
        if (to !== undefined) {
            event.accepted = true;
            moveTo(active < 0 ? 0 : to);
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && active >= 0) {
            event.accepted = true;
            if (!event.isAutoRepeat)
                chooseActive();
        }
    }

    // The scroller's top border (rekta.css:464): the region starts at its first hairline.
    Hairline {
        width: list.width
    }

    BusyLine {
        objectName: "busy"
        width: list.width
        busy: list.loading
    }

    ListView {
        id: view

        objectName: "view"
        y: Geometry.hairline
        width: list.width
        height: list.height - y
        focus: true
        clip: true
        model: list.loading ? [] : list.rows
        cacheBuffer: Geometry.listRowsAround * Tokens.rowHeight
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false

        delegate: ListRow {
            required property int index
            required property var modelData

            width: view.width
            text: modelData.text
            icon: modelData.icon
            chosen: list.chosen === index
            ringed: list.activeFocus && list.active === index
            onClicked: list.choose(index)
        }
    }

    // Still placeholders hold the rows' place until the first rows come (rekta.css:673–674); nothing shimmers.
    Column {
        objectName: "ghosts"
        y: Geometry.hairline
        visible: list.loading

        Repeater {
            model: list.loading ? Math.max(0, Math.ceil(view.height / Tokens.rowHeight)) : 0

            delegate: Item {
                readonly property bool turnsWhole: true

                width: list.width
                height: Tokens.rowHeight

                Rectangle {
                    x: Geometry.listRowLead + Tokens.spaceS
                    anchors.verticalCenter: parent.verticalCenter
                    width: Geometry.ghostWidth * Tokens.fontSizeS
                    height: Geometry.ghostHeight * Tokens.fontSizeS
                    radius: Tokens.radiusS
                    color: Tokens.color.surface
                }

                Hairline {
                    y: parent.height - height
                }
            }
        }
    }

    // A sentence on the first hairline, in text-contrast-high, says what is empty (rekta.css:675).
    Body {
        objectName: "empty"
        y: Geometry.hairline + Tokens.spaceM
        width: list.width
        visible: !list.loading && list.rows.length === 0
        text: list.empty
        color: Tokens.color.textContrastHigh
    }

    // The list's own ring, outside (rekta.css:471).
    FocusRing {
        shown: list.activeFocus
    }
}
