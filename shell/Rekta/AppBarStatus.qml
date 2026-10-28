pragma ComponentBehavior: Bound

import QtQuick

// The status words of the app bar: Rekta's live state, "a square and a word, and the word is always visible"
// (navigation.md, "App bar"; rekta.css:654–656), here up to several, each a control that opens the place where it can
// be changed. A deviation: Rekta knows one live state and a press on it does nothing. Like the live state they never
// move into "more" (AppBar). A word comes and goes with a fade over duration-short and ease-base (motion.md, "State
// changes"); once it has gone the bar lays itself out again.
Item {
    id: status

    // The words to show, in order: { key, word, status ("error" or ""), name }; `name` is what assistive technology says.
    property var words: []
    // Every key the words may have, in the order they stand on the bar.
    property list<string> keys: []
    // False while no word stands; the bar then keeps no room for it.
    readonly property bool present: standing > 0
    property int standing: 0

    // The word that was pressed.
    signal activated(var word)

    function count() {
        standing = Array.from(row.children).filter(child => (child as WordControl)?.present === true).length;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Geometry.appBarControl
    visible: present

    Row {
        id: row

        spacing: Tokens.spaceXs

        Repeater {
            model: status.keys

            WordControl {}
        }
    }

    component WordControl: AppBarButton {
        id: control

        required property string modelData
        readonly property var current: status.words.find(word => word.key === modelData)
        readonly property bool wanted: current !== undefined
        // The word last shown, which stays while it fades.
        property var shown: null
        property bool fading: false

        objectName: `status-${modelData}`
        text: shown?.name ?? ""
        present: wanted || fading
        opacity: wanted ? 1 : 0
        face: StatusTag {
            x: Geometry.appBarControlPadding
            y: (Geometry.appBarControl - implicitHeight) / 2
            status: control.shown?.status ?? ""
            word: control.shown?.word ?? ""
            figures: true
        }

        onCurrentChanged: {
            if (current)
                shown = current;
        }
        onWantedChanged: {
            if (wanted)
                return;
            fading = true;
            fade.restart();
        }
        onPresentChanged: status.count()
        onClicked: status.activated(shown)
        Component.onCompleted: {
            if (current)
                shown = current;
            status.count();
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.durationShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeBase
            }
        }

        Timer {
            id: fade

            interval: Tokens.durationShort
            onTriggered: control.fading = false
        }
    }
}
