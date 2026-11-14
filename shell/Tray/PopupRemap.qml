import QtQuick

// Decides when a popup is mapped. A mapped popup that changes size keeps showing its old frame, scaled, until the next
// key press, so a level of the tray menu with another size would stay unseen. Unmapped for one turn of the event loop and
// mapped again it paints at the new size. Only a size it was not mapped at counts: each time it is mapped its rows turn
// visible one after another, so a menu is as wide as the rows visible so far for a moment, and remapping for that would
// never end.
QtObject {
    id: remap

    // What the popup shows; its size is watched.
    required property Item surface
    // Whether the popup should be on screen.
    property bool wanted: false
    property bool remapping: false
    readonly property bool mapped: wanted && !remapping
    // The surface's size when the popup was last mapped.
    property size mappedSize

    onMappedChanged: {
        if (mapped)
            mappedSize = Qt.size(surface.width, surface.height);
    }

    // Later: a size can change while `mapped` is being evaluated, and setting `remapping` then loops.
    function again() {
        Qt.callLater(unmap);
    }

    function unmap() {
        if (!wanted || remapping || (surface.width === mappedSize.width && surface.height === mappedSize.height))
            return;
        remapping = true;
        Qt.callLater(() => remapping = false);
    }

    readonly property Connections resizes: Connections {
        target: remap.surface

        function onWidthChanged() {
            remap.again();
        }

        function onHeightChanged() {
            remap.again();
        }
    }
}
