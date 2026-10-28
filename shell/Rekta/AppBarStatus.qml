pragma ComponentBehavior: Bound

import QtQuick

// The status words of the app bar: tags in controls. Each is a tag (rekta.css:609–610: a square and its word, the word
// always visible) in a control of the bar (.rk-ab, rekta.css:621–629) that opens the place where it can be changed.
// A deviation (ADR-032, point 3): Rekta's single live-state slot (.rk-ab-status, rekta.css:632) is one plain text that
// does nothing; here there are several, they are controls, and they take the controls' gap, size and weight, not the
// slot's. Like the live state they never move into "more" (AppBar).
//
// `words` are all the deviations in order, `limit` how many of them stand; the bar sets it from the room it has. The rest
// are counted in one more word, "+N". A word comes and goes with a fade over duration-short and ease-base (motion.md,
// "State changes"); once it has gone the bar lays itself out again.
Item {
    id: status

    // All the deviations, in order: { key, word, status ("error" or ""), name }; `name` is what assistive technology says.
    property var words: []
    // The word for the deviations beyond the limit, as a function of those: { key, word, status, name }.
    property var more: hidden => null
    // Every key the words may have, in the order they stand on the bar.
    property list<string> keys: []
    // The most words that stand, and how many do; the bar lowers it when it has no room for them all.
    property int most: 2
    property int limit: most
    readonly property var shown: shownAt(limit)
    // False while no word stands; the bar then keeps no room for it.
    readonly property bool present: standing > 0
    property int standing: 0

    // The word that was pressed.
    signal activated(var word)

    // The words that stand with a limit: the first ones and a count of the rest, which at 0 is all there is.
    function shownAt(count: int): var {
        if (words.length <= count)
            return words;
        return words.slice(0, count).concat([more(words.slice(count))]);
    }

    // The room the words take with a limit, as the controls will be: whole pixels, at least 48.
    // ponytail: FontMetrics measures the semibold word a little wider than the text draws it (6 px in 70 with Atkinson), so
    // the bar reserves a little too much; measure the words with hidden texts if that ever shows.
    function widthAt(count: int): real {
        const shownWords = shownAt(count);
        const widths = shownWords.map(word => Math.ceil(Math.max(Geometry.appBarControl, 2 * Geometry.appBarControlPadding + Geometry.tagMark + Geometry.tagGap + metrics.advanceWidth(word.word))));
        return widths.reduce((sum, width) => sum + width, 0) + Tokens.spaceXs * Math.max(0, widths.length - 1);
    }

    function count() {
        standing = Array.from(row.children).filter(child => (child as WordControl)?.present === true).length;
    }

    implicitWidth: widthAt(limit)
    implicitHeight: Geometry.appBarControl
    visible: present

    FontMetrics {
        id: metrics

        font.family: Tokens.fontSans
        font.pixelSize: Tokens.fontSizeXs
        font.weight: Tokens.fontWeightSemibold
        font.features: ({ "tnum": 1 })
    }

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
        readonly property var current: status.shown.find(word => word.key === modelData)
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
