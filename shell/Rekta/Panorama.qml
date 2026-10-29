pragma ComponentBehavior: Bound

import QtQuick

// A panorama (layout.md "Panorama" and "Sideways scrolling by mouse wheel"; navigation.md:52–64, :288–311; motion.md
// "Panorama scroll"; rekta.css:853–857, :1163–1180; rekta.js panorama(), :825–966): sections side by side, each
// sized in tile units, so a wider window shows more sections, never wider ones. Each child is a section (see
// Section); a section scrolls vertically within itself, and the panorama is never taller than its box. When every
// section fits nothing scrolls. Compact the sections stack and the panorama scrolls vertically, the wheel untouched.
// An optional pivot of section titles follows the scroll and jumps to a section.
//
// facetRow is the same machinery for the facets of a wide pivot (rekta.css:197–207; rekta.js pivot(), :1041–1074):
// no inset and no trailing spacer, the wheel not redirected, and the facet chosen is the one scrolled into view.
Item {
    id: panorama

    default property alias content: row.data
    // --rk-sec-w (rekta.css:1173)
    property real sectionWidth: 3 * Tokens.tileUnit + 2 * Tokens.spaceS + 2 * Tokens.spaceXl
    property real placeWidth: width
    property real viewportHeight: Window.height
    property bool facetRow: false
    // The section strip: it follows the scroll, and choosing a title jumps to that section.
    property Pivot sectionStrip
    readonly property bool sideways: facetRow || Prefs.sizeClass(placeWidth, viewportHeight) === "sideways"
    readonly property real inset: facetRow ? 0 : sideways ? Tokens.spaceXl : Tokens.spaceM
    readonly property real gap: Tokens.spaceXl
    readonly property int currentIndex: reading.current
    // Everything fits: nothing scrolls, and no spacer lets the last section reach the left edge (rekta.css:1179).
    readonly property bool fit: fits()
    readonly property alias scroller: flick
    readonly property alias sectionParent: row
    readonly property alias gliding: glide.running

    // The nearest section's start: flush left, or as far as the panorama scrolls (rekta.js startOf(), :833).
    function startOf(index: int): real {
        const section = sectionItems()[index];
        if (!section)
            return 0;
        return Math.min(sideways ? section.x - inset : section.y, mostScroll());
    }

    // Aligns a section and marks it (rekta.js goTo(), :843); focusHeading puts the focus on its heading.
    function goTo(index: int, focusHeading: bool, instant: bool) {
        const section = sectionItems()[index];
        if (!section)
            return;
        reading.jumped = true;
        mark(index);
        glideTo(startOf(index), instant);
        if (focusHeading && !facetRow && typeof section.focusHeading === "function")
            section.focusHeading();
    }

    // One wheel event at wheel.x/wheel.y; true when the panorama took it (rekta.js wheel(), :872).
    function handleWheel(wheel: var, now: real): bool {
        userScroll();
        if (!sideways || facetRow)
            return false;
        reading.pointer = Qt.point(wheel.x, wheel.y);
        const e = WheelLatch.webEvent(wheel, Application.styleHints.wheelScrollLines, Geometry.wheelLinePixels, Qt.ControlModifier, Qt.ShiftModifier);
        const routed = WheelLatch.route(reading.gesture, e, now, Tokens.durationWheelLatch, host);
        reading.gesture = routed.gesture;
        if (routed.fresh)
            reading.jumped = false;
        if (routed.action === "inner")
            return scrollVertically(routed.gesture.inner, e.dy);
        if (routed.action === "pan")
            return scrollSideways(e.dy);
        // ponytail: Qt's Flickable does not turn Shift+wheel sideways as a browser does, so it is done here, unlatched.
        if (e.shift && !e.ctrl)
            return scrollSideways(Math.abs(e.dx) > Math.abs(e.dy) ? e.dx : e.dy);
        return routed.action === "swallow";
    }

    function sectionItems(): var {
        return row.children;
    }

    function fits(): bool {
        return sideways && reading.reach <= width + 1;
    }

    // The scrolled extent, from the layout and not from the Flickable's bindings, which a change of class may not have
    // reached yet when it jumps.
    function extent(): size {
        if (!sideways)
            return Qt.size(width, reading.stackHeight);
        // The last section can reach the left edge: a spacer after it, as wide as is left (rekta.css:1178).
        const spacer = facetRow ? 0 : Math.max(0, width - 2 * inset - sectionWidth - gap);
        return Qt.size(fits() ? width : reading.reach + gap + spacer + inset, height);
    }

    function mostScroll(): real {
        return Math.max(0, sideways ? extent().width - width : extent().height - height);
    }

    function mark(index: int) {
        reading.current = index;
        if (sectionStrip && sectionStrip.currentIndex !== index)
            sectionStrip.currentIndex = index;
    }

    function glideTo(position: real, instant: bool) {
        glide.stop();
        glide.property = sideways ? "contentX" : "contentY";
        glide.to = position;
        glide.duration = instant ? 0 : Tokens.durationPivotGlide;
        glide.start();
    }

    // A wheel, a touch or a key is the user's: a running jump stops, and following the scroll is on again (:869).
    function userScroll() {
        reading.jumped = false;
        glide.stop();
    }

    function scrollSideways(by: real): bool {
        const to = Math.max(0, Math.min(mostScroll(), flick.contentX + by));
        flick.cancelFlick();
        flick.contentX = to;
        return true;
    }

    function scrollVertically(flickable: var, by: real): bool {
        const top = flickable.originY - flickable.topMargin;
        const bottom = Math.max(top, flickable.originY + flickable.contentHeight + flickable.bottomMargin - flickable.height);
        flickable.cancelFlick();
        flickable.contentY = Math.max(top, Math.min(bottom, flickable.contentY + by));
        return true;
    }

    function scrollableVertically(item: var, down: bool): bool {
        if (!(item instanceof Flickable) || !item.interactive || item.flickableDirection === Flickable.HorizontalFlick)
            return false;
        return item.contentHeight > item.height + 1 && host.room(item, down);
    }

    // The nearest flick at the pointer with room in the wheel's direction (rekta.js:882–885).
    function innerScrollerAt(down: bool): var {
        let at = row.mapFromItem(panorama, reading.pointer.x, reading.pointer.y);
        let leaf = row;
        for (let child = leaf.childAt(at.x, at.y); child; child = leaf.childAt(at.x, at.y)) {
            at = Qt.point(at.x - child.x, at.y - child.y);
            leaf = child;
        }
        for (let item = leaf; item && item !== row; item = item.parent) {
            if (scrollableVertically(item, down))
                return item;
        }
        return null;
    }

    // Sections side by side from the inset, or stacked top to bottom (rekta.css:1167–1173, :853–856).
    function relayout() {
        const sections = sectionItems();
        const stacked = !sideways;
        let along = inset;
        let top = 0;
        for (let k = 0; k < sections.length; k++) {
            const section = sections[k];
            wire(section);
            const own = section instanceof Section && section.sectionWidth > 0 ? section.sectionWidth : sectionWidth;
            if (section instanceof Section) {
                section.stacked = stacked;
                section.separated = k > 0;
            }
            section.width = stacked ? width - 2 * inset : own;
            section.height = stacked ? section.implicitHeight : flick.height;
            section.x = stacked ? inset : along;
            section.y = stacked ? top : 0;
            along += section.width + gap;
            top += section.height;
        }
        reading.reach = sections.length ? along - gap : inset;
        reading.stackHeight = top;
    }

    function wire(section: var) {
        if (reading.wired.has(section))
            return;
        reading.wired.add(section);
        section.implicitHeightChanged.connect(relayout);
        if (section instanceof Section)
            section.sectionWidthChanged.connect(relayout);
    }

    // The section being read follows the scroll (rekta.js follow(), :852; a wide pivot's follow(), :1066).
    function follow() {
        const sections = sectionItems();
        if (fit || !sections.length)
            return;
        const chosen = facetRow ? followedFacet(sections) : followedSection(sections);
        if (chosen >= 0 && chosen !== reading.current)
            mark(chosen);
    }

    function followedSection(sections: var): int {
        if (reading.jumped)
            return -1;
        const reach = (sideways ? flick.width : flick.height) / 3;
        const here = sideways ? flick.contentX : flick.contentY;
        if (sideways && here >= mostScroll() - 1)
            return sections.length - 1;
        let chosen = 0;
        for (let k = 0; k < sections.length; k++) {
            if ((sideways ? sections[k].x : sections[k].y) - here <= reach)
                chosen = k;
        }
        return chosen;
    }

    // Wide facets: the one chosen stays while whole in sight, else the first past half of its width at the edge.
    function followedFacet(sections: var): int {
        if (glide.running)
            return -1;
        const mine = sections[reading.current];
        const left = mine ? mine.x - flick.contentX : 0;
        if (mine && left >= -1 && left + mine.width <= flick.width + 1)
            return -1;
        if (flick.contentX >= mostScroll() - 1)
            return sections.length - 1;
        return sections.findIndex(p => p.x - flick.contentX + p.width > 1 + p.width / 2);
    }

    activeFocusOnTab: !facetRow
    Accessible.role: Accessible.Pane

    onWidthChanged: relayout()
    onHeightChanged: relayout()
    onSectionWidthChanged: relayout()
    onInsetChanged: relayout()
    // A change of size class keeps the section being read, not an offset (layout.md, "Size classes").
    onSidewaysChanged: {
        relayout();
        goTo(reading.current, false, true);
        reading.jumped = false;
    }
    Component.onCompleted: {
        relayout();
        mark(reading.current);
    }

    // ← → PageUp PageDown jump a section, Home End to the ends; only on the panorama itself (rekta.js key(), :901).
    Keys.onPressed: event => {
        if (Window.activeFocusItem !== panorama || !sideways || facetRow || (event.modifiers & (Qt.AltModifier | Qt.ControlModifier | Qt.MetaModifier)))
            return;
        const last = sectionItems().length - 1;
        const at = reading.current;
        const moves = {
            [Qt.Key_Right]: at + 1,
            [Qt.Key_PageDown]: at + 1,
            [Qt.Key_Left]: at - 1,
            [Qt.Key_PageUp]: at - 1,
            [Qt.Key_Home]: 0,
            [Qt.Key_End]: last
        };
        if (!(event.key in moves))
            return;
        goTo(Math.max(0, Math.min(last, moves[event.key])), false, false);
        event.accepted = true;
    }

    QtObject {
        id: reading

        property int current: 0
        // Jumped to a section by key or strip: the scroll that follows is no reason to mark another (rekta.js `clicked`).
        property bool jumped: false
        property real reach: 0
        property real stackHeight: 0
        property point pointer
        property var gesture: null
        property var wired: new Set()
    }

    // The host of the wheel latch's questions (WheelLatch.route).
    QtObject {
        id: host

        function innerAt(down: bool): var {
            return panorama.innerScrollerAt(down);
        }

        function room(scrolled: var, down: bool): bool {
            return down ? !scrolled.atYEnd : !scrolled.atYBeginning;
        }

        function panRoom(down: bool): bool {
            return down ? panorama.scroller.contentX < panorama.mostScroll() - 1 : panorama.scroller.contentX > 0;
        }
    }

    Connections {
        function onSelected(index: int) {
            panorama.goTo(index, false, false);
        }

        function onActivated(index: int) {
            panorama.goTo(index, true, false);
        }

        target: panorama.sectionStrip
    }

    Flickable {
        id: flick

        objectName: "scroller"
        anchors.fill: parent
        clip: true
        interactive: !panorama.fit
        flickableDirection: panorama.sideways ? Flickable.HorizontalFlick : Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: panorama.extent().width
        contentHeight: panorama.extent().height

        onContentXChanged: if (panorama.sideways)
            panorama.follow()
        onContentYChanged: if (!panorama.sideways)
            panorama.follow()
        onMovementStarted: panorama.userScroll()
        onContentWidthChanged: returnToBounds()
        onContentHeightChanged: returnToBounds()

        Item {
            id: row

            objectName: "row"
            width: flick.contentWidth
            height: flick.contentHeight
            onChildrenChanged: panorama.relayout()
        }

        NumberAnimation {
            id: glide

            objectName: "glide"
            target: flick
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easePivotGlide
        }
    }

    // The wheel is Rekta's rules', decided before any item under it sees it (layout.md, rules 1–6).
    MouseArea {
        anchors.fill: parent
        z: 1
        enabled: panorama.sideways && !panorama.facetRow
        acceptedButtons: Qt.NoButton
        onWheel: wheel => wheel.accepted = panorama.handleWheel(wheel, Date.now())
    }

    FocusRing {
        shown: panorama.activeFocus && !panorama.facetRow
    }
}
