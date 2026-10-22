pragma ComponentBehavior: Bound
import QtQuick
import "Status.js" as Status

// One toast, made and taken away by its Toaster (rekta.css:893–930; rekta.js toaster()). An ink strip for something
// that just happened; with a status, that fill, for a failure whose control has gone (states.md, "Pending actions").
// It stays its window, duration-toast, which holds while it is hovered or has focus. With undo, the window closes as a
// 2px line and a tabular figure, once a second. The window runs against a deadline in wall-clock time, and reduced
// motion leaves it alone (motion.md, "Reduced motion").
FocusScope {
    id: toast

    required property Toaster toaster
    property string key
    property string text
    // A notification's summary, semibold above the text; with it the text keeps to bodyMaxLines and ends in an ellipsis.
    // The reader still gets all of it. The shell's own addition to Rekta's one-sentence toast.
    property string title
    readonly property int bodyMaxLines: 2
    // { run }: the text is a control; pressing it calls run and ends the toast as "acted". What the press does, such as
    // bringing the app forward, is the host's. Without it the text is only text, as in Rekta.
    property var open: null
    // The toast has no window and no countdown line; it ends by a press, its action, Escape or dismiss().
    property bool stays: false
    // info | success | warning | error, or "" for the ink strip; a success says it without a status (states.md).
    property string status
    // The app the toast speaks for, at the front of the strip: the shell's own addition to Rekta's toast.
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
    // True while the toast it replaces leaves.
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
    readonly property string spoken: title !== "" ? `${title}. ${text}` : text
    // An undo toast says how long its window is.
    readonly property string announcement: undoAction ? `${spoken}, ${seconds} ${seconds === 1 ? "second" : "seconds"} to ${action}` : spoken
    // Runs from 0, above the top edge, to 1, at rest.
    property real entry: 0

    function begin() {
        waiting = false;
        announce();
        slidingIn.start();
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
        done = true;
        running = false;
        tick.stop();
        const hadFocus = activeFocus;
        toaster.letGo(toast);
        if (waiting)
            goAway();
        else
            slidingOut.start();
        if (doUndo && undoAction)
            undoAction();
        if (endHandler)
            endHandler(doUndo && undoAction ? "undone" : reason);
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

    // An undo toast steps its figure on whole seconds; a plain one only goes when its window runs out.
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

    // A toast on its way out takes no press (rekta.css:901).
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

    x: (toaster.width - width) / 2
    y: toaster.rest - (1 - entry) * (toaster.rest + height)
    width: Math.min(Geometry.toastMaxWidth, toaster.width - 2 * Tokens.spaceM, front.width + words.implicitWidth + actionBox.width)
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
        id: slidingIn

        objectName: "slidingIn"
        target: toast
        property: "entry"
        to: 1
        duration: toast.toaster.slideIn
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easePivotGlide
    }

    NumberAnimation {
        id: slidingOut

        objectName: "slidingOut"
        target: toast
        property: "entry"
        to: 0
        duration: toast.toaster.slideOut
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeOut
        onFinished: toast.goAway()
    }

    HoverHandler {
        id: hover
    }

    // Hover and press lay `hover` over a part of the strip (rekta.css:916, :1032).
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

        Image {
            objectName: "appIcon"
            x: Tokens.spaceM
            anchors.verticalCenter: parent.verticalCenter
            width: Geometry.iconSize
            height: Geometry.iconSize
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            source: toast.icon
            visible: parent.width > 0
        }

        // The picture is square with the tile's corners: a ring in the strip's own ground, whose inner edge is the
        // picture's rounded outline (its radius is the outer radius less the ring's width).
        Rectangle {
            objectName: "corners"
            x: Tokens.spaceM - Tokens.radiusTile
            anchors.verticalCenter: parent.verticalCenter
            width: Geometry.iconSize + 2 * Tokens.radiusTile
            height: width
            visible: parent.width > 0
            color: "transparent"
            radius: 2 * Tokens.radiusTile
            border.width: Tokens.radiusTile
            border.color: toast.ground
        }
    }

    Item {
        id: words

        objectName: "words"
        x: front.width
        anchors.verticalCenter: parent.verticalCenter
        width: toast.width - front.width - actionBox.width
        implicitWidth: Math.max(heading.visible ? heading.implicitWidth : 0, message.implicitWidth)
        height: message.y + message.height

        TextRole {
            id: heading

            objectName: "title"
            width: parent.width
            visible: toast.title !== ""
            text: toast.title
            font.pixelSize: Tokens.fontSizeS
            font.weight: Tokens.fontWeightSemibold
            color: toast.ink
            elide: Text.ElideRight
            maximumLineCount: 1
            leftPadding: message.leftPadding
            rightPadding: Tokens.spaceM
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
            // Next to the app's icon the words keep the space a glyph keeps from its label (rekta.css:212).
            leftPadding: front.width > 0 ? Tokens.spaceS : Tokens.spaceM
            rightPadding: Tokens.spaceM
            topPadding: heading.visible ? lineBoxTop : Tokens.spaceS + Tokens.spaceXs + lineBoxTop
            bottomPadding: Tokens.spaceS + Tokens.spaceXs + lineBoxBottom
        }
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

        FocusRing {
            onFill: true
            ink: toast.ink
            offset: -Geometry.toastFocusInset
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
        width: toast.actionLabel !== "" ? Math.max(Tokens.controlHeight, label.implicitWidth + (toast.undoAction ? Tokens.spaceS + count.implicitWidth : 0) + 2 * Tokens.spaceM) : 0
        height: toast.height
        visible: width > 0
        activeFocusOnTab: visible
        Accessible.role: Accessible.Button
        Accessible.name: toast.actionLabel
        Accessible.onPressAction: toast.press()

        Keys.onPressed: event => toast.activateOnKey(event, toast.press)

        // Hover and press lay `hover` over it (rekta.css:916, :1032), up to the toast's rounded end.
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

            Text {
                id: count

                objectName: "count"
                visible: toast.undoAction !== null
                text: toast.seconds
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.fontSizeS
                font.weight: Tokens.fontWeightMedium
                font.features: ({ "tnum": 1 })
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
