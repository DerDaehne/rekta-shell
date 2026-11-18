import QtQuick

// Laid into a popup's window, it reports a press outside `bounds`: the window, or the part of it that shows anything.
// Qt hands each touch on another window of the program to the open popup first, and a Qt Quick window keeps every
// touch it is given, so while a popup is open a finger never reaches the window it lands on; a pointer handler in the
// popup never sees a point outside its own window either. It takes no press itself: a mouse press outside still reaches
// the window under it.
MouseArea {
    id: area

    // What counts as inside; a point in the window but outside it counts as outside.
    property Item bounds: null
    // Qt hands an item only points within its bounds, so it reaches past the window as far as the desktop spans.
    readonly property real reach: Screen.desktopAvailableWidth + Screen.desktopAvailableHeight

    // `at` is where it landed, in this window.
    signal pressedOutside(point at)

    x: -reach
    y: -reach
    width: Window.width + 2 * reach
    height: Window.height + 2 * reach

    onPressed: mouse => {
        mouse.accepted = false;
        const inWindow = mapToItem(null, mouse.x, mouse.y);
        const inBounds = bounds ? mapToItem(bounds, mouse.x, mouse.y) : inWindow;
        const size = bounds ? Qt.size(bounds.width, bounds.height) : Qt.size(Window.width, Window.height);
        if (inBounds.x < 0 || inBounds.y < 0 || inBounds.x >= size.width || inBounds.y >= size.height)
            pressedOutside(Qt.point(inWindow.x, inWindow.y));
    }
}
