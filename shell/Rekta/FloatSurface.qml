import QtQuick

// A surface that floats next to the control that opened it (states.md, "Floating surfaces"; rekta.css:1016–1024): bg, a
// 1px text-contrast-medium edge, radius-s, no shadow. As wide as its widest row, from 12rem up to 24rem (less in a
// narrow window); at most 24rem, 60% of the window or the window less space-m above and below high
// (rekta.js:2053), scrolling the rest. It comes in with a fade and a 4px shift away from its control and leaves at
// once. The host floats it above the window (an overlay, or a popup of its own where it must reach past the window)
// and places it with Placement.float, which also gives its side.
Rectangle {
    id: surface

    property bool open: false
    // Its host cannot show it yet: it stays open and comes in once that ends.
    property bool held: false
    readonly property bool showing: open && !held
    // Why it closes, set by whoever closes it; "other" for a choice, Tab or code. Named in the one line it writes.
    property string closeReason: "other"
    // Its name in that line; a surface without one writes none.
    property string traced: ""
    property double openedAt: 0
    // "below" or "above" its control, from Placement.float.
    property string side: "below"
    // The window it has to fit in.
    property size area: Qt.size(Window.width, Window.height)
    // Runs from 0 to 1 as it comes in.
    property real entry: 1
    readonly property real shift: (1 - entry) * (side === "above" ? Geometry.floatShift : -Geometry.floatShift)
    default property alias content: column.data
    readonly property alias rows: column.children
    readonly property real maxWidth: Math.min(Geometry.floatMaxSize, area.width - 2 * Tokens.spaceM)
    readonly property real maxHeight: Math.max(0, Math.min(Geometry.floatMaxSize, Geometry.floatMaxHeightShare * area.height, area.height - 2 * Tokens.spaceM))
    readonly property real widestRow: Array.from(rows).reduce((widest, row) => row.visible || !surface.visible ? Math.max(widest, row.implicitWidth) : widest, 0)

    // Scrolls a row into view, as focus does on the web.
    function reveal(row: Item) {
        column.forceLayout();
        const top = row.mapToItem(column, 0, 0).y;
        scroller.contentY = Math.min(top, Math.max(scroller.contentY, top + row.height - scroller.height));
    }

    // Closed by a press outside it. It goes once that press has reached what it landed on: its own control then still
    // sees it open and closes it rather than opening it again (rekta.js:2095–2096, a click on the trigger never counts
    // as a click outside), and the end of a popup's grab lets the release reach that control.
    function dismiss(reason: string) {
        Qt.callLater(() => surface.closeAs(reason));
    }

    // Closes it for a reason only while it is open, so a closer that comes late leaves no reason behind.
    function closeAs(reason: string) {
        if (!open)
            return;
        closeReason = reason;
        open = false;
    }

    function within(box: rect, at: point): bool {
        return at.x >= box.x && at.y >= box.y && at.x < box.x + box.width && at.y < box.y + box.height;
    }

    // A press the open popup was handed, at `at` in the popup's window, which stands at `origin` in the host window: on the
    // host's own opener it is a second press, elsewhere on the host a press on it, anywhere else a press outside.
    function pressReason(at: point, origin: point, host: rect, opener: rect): string {
        const inHost = Qt.point(origin.x + at.x, origin.y + at.y);
        if (within(opener, inHost))
            return "second-press";
        return within(host, inHost) ? "press-on-bar" : "press-outside";
    }

    // The compositor or Qt closed the popup that holds this surface. Qt closes its popups when the program loses the
    // keyboard; the compositor does so for a change of the active window or a press in another program.
    function popupClosed(appActive: bool) {
        dismiss(appActive ? "popup-done" : "keyboard-lost");
    }

    // The one journal line of a close; none for a surface without a name.
    function closeLine(reason: string, sinceOpen: int): string {
        return traced ? `rekta-float: surface=${traced} reason=${reason} ms=${sinceOpen}` : "";
    }

    function reportClose() {
        const sinceOpen = Date.now() - openedAt;
        const line = closeLine(closeReason, sinceOpen);
        if (line)
            console.info(line);
        closedFor(closeReason, sinceOpen);
    }

    // Its size with its rows laid out now, not at the next frame, so a host can place it as it opens.
    function measured(): size {
        column.forceLayout();
        return Qt.size(implicitWidth, implicitHeight);
    }

    // The minimum wins over the maximum, as min-width does over max-width.
    implicitWidth: Math.max(Geometry.floatMinWidth, Math.min(maxWidth, widestRow + 2 * border.width))
    implicitHeight: Math.min(maxHeight, column.implicitHeight + 2 * border.width)
    visible: showing
    z: Tokens.layerFloat
    opacity: entry
    color: Tokens.color.bg
    radius: Tokens.radiusS
    border.width: Geometry.floatBorder
    border.color: Tokens.color.textContrastMedium
    transform: Translate {
        y: surface.shift
    }

    // Once per close: what closed it and how long after it opened.
    signal closedFor(string reason, int sinceOpen)

    onShowingChanged: {
        comingIn.stop();
        entry = 1;
        if (showing)
            comingIn.start();
    }
    onOpenChanged: {
        if (open) {
            openedAt = Date.now();
            closeReason = "other";
            KeyLayers.opened(surface);
        } else {
            KeyLayers.closed(surface);
            reportClose();
        }
    }
    Component.onDestruction: KeyLayers.closed(surface)

    NumberAnimation {
        id: comingIn

        objectName: "comingIn"
        target: surface
        property: "entry"
        from: 0
        to: 1
        duration: Tokens.durationFloat
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
    }

    Flickable {
        id: scroller

        objectName: "scroller"
        anchors.fill: parent
        anchors.margins: surface.border.width
        contentWidth: width
        contentHeight: column.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: column

            width: scroller.width
            topPadding: Tokens.spaceXs
            bottomPadding: Tokens.spaceXs
        }
    }
}
