pragma ComponentBehavior: Bound
import QtQuick
import "Status.js" as Status

// One toast, made and taken away by its Toaster (rekta.css:1195–1268; rekta.js toaster()). An ink strip for something
// that just happened; with a status, that fill, for a failure whose control has gone (states.md, "Pending actions").
// It stays its window, duration-toast, which holds while it is hovered or has focus. With undo, the window closes as a
// 2px line, stepped once a second. A deliberate deviation: Rekta also shows the seconds as a figure beside the action
// (rekta.js:1559 `.rk-toast-count`, rekta.css:1249), which beside the verb ("undo 4") reads as a quantity, so only the
// line is seen and the seconds are only spoken (`announcement`). The window runs against a deadline in wall-clock
// time, and reduced motion leaves it alone (motion.md, "Reduced motion").
//
// A notification from another program (states.md:79–104; rekta.css:1213–1228) brings a title over its text, the
// sender's icon or its own picture at the start, and a text that is a button. Deliberate deviation: Rekta has the sender's
// name in the title or the text (states.md:98–99); here it stands in a line of its own above the title, in the small
// size of a meta, where the program may have put it nowhere.
//
// A toast that stays has no window, so it ends in a quiet icon button that sends it away and runs nothing, after its
// action, as high as the toast and tinted and ringed as the action is. Rekta 0.6.0 has no such button
// (rekta.css:1195–1268); this follows the rule Rekta has settled for its next release.
FocusScope {
    id: toast

    required property Toaster toaster
    property string key
    property string text
    // Semibold above the text. Title and text each keep to Geometry.toastMaxLines and end in an ellipsis (rekta.css
    // :1228); the reader still gets all of it (states.md:90–92). The title's cut is ahead of the pinned stylesheet, which
    // lets it run on (:1227); the text's cut without a title is ahead of the pinned docs, which tie it to the title
    // (states.md:92, behaviour.md:688–689). Rekta has since decided that a foreign notification's toast always keeps to a
    // known height. Any other toast's text stands whole.
    property string title
    // The name of the program a notification comes from: one line above the title, cut at its end with an ellipsis; the
    // reader still gets all of it, and first. Empty for a toast of the product's own.
    property string sender
    // The word of a neutral tag at the end of the text, before the action (`.rk-tag` without a status). It stands last
    // but is said first, so that a reader hears it before the text it qualifies.
    property string tag
    // { run }: the text is a button, tinted on hover and press and ringed on focus as the action is (rekta.css:1217–1222,
    // :1375; states.md:100–102); pressing it calls run and ends the toast as "acted". What the press does is the host's:
    // a notification's default action or, a deliberate deviation, bringing its app forward. Without it the text is only
    // text, as in a toast of the product's own.
    property var open: null
    // The toast has no window and no countdown line; it ends by a press, its action, its close button, Escape or dismiss().
    property bool stays: false
    // info | success | warning | error, or "" for the ink strip; a success says it without a status (states.md).
    property string status
    // The sender's icon or the notification's own picture, cropped square at the front of the strip in the icon's 20px
    // field (rekta.css:1214–1215, :1224–1225). Deliberate deviations: an app's icon keeps its colours where Rekta takes a
    // single-colour one first (states.md:93–96), and the picture keeps the tile's corners (see Picture).
    property url icon
    // "undo", "redo" or the label of another action with a window.
    property string action: "undo"
    property var undoAction: null
    // { label, run }: a plain action without a countdown ("reload").
    property var act: null
    // Where focus returns when the toast had it as it goes.
    property Item from: null
    property var endHandler: null
    property int windowMs: 0
    // A notification from another program: its count in the bar gives way to it.
    property bool notification: false
    // True while the toast it replaces leaves, or while its count makes way.
    property bool waiting: false

    property double total: undoAction ? windowMs || toaster.undoWindow : Tokens.durationToast
    // What is left of the window while it stands still (held, or not in yet), and its deadline while it runs.
    property double remaining: total
    property double deadline: 0
    property bool running: false
    property bool done: false
    // What is left as of the last step; the figure and the line show it.
    property double shownLeft: remaining
    readonly property int seconds: Math.max(0, Math.ceil(shownLeft / 1000))
    readonly property bool held: !waiting && !done && (hover.hovered || activeFocus)
    readonly property color ink: status !== "" ? Tokens.color.textPrimary : Tokens.color.bg
    readonly property color ground: Status.tileFill(status, Tokens.color, Tokens.color.textPrimary)
    readonly property string actionLabel: undoAction ? action : act?.label ?? ""
    // The action and the close button, at the trailing end.
    readonly property real trailingWidth: actionBox.width + closeBox.width
    readonly property string spoken: [sender, tag, title, text].filter(part => part !== "").join(". ")
    // An undo toast says how long its window is.
    readonly property string announcement: undoAction ? `${spoken}, ${seconds} ${seconds === 1 ? "second" : "seconds"} to ${action}` : spoken
    // Runs from 0, its travel below its place and unseen, to 1 at rest, linear in time. A toast of the product's own goes
    // down by running it back, so it plays the same curve backwards, as the stylesheet's reversed keyframes do
    // (rekta.css:1200, :1203, :1267).
    property real phase: 0
    readonly property easingCurve easeIn: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })
    readonly property real entry: easeIn.valueForProgress(phase)
    // A notification came from outside: its toast travels whole from the bottom edge and back, without a fade
    // (rekta.css:1229–1235, :1439). The host's surface ends at the bar, which hides it behind the bar.
    readonly property real travel: notification ? height + Tokens.appbarHeight + Tokens.spaceS : Geometry.toastRise
    // A notification's way down, from 0 at rest to 1 out of sight.
    property real down: 0
    // How far below its place the toast stands, as a share of its travel.
    readonly property real below: notification && done ? down : 1 - entry

    function begin() {
        waiting = false;
        announce();
        rising.start();
        // Just made, or hidden while it waited: nothing holds it yet.
        run();
    }

    function undo() {
        if (undoAction)
            leave(true, "undone");
    }

    function leave(doUndo: bool, reason: string) {
        if (done)
            return;
        // A notification's way down goes on from wherever its way up had got to.
        down = 1 - entry;
        done = true;
        running = false;
        tick.stop();
        const hadFocus = activeFocus;
        const goingDown = notification ? gliding : sinking;
        const way = waiting ? 0 : goingDown.duration;
        rising.stop();
        const ending = doUndo && undoAction ? "undone" : reason;
        toaster.letGo(toast);
        if (waiting)
            goAway();
        else
            goingDown.start();
        if (doUndo && undoAction)
            undoAction();
        if (endHandler)
            endHandler(ending);
        toaster.handCountBack(toast, way);
        if (hadFocus)
            from?.forceActiveFocus();
    }

    // The same key: a second action joins this toast. Its undo, window and onEnd are the new ones; a previous onEnd
    // that a new one replaces hears "merged", since its action now rides on the new one.
    function update(words: string, newUndo: var, newWindowMs: int, newEnd: var) {
        undoAction = newUndo;
        if (newEnd) {
            const before = endHandler;
            endHandler = newEnd;
            if (before && before !== newEnd)
                before("merged");
        }
        stop();
        total = newWindowMs || windowMs || toaster.undoWindow;
        remaining = total;
        text = words;
        paint();
        announce();
        if (!held)
            run();
    }

    function timeLeft(): double {
        return running ? Math.max(0, deadline - toaster.now()) : remaining;
    }

    function paint() {
        shownLeft = timeLeft();
    }

    // An undo toast steps its line on whole seconds; a plain one only goes when its window runs out.
    function schedule() {
        const ms = deadline - toaster.now();
        tick.interval = Math.max(0, undoAction ? ms % 1000 || 1000 : ms);
        tick.restart();
    }

    // Each step reads the clock, so a late one catches up at once.
    function step() {
        if (!running)
            return;
        if (deadline - toaster.now() <= 0) {
            running = false;
            remaining = 0;
            paint();
            leave(false, "expired");
            return;
        }
        paint();
        schedule();
    }

    function run() {
        if (running || done || waiting || stays)
            return;
        running = true;
        deadline = toaster.now() + remaining;
        schedule();
    }

    function stop() {
        if (!running)
            return;
        remaining = Math.max(0, deadline - toaster.now());
        running = false;
        tick.stop();
    }

    // An error is said at once; anything else when the reader is free.
    function announce() {
        Accessible.announce(announcement, status === "error" ? Accessible.Assertive : Accessible.Polite);
    }

    function goAway() {
        toaster.gone();
        destroy();
    }

    // A toast on its way out takes no press (rekta.css:1203).
    function press() {
        if (done)
            return;
        if (undoAction) {
            undo();
            return;
        }
        leave(false, "acted");
        act.run();
    }

    function pressText() {
        if (done)
            return;
        leave(false, "acted");
        open.run();
    }

    function dismiss() {
        leave(false, "dismissed");
    }

    // The keyboard comes to it at its first control.
    function takeFocus() {
        [openBox, actionBox, closeBox].find(control => control.visible)?.forceActiveFocus(Qt.TabFocusReason);
    }

    // Enter and Space press once; a held key does not repeat the press.
    function activateOnKey(event, press: var) {
        if (![Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].includes(event.key))
            return;
        event.accepted = true;
        if (!event.isAutoRepeat)
            press();
    }

    onHeldChanged: {
        if (done || waiting)
            return;
        if (held)
            stop();
        else
            run();
    }

    // Flush with the trailing edge it is given, space-m inside the region's sides (rekta.css:1190), space-s above the bar;
    // hung from the top, centred space-m below the region's top and coming down from above (rekta.css:1187–1189, :1449).
    x: toaster.hangsFromTop ? (toaster.width - width) / 2 : Math.max(Tokens.spaceM, Math.min(toaster.trailingEdge, toaster.width - Tokens.spaceM) - width)
    y: toaster.hangsFromTop ? Tokens.spaceM - below * travel : toaster.height - Tokens.spaceS - height + below * travel
    opacity: notification ? 1 : entry
    width: Math.min(Geometry.toastMaxWidth, toaster.width - 2 * Tokens.spaceM, front.width + words.implicitWidth + tagBox.width + trailingWidth)
    height: Math.max(Tokens.controlHeight + Tokens.spaceXs, words.height)
    visible: !waiting
    Accessible.role: status === "error" ? Accessible.AlertMessage : Accessible.Notification
    Accessible.name: spoken

    Timer {
        id: tick

        objectName: "tick"
        onTriggered: toast.step()
    }

    NumberAnimation {
        id: rising

        objectName: "rising"
        target: toast
        property: "phase"
        to: 1
        duration: Tokens.durationShort
        // Once in, a notification's toast gives its count back; for any other the count is back already.
        onFinished: toast.toaster.takeCountBack()
    }

    NumberAnimation {
        id: sinking

        objectName: "sinking"
        target: toast
        property: "phase"
        to: 0
        duration: Tokens.durationShort
        onFinished: toast.goAway()
    }

    // A notification's toast leaves back out the way it came, over 0.6 × duration-short on ease-out (rekta.css:1233).
    NumberAnimation {
        id: gliding

        objectName: "gliding"
        target: toast
        property: "down"
        to: 1
        duration: Geometry.toastEdgeOutShare * Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeOut
        onFinished: toast.goAway()
    }

    HoverHandler {
        id: hover
    }

    // Hover and press lay `hover` over a part of the strip (rekta.css:1247, :1375).
    component Tint: Rectangle {
        property bool lit

        anchors.fill: parent
        color: Tokens.color.hover
        opacity: lit ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.durationShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeBase
            }
        }
    }

    Rectangle {
        objectName: "fill"
        anchors.fill: parent
        radius: Tokens.radiusS
        color: toast.ground
    }

    Item {
        id: front

        width: toast.icon.toString() !== "" ? Tokens.spaceM + Geometry.iconSize : 0
        height: toast.height

        Picture {
            objectName: "appIcon"
            x: Tokens.spaceM
            anchors.verticalCenter: parent.verticalCenter
            source: toast.icon
            ground: toast.ground
            visible: parent.width > 0
        }
    }

    Item {
        id: words

        objectName: "words"
        x: front.width
        anchors.verticalCenter: parent.verticalCenter
        width: toast.width - front.width - tagBox.width - toast.trailingWidth
        // From unwrapped copies: a wrapped Text's implicitWidth follows its width, which follows the toast's.
        implicitWidth: Math.max(byline.visible ? naturalWidth(byline, bylineLine) : 0, heading.visible ? naturalWidth(heading, headingLine) : 0, naturalWidth(message, messageLine))
        height: message.y + message.height

        function naturalWidth(role: Text, line: Text): real {
            return line.implicitWidth + role.leftPadding + role.rightPadding;
        }

        Unwrapped {
            id: bylineLine

            role: byline
        }

        Unwrapped {
            id: headingLine

            role: heading
        }

        Unwrapped {
            id: messageLine

            objectName: "messageLine"

            role: message
        }

        TextRole {
            id: byline

            objectName: "sender"
            width: parent.width
            visible: toast.sender !== ""
            text: toast.sender
            font.pixelSize: Tokens.fontSizeXxs
            font.weight: Tokens.fontWeightRegular
            color: toast.ink
            textFormat: Text.PlainText
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
            maximumLineCount: 1
            leftPadding: message.leftPadding
            rightPadding: message.rightPadding
            topPadding: Tokens.spaceS + Tokens.spaceXs + lineBoxTop
            bottomPadding: lineBoxBottom
        }

        TextRole {
            id: heading

            objectName: "title"
            y: byline.visible ? byline.height : 0
            width: parent.width
            visible: toast.title !== ""
            text: toast.title
            textFormat: Text.PlainText
            font.pixelSize: Tokens.fontSizeS
            font.weight: Tokens.fontWeightSemibold
            color: toast.ink
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: Geometry.toastMaxLines
            leftPadding: message.leftPadding
            rightPadding: message.rightPadding
            topPadding: (byline.visible ? 0 : Tokens.spaceS + Tokens.spaceXs) + lineBoxTop
            bottomPadding: lineBoxBottom
        }

        TextRole {
            id: message

            objectName: "message"
            y: heading.visible ? heading.y + heading.height : byline.visible ? byline.height : 0
            width: parent.width
            text: toast.text
            // The server reports no body-markup, so a program's words are never rich text (no markup, no image fetch).
            textFormat: Text.PlainText
            font.pixelSize: Tokens.fontSizeS
            font.weight: Tokens.fontWeightRegular
            color: toast.ink
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: heading.visible || toast.notification ? Geometry.toastMaxLines : 2147483647
            // The icon field and the words are the text's row, space-s apart (rekta.css:1223).
            leftPadding: front.width > 0 ? Tokens.spaceS : Tokens.spaceM
            // A tag after the words stands the gap of the text's row away (rekta.css:1223).
            rightPadding: toast.tag !== "" ? Tokens.spaceS : Tokens.spaceM
            topPadding: heading.visible || byline.visible ? lineBoxTop : Tokens.spaceS + Tokens.spaceXs + lineBoxTop
            bottomPadding: Tokens.spaceS + Tokens.spaceXs + lineBoxBottom
        }
    }

    // At the end of the text, before the action; the text's row keeps space-m at its end (rekta.css:1212, :1223).
    Item {
        id: tagBox

        x: toast.width - toast.trailingWidth - width
        width: toast.tag !== "" ? tagFace.implicitWidth + Tokens.spaceM : 0
        height: toast.height
        visible: width > 0

        StatusTag {
            id: tagFace

            objectName: "tag"
            anchors.verticalCenter: parent.verticalCenter
            word: toast.tag
            inInkToast: toast.status === ""
        }
    }

    component Unwrapped: Text {
        required property Text role

        visible: false
        font: role.font
        text: role.text
        textFormat: role.textFormat
    }

    // The text as a control, from the toast's start edge to the action: pointer, Enter and Space.
    Item {
        id: openBox

        objectName: "open"
        width: toast.width - toast.trailingWidth
        height: toast.height
        visible: toast.open !== null
        activeFocusOnTab: visible
        Accessible.role: Accessible.Button
        Accessible.name: toast.spoken
        Accessible.onPressAction: toast.pressText()
        Keys.onPressed: event => toast.activateOnKey(event, toast.pressText)

        Tint {
            objectName: "press"
            topLeftRadius: Tokens.radiusS
            bottomLeftRadius: Tokens.radiusS
            lit: openHover.hovered || openTap.pressed
        }

        // Closer to the edge than the action's (rekta.css:1222, :1248).
        FocusRing {
            onFill: true
            ink: toast.ink
            offset: -Tokens.spaceXs
        }

        TapHandler {
            id: openTap

            longPressThreshold: 0
            onTapped: toast.pressText()
        }

        HoverHandler {
            id: openHover

            cursorShape: Qt.PointingHandCursor
        }
    }

    // A control at the toast's trailing end: hover and press lay `hover` over it, up to the toast's rounded end when it
    // is last, and its focus ring sits 10px inside (rekta.css:1247–1248, :1375).
    component EndControl: Item {
        id: control

        required property color ink
        property bool last: true

        signal activated

        visible: width > 0
        activeFocusOnTab: visible
        Accessible.role: Accessible.Button

        Tint {
            objectName: "press"
            topRightRadius: control.last ? Tokens.radiusS : 0
            bottomRightRadius: control.last ? Tokens.radiusS : 0
            lit: endHover.hovered || endTap.pressed
        }

        FocusRing {
            onFill: true
            ink: control.ink
            offset: -Geometry.toastFocusInset
        }

        TapHandler {
            id: endTap

            longPressThreshold: 0
            onTapped: control.activated()
        }

        HoverHandler {
            id: endHover

            cursorShape: Qt.PointingHandCursor
        }
    }

    EndControl {
        id: actionBox

        objectName: "action"
        x: toast.width - closeBox.width - width
        // ponytail: half of the widest toast, until Rekta gives the action a width.
        readonly property real maxWidth: Math.min(Geometry.toastMaxWidth, toast.toaster.width - 2 * Tokens.spaceM) / 2
        width: toast.actionLabel !== "" ? Math.max(Tokens.controlHeight, Math.min(label.implicitWidth + 2 * Tokens.spaceM, maxWidth)) : 0
        height: toast.height
        ink: toast.ink
        last: !closeBox.visible
        Accessible.name: toast.actionLabel
        Accessible.onPressAction: toast.press()
        Keys.onPressed: event => toast.activateOnKey(event, toast.press)
        onActivated: toast.press()

        Rectangle {
            objectName: "divider"
            y: Tokens.spaceS + Tokens.spaceXs
            width: Geometry.hairline
            height: parent.height - 2 * y
            color: Qt.alpha(toast.ink, Geometry.toastDividerOpacity)
        }

        Row {
            anchors.centerIn: parent
            spacing: Tokens.spaceS

            Text {
                id: label

                objectName: "actionLabel"
                text: toast.actionLabel
                width: Math.min(implicitWidth, actionBox.width - 2 * Tokens.spaceM)
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.fontSizeS
                font.weight: Tokens.fontWeightSemibold
                color: toast.ink
            }
        }
    }

    // Square at control-height, never below the touch target on a touch system, its glyph 20px (forms.md:305–311).
    EndControl {
        id: closeBox

        objectName: "close"
        x: toast.width - width
        width: toast.stays ? Math.max(Tokens.controlHeight, Prefs.systemHasTouch ? Tokens.touchTarget : 0) : 0
        height: toast.height
        ink: toast.ink
        Accessible.name: toast.toaster.dismissWord
        Accessible.onPressAction: toast.dismiss()
        Keys.onPressed: event => toast.activateOnKey(event, toast.dismiss)
        onActivated: toast.dismiss()

        Icon {
            objectName: "glyph"
            anchors.centerIn: parent
            name: "close"
            size: Geometry.iconSize
            color: toast.ink
        }
    }

    // What is left of the undo window, shrinking toward the action's side; each step glides like a live bar.
    Rectangle {
        objectName: "line"
        x: Tokens.spaceXs
        y: toast.height - Tokens.spaceXs - height
        width: toast.width - 2 * Tokens.spaceXs
        height: Geometry.toastLine
        visible: toast.undoAction !== null && !toast.stays
        color: toast.ink
        transform: Scale {
            origin.x: toast.width - 2 * Tokens.spaceXs
            xScale: toast.total > 0 ? toast.shownLeft / toast.total : 0

            Behavior on xScale {
                NumberAnimation {
                    duration: Tokens.durationLong
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.easeIn
                }
            }
        }
    }
}
