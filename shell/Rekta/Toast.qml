pragma ComponentBehavior: Bound
import QtQuick
import "Status.js" as Status

// One toast, made and taken away by its Toaster (rekta.css:1164–1236; rekta.js toaster()). An ink strip for something
// that just happened; with a status, that fill, for a failure whose control has gone (states.md, "Pending actions").
// It stays its window, duration-toast, which holds while it is hovered or has focus. With undo, the window closes as a
// 2px line, stepped once a second. A deliberate deviation: Rekta also shows the seconds as a figure beside the action
// (rekta.js:1550 `.rk-toast-count`, rekta.css:1217), which beside the verb ("undo 4") reads as a quantity, so only the
// line is seen and the seconds are only spoken (`announcement`). The window runs against a deadline in wall-clock
// time, and reduced motion leaves it alone (motion.md, "Reduced motion").
//
// A notification from another program (states.md:78–103; rekta.css:1181–1196) brings a title over its text, the
// sender's icon or its own picture at the start, and a text that is a button. A deliberate deviation: the title is the
// one the notification brings, so the sender's name stands in the title or the text only where the program put it there,
// where Rekta has it there always (states.md:97–98).
FocusScope {
    id: toast

    required property Toaster toaster
    property string key
    property string text
    // Semibold above the text, on as many lines as it needs (rekta.css:1195); under it the text keeps to bodyMaxLines
    // and ends in an ellipsis (:1196). The reader still gets all of it (states.md:89–91). Without a title the text is one
    // uncut sentence, as in any toast (states.md:91, behaviour.md:678–679), though Rekta's script cuts it beside an icon
    // (rekta.js:1532–1542); the docs are followed until Rekta settles which holds.
    property string title
    readonly property int bodyMaxLines: 2
    // The word of a neutral tag at the end of the text, before the action (`.rk-tag` without a status). It stands last
    // but is said first, so that a reader hears it before the text it qualifies.
    property string tag
    // { run }: the text is a button, tinted on hover and press and ringed on focus as the action is (rekta.css:1185–1190,
    // :1343; states.md:99–101); pressing it calls run and ends the toast as "acted". What the press does is the host's:
    // a notification's default action or, a deliberate deviation, bringing its app forward. Without it the text is only
    // text, as in a toast of the product's own.
    property var open: null
    // The toast has no window and no countdown line; it ends by a press, its action, Escape or dismiss().
    property bool stays: false
    // info | success | warning | error, or "" for the ink strip; a success says it without a status (states.md).
    property string status
    // The sender's icon or the notification's own picture, cropped square at the front of the strip in the icon's 20px
    // field (rekta.css:1182–1183, :1192–1193). Deliberate deviations: an app's icon keeps its colours where Rekta takes a
    // single-colour one first (states.md:92–95), and the picture keeps the tile's corners (see Picture).
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
    readonly property string spoken: [tag, title, text].filter(part => part !== "").join(". ")
    // An undo toast says how long its window is.
    readonly property string announcement: undoAction ? `${spoken}, ${seconds} ${seconds === 1 ? "second" : "seconds"} to ${action}` : spoken
    // Runs from 0, its travel below its place and unseen, to 1 at rest, linear in time. A toast of the product's own goes
    // down by running it back, so it plays the same curve backwards, as the stylesheet's reversed keyframes do
    // (rekta.css:1169, :1172, :1235).
    property real phase: 0
    readonly property easingCurve easeIn: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })
    readonly property real entry: easeIn.valueForProgress(phase)
    // A notification came from outside: its toast travels whole from the bottom edge and back, without a fade
    // (rekta.css:1197–1203, :1407). The host's surface ends at the bar, which hides it behind the bar.
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
        toaster.letGo(toast);
        if (waiting)
            goAway();
        else
            goingDown.start();
        if (doUndo && undoAction)
            undoAction();
        if (endHandler)
            endHandler(doUndo && undoAction ? "undone" : reason);
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

    // A toast on its way out takes no press (rekta.css:1172).
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

    // Flush with the trailing edge it is given, space-m inside the region's sides (rekta.css:1159), space-s above the bar;
    // hung from the top, centred space-m below the region's top and coming down from above (rekta.css:1156–1158, :1417).
    x: toaster.hangsFromTop ? (toaster.width - width) / 2 : Math.max(Tokens.spaceM, Math.min(toaster.trailingEdge, toaster.width - Tokens.spaceM) - width)
    y: toaster.hangsFromTop ? Tokens.spaceM - below * travel : toaster.height - Tokens.spaceS - height + below * travel
    opacity: notification ? 1 : entry
    width: Math.min(Geometry.toastMaxWidth, toaster.width - 2 * Tokens.spaceM, front.width + words.implicitWidth + tagBox.width + actionBox.width)
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
        onFinished: {
            if (toast.notification)
                toast.toaster.takeCountBack();
        }
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

    // A notification's toast leaves back out the way it came, over 0.6 × duration-short on ease-out (rekta.css:1201).
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

    // Hover and press lay `hover` over a part of the strip (rekta.css:1215, :1343).
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
        width: toast.width - front.width - tagBox.width - actionBox.width
        // From unwrapped copies: a wrapped Text's implicitWidth follows its width, which follows the toast's.
        implicitWidth: Math.max(heading.visible ? naturalWidth(heading, headingLine) : 0, naturalWidth(message, messageLine))
        height: message.y + message.height

        function naturalWidth(role: Text, line: Text): real {
            return line.implicitWidth + role.leftPadding + role.rightPadding;
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
            id: heading

            objectName: "title"
            width: parent.width
            visible: toast.title !== ""
            text: toast.title
            font.pixelSize: Tokens.fontSizeS
            font.weight: Tokens.fontWeightSemibold
            color: toast.ink
            wrapMode: Text.Wrap
            leftPadding: message.leftPadding
            rightPadding: message.rightPadding
            topPadding: Tokens.spaceS + Tokens.spaceXs + lineBoxTop
            bottomPadding: lineBoxBottom
        }

        TextRole {
            id: message

            objectName: "message"
            y: heading.visible ? heading.height : 0
            width: parent.width
            text: toast.text
            font.pixelSize: Tokens.fontSizeS
            font.weight: Tokens.fontWeightRegular
            color: toast.ink
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: heading.visible ? toast.bodyMaxLines : 2147483647
            // The icon field and the words are the text's row, space-s apart (rekta.css:1191).
            leftPadding: front.width > 0 ? Tokens.spaceS : Tokens.spaceM
            // A tag after the words stands the gap of the text's row away (rekta.css:1191).
            rightPadding: toast.tag !== "" ? Tokens.spaceS : Tokens.spaceM
            topPadding: heading.visible ? lineBoxTop : Tokens.spaceS + Tokens.spaceXs + lineBoxTop
            bottomPadding: Tokens.spaceS + Tokens.spaceXs + lineBoxBottom
        }
    }

    // At the end of the text, before the action; the text's row keeps space-m at its end (rekta.css:1180, :1191).
    Item {
        id: tagBox

        x: toast.width - actionBox.width - width
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
        width: toast.width - actionBox.width
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

        // Closer to the edge than the action's (rekta.css:1190, :1216).
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

    Item {
        id: actionBox

        objectName: "action"
        x: toast.width - width
        width: toast.actionLabel !== "" ? Math.max(Tokens.controlHeight, label.implicitWidth + 2 * Tokens.spaceM) : 0
        height: toast.height
        visible: width > 0
        activeFocusOnTab: visible
        Accessible.role: Accessible.Button
        Accessible.name: toast.actionLabel
        Accessible.onPressAction: toast.press()

        Keys.onPressed: event => toast.activateOnKey(event, toast.press)

        // Hover and press lay `hover` over it (rekta.css:1215, :1343), up to the toast's rounded end.
        Tint {
            objectName: "press"
            topRightRadius: Tokens.radiusS
            bottomRightRadius: Tokens.radiusS
            lit: actionHover.hovered || actionTap.pressed
        }

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

                text: toast.actionLabel
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.fontSizeS
                font.weight: Tokens.fontWeightSemibold
                color: toast.ink
            }
        }

        FocusRing {
            onFill: true
            ink: toast.ink
            offset: -Geometry.toastFocusInset
        }

        TapHandler {
            id: actionTap

            longPressThreshold: 0
            onTapped: toast.press()
        }

        HoverHandler {
            id: actionHover

            cursorShape: Qt.PointingHandCursor
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
