pragma ComponentBehavior: Bound

import QtQuick

// The app bar (navigation.md, "App bar"; rekta.css:797–861, :1412; rekta.js appbar(), :2699–2815): along the bottom,
// frosted glass under a hairline, its controls 48px in every density. The middle takes the room the controls leave
// and gives it up first: it cuts its words, then is gone while "more" shows. Controls that still do not fit move into
// "more", the least important first, and its menu repeats their words. Pinned, the middle keeps its words up to half
// the bar and the controls make room. The glass is the bar's; the blur behind it is the host's.
//
// When a control widens, comes or goes, the others glide to their new places (motion.md, "Resize and re-flow"); one that
// goes, into "more" or for good, fades out first, and one that comes fades in (motion.md, "Arriving, leaving").
//
// Away (under a full-screen window) it slides down out of sight, and comes back the same way: it leaves with ease-out
// and arrives with ease-in, as everything that leaves and arrives does (motion.md).
//
// A `centre` item stands in the middle of the bar; what comes before it holds the leading side, what comes after it the
// trailing side, and nothing runs under it. Without one the bar is a single row, as on the web. Other items are left
// where they are.
//
// The status words (`AppBarStatus`) never move into "more", as the live state never does in Rekta (navigation.md,
// "When the bar is full"); the other controls give way to them first, then the words give up places, down to a single "+N".
Rectangle {
    id: bar

    // The controls, the middle and the centre item, in their order along the bar.
    default property alias content: strip.data
    // One of the content items, centred in the bar.
    property Item centre: null
    // Sideways (the viewport wide and tall enough) the bar takes desktop padding (rekta.css:1410–1412).
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
    readonly property AppBarStatus statusItem: statusWords()
    readonly property alias more: moreButton
    readonly property alias menu: moreMenu
    // While a control fades out of the bar: the rest wait with their gliding until it has gone.
    readonly property bool settling: buttons().some(control => control.fading)
    // While the controls glide to their new places.
    readonly property bool gliding: motion.running
    readonly property alias reflow: motion
    // True once the bar has laid itself out; before that nothing glides or fades.
    property bool ready: false
    // The room the bar last laid itself out in (roomKey()).
    property string laidOutIn: ""
    // Where the menu rises, in the bar's coordinates: above "more" at the trailing edge (rekta.css:857–861).
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
        const items = Array.from(strip.children).filter(item => item === centre || (item as AppBarButton)?.present === true || (item as AppBarMiddle) !== null || (item as AppBarStatus)?.present === true);
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

    // The room an item needs at least: the middle gives all of it up, unless pinned; the status words take what their limit
    // lets them.
    function least(item: Item, statusLimit: int): real {
        const status = item as AppBarStatus;
        if (status)
            return status.widthAt(statusLimit);
        const middle = item as AppBarMiddle;
        if (!middle)
            return item.implicitWidth;
        return middle.pinned ? Math.min(middle.implicitWidth, Geometry.appBarPinnedShare * width) : 0;
    }

    function fits(region: var, moved: var, moreShown: bool, statusLimit: int): bool {
        const shown = region.items.filter(item => shows(item, moved, moreShown));
        const widths = shown.map(item => least(item, statusLimit));
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

    // Which controls move into "more", and whether it shows; a control moves only from a side that does not fit. When the
    // controls have all gone and the status words still do not fit, they give up words, down to one count of them.
    function layoutPlan(): var {
        const sides = regions();
        const most = statusWords()?.most ?? 0;
        const fitAll = (moved, moreShown, limit) => sides.every(region => fits(region, moved, moreShown, limit));
        if (fitAll([], false, most))
            return { sides, moved: [], more: false, statusLimit: most };
        const moved = [];
        for (const control of candidates()) {
            if (fitAll(moved, true, most))
                break;
            if (!fits(sides.find(region => region.items.includes(control)), moved, true, most))
                moved.push(control);
        }
        // ponytail: with the readout in the centre (centreReserve) below about 520 px not even "+N" fits beside "more" and
        // it overlaps the clock; hide the words then, or let the bar scroll them, once a bar that narrow matters.
        let limit = most;
        while (limit > 0 && !fitAll(moved, true, limit))
            limit--;
        const order = Array.from(strip.children);
        return { sides, moved: moved.sort((a, b) => order.indexOf(a) - order.indexOf(b)), more: true, statusLimit: limit };
    }

    function statusWords(): AppBarStatus {
        return Array.from(strip.children).map(item => item as AppBarStatus).find(item => item !== null) ?? null;
    }

    // Before the middle the items pack from the start, after it to the end, also while it has given way; the middle
    // takes what is left. A side without one packs to its start, the trailing side to its end. Adds where each goes to
    // `targets`.
    function place(region: var, targets: var) {
        const at = region.items.findIndex(item => (item as AppBarMiddle) !== null);
        const split = at >= 0 ? at : region.packEnd ? 0 : region.items.length;
        const visible = items => items.filter(item => item !== region.items[at] && shows(item, plan.moved, plan.more));
        const after = visible(region.items.slice(split));
        if (plan.more && region.more)
            after.push(moreButton);
        let start = region.start;
        for (const item of visible(region.items.slice(0, split))) {
            put(targets, item, start, widthOf(item));
            start += widthOf(item) + gap;
        }
        let end = region.end;
        for (const item of after.reverse()) {
            end -= widthOf(item);
            put(targets, item, end, widthOf(item));
            end -= gap;
        }
        if (at >= 0 && shows(region.items[at], plan.moved, plan.more))
            fill(targets, region.items[at] as AppBarMiddle, start, end);
    }

    // The status words' room is read from their slots: the bar lays out as soon as they are present, which may be before
    // their implicitWidth has followed the same change.
    function widthOf(item: Item): real {
        return (item as AppBarStatus)?.occupied() ?? item.implicitWidth;
    }

    function fill(targets: var, middle: AppBarMiddle, start: real, end: real) {
        const room = Math.max(0, end - start);
        put(targets, middle, start, middle.pinned ? Math.min(middle.implicitWidth, Geometry.appBarPinnedShare * width, room) : room);
    }

    // Centred across the bar, as `align-items: center` does; the status words follow their row.
    function put(targets: var, item: Item, x: real, itemWidth: real) {
        targets.push({ item, x, width: itemWidth, y: Math.round((height - item.height) / 2) });
        const status = item as AppBarStatus;
        if (status)
            targets.push(...status.places(x));
    }

    // What the sides have to lay out in; the controls glide only while it stays as it is.
    function roomKey(): string {
        return JSON.stringify([height, plan.sides.map(region => [region.start, region.end])]);
    }

    // Every control but the centre, the status words among them, also those that are not present yet, so that one that
    // comes later fades in too.
    function buttons(): var {
        return Array.from(strip.children).concat([moreButton], statusWords()?.controls() ?? []).filter(item => item !== centre && (item as AppBarButton) !== null);
    }

    // What changes at once: what goes, into "more" or for good, starts fading out; the middle and the words follow the
    // plan. Once nothing fades any more, the rest glide to their places while what comes fades in where it rests (rekta.js
    // presence(), :3430–3446); until then it waits out of sight. A change of the room the sides have, such as the
    // window's width, lays out at once: what that change brings comes and goes without a fade, what comes or goes after
    // it fades again.
    function apply() {
        const room = roomKey();
        const still = ready && room === laidOutIn;
        buttons().forEach(control => (control.animated = still));
        arrange(room, still);
        buttons().forEach(control => (control.animated = ready));
    }

    function arrange(room: string, still: bool) {
        for (const item of plan.sides.reduce((items, region) => items.concat(region.items), [])) {
            const middle = item as AppBarMiddle;
            if (middle)
                middle.visible = shows(middle, plan.moved, plan.more);
        }
        for (const control of buttons())
            control.overflowed = control === moreButton ? !plan.more : plan.moved.includes(control);
        const words = statusWords();
        if (words)
            words.limit = plan.statusLimit;
        // The words are counted a moment after they change, and the bar lays out with them once they are.
        if (words && !words.counted(plan.statusLimit))
            return;
        if (!settling) {
            layOut(still);
            laidOutIn = room;
        }
        buttons().forEach(control => (control.held = !motion.known.includes(control)));
    }

    function layOut(glide: bool) {
        if (centre) {
            centre.x = Math.round((width - centre.implicitWidth) / 2);
            centre.y = Math.round((height - centre.height) / 2);
        }
        const targets = [];
        plan.sides.forEach(region => place(region, targets));
        motion.show(targets, glide);
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

    // The status words change without the plan, as a fading word goes; the bar lays them out with the rest.
    Connections {
        target: bar.statusItem

        function onSlotsChanged() {
            Qt.callLater(bar.apply);
        }
    }
    onHeightChanged: apply()
    onSettlingChanged: {
        if (!settling)
            apply();
    }
    Component.onCompleted: {
        apply();
        ready = true;
        laidOutIn = roomKey();
        buttons().forEach(control => (control.animated = true));
    }

    Reflow {
        id: motion

        frame: bar
    }

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
