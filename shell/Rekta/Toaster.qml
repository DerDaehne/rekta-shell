pragma ComponentBehavior: Bound
import QtQuick

// The toast region (behaviour.md `toaster()`; rekta.css:1144–1236): one toast at a time, rising from the app bar, its
// trailing edge flush with that of the control that counts notifications, as Rekta's compact toast rises from the bar
// (rekta.css:1407). A new toast replaces the one open and comes in once that one has gone; the same key with undo joins
// the open toast instead and restarts its window. Escape inside a toast dismisses it (key layer 30); Ctrl+Z undoes while
// an undo window is open, except in a text field (layer 25). It stays on the toast layer, below floating surfaces and
// below sheets, which sit in the modal layer above everything (states.md, "Layers"; platforms.md, "Layer"). The host
// puts it along the top of the app bar and gives it its width; it is as high as its toast needs.
//
// A notification's toast rises from its count: the count gives way (`countAway`), the toast comes in once the count is
// turn-overlap through its way out, and the count comes back once the toast is turn-overlap through its way down, unless
// another notification's toast comes next (motion.md:14, the place change's hand-over; rekta.js:594).
// A deliberate deviation: sideways Rekta hangs toasts from the top centre (rekta.css:1158, :1417), and a notification
// from another program glides in whole from the window's edge without a fade, compact from the bottom edge
// (states.md:84–88; motion.md:36; rekta.css:1197–1203). Here every toast, a notification's too, rises from the bar as a
// compact toast of the product's own does (rekta.css:1169, :1172, :1407), so that a notification rises from the control
// that counts it.
Item {
    id: toaster

    // The toast that shows or waits to show; null when none is open. Set by show(), never from outside.
    property Toast open: null
    // The word of the undo action; Ctrl+Z undoes a toast that carries it.
    property string undoWord: "undo"
    // Wall-clock time in ms: undo windows run against it, so a late timer never stretches them. Tests set their own.
    property var clock: () => Date.now()
    // An undo window takes duration-toast in whole seconds (rekta.js toaster(), `tokenWindow`).
    readonly property int undoWindow: (Math.round(Tokens.durationToast / 1000) || 5) * 1000
    // Toasts on their way out; a new toast waits for them.
    property int leaving: 0
    // Where the toasts' trailing edge goes, in the toaster's x: that of the control that counts notifications, or of the
    // bar's "more" while that holds it. The host sets it.
    property real trailingEdge: width
    // Whether that control is in sight to give way; while it is not, a notification's toast comes in at once.
    property bool countInSight: false
    // While a notification's toast is on its way in, stands or is on its way down: the count gives way. Set here only.
    property bool countAway: false
    // The count leaves as the old count of a peek does; a notification's toast comes in turn-overlap into that way.
    readonly property int countGoes: Math.round(Tokens.turnOverlap * Geometry.peekOutShare * Tokens.durationModerate)
    property var removeKeyLayers: []

    function now(): double {
        return clock();
    }

    // Shows one toast and returns it. Options as rekta.js toaster.show(): key, undo (a function), from (the item focus
    // returns to), action ("undo", "redo" or another label), act ({ label, run }), status, windowMs, onEnd(reason); and
    // icon, an image for the app the toast speaks for, at its front; title, open ({ run }, the text as a control) and
    // stays (no window until it is dismissed); notification, a notification from another program, which its count gives
    // way to.
    function show(text: string, options: var): Toast {
        const o = Object.assign({ key: text, undo: null, from: null, action: undoWord, act: null, status: "", windowMs: 0, onEnd: null, icon: "", title: "", open: null, stays: false, notification: false }, options);
        if (open && open.key === o.key && open.undoAction && o.undo) {
            open.update(text, o.undo, o.windowMs, o.onEnd);
            return open;
        }
        // The one open lets go once the next is known, so that its count stays away for a notification that follows.
        const replaced = open;
        const toast = toastComponent.createObject(cell, {
            toaster: toaster,
            key: o.key,
            text: text,
            status: o.status,
            icon: o.icon,
            title: o.title,
            open: o.open,
            stays: o.stays,
            action: o.action,
            undoAction: o.undo,
            act: o.act,
            from: o.from,
            endHandler: o.onEnd,
            windowMs: o.windowMs,
            notification: o.notification,
            waiting: true
        }) as Toast;
        open = toast;
        if (o.notification)
            giveWay();
        replaced?.leave(false, "replaced");
        beginNext();
        return toast;
    }

    function dismiss() {
        open?.leave(false, "dismissed");
    }

    // A toast has begun to leave.
    function letGo(toast: Toast) {
        if (open === toast)
            open = null;
        leaving++;
    }

    // A toast that began to leave over `way` ms has ended, and its end may have shown the next toast. A notification's
    // hands its count back turn-overlap into that way.
    function handCountBack(toast: Toast, way: int) {
        if (!toast.notification)
            return;
        countBack.interval = Math.round(Tokens.turnOverlap * way);
        if (countBack.interval > 0)
            countBack.restart();
        else
            takeCountBack();
    }

    // A toast has gone: the one waiting may come in.
    function gone() {
        leaving--;
        beginNext();
    }

    // The count starts to give way; a notification's toast waits until it is turn-overlap through.
    function giveWay() {
        if (countAway)
            return;
        countAway = true;
        if (countInSight && countGoes > 0)
            handOver.restart();
    }

    // The count comes back, unless the toast that comes next is a notification's too.
    function takeCountBack() {
        countAway = open?.notification ?? false;
        if (!countAway)
            handOver.stop();
    }

    // The toast waiting comes in once the one before has gone and the count has made way.
    function beginNext() {
        if (open?.waiting && leaving === 0 && !handOver.running)
            open.begin();
    }

    function holdsFocus(focusItem: Item): bool {
        for (let item = focusItem; item; item = item.parent) {
            if (item === open)
                return true;
        }
        return false;
    }

    function isUndoKey(event: KeyEvent): bool {
        const command = (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) !== 0;
        return event.key === Qt.Key_Z && command && !(event.modifiers & Qt.ShiftModifier);
    }

    // Escape inside the toast dismisses it.
    function dismissOnEscape(event: KeyEvent, focusItem: Item): bool {
        if (event.key !== Qt.Key_Escape || !open || !holdsFocus(focusItem))
            return false;
        open.leave(false, "dismissed");
        return true;
    }

    // Ctrl+Z undoes while an undo window is open. A text field takes its own Ctrl+Z before any layer sees it.
    function undoOnCtrlZ(event: KeyEvent): bool {
        if (!open?.undoAction || open.action !== undoWord || !isUndoKey(event))
            return false;
        open.undo();
        return true;
    }

    // Toasts stand space-s above the bar (rekta.css:1407).
    implicitHeight: Tokens.spaceS + Array.from(cell.children).reduce((tallest, toast) => Math.max(tallest, toast.height), 0)
    z: Tokens.layerToast

    Component.onCompleted: removeKeyLayers = [
        KeyLayers.on(30, (event, focusItem) => dismissOnEscape(event, focusItem)),
        KeyLayers.on(25, event => undoOnCtrlZ(event))
    ]
    Component.onDestruction: removeKeyLayers.forEach(remove => remove())

    Component {
        id: toastComponent

        Toast {}
    }

    Timer {
        id: handOver

        objectName: "handOver"
        interval: toaster.countGoes
        onTriggered: toaster.beginNext()
    }

    Timer {
        id: countBack

        objectName: "countBack"
        onTriggered: toaster.takeCountBack()
    }

    Item {
        id: cell

        anchors.fill: parent
    }
}
