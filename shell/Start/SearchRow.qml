import QtQuick
import Rekta

// A row of the search below its app tiles: a palette entry (navigation.md, "Go to"; rekta.css:806), a menu item whose
// press acts. The best hit says which key acts, as the best app tile does.
MenuItem {
    id: row

    // The best hit of the search, which Enter acts on.
    property bool best: false
    // As a tile that opens: the arrow keys reach it.
    readonly property bool opens: true
    // A place change turns a row as one part.
    readonly property bool turnsWhole: true

    signal activated

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
        text: "enter"
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
