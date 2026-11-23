import QtQuick
import Rekta

// A row of the search below its app tiles: a palette entry (navigation.md, "Go to"; rekta.css:1067), a menu item whose
// press acts. It stands on the Start's surface, so it has no indent (`.rk-rows`, rekta.css:77–78), and every text of the
// search starts at one edge, with or without an icon. The best hit says which key acts, as the best app tile does.
MenuItem {
    id: row

    // The hit it shows, one of Rules.rowGroups' rows or Rules.waysOut: {text, lead, icon, glyph, key, best, run}.
    property var entry: null
    // The best hit of the search, which Enter acts on.
    readonly property bool best: row.entry?.best === true
    // As a tile that opens: the arrow keys reach it.
    readonly property bool opens: true
    // A place change turns a row as one part.
    readonly property bool turnsWhole: true

    signal activated

    text: row.entry?.text ?? ""
    lead: row.entry?.lead ?? ""
    icon: row.entry?.glyph ? "" : (row.entry?.icon ?? "")
    glyph: row.entry?.glyph ?? ""
    keyHint: row.entry?.key ?? ""
    inset: 0
    iconSlot: true
    activeFocusOnTab: true
    Accessible.role: Accessible.Button

    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat)
            row.activated();
    }

    MouseArea {
        parent: row
        anchors.fill: parent
        onClicked: row.activated()
    }

    KeyHint {
        objectName: "enterKey"
        visible: row.best
        text: "Enter"
    }

    Kicker {
        objectName: "bestWord"
        visible: row.best
        text: "bester treffer"
        color: Tokens.color.textContrastHigh
        font.pixelSize: Tokens.fontSizeXs
        lineHeightFactor: Tokens.lineHeightCompact
        wrapMode: Text.NoWrap
    }
}
