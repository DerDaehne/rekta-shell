import QtQuick

// Decides when a popup is mapped. A mapped popup that changes size keeps showing its old frame, scaled, until the next
// key press, so a level of the tray menu with another size would stay unseen. Unmapped for one turn of the event loop and
// mapped again it paints at the new size.
QtObject {
    id: remap

    // What the popup shows; its size is watched.
    required property Item surface
    // Whether the popup should be on screen.
    property bool wanted: false
    property bool remapping: false
    readonly property bool mapped: wanted && !remapping

    // Later: a size can change while `mapped` is being evaluated, and setting `remapping` then loops.
    function again() {
        Qt.callLater(unmap);
    }

    function unmap() {
        if (!wanted || remapping)
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
