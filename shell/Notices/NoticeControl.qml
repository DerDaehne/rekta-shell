pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// "meldungen N" in the app bar: N counts the notifications nobody has seen. A press opens them as a menu above it,
// which sees them all: newest first, the app's word, the summary and the time where a key hint goes. Choosing one runs
// its default action; one without is disabled and says so. After a hairline, "alle entfernen" closes them all. The
// host places the menu, as it places "more" (AppBar.floatPlace). A deliberate deviation until the notification
// centre: Rekta's menu rows are verbs or options, these are content.
AppBarButton {
    id: messages

    required property NoticeBoard board
    property var locale: Qt.locale()
    // The window the list has to fit in.
    property size area: Qt.size(Window.width, Window.height)
    readonly property alias list: menu

    icon: "bell"
    text: "meldungen"
    count: board.unseen

    onClicked: {
        if (menu.open) {
            menu.close(false);
            return;
        }
        // Seen first: a new list of rows builds them anew, and the focus goes to the new first row.
        board.seen();
        menu.openAt(0);
    }

    Menu {
        id: menu

        objectName: "list"
        control: messages
        area: messages.area

        onChosen: item => {
            if (item === clearAll)
                messages.board.clear();
            else
                messages.board.choose((item as NoticeRow).modelData);
        }

        Repeater {
            model: messages.board.rows

            delegate: NoticeRow {}
        }

        MenuSeparator {
            visible: messages.board.rows.length > 0
        }

        MenuItem {
            id: clearAll

            objectName: "clear"
            text: "alle entfernen"
            disabledReason: messages.board.rows.length > 0 ? "" : "keine meldungen"
        }
    }

    component NoticeRow: MenuItem {
        required property var modelData

        lead: modelData.app
        text: modelData.summary
        keyHint: Calendar.timeWords(modelData.time, messages.locale)
        disabledReason: messages.board.canAct(modelData) ? "" : "keine aktion"
    }
}
