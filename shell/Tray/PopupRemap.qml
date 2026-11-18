import QtQuick

// Decides when a popup is mapped. A mapped popup must keep its size and place: for a change Qt asks the compositor to
// reposition it and commits nothing until that request is answered, but Quickshell asks as well, KWin answers only the
// last request, and the popup keeps its last frame, scaled. So its window spans every place its surface can take
// beside its control (AppBar.floatSpan), and the surface moves and changes size within it. Only a surface that no
// longer lies within the window unmaps the popup for one turn of the event loop, and it maps anew at the room it needs.
QtObject {
    id: remap

    // What the popup shows, placed in its window.
    required property Item surface
    // The size of the popup's window.
    property size room
    // Whether the popup should be on screen.
    property bool wanted: false
    property bool remapping: false
    readonly property bool mapped: wanted && !remapping
    readonly property bool fits: surface.x >= 0 && surface.y >= 0 && surface.x + surface.width <= room.width && surface.y + surface.height <= room.height

    // Later: the room can change while `mapped` is being evaluated, and setting `remapping` then loops.
    onFitsChanged: Qt.callLater(unmap)

    function unmap() {
        if (!wanted || remapping || fits)
            return;
        remapping = true;
        Qt.callLater(() => remapping = false);
    }
}
