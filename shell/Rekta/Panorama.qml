pragma ComponentBehavior: Bound

import QtQuick

// A panorama (layout.md "Panorama" and "Sideways scrolling by mouse wheel"; navigation.md:57–69, :450–479; motion.md
// "Panorama scroll"; rekta.css:1124–1128, :1478–1499; rekta.js panorama(), :946–1119): sections side by side, each
// sized in tile units, so a wider window shows more sections, never wider ones. Each child is a section (see
// Section); a section scrolls vertically within itself, and the panorama is never taller than its box. When every
// section fits nothing scrolls. Compact the sections stack and the panorama scrolls vertically, the wheel untouched.
// An optional pivot of section titles follows the scroll and jumps to a section.
//
// facetRow is the same machinery for the facets of a wide pivot (rekta.css:285–295; rekta.js pivot(), :1210–1252):
// no inset and no trailing spacer, the wheel not redirected, and the facet chosen is the one scrolled into view.
Item {
    id: panorama

    default property alias content: row.data
    // --rk-sec-w (rekta.css:1492)
    property real sectionWidth: 3 * Tokens.tileUnit + 2 * Tokens.spaceS + 2 * Tokens.spaceXl
    property real placeWidth: width
    property real viewportHeight: Window.height
    property bool facetRow: false
    // A place turns the parts of the sections, not the panorama as one (PlaceTurn.turnsWhole; rekta.js turnUnits() opens boxes).
    property bool turnsWhole: false
    // The section strip: it follows the scroll, and choosing a title jumps to that section.
    property Pivot sectionStrip
    readonly property bool sideways: facetRow || Prefs.sizeClass(placeWidth, viewportHeight) === "sideways"
    readonly property real inset: facetRow ? 0 : sideways ? Tokens.spaceXl : Tokens.spaceM
    // The gap between the sections: space-xl, or as spread() makes it so that the window's edge never falls flush.
    readonly property real gap: reading.gap
    readonly property int currentIndex: reading.current
    // Everything fits: nothing scrolls, and no spacer lets the last section reach the left edge (rekta.css:1498).
    readonly property bool fit: fits()
    readonly property alias scroller: flick
    readonly property alias sectionParent: row
    readonly property alias gliding: glide.running

    // A gesture that began at an end of the panorama and goes on that way: a host may take it for its own (a wheel gesture
    // once, a swipe when it ends), forward being right and down. A panorama that fits has both ends under every gesture.
    signal pastEnd(bool forward)

    // The nearest section's start: flush left, or as far as the panorama scrolls (rekta.js startOf(), :954).
    function startOf(index: int): real {
        const section = sectionItems()[index];
        if (!section)
            return 0;
        return Math.min(sideways ? section.x - inset : section.y, mostScroll());
    }

    // Aligns a section and marks it (rekta.js goTo(), :964); focusHeading puts the focus on its heading.
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

    // One wheel event at wheel.x/wheel.y; true when the panorama took it (rekta.js wheel(), :998). The row of a wide
    // facet pivot takes only Shift+wheel (layout.md:99–101): a vertical wheel over its facets never moves it sideways.
    function handleWheel(wheel: var, now: real): bool {
        userScroll();
        if (!sideways)
            return false;
        reading.pointer = Qt.point(wheel.x, wheel.y);
        const e = WheelLatch.webEvent(wheel, Application.styleHints.wheelScrollLines, Geometry.wheelLinePixels, Qt.ControlModifier, Qt.ShiftModifier);
        if (facetRow)
            return shiftSideways(e);
        const routed = WheelLatch.route(reading.gesture, e, now, Tokens.durationWheelLatch, host);
        reading.gesture = routed.gesture;
        if (routed.fresh && routed.action === "pass")
            fallThrough(e);
        if (routed.action === "inner")
            return scrollVertically(routed.gesture.inner, e.dy);
        if (routed.action === "pan")
            return scrollSideways(e.dy);
        return shiftSideways(e) || routed.action === "swallow";
    }

    // The first event of a gesture that the panorama cannot move its way, and no one's native scroll does: it is the host's.
    function fallThrough(e: var) {
        if (e.ctrl)
            return;
        const along = Math.abs(e.dx) > Math.abs(e.dy) ? e.dx : e.dy;
        if (along !== 0 && !panRoom(along > 0))
            pastEnd(along > 0);
    }

    function panRoom(forward: bool): bool {
        return forward ? flick.contentX < mostScroll() - 1 : flick.contentX > 0;
    }

    // ponytail: Qt's Flickable does not turn Shift+wheel sideways as a browser does, so it is done here, unlatched;
    // it falls through at the ends like any sideways scroll.
    function shiftSideways(e: var): bool {
        if (!e.shift || e.ctrl)
            return false;
        return scrollSideways(Math.abs(e.dx) > Math.abs(e.dy) ? e.dx : e.dy);
    }

    // The sections in sight of the layout: a hidden one takes no room (display: none). While the panorama itself is
    // hidden every child counts, as nothing says which of them is hidden for itself. It counts as hidden until it has
    // shown whole: Qt shows the sections one by one before the row, and a layout of the first few would fit and pull
    // the view back to the start (rekta.js:1070).
    function sectionItems(): var {
        return [...row.children].filter(child => !reading.shown || !row.visible || child.visible);
    }

    function fits(): bool {
        return sideways && reading.reach <= width + Geometry.panoramaFitSlack;
    }

    // A panorama that reaches past its window never ends flush on a section's edge (layout.md "Never flush at the edge";
    // rekta.js spread(), :1043–1067): with the first section at the start, the window's edge falls inside a section, at
    // least space-xl from either of its ends. The gap changes from space-xl by as little as that takes, never below
    // space-m; a last section cut by less than space-xl fits instead, when a smaller gap lets it.
    function spread(sizes: var, edge: real): real {
        const xl = Tokens.spaceXl;
        const n = sizes.length;
        const before = j => sizes.slice(0, j).reduce((sum, w) => sum + w, 0);
        const fitsWith = g => before(n) + (n - 1) * g <= edge + Geometry.panoramaFitSlack;
        const inside = g => sizes.some((w, i) => before(i) + i * g + xl <= edge + Geometry.panoramaEdgeSlack && edge - Geometry.panoramaEdgeSlack <= before(i) + i * g + w - xl);
        if (facetRow || !sideways || fitsWith(xl) || inside(xl))
            return xl;
        const ways = n > 1 ? [Math.floor((edge - before(n)) / (n - 1))] : [];
        for (let j = 1; j <= n; j++) {
            if (j < n)
                ways.push(Math.floor((edge - xl - before(j)) / j));
            if (j > 1)
                ways.push(Math.ceil((edge + xl - before(j)) / (j - 1)));
        }
        // Of two as near to space-xl, the one found first, as Rekta's stable sort keeps it.
        const nearest = (best, g) => best === undefined || Math.abs(g - xl) < Math.abs(best - xl) ? g : best;
        return ways.filter(g => g >= Tokens.spaceM && (inside(g) || fitsWith(g))).reduce(nearest, undefined) ?? xl;
    }

    // The scrolled extent, from the layout and not from the Flickable's bindings, which a change of class may not have
    // reached yet when it jumps.
    function extent(): size {
        if (!sideways)
            return Qt.size(width, reading.stackHeight);
        // The last section can reach the left edge: a spacer after it, as wide as is left (rekta.css:1497–1498).
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

    // Anything the user does with the panorama makes the scroll that follows worth following again (rekta.js:995).
    function userScroll() {
        reading.jumped = false;
    }

    // ponytail: Rekta lets a running jump go on under a wheel; here its animation would write the position every frame
    // and pull the panorama back from the user's hand, so a wheel that moves the panorama, or a drag, stops it. A wheel
    // that scrolls a section, or one that is not the panorama's, leaves it running.
    function takeOver() {
        glide.stop();
    }

    // A focused item beyond the edge scrolls into view with space-xl clear, as a browser does with
    // `scroll-padding-inline` (rekta.css:1488), at once like the wheel.
    // ponytail: sideways only; a stacked panorama's vertical reveal is the nearest scroller's.
    function revealFocus() {
        const focused = Window.activeFocusItem;
        if (!sideways || fit || glide.running || !focused || !visible)
            return;
        let item = focused;
        while (item && item !== row)
            item = item.parent;
        if (item)
            Reveal.alongInto(flick, focused, inset, mostScroll());
    }

    // A swipe that began at an end and ends having gone on past it (the flick stops at its ends but tells how far).
    function swiped(dragging: bool) {
        if (dragging) {
            reading.dragFrom = {
                start: flick.atXBeginning,
                end: flick.atXEnd
            };
        } else if (sideways && !facetRow && flick.horizontalOvershoot > 0 && reading.dragFrom.end) {
            pastEnd(true);
        } else if (sideways && !facetRow && flick.horizontalOvershoot < 0 && reading.dragFrom.start) {
            pastEnd(false);
        }
    }

    function scrollSideways(by: real): bool {
        const to = Math.max(0, Math.min(mostScroll(), flick.contentX + by));
        flick.cancelFlick();
        const moved = to !== flick.contentX;
        if (moved)
            takeOver();
        flick.contentX = to;
        return moved;
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

    // The nearest flick at the pointer with room in the wheel's direction (rekta.js:1008–1011).
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

    // Sections side by side from the inset, or stacked top to bottom (rekta.css:1486–1492, :1124–1127).
    function relayout() {
        if (reading.gone)
            return;
        const sections = sectionItems();
        row.children.forEach(wire);
        const stacked = !sideways;
        const sizes = sections.map(section => section instanceof Section && section.sectionWidth > 0 ? section.sectionWidth : sectionWidth);
        reading.gap = spread(sizes, width - inset);
        let along = inset;
        let top = 0;
        for (let k = 0; k < sections.length; k++) {
            const section = sections[k];
            if (section instanceof Section) {
                section.stacked = stacked;
                section.separated = k > 0;
            }
            section.width = stacked ? width - 2 * inset : sizes[k];
            section.height = stacked ? section.implicitHeight : flick.height;
            section.x = stacked ? inset : along;
            section.y = stacked ? top : 0;
            along += section.width + gap;
            top += section.height;
        }
        reading.reach = sections.length ? along - gap : inset;
        reading.stackHeight = top;
        markInSight(sections);
        keepReading();
        followLayout();
    }

    // A stacked section that grows or shrinks moves the ones below it under a still view, so the mark goes where the
    // view now is; a layout made while the sections were still filling in leaves no stale mark behind.
    function followLayout() {
        if (!sideways)
            follow();
    }

    // A gap new since the panorama last showed keeps the section being read, not an offset, at once (rekta.js fit(),
    // :1069–1080): a panorama laid out while hidden jumps as it shows.
    function keepReading() {
        if (!row.visible)
            return;
        const was = reading.shownGap;
        reading.shownGap = reading.gap;
        if (reading.gap === was || !sideways || flick.contentX <= 0)
            return;
        goTo(reading.current, false, true);
        reading.jumped = false;
    }

    // A section that comes or goes moves the others under a still view, so the mark goes to the section the view now
    // shows, whatever jump held it (behaviour.md:491–494). Only a panorama that shows knows which sections are in sight.
    // ponytail: a glide under way goes on to its old offset, the mark following; re-aim it at its section if that shows.
    function markInSight(sections: var) {
        const same = sections.length === reading.inSight.length && sections.every((section, k) => section === reading.inSight[k]);
        if (same || facetRow || !row.visible || !sections.length)
            return;
        reading.inSight = sections;
        userScroll();
        mark(sectionAtEdge(sections));
    }

    function wire(section: var) {
        if (reading.wired.has(section))
            return;
        reading.wired.add(section);
        section.implicitHeightChanged.connect(relayout);
        section.visibleChanged.connect(relayout);
        if (section instanceof Section)
            section.sectionWidthChanged.connect(relayout);
    }

    // The section being read follows the scroll (rekta.js follow(), :973; a wide pivot's follow(), :1244).
    function follow() {
        const sections = sectionItems();
        if (fit || !sections.length)
            return;
        const chosen = facetRow ? followedFacet(sections) : reading.jumped ? -1 : sectionAtEdge(sections);
        if (chosen >= 0 && chosen !== reading.current)
            mark(chosen);
    }

    // The last section whose leading edge lies within a third of the view, stacked of the window's height; sideways at the
    // start the first and at the end the last, however narrow the sections (rekta.js follow(), :973–990).
    function sectionAtEdge(sections: var): int {
        const reach = (sideways ? flick.width : viewportHeight) / 3;
        const here = sideways ? flick.contentX : flick.contentY;
        if (sideways && here <= 1)
            return 0;
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
    Window.onActiveFocusItemChanged: revealFocus()
    // A change of size class keeps the section being read, not an offset (layout.md, "Size classes").
    onSidewaysChanged: {
        relayout();
        goTo(reading.current, false, true);
        reading.jumped = false;
    }
    Component.onDestruction: reading.gone = true
    Component.onCompleted: {
        relayout();
        mark(reading.current);
    }

    // Stacked the panorama is the page, and the keys scroll it as they scroll a page, which Rekta leaves to the platform
    // (layout.md:33–37; rekta.js key(), :1028): PageUp PageDown by the height in view, as Qt's own scroll areas step,
    // wherever the focus is in it; Home End to the top and the bottom on the panorama itself, as a grid takes them.
    function pageKey(event: KeyEvent, onItself: bool): bool {
        if (sideways || facetRow || (event.modifiers & (Qt.AltModifier | Qt.ControlModifier | Qt.MetaModifier)))
            return false;
        const moves = {
            [Qt.Key_PageDown]: flick.contentY + flick.height,
            [Qt.Key_PageUp]: flick.contentY - flick.height
        };
        if (onItself) {
            moves[Qt.Key_Home] = 0;
            moves[Qt.Key_End] = mostScroll();
        }
        if (!(event.key in moves))
            return false;
        // A key that scrolls is the user's own scroll, wherever the focus is: it ends a jump's hold on the mark.
        userScroll();
        takeOver();
        flick.cancelFlick();
        flick.contentY = Math.max(0, Math.min(mostScroll(), moves[event.key]));
        return true;
    }

    // Sideways: ← → PageUp PageDown jump a section, Home End to the ends; only on the panorama itself (rekta.js key(),
    // :1027). Stacked: pageKey().
    Keys.onPressed: event => {
        userScroll();
        if (pageKey(event, Window.activeFocusItem === panorama)) {
            event.accepted = true;
            return;
        }
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
        // A key is the user's: the scroll its jump causes is followed, only a click wins over that.
        // ponytail: following a key's own jump is Rekta 0.5.0's; 0.6.0 keeps its target marked for the whole glide, as
        // a click's (rekta.js:993–995).
        userScroll();
        event.accepted = true;
    }

    QtObject {
        id: reading

        property int current: 0
        // Jumped to a section by the strip: the scroll that follows is no reason to mark another (rekta.js `clicked`).
        property bool jumped: false
        property real reach: 0
        property real gap: Tokens.spaceXl
        // The gap of the last layout while the panorama showed.
        property real shownGap: Tokens.spaceXl
        property real stackHeight: 0
        property point pointer
        property var gesture: null
        property var dragFrom: ({})
        property var wired: new Set()
        // The sections in sight at the last layout while the panorama showed. Shown again with others in sight, it
        // marks by position.
        property var inSight: []
        // The row's visibility as last signalled, which lags behind `row.visible` while its sections are shown.
        property bool shown: row.visible
        onShownChanged: panorama.relayout()
        // Items of a panorama that is being destroyed still signal; nothing is laid out then.
        property bool gone: false
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
            return panorama.panRoom(down);
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
        boundsBehavior: Flickable.DragOverBounds
        boundsMovement: Flickable.StopAtBounds
        contentWidth: panorama.extent().width
        contentHeight: panorama.extent().height

        onContentXChanged: if (panorama.sideways)
            panorama.follow()
        onContentYChanged: if (!panorama.sideways)
            panorama.follow()
        onDraggingChanged: panorama.swiped(dragging)
        onMovementStarted: {
            panorama.userScroll();
            panorama.takeOver();
        }
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
        enabled: panorama.sideways
        acceptedButtons: Qt.NoButton
        onWheel: wheel => wheel.accepted = panorama.handleWheel(wheel, Date.now())
    }

    FocusRing {
        shown: panorama.activeFocus && !panorama.facetRow
    }
}
