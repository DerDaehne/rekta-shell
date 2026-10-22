import QtQuick

// A sheet (states.md, "Layers"; forms.md, "A form in a sheet"; behaviour.md, `sheet()`; rekta.css:825–846): a short
// question hanging from the top edge over the shading, while everything behind stays where it was. It comes 16px down
// with a fade over duration-short and leaves the way it came in 0.8 × that (motion.md, "Sheets"). It holds the focus
// while it is open and gives it back once it has gone. Escape (a key layer), the shading and its close button are
// close requests: while `dirty` it asks first, in its own place. The host lays it over its whole surface, above the
// toasts, has what lies behind blurred (rekta.css:832) and routes keys to KeyLayers.
Item {
    id: sheet

    property string kicker
    property string title
    // Unsaved input: a close request asks before it goes.
    property bool dirty: false
    // The visible way out of a sheet without a safe answer of its own, at its top corner.
    property bool closeButton: true
    // What takes the focus as it opens; by default the first control in it.
    property Item initialFocus
    // Where the focus goes back once it has gone; by default what had the focus as it opened. A host that shows the
    // sheet in a window of its own names the control that opened it.
    property Item opener
    // The question that takes the sheet's place before unsaved input goes.
    property string askKicker: "unsaved"
    property string askTitle: "Discard what you entered?"
    property string keepWord: "keep editing"
    property string discardWord: "discard changes"
    // Set by show(), request() and close(): open from show() until it has gone, asking while the question shows.
    property bool open: false
    property bool asking: false
    // Runs from 0 to 1 as it comes in, and back to 0 as it leaves.
    property real entry: 1
    // The shading's opacity: there at once, it fades as the sheet leaves.
    property real shade: 1
    readonly property real shift: -(1 - entry) * Geometry.sheetShift
    readonly property bool sideways: Prefs.sizeClass(width, height) === "sideways"
    default property alias content: form.data

    // It has gone, with the answer that closed it ("cancel" for a close request).
    signal closed(string answer)

    function show() {
        if (open)
            return;
        memo.focused = opener ?? Window.activeFocusItem;
        open = true;
        shade = 1;
        KeyLayers.opened(sheet);
        comingIn.restart();
        (initialFocus ?? startGuard.nextItemInFocusChain(true)).forceActiveFocus();
    }

    // Escape, the shading, the close button or a cancel answer: while dirty it asks first, and while it asks, a close
    // request means keep editing.
    function request(answer: string) {
        if (!open)
            return;
        // While it leaves, a request only ends the leave at once, keeping the answer it leaves with (rekta.js:1536).
        if (going.running)
            leave(memo.answer);
        else if (asking)
            keepEditing();
        else if (dirty)
            askFirst(answer);
        else
            leave(answer);
    }

    // The app's own decision, a save or an answer: it leaves without asking.
    function close(answer: string) {
        if (open)
            leave(answer);
    }

    function askFirst(answer: string) {
        memo.answer = answer;
        memo.beforeAsking = Window.activeFocusItem;
        asking = true;
        keep.forceActiveFocus();
    }

    function keepEditing() {
        asking = false;
        memo.beforeAsking?.forceActiveFocus();
    }

    // It leaves the way it came, and its answer counts once it has gone; a close while it leaves ends it at once
    // (rekta.js:1536).
    function leave(answer: string) {
        asking = false;
        memo.answer = answer;
        if (going.running) {
            going.stop();
            gone();
            return;
        }
        comingIn.stop();
        going.start();
    }

    function gone() {
        open = false;
        asking = false;
        KeyLayers.closed(sheet);
        // The focus goes back only to something that still shows (rekta.js:2424).
        if (memo.focused?.visible)
            memo.focused.forceActiveFocus();
        closed(memo.answer);
    }

    function holds(item: Item): bool {
        for (let inside = item; inside; inside = inside.parent) {
            if (inside === panel)
                return true;
        }
        return false;
    }

    visible: open

    // Below a tip (45), as a floating surface (behaviour.md, `keys.on`): Escape is a close request.
    Component.onCompleted: memo.offLayer = KeyLayers.on(40, (event, focusItem) => {
        if (!sheet.open || event.key !== Qt.Key_Escape || !sheet.holds(focusItem))
            return false;
        sheet.request("cancel");
        return true;
    })
    Component.onDestruction: {
        memo.offLayer();
        KeyLayers.closed(sheet);
    }

    QtObject {
        id: memo

        property Item focused
        property Item beforeAsking
        property string answer
        property var offLayer
    }

    NumberAnimation {
        id: comingIn

        objectName: "comingIn"
        target: sheet
        property: "entry"
        from: 0
        to: 1
        duration: Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
    }

    ParallelAnimation {
        id: going

        onFinished: sheet.gone()

        NumberAnimation {
            objectName: "goingUp"
            target: sheet
            property: "entry"
            to: 0
            duration: 0.8 * Tokens.durationShort
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeOut
        }

        // The shading fades linearly as the sheet leaves (rekta.js:1540).
        NumberAnimation {
            target: sheet
            property: "shade"
            to: 0
            duration: 0.8 * Tokens.durationShort
        }
    }

    Rectangle {
        objectName: "shading"
        anchors.fill: parent
        color: Tokens.color.shading
        opacity: sheet.shade

        // Nothing behind reacts while it is open; a tap on the shading, not on the sheet, is a close request
        // (rekta.js:1571–1575).
        MouseArea {
            id: shadingArea

            anchors.fill: parent
            hoverEnabled: true
            onClicked: mouse => {
                if (!panel.contains(shadingArea.mapToItem(panel, mouse.x, mouse.y)))
                    sheet.request("cancel");
            }
            onWheel: {}
        }
    }

    // `margin: 0 auto auto; width: min(32rem, 100%); max-height: calc(100dvh - space-xl)`; the bottom edge a hairline
    // in text-contrast-low, the bottom corners radius-m (rekta.css:826–828).
    Rectangle {
        id: panel

        objectName: "panel"
        x: (sheet.width - width) / 2
        width: Math.min(Geometry.sheetMaxWidth, sheet.width)
        height: Math.min(sheet.height - Tokens.spaceXl, scroller.contentHeight + Geometry.hairline)
        opacity: sheet.entry
        // Faded as one, as CSS opacity is, so the hairline beneath does not show through the ground.
        layer.enabled: sheet.entry < 1
        color: Tokens.color.textContrastLow
        radius: Tokens.radiusM
        topLeftRadius: 0
        topRightRadius: 0
        Accessible.role: Accessible.Dialog
        Accessible.name: sheet.title
        transform: Translate {
            y: sheet.shift
        }

        // Tab from the last control comes round to the first, Shift+Tab from the first to the last.
        FocusGuard {
            id: startGuard

            onActiveFocusChanged: {
                if (activeFocus)
                    endGuard.nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason);
            }
        }

        Rectangle {
            width: parent.width
            height: parent.height - Geometry.hairline
            color: Tokens.color.bg
            radius: parent.radius
            topLeftRadius: 0
            topRightRadius: 0

            Flickable {
                id: scroller

                // `padding: space-l space-m`, space-xl at the sides in a sideways viewport (rekta.css:827, :1100–1104)
                readonly property real inset: sheet.sideways ? Tokens.spaceXl : Tokens.spaceM

                objectName: "scroller"
                anchors.fill: parent
                contentWidth: width
                contentHeight: 2 * Tokens.spaceL + (sheet.asking ? question.height : form.height)
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                // `.rk-sheet > * + * { margin-top: space-m }` (rekta.css:833)
                Column {
                    id: form

                    objectName: "form"
                    visible: !sheet.asking
                    x: scroller.inset
                    y: Tokens.spaceL
                    width: scroller.width - 2 * scroller.inset
                    spacing: Tokens.spaceM

                    Heading {
                        kicker: sheet.kicker
                        title: sheet.title
                        besideClose: sheet.closeButton
                    }
                }

                // The question takes the sheet's place, in it (rekta.css:844).
                Column {
                    id: question

                    objectName: "ask"
                    visible: sheet.asking
                    x: scroller.inset
                    y: Tokens.spaceL
                    width: scroller.width - 2 * scroller.inset
                    spacing: Tokens.spaceM
                    Accessible.role: Accessible.Grouping
                    Accessible.name: sheet.askTitle

                    Heading {
                        kicker: sheet.askKicker
                        title: sheet.askTitle
                    }

                    Actions {
                        width: parent.width

                        Button {
                            id: keep

                            objectName: "keep"
                            variant: "primary"
                            text: sheet.keepWord
                            onClicked: sheet.keepEditing()
                        }

                        Button {
                            objectName: "discard"
                            text: sheet.discardWord
                            onClicked: sheet.leave(memo.answer)
                        }
                    }
                }

                // `.rk-sheet-close { position: absolute; top: space-xs; right: space-xs }` (rekta.css:841)
                IconButton {
                    objectName: "close"
                    visible: sheet.closeButton && !sheet.asking
                    x: scroller.width - Tokens.spaceXs - width
                    y: Tokens.spaceXs
                    icon: "close"
                    label: "close"
                    variant: "quiet"
                    onClicked: sheet.request("cancel")
                }
            }
        }

        FocusGuard {
            id: endGuard

            onActiveFocusChanged: {
                if (activeFocus)
                    startGuard.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason);
            }
        }
    }

    // A kicker, then the question as a group heading (forms.md, "A form in a sheet").
    component Heading: Column {
        id: heading

        property alias kicker: kickerText.text
        property alias title: titleText.text
        // The kicker keeps clear of the close button (rekta.css:842).
        property bool besideClose: false

        width: parent.width
        visible: kicker !== "" || title !== ""
        // `.rk-sheet .rk-kicker + * { margin-top: space-xs }` (rekta.css:834)
        spacing: Tokens.spaceXs

        Kicker {
            id: kickerText

            width: parent.width
            visible: text !== ""
            rightPadding: heading.besideClose ? Tokens.touchTarget : 0
        }

        GroupHeading {
            id: titleText

            width: parent.width
            visible: text !== ""
        }
    }

    // Takes the focus only to pass it on.
    component FocusGuard: Item {
        activeFocusOnTab: true
        Accessible.ignored: true
    }
}
