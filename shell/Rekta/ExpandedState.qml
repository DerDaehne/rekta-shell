import QtQuick

// Tells assistive technology whether its target is expanded. Qt before 6.12 has no Accessible.expandable and
// Accessible.expanded, so there the state is left out.
QtObject {
    id: root

    required property Item target
    property bool expanded: false

    function announce(): void {
        if (!("expanded" in target.Accessible))
            return;
        target.Accessible.expandable = true;
        target.Accessible.expanded = expanded;
    }

    onExpandedChanged: announce()
    Component.onCompleted: announce()
}
