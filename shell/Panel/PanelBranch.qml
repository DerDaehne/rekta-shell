import QtQuick
import Rekta

// Rows that unfold below the row that opened them and push what stands below down; nothing floats. It unfolds and folds
// as a tree branch does (motion.md, "Tree branch"; rekta.js:2776, :2779): the height grows with a fade, in
// duration-short on ease-in, and closes in 0.7 of that on ease-out. Its rows are MenuItems; pressing one, or Enter or
// Space on it, says so in `activated`. Escape folds it and the focus goes back to what opened it. It keeps itself in view
// in the scroller it stands in.
Item {
    id: branch

    property bool expanded: false
    // Runs from 0 to 1 as it unfolds, and back as it folds.
    property real unfolded: 0
    // What opened it; the focus goes back there.
    property Item opener
    default property alias rows: list.data

    signal activated(MenuItem row)

    function expand() {
        expanded = true;
        folding.stop();
        unfolding.start();
    }

    function collapse() {
        expanded = false;
        unfolding.stop();
        folding.start();
    }

    function toggle() {
        if (expanded)
            collapse();
        else
            expand();
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
            opener?.forceActiveFocus(Qt.TabFocusReason);
            return true;
        }
        if (![Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key))
            return false;
        if (!event.isAutoRepeat)
            press(Window.activeFocusItem);
        return true;
    }

    function reveal() {
        if (expanded)
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
    opacity: unfolded
    clip: true
    Keys.onPressed: event => event.accepted = handleKey(event)

    NumberAnimation {
        id: unfolding

        objectName: "unfolding"
        target: branch
        property: "unfolded"
        to: 1
        duration: Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
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
