import QtQuick

// The facets a pivot picks between, one in sight at a time (motion.md, "Facet change"). The chosen facet comes in
// from the trailing edge going forward, from the leading edge going back, by slide-distance with a fade, over
// 0.75 × duration-moderate; the one left goes at once.
//
// With a `facetStrip` and from pivot-wide up (navigation.md:52–64; rekta.css:192–207; rekta.js pivot(), :1041–1074)
// every facet shows at once, side by side as a panorama row, sized in tile units. The strip stays, follows the scroll
// (the facet scrolled into view is the one chosen) and jumps to a facet; Tab on the strip enters the facet chosen. A
// facet taller than the row brings its own scroller. A pivot that picks the place never goes wide.
Item {
    id: facets

    property Pivot facetStrip
    property int currentIndex: facetStrip ? facetStrip.currentIndex : 0
    property int previousIndex: 0
    // The first display stands still; only a change of facet slides (motion.md, "Next item, same place").
    property bool shown: false
    property real sectionWidth: panorama.sectionWidth
    readonly property bool wide: facetStrip !== null && facetStrip.level === "facet" && width >= Tokens.pivotWide
    default property alias content: holder.data

    function showChosen() {
        const items = wide ? [] : holder.children;
        for (let k = 0; k < items.length; k++)
            items[k].visible = k === currentIndex;
    }

    // ponytail: the facets present when the width changes are the ones laid out side by side; one added while wide
    // joins at the next change.
    function arrange() {
        if (wide)
            gather();
        else
            release();
        showChosen();
        if (wide)
            panorama.goTo(currentIndex, false, true);
    }

    function gather() {
        for (const item of [...holder.children]) {
            const slot = slotComponent.createObject(panorama.sectionParent, {
                facet: item
            });
            item.visible = true;
            item.parent = slot;
            slots = [...slots, slot];
        }
    }

    function release() {
        for (const slot of slots) {
            slot.facet.parent = holder;
            slot.destroy();
        }
        slots = [];
    }

    property var slots: []

    onWideChanged: {
        if (shown)
            arrange();
    }
    onCurrentIndexChanged: {
        showChosen();
        if (wide) {
            if (panorama.currentIndex !== currentIndex)
                panorama.goTo(currentIndex, false, false);
            return;
        }
        if (!shown)
            return;
        shift.x = (currentIndex > previousIndex ? 1 : -1) * Tokens.slideDistance;
        holder.opacity = 0;
        enter.restart();
        previousIndex = currentIndex;
    }
    Component.onCompleted: {
        previousIndex = currentIndex;
        showChosen();
        shown = true;
        if (wide)
            arrange();
    }

    Item {
        id: holder

        objectName: "holder"
        width: facets.width
        height: facets.height
        visible: !facets.wide
        transform: Translate {
            id: shift

            objectName: "shift"
        }

        onChildrenChanged: facets.showChosen()
    }

    Panorama {
        id: panorama

        objectName: "row"
        anchors.fill: parent
        visible: facets.wide
        facetRow: true
        // The facet scrolled into view becomes the one chosen (navigation.md:62).
        onCurrentIndexChanged: {
            if (facets.wide && facets.facetStrip && facets.facetStrip.currentIndex !== currentIndex)
                facets.facetStrip.select(currentIndex);
        }
    }

    Binding {
        target: facets.facetStrip
        property: "tabInto"
        value: facets.wide ? facets.slots[facets.currentIndex] ?? null : null
        when: facets.facetStrip !== null
    }

    Component {
        id: slotComponent

        Item {
            required property Item facet

            // A facet is no tab stop of its own (rekta.js:1134 gives its panel tabindex -1); once the strip has led Tab
            // into it, Tab goes on through what it holds.
            activeFocusOnTab: activeFocus

            FocusRing {
                shown: parent.activeFocus
            }
        }
    }

    ParallelAnimation {
        id: enter

        objectName: "enter"
        readonly property real duration: 0.75 * Tokens.durationModerate

        NumberAnimation {
            target: shift
            property: "x"
            to: 0
            duration: enter.duration
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeOut
        }
        NumberAnimation {
            target: holder
            property: "opacity"
            to: 1
            duration: enter.duration
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeOut
        }
    }
}
