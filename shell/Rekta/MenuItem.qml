import QtQuick

// One row of a menu (states.md, "Floating surfaces"; rekta.css:789–797): a lowercase verb or option at the density's
// row height; a checkbox or radio option starts with a 10px square, filled when chosen; a key hint sits at the end.
// A disabled item stays in the list, greyed, and says why in its label ("print (needs a printer)"). The menu moves
// the focus between rows; the focused row shows the ring inside and the hover colour, and an enabled row under the
// pointer takes the hover colour too (rekta.css:793, :1027).
Item {
    id: item

    property string text
    // item | checkbox | radio
    property string kind: "item"
    property bool checked: false
    // The keys that do the same from anywhere, such as "Ctrl S".
    property string keyHint
    property string disabledReason
    readonly property bool disabled: disabledReason !== ""
    readonly property bool checkable: kind !== "item"
    readonly property string label: disabled ? `${text} (${disabledReason})` : text
    readonly property color ink: disabled ? Tokens.color.disabled : Tokens.color.textPrimary
    readonly property real checkSpace: checkable ? Geometry.menuCheck + Tokens.spaceS : 0
    // `.rk-menu-key { padding-left: space-l }` on top of the row's gap (rekta.css:790, :797)
    readonly property real keySpace: keyHint !== "" ? Tokens.spaceS + Tokens.spaceL + key.implicitWidth : 0

    width: parent ? parent.width : implicitWidth
    implicitWidth: 2 * Tokens.spaceM + checkSpace + words.implicitWidth + keySpace
    implicitHeight: Tokens.rowHeight
    Accessible.role: Accessible.MenuItem
    Accessible.name: label
    Accessible.checkable: checkable
    Accessible.checked: checked

    Rectangle {
        objectName: "tint"
        anchors.fill: parent
        visible: item.activeFocus || (pointer.hovered && !item.disabled)
        color: Tokens.color.hover
    }

    Rectangle {
        objectName: "check"
        x: Tokens.spaceM
        anchors.verticalCenter: parent.verticalCenter
        width: Geometry.menuCheck
        height: Geometry.menuCheck
        visible: item.checkable
        color: item.checked ? item.ink : "transparent"
        border.width: Geometry.menuCheckBorder
        border.color: item.ink
    }

    Text {
        id: words

        objectName: "label"
        x: Tokens.spaceM + item.checkSpace
        anchors.verticalCenter: parent.verticalCenter
        text: item.label
        font.family: Tokens.fontSans
        font.pixelSize: Tokens.fontSizeS
        color: item.ink
    }

    Text {
        id: key

        objectName: "key"
        anchors.right: parent.right
        anchors.rightMargin: Tokens.spaceM
        anchors.verticalCenter: parent.verticalCenter
        visible: item.keyHint !== ""
        text: item.keyHint
        font.family: Tokens.fontSans
        font.pixelSize: Tokens.fontSizeXxs
        color: Tokens.color.textContrastHigh
    }

    FocusRing {
        offset: -Geometry.focusRingInsetInRow
    }

    HoverHandler {
        id: pointer

        cursorShape: item.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
    }
}
