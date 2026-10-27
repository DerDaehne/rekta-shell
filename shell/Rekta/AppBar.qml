pragma ComponentBehavior: Bound

import QtQuick

// The app bar (navigation.md, "App bar"; rekta.css:616–653, :1101; rekta.js appbar(), :2287–2353): along the bottom,
// frosted glass under a hairline, its controls 48px in every density. The middle takes the room the controls leave
// and gives it up first: it cuts its words, then is gone while "more" shows. Controls that still do not fit move into
// "more", the least important first, and its menu repeats their words. Pinned, the middle keeps its words up to half
// the bar and the controls make room. The glass is the bar's; the blur behind it is the host's.
//
// Away (under a full-screen window) it slides down out of sight, and comes back the same way: it leaves with ease-out
// and arrives with ease-in, as everything that leaves and arrives does (motion.md).
//
// A `centre` item stands in the middle of the bar; what comes before it holds the leading side, what comes after it the
// trailing side, and nothing runs under it. Without one the bar is a single row, as on the web. Other items are left
// where they are.
Rectangle {
    id: bar

    // The controls, the middle and the centre item, in their order along the bar.
    default property alias content: strip.data
    // One of the content items, centred in the bar.
    property Item centre: null
    // Sideways (the viewport wide and tall enough) the bar takes desktop padding (rekta.css:1099–1101).
    property real viewportHeight: Window.height
    // The window "more" has to fit in; the bar runs along its bottom.
    property size area: Qt.size(Window.width, Window.height)
    // Room kept free around the centre item for something wider that takes its place for a moment.
    property real centreReserve: 0
    // Out of sight below the window's bottom edge.
    property bool away: false
    // While it slides away or back; a host keeps its window until it is out of sight.
    readonly property bool sliding: slide.running
    readonly property real padding: Prefs.sizeClass(width, viewportHeight) === "sideways" ? Tokens.spaceXl : Tokens.spaceM
    readonly property real gap: Tokens.spaceXs
    readonly property var plan: layoutPlan()
    readonly property alias more: moreButton
    readonly property alias menu: moreMenu
    // Where the menu rises, in the bar's coordinates: above "more" at the trailing edge (rekta.css:649–653).
    readonly property var menuPlace: floatPlace(moreButton, Qt.size(moreMenu.width, moreMenu.height))

    // Where a floating surface of one of the bar's controls goes, in the bar's coordinates (Placement.float in `area`).
    function floatPlace(control: Item, size: size, align = "start"): var {
        const top = area.height - height;
        const place = Placement.float(Qt.rect(control.x, top + control.y, control.width, control.height), size, area, align);
        return { x: place.x, y: place.y - top, side: place.side };
    }

    // Where the tooltip of one of the bar's controls goes, in the bar's coordinates (Placement.tip in `area`).
    function tipPlace(control: Item, size: size): var {
        const top = area.height - height;
        const at = control.mapToItem(bar, 0, 0);
        const place = Placement.tip(Qt.rect(at.x, top + at.y, control.width, control.height), size, area);
        return { x: place.x, y: place.y - top, side: place.side };
    }

    // The leading and trailing side around the centre item, or the whole bar; "more" ends the last.
    function regions(): var {
        const items = Array.from(strip.children).filter(item => item === centre || (item as AppBarButton)?.present === true || (item as AppBarMiddle) !== null);
        const at = centre ? items.indexOf(centre) : -1;
        if (at < 0)
            return [{ items, start: padding, end: width - padding, packEnd: false, more: true }];
        const half = Math.max(centre.implicitWidth, centreReserve) / 2;
        return [
            { items: items.slice(0, at), start: padding, end: width / 2 - half - gap, packEnd: false, more: false },
            { items: items.slice(at + 1), start: width / 2 + half + gap, end: width - padding, packEnd: true, more: true }
        ];
    }

    function shows(item: Item, moved: var, moreShown: bool): bool {
        const middle = item as AppBarMiddle;
        if (middle)
            return middle.present && (!moreShown || middle.pinned);
        return !moved.includes(item);
    }

    // The room an item needs at least: the middle gives all of it up, unless pinned.
    function least(item: Item): real {
        const middle = item as AppBarMiddle;
        if (!middle)
            return item.implicitWidth;
        return middle.pinned ? Math.min(middle.implicitWidth, Geometry.appBarPinnedShare * width) : 0;
    }

    function fits(region: var, moved: var, moreShown: bool): bool {
        const shown = region.items.filter(item => shows(item, moved, moreShown));
        const widths = shown.map(item => least(item));
        if (moreShown && region.more)
            widths.push(moreButton.implicitWidth);
        const needed = widths.reduce((sum, w) => sum + w, 0) + gap * Math.max(0, widths.length - 1);
        // Half a pixel for rounding, like rekta.js's fits().
        return needed <= region.end - region.start + 0.5;
    }

    // Least important first; among equals, from the end (rekta.js appbar()).
    function candidates(): var {
        const controls = Array.from(strip.children).filter(item => item !== centre && (item as AppBarButton)?.present === true);
        return controls.map((control, i) => ({ control, i })).sort((a, b) => a.control.priority - b.control.priority || b.i - a.i).map(entry => entry.control);
    }

    // Which controls move into "more", and whether it shows; a control moves only from a side that does not fit.
    function layoutPlan(): var {
        const sides = regions();
        const fitAll = (moved, moreShown) => sides.every(region => fits(region, moved, moreShown));
        if (fitAll([], false))
            return { sides, moved: [], more: false };
        const moved = [];
        for (const control of candidates()) {
            if (fitAll(moved, true))
                break;
            if (!fits(sides.find(region => region.items.includes(control)), moved, true))
                moved.push(control);
        }
        const order = Array.from(strip.children);
        return { sides, moved: moved.sort((a, b) => order.indexOf(a) - order.indexOf(b)), more: true };
    }

    // Before the middle the items pack from the start, after it to the end, also while it has given way; the middle
    // takes what is left. A side without one packs to its start, the trailing side to its end.
    function place(region: var) {
        const at = region.items.findIndex(item => (item as AppBarMiddle) !== null);
        const split = at >= 0 ? at : region.packEnd ? 0 : region.items.length;
        const visible = items => items.filter(item => item !== region.items[at] && shows(item, plan.moved, plan.more));
        const after = visible(region.items.slice(split));
        if (plan.more && region.more)
            after.push(moreButton);
        let start = region.start;
        for (const item of visible(region.items.slice(0, split))) {
            put(item, start);
            start += item.width + gap;
        }
        let end = region.end;
        for (const item of after.reverse()) {
            end -= item.width;
            put(item, end);
            end -= gap;
        }
        if (at >= 0 && shows(region.items[at], plan.moved, plan.more))
            fill(region.items[at] as AppBarMiddle, start, end);
    }

    function fill(middle: AppBarMiddle, start: real, end: real) {
        const room = Math.max(0, end - start);
        middle.width = middle.pinned ? Math.min(middle.implicitWidth, Geometry.appBarPinnedShare * width, room) : room;
        put(middle, start);
    }

    // Centred across the bar, as `align-items: center` does.
    function put(item: Item, x: real) {
        item.x = Math.round(x);
        item.y = Math.round((height - item.height) / 2);
    }

    function apply() {
        for (const item of plan.sides.reduce((items, region) => items.concat(region.items), [])) {
            const control = item as AppBarButton;
            if (control)
                control.overflowed = plan.moved.includes(control);
            const middle = item as AppBarMiddle;
            if (middle)
                middle.visible = shows(middle, plan.moved, plan.more);
        }
        moreButton.overflowed = !plan.more;
        if (centre)
            put(centre, (width - centre.implicitWidth) / 2);
        plan.sides.forEach(region => place(region));
    }

    implicitHeight: Tokens.appbarHeight
    z: Tokens.layerAppbar
    color: Tokens.color.glass
    transform: Translate {
        y: bar.away ? bar.height : 0

        Behavior on y {
            id: slideTo

            NumberAnimation {
                id: slide

                objectName: "slide"
                duration: Tokens.durationShort
                easing.type: Easing.Bezier
                // The Behavior sets its target before the slide takes its curve; a binding on `away` may update later.
                easing.bezierCurve: slideTo.targetValue > 0 ? Tokens.easeOut : Tokens.easeIn
            }
        }
    }
    Accessible.role: Accessible.ToolBar
    Accessible.name: "app bar"

    onPlanChanged: apply()
    onHeightChanged: apply()
    Component.onCompleted: apply()

    Hairline {
        objectName: "hairline"
        width: bar.width
    }

    Item {
        id: strip

        anchors.fill: parent
    }

    AppBarButton {
        id: moreButton

        objectName: "more"
        icon: "more"
        text: "mehr"
        overflowed: true

        onClicked: {
            if (moreMenu.open)
                moreMenu.close(true);
            else
                moreMenu.openAt(0);
        }
    }

    Menu {
        id: moreMenu

        objectName: "moreMenu"
        control: moreButton
        area: bar.area
        x: bar.menuPlace.x
        y: bar.menuPlace.y
        side: bar.menuPlace.side

        onChosen: item => (item as MovedControl)?.modelData.click()

        Repeater {
            model: bar.plan.moved

            delegate: MovedControl {}
        }
    }

    // A control in "more" repeats its words and its reason; choosing it presses the control.
    component MovedControl: MenuItem {
        required property AppBarButton modelData

        text: modelData.words
        disabledReason: modelData.disabledReason
    }
}
