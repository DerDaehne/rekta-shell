import QtQuick
import Rekta

// Rows that unfold below the row that opened them and push what stands below down; nothing floats. It unfolds and folds
// as a tree branch does (motion.md, "Tree branch"; rekta.js:3336, :3339): the height grows with a fade, in
// duration-short on ease-in, and closes in 0.7 of that on ease-out. Its rows are MenuItems; pressing one, or Enter or
// Space on it, says so in `activated`. Escape folds it and the focus goes back to what opened it; opened from elsewhere,
// the focus goes to its first row. While it unfolds it keeps itself in view in the scroller it stands in; once open it
// leaves the view alone.
Item {
    id: branch

    property bool expanded: false
    // Runs from 0 to 1 as it unfolds, and back as it folds.
    property real unfolded: 0
    // From the start of an unfold until the column has placed it.
    property bool revealing: false
    // The control in its row that opens it.
    property Item opener
    // What opened it last, its opener or a control elsewhere; the focus goes back there.
    property Item openedBy
    // Opened from elsewhere than its opener: the focus goes to its first row once it shows.
    property bool focusOnShow: false
    property var removeEscapeLayer: () => {}
    default property alias rows: list.data

    signal activated(MenuItem row)

    function expand() {
        openedBy = opener;
        expanded = true;
        revealing = true;
        settle.stop();
        folding.stop();
        unfolding.start();
    }

    function collapse() {
        expanded = false;
        revealing = false;
        focusOnShow = false;
        unfolding.stop();
        folding.start();
    }

    function toggle() {
        if (expanded)
            collapse();
        else
            expand();
    }

    // Opened by a control elsewhere: unfolds with the focus on its first row, or on its opener while it has none.
    function expandFocused(control: Item) {
        focusOnShow = true;
        expand();
        openedBy = control;
        focusFirstRowOnceShown();
    }

    // Its rows show only once it shows itself.
    function focusFirstRowOnceShown() {
        if (!focusOnShow || !visible)
            return;
        focusOnShow = false;
        const first = Array.from(list.children).find(row => row instanceof MenuItem && row.visible);
        (first ?? opener)?.forceActiveFocus(Qt.TabFocusReason);
    }

    // Folded at once, for when it goes out of sight.
    function fold() {
        collapse();
        folding.complete();
    }

    // Untyped, so a test can hand it a held key; a held key chooses once.
    function handleKey(event: var): bool {
        if (!expanded)
            return false;
        if (event.key === Qt.Key_Escape) {
            collapse();
            openedBy?.forceActiveFocus(Qt.TabFocusReason);
            return true;
        }
        if (![Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key))
            return false;
        if (!event.isAutoRepeat)
            press(Window.activeFocusItem);
        return true;
    }

    // Unfolded by a pointer it may hold no focus, yet Escape folds it before anything behind it sees the key, and the
    // focus stays where it is; a sheet or menu over it is nearer (navigation.md, "Who gets a key"). Untyped, so a test
    // can hand it a key.
    function foldOnEscape(event: var, focusItem: Item): bool {
        if (!expanded || event.key !== Qt.Key_Escape || KeyLayers.surfaces.length > 0 || focusItem?.Window.window !== Window.window)
            return false;
        collapse();
        return true;
    }

    function reveal() {
        if (revealing)
            Reveal.intoView(branch, height);
    }

    function press(row: Item) {
        if (row instanceof MenuItem && !(row as MenuItem).disabled)
            activated(row as MenuItem);
    }

    width: parent ? parent.width : 0
    height: unfolded * list.implicitHeight
    onHeightChanged: reveal()
    // A column places a row that just appeared only on its next layout.
    onYChanged: reveal()
    visible: unfolded > 0
    onVisibleChanged: focusFirstRowOnceShown()
    opacity: unfolded
    clip: true
    Keys.onPressed: event => event.accepted = handleKey(event)
    Component.onCompleted: removeEscapeLayer = KeyLayers.on(40, (event, focusItem) => foldOnEscape(event, focusItem))
    Component.onDestruction: removeEscapeLayer()

    NumberAnimation {
        id: unfolding

        objectName: "unfolding"
        target: branch
        property: "unfolded"
        to: 1
        duration: Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
        onStopped: settle.restart()
    }

    // The column places a row that just appeared on its next layout, which can come after the animation has ended.
    // ponytail: a fixed wait for that layout; track the column's own polish if a slow frame ever outlasts it.
    Timer {
        id: settle

        interval: 100
        onTriggered: branch.revealing = false
    }

    NumberAnimation {
        id: folding

        objectName: "folding"
        target: branch
        property: "unfolded"
        to: 0
        duration: Geometry.branchCloseShare * Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeOut
    }

    Column {
        id: list

        width: branch.width
    }

    TapHandler {
        // A slow click is still a click.
        longPressThreshold: 0

        onTapped: eventPoint => branch.press(list.childAt(eventPoint.position.x, eventPoint.position.y))
    }
}
