import QtQuick

// The keyboard focus ring of the item it is declared in. On a fill (a status tile, the accent) it sits inside in the
// fill's text colour, which clears AA on every fill; on a neutral ground it sits outside in `focus`
// (accessibility.md, "Focus on fills"). Like `:focus-visible` (rekta.css:42) it is for the keyboard: an ancestor that
// sets `ringsHidden` (a surface a pointer opened) hides every ring inside it until the keyboard takes over.
Rectangle {
    property bool onFill: false
    // The text colour on the fill; only used on a fill.
    property color ink: Tokens.color.textPrimary
    // Shown while the item has keyboard focus.
    property bool shown: parent ? parent.activeFocus : false

    // Untyped, as the hosts are of any type.
    function hides(host: var): bool {
        return host.ringsHidden === true;
    }

    readonly property bool hiddenByHost: {
        for (let host = parent; host; host = host.parent) {
            if (hides(host))
                return true;
        }
        return false;
    }

    // Like CSS outline-offset: where the ring starts, outward from the edge (negative: inside).
    property real offset: onFill ? -Geometry.focusRingInsetOnFill : Geometry.focusRingOffset

    anchors.fill: parent
    anchors.margins: -(offset + border.width)
    z: 1
    visible: shown && !hiddenByHost
    color: "transparent"
    border.width: Geometry.focusRingWidth
    border.color: onFill ? ink : Tokens.color.focus
}
