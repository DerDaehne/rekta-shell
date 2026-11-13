pragma ComponentBehavior: Bound

import QtQuick

// The status words of the app bar: tags in controls. Each is a tag (rekta.css:790–791: a square and its word, the word
// always visible) in a control of the bar (.rk-ab, rekta.css:802–813) that opens the place where it can be changed.
// They stand where Rekta's live state stands, at the start of the leading side before the middle (navigation.md, "A
// control in the middle"). A deliberate deviation: Rekta's single live-state slot (.rk-ab-status, rekta.css:824) is one
// plain text that does nothing; here there are several, they are controls, and they take the controls' gap, size and
// weight, not the slot's. Like the live state they never move into "more" (AppBar).
//
// `words` are all the deviations in order, `limit` how many of them stand; the bar sets it from the room it has. The rest
// are counted in one more word, "+N". A word arrives with a fade over duration-short and leaves over 0.6 of it (motion.md,
// "Arriving, leaving"). The bar places the words with its other controls, so they glide with them; one that leaves keeps
// its place until it has gone.
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
    // The words that stand and those still fading out, in order.
    property var slots: []
    // False while no word stands; the bar then keeps no room for it.
    readonly property bool present: slots.length > 0

    // The word that was pressed, and whether a pointer did it, not the keyboard on the focused word.
    signal activated(var word, bool byPointer)

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
        return span(shownAt(count).map(word => wordWidth(word.word)));
    }

    function wordWidth(text: string): real {
        return Math.ceil(Math.max(Geometry.appBarControl, 2 * Geometry.appBarControlPadding + Geometry.tagMark + Geometry.tagGap + metrics.advanceWidth(text)));
    }

    function span(widths: var): real {
        return widths.reduce((sum, width) => sum + width, 0) + Tokens.spaceXs * Math.max(0, widths.length - 1);
    }

    // The room the words take now: those that stand and those still fading out, which the bar lays out around until
    // they have gone.
    function occupied(): real {
        return span(slots.map(slot => wordWidth(slot.shown?.word ?? "")));
    }

    function controls(): var {
        return Array.from(row.children).filter(child => (child as WordControl) !== null);
    }

    // Counted after a change has settled: a word that begins to fade is for a moment neither wanted nor fading. A tag is
    // a Row, which takes its new width only when it is next laid out; the bar needs it now.
    function count() {
        const all = controls();
        all.forEach(control => (control.face as StatusTag).forceLayout());
        slots = all.filter(slot => slot.wanted || slot.fading);
    }

    // Whether the words that stand are those a limit of `wordLimit` lets stand.
    function counted(wordLimit: int): bool {
        const standing = slots.filter(slot => slot.wanted).map(slot => slot.modelData);
        const due = shownAt(wordLimit).map(word => word.key).filter(key => keys.includes(key));
        const settled = slots.every(slot => slot.wanted || slot.fading);
        return settled && standing.length === due.length && due.every(key => standing.includes(key));
    }

    // Where the words stand, side by side, when the row starts at `start` in the bar; y is in the row.
    function places(start: real): var {
        const places = [];
        let x = start;
        for (const slot of slots) {
            places.push({ item: slot, x, width: slot.implicitWidth, y: 0 });
            x += slot.implicitWidth + Tokens.spaceXs;
        }
        return places;
    }

    implicitWidth: occupied()
    implicitHeight: Geometry.appBarControl
    visible: present

    Component.onCompleted: count()

    FontMetrics {
        id: metrics

        font.family: Tokens.fontSans
        font.pixelSize: Tokens.fontSizeXs
        font.weight: Tokens.fontWeightSemibold
        font.features: ({ "tnum": 1 })
    }

    Item {
        id: row

        Repeater {
            model: status.keys

            WordControl {}
        }
    }

    component WordControl: AppBarButton {
        id: control

        required property string modelData
        readonly property var current: status.shown.find(word => word.key === modelData)
        // The word last shown, which stays while it fades.
        property var shown: null

        objectName: `status-${modelData}`
        text: shown?.name ?? ""
        present: current !== undefined
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
        onWantedChanged: Qt.callLater(status.count)
        onFadingChanged: Qt.callLater(status.count)
        onImplicitWidthChanged: Qt.callLater(status.count)
        onClicked: status.activated(shown, !control.activeFocus)
        Component.onCompleted: {
            if (current)
                shown = current;
            Qt.callLater(status.count);
        }
    }
}
