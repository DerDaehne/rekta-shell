pragma ComponentBehavior: Bound
import QtQuick

// The toast region (behaviour.md `toaster()`; rekta.css:873–930): one toast at a time, hanging from the top centre. A
// new toast replaces the one open and comes in once that one has gone; the same key with undo joins the open toast
// instead and restarts its window. Escape inside a toast dismisses it (key layer 30); Ctrl+Z undoes while an undo
// window is open, except in a text field (layer 25). It stays on the toast layer, below floating surfaces and below
// sheets, which sit in the modal layer above everything (states.md, "Layers"; platforms.md, "Layer"). The host puts it
// at the top of its screen and gives it its width; it is as high as its toast needs.
Item {
    id: toaster

    // The shell's own entrance, chosen over Rekta's fade from 12px: a toast slides in whole from the top edge, without
    // a fade, to 12px below it on the pivot glide, and leaves back up on ease-out in 0.6 of that time.
    readonly property real rest: 12
    readonly property int slideIn: Tokens.reducedMotion ? 0 : 300
    readonly property int slideOut: slideIn * 0.6

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
    property var removeKeyLayers: []

    function now(): double {
        return clock();
    }

    // Shows one toast and returns it. Options as rekta.js toaster.show(): key, undo (a function), from (the item focus
    // returns to), action ("undo", "redo" or another label), act ({ label, run }), status, windowMs, onEnd(reason); and
    // icon, an image for the app the toast speaks for, at its front; title, open ({ run }, the text as a control) and
    // stays (no window until it is dismissed).
    function show(text: string, options: var): Toast {
        const o = Object.assign({ key: text, undo: null, from: null, action: undoWord, act: null, status: "", windowMs: 0, onEnd: null, icon: "", title: "", open: null, stays: false }, options);
        if (open && open.key === o.key && open.undoAction && o.undo) {
            open.update(text, o.undo, o.windowMs, o.onEnd);
            return open;
        }
        if (open)
            open.leave(false, "replaced");
        open = toastComponent.createObject(cell, {
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
            waiting: leaving > 0
        }) as Toast;
        if (leaving === 0)
            open.begin();
        return open;
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

    // A toast has gone: the one waiting comes in.
    function gone() {
        leaving--;
        if (leaving === 0 && open?.waiting)
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

    implicitHeight: rest + Array.from(cell.children).reduce((tallest, toast) => Math.max(tallest, toast.height), 0)
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

    Item {
        id: cell

        anchors.fill: parent
    }
}
