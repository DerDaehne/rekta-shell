import QtQuick

// Tells assistive technology whether its target is expanded. Qt before 6.12 has no Accessible.expandable and
// Accessible.expanded, so there the state is left out.
QtObject {
    id: root

    required property Item target
    // False for a target that opens nothing of its own: it is then neither expandable nor expanded.
    property bool expandable: true
    property bool expanded: false

    function announce(): void {
        if (!("expanded" in target.Accessible))
            return;
        target.Accessible.expandable = expandable;
        target.Accessible.expanded = expandable && expanded;
    }

    onExpandableChanged: announce()
    onExpandedChanged: announce()
    Component.onCompleted: announce()
}
