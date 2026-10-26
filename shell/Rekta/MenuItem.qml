import QtQuick

// One row of a menu (states.md, "Floating surfaces"; rekta.css:789–797): a lowercase verb or option at the density's
// row height; a checkbox or radio option starts with a 10px square, filled when chosen; an option of a field's list
// keeps a slot at its start for the check the chosen one carries (rekta.css:324–325); a key hint sits at the end.
// A disabled item stays in the list, greyed, and says why in its label ("print (needs a printer)"). The menu moves the
// focus between rows; the focused row shows the ring inside and the hover colour, and an enabled row under the pointer
// takes the hover colour too (rekta.css:793, :1027). In a row narrower than its words they are cut.
Item {
    id: item

    property string text
    // item | checkbox | radio | option
    property string kind: "item"
    property bool checked: false
    // An image at the front of the row, 20px: the shell's own addition to Rekta's text-only rows. When one row of a menu has
    // one, every row's text starts at the same edge.
    property url icon
    // The same, by the name of a Rekta icon.
    property string glyph
    // One word in semibold before the text, such as the app a message comes from.
    property string lead
    // The keys that do the same from anywhere, such as "Ctrl S".
    property string keyHint
    property string disabledReason
    // Off with no reason to give: a foreign menu's entry that the app has turned off.
    property bool dimmed: false
    // Choosing it opens a deeper level the host swaps in, so the menu stays open.
    property bool opensLevel: false
    readonly property bool disabled: disabledReason !== "" || dimmed
    readonly property bool checkable: kind !== "item"
    readonly property string label: disabledReason !== "" ? `${text} (${disabledReason})` : text
    readonly property color ink: disabled ? Tokens.color.disabled : Tokens.color.textPrimary
    readonly property real checkSpace: {
        if (kind === "option")
            return Geometry.optionCheckWidth + Geometry.optionCheckGap + Tokens.spaceS;
        return checkable ? Geometry.menuCheck + Tokens.spaceS : 0;
    }
    readonly property bool hasIcon: icon.toString() !== "" || glyph !== ""
    readonly property bool menuHasIcons: Array.from(parent?.children ?? []).some(row => row.hasIcon === true && (row.visible || !item.visible))
    readonly property real iconSpace: menuHasIcons ? Geometry.iconSize + Tokens.spaceS : 0
    readonly property real leadSpace: lead !== "" ? leadWords.implicitWidth + Tokens.spaceS : 0
    readonly property real textEdge: Tokens.spaceM + checkSpace + iconSpace + leadSpace
    readonly property string spoken: lead !== "" ? `${lead} ${label}` : label
    // `.rk-menu-key { padding-left: space-l }` on top of the row's gap (rekta.css:790, :797)
    readonly property real keySpace: keyHint !== "" ? Tokens.spaceS + Tokens.spaceL + key.implicitWidth : 0

    width: parent ? parent.width : implicitWidth
    implicitWidth: 2 * Tokens.spaceM + checkSpace + iconSpace + leadSpace + words.implicitWidth + keySpace
    implicitHeight: Tokens.rowHeight
    Accessible.role: Accessible.MenuItem
    Accessible.name: spoken
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
        visible: item.checkable && item.kind !== "option"
        color: item.checked ? item.ink : "transparent"
        border.width: Geometry.menuCheckBorder
        border.color: item.ink
    }

    // Its leading and bottom edges, turned: a check without a box.
    Item {
        objectName: "mark"
        x: Tokens.spaceM
        // Its -3px top margin counts in the box flex centres.
        y: (item.height - (Geometry.optionCheckHeight - Geometry.optionCheckLift)) / 2 - Geometry.optionCheckLift
        width: Geometry.optionCheckWidth
        height: Geometry.optionCheckHeight
        rotation: Geometry.listCheckAngle
        visible: item.kind === "option" && item.checked

        Rectangle {
            width: Geometry.listCheckStroke
            height: parent.height
            color: item.ink
        }

        Rectangle {
            y: parent.height - Geometry.listCheckStroke
            width: parent.width
            height: Geometry.listCheckStroke
            color: item.ink
        }
    }

    Image {
        objectName: "icon"
        x: Tokens.spaceM + item.checkSpace
        anchors.verticalCenter: parent.verticalCenter
        width: Geometry.iconSize
        height: Geometry.iconSize
        sourceSize: Qt.size(width, height)
        source: item.icon
        visible: item.icon.toString() !== ""
    }

    Icon {
        objectName: "glyph"
        x: Tokens.spaceM + item.checkSpace
        anchors.verticalCenter: parent.verticalCenter
        size: Geometry.iconSize
        name: item.glyph
        color: item.ink
        visible: item.glyph !== ""
    }

    Text {
        id: leadWords

        objectName: "lead"
        x: Tokens.spaceM + item.checkSpace + item.iconSpace
        anchors.verticalCenter: parent.verticalCenter
        visible: item.lead !== ""
        text: item.lead
        font.family: Tokens.fontSans
        font.pixelSize: Tokens.fontSizeS
        font.weight: Tokens.fontWeightSemibold
        color: item.ink
    }

    Text {
        id: words

        objectName: "label"
        x: item.textEdge
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, item.width - item.textEdge - item.keySpace - Tokens.spaceM)
        text: item.label
        elide: Text.ElideRight
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
