import QtQuick

// Laid into a popup's window, it reports a press outside that window. Qt hands each touch on another window of the
// program to the open popup first, and a Qt Quick window keeps every touch it is given, so while a popup is open a
// finger never reaches the window it lands on; a pointer handler in the popup never sees a point outside its own
// window either. It takes no press itself: a mouse press outside still reaches the window under it.
MouseArea {
    id: area

    // Qt hands an item only points within its bounds, so it reaches past the window as far as the desktop spans.
    readonly property real reach: Screen.desktopAvailableWidth + Screen.desktopAvailableHeight

    signal pressedOutside

    x: -reach
    y: -reach
    width: Window.width + 2 * reach
    height: Window.height + 2 * reach

    onPressed: mouse => {
        mouse.accepted = false;
        const inWindow = mapToItem(null, mouse.x, mouse.y);
        if (inWindow.x < 0 || inWindow.y < 0 || inWindow.x >= Window.width || inWindow.y >= Window.height)
            pressedOutside();
    }
}
