import QtQuick

// One row of a menu (states.md, "Floating surfaces"; rekta.css:1013–1021): a lowercase verb or option at the density's
// row height; a checkbox or radio option starts with a 10px square, filled when chosen; a key hint sits at the end.
// A disabled item stays in the list, greyed, and says why in its label ("print (needs a printer)"). The menu moves the
// focus between rows; the focused row shows the ring inside and the hover colour, and an enabled row under the pointer
// takes the hover colour too (rekta.css:1017, :1338). In a row narrower than its words they are cut.
Item {
    id: item

    property string text
    // item | checkbox | radio
    property string kind: "item"
    property bool checked: false
    // An image at the front of the row, 20px; when one row of a menu has one, every row's text starts at the same edge
    // (rekta.css:1024–1025).
    property url icon
    // The same, by the name of a Rekta icon.
    property string glyph
    // One word in semibold before the text, such as the app a message comes from.
    property string lead
    // The keys that do the same from anywhere, such as "Ctrl S".
    property string keyHint
    // Marks at the end of the row, before a key hint, such as a device's battery and state: the shell's own addition.
    default property alias trailing: end.data
    property string disabledReason
    // Off with no reason to give: a foreign menu's entry that the app has turned off.
    property bool dimmed: false
    // The room before and after the row's content: space-m inside a bordered menu (rekta.css:1014), none for rows that
    // stand on a surface (`.rk-rows`, rekta.css:73–74).
    property real inset: Tokens.spaceM
    // Keeps the icon's room also for a row without one, so every text of a list starts at one edge.
    property bool iconSlot: false
    // Choosing it opens a deeper level the host swaps in, so the menu stays open. The row ends in a chevron pointing on
    // (rekta.css:1029–1032).
    property bool opensLevel: false
    // The back row of a level (rekta.css:1033–1037): a chevron pointing back instead of an icon, words in text-contrast-high
    // and semibold, a hairline below. It is no row with an icon, so it takes no part in the edge the others share.
    property bool isBack: false
    readonly property bool disabled: disabledReason !== "" || dimmed
    readonly property bool checkable: kind !== "item"
    readonly property string label: disabledReason !== "" ? `${text} (${disabledReason})` : text
    readonly property color ink: disabled ? Tokens.color.disabled : isBack ? Tokens.color.textContrastHigh : Tokens.color.textPrimary
    readonly property real checkSpace: !isBack && ((checkable && !checkInIconSlot) || menuHasCheckWithIcon) ? Geometry.menuCheck + Tokens.spaceS : 0
    readonly property bool hasIcon: !isBack && (icon.toString() !== "" || glyph !== "")
    readonly property var menuRows: Array.from(parent?.children ?? []).filter(row => row.visible || !item.visible)
    readonly property bool menuHasIcons: menuRows.some(row => row.hasIcon === true)
    // A row with a box and an icon has the box first (states.md:138–141); every row keeps the box's room, so all texts
    // start at one edge.
    readonly property bool menuHasCheckWithIcon: menuRows.some(row => row.hasIcon === true && row.checkable === true)
    // Otherwise, in a menu with icons, a row without one has its box where the icons stand, so every text starts at one
    // edge.
    readonly property bool checkInIconSlot: checkable && menuHasIcons && !hasIcon && !menuHasCheckWithIcon
    readonly property real iconSpace: !isBack && (menuHasIcons || iconSlot) ? Geometry.iconSize + Tokens.spaceS : 0
    readonly property real leadSpace: lead !== "" ? leadWords.implicitWidth + Tokens.spaceS : 0
    readonly property real chevronSpace: isBack ? Geometry.chevronSize + Tokens.spaceS : 0
    readonly property bool hasOnward: opensLevel && !isBack
    readonly property real onwardSpace: hasOnward ? Tokens.spaceS + Geometry.chevronSize : 0
    readonly property real textEdge: inset + chevronSpace + checkSpace + iconSpace + leadSpace
    readonly property string spoken: lead !== "" ? `${lead} ${label}` : label
    // `.rk-menu-key { padding-left: space-l }` on top of the row's gap (rekta.css:1014, :1021)
    readonly property real keyGap: keyHint !== "" ? Tokens.spaceS + Tokens.spaceL : 0
    readonly property real keySpace: keyGap + key.width
    readonly property real endSpace: end.implicitWidth > 0 ? Tokens.spaceS + end.implicitWidth : 0
    // ponytail: Rekta does not yet say how a key hint and the chevron on share the row's end (both `margin-left: auto`,
    // rekta.css:1021, :1032); its proposal stands meanwhile: the hint before the chevron, space-s between, the hint
    // shortened with an ellipsis so the chevron stays. Follow Rekta's answer once it comes.
    readonly property real keyRoom: width - textEdge - words.implicitWidth - endSpace - keyGap - onwardSpace - inset

    width: parent ? parent.width : implicitWidth
    implicitWidth: 2 * inset + chevronSpace + checkSpace + iconSpace + leadSpace + words.implicitWidth + endSpace + keyGap + key.implicitWidth + onwardSpace
    implicitHeight: Tokens.rowHeight
    Accessible.role: Accessible.MenuItem
    Accessible.name: spoken
    Accessible.checkable: checkable
    Accessible.checked: checked

    // Focus the keyboard gives shows the whole of a cut label at once; focus a pointer gave does not (`:focus-visible`,
    // rekta.js:3081).
    onActiveFocusChanged: {
        if (activeFocus && !ring.hiddenByHost)
            labelTip.show();
        else
            Tips.leave(words);
    }

    Rectangle {
        objectName: "tint"
        anchors.fill: parent
        visible: item.activeFocus || (pointer.hovered && !item.disabled)
        color: Tokens.color.hover
    }

    Rectangle {
        objectName: "check"
        x: item.inset + (item.checkInIconSlot ? (Geometry.iconSize - Geometry.menuCheck) / 2 : 0)
        anchors.verticalCenter: parent.verticalCenter
        width: Geometry.menuCheck
        height: Geometry.menuCheck
        visible: item.checkable
        color: item.checked ? item.ink : "transparent"
        border.width: Geometry.menuCheckBorder
        border.color: item.ink
    }

    PictureIcon {
        objectName: "icon"
        x: item.inset + item.checkSpace
        anchors.verticalCenter: parent.verticalCenter
        source: item.icon
        visible: item.icon.toString() !== ""
    }

    Icon {
        objectName: "glyph"
        x: item.inset + item.checkSpace
        anchors.verticalCenter: parent.verticalCenter
        size: Geometry.iconSize
        name: item.glyph
        color: item.ink
        visible: item.glyph !== ""
    }

    Text {
        id: leadWords

        objectName: "lead"
        x: item.inset + item.checkSpace + item.iconSpace
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
        width: Math.max(0, item.width - item.textEdge - item.endSpace - item.keySpace - item.onwardSpace - item.inset)
        text: item.label
        elide: Text.ElideRight
        font.family: Tokens.fontSans
        font.pixelSize: Tokens.fontSizeS
        font.weight: item.isBack ? Tokens.fontWeightSemibold : Font.Normal
        color: item.ink

        OverflowTip {
            id: labelTip
        }
    }

    Chevron {
        objectName: "chevron"
        x: item.inset + Geometry.chevronBackNudge
        anchors.verticalCenter: parent.verticalCenter
        rotation: Geometry.chevronBackTurn
        color: item.ink
        visible: item.isBack
    }

    Chevron {
        objectName: "onward"
        x: item.width - item.inset - width - Geometry.chevronOnNudge
        anchors.verticalCenter: parent.verticalCenter
        rotation: Geometry.chevronOnTurn
        color: item.ink
        visible: item.hasOnward
    }

    Hairline {
        objectName: "hairline"
        y: parent.height - height
        visible: item.isBack
    }

    Row {
        id: end

        objectName: "end"
        anchors.right: parent.right
        anchors.rightMargin: item.inset + item.keySpace + item.onwardSpace
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spaceS
    }

    Text {
        id: key

        objectName: "key"
        anchors.right: parent.right
        anchors.rightMargin: item.inset + item.onwardSpace
        anchors.verticalCenter: parent.verticalCenter
        width: item.hasOnward ? Math.max(0, Math.min(implicitWidth, item.keyRoom)) : implicitWidth
        elide: Text.ElideRight
        visible: item.keyHint !== ""
        text: item.keyHint
        font.family: Tokens.fontSans
        font.pixelSize: Tokens.fontSizeXxs
        color: Tokens.color.textContrastHigh
    }

    // Inside a row with room of its own, outside one that has none (rekta.css:44, :463).
    FocusRing {
        id: ring

        objectName: "ring"
        offset: item.inset > 0 ? -Geometry.focusRingInsetInRow : Geometry.focusRingOffset
    }

    HoverHandler {
        id: pointer

        cursorShape: item.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
    }
}
