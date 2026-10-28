pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The session's actions as a banner over the shading (Rekta has no pattern for session actions yet): across the top
// in a status banner's geometry and its neutral look, on surface with a hairline below (rekta.css:932–960), the word
// "sitzung" large and light in the first tile column, the actions as buttons from the second, sharing its baseline.
// It comes in once with a fade and 8px over duration-short, as a banner state does (motion.md, "Status banner"), the
// shading fading in alongside; it leaves the same way in 0.8 × that with ease-out, as a sheet leaves (motion.md,
// "Sheets"). An action that clears the shading takes the shading away at once as it is chosen, and the banner leaves
// alone. Escape, Back and a press on the shading send it away; ← → and Tab go from button to button, Enter or Space
// acts. Once it has gone the focus goes back.
// An action that ends the session (endsSession) first counts down duration-toast in whole seconds in the buttons' place,
// "ausschalten in 5 · abbrechen", under Rekta's undo line (behaviour.md, "Undo"; rekta.css:919–927). Enter acts at once;
// Escape, Back, "abbrechen" and a press on the shading take it back to the actions with nothing done. Rekta asks a
// confirm sheet for what cannot be undone (live.md:69–71); this window replaces it.
FocusScope {
    id: sessionBanner

    // { name, text, group, primary, endsSession, disabledReason, run }, in their order.
    property var actions: []
    // From show() until it has gone; a host shows its surface while this holds.
    property bool open: false
    // Runs from 0 to 1 as it comes in, and back to 0 as it leaves; the shading's opacity runs alongside.
    property real entry: 1
    property real shade: 1
    // The screen behind lies shaded, and blurred by the host, until an action that clears the shading is chosen.
    property bool shaded: true
    // The action counting down, null while none. Wall-clock time in ms: a late timer never stretches the window.
    property var counting: null
    property var clock: () => Date.now()
    property double deadline: 0
    property double shownLeft: 0
    readonly property int countdownMs: (Math.round(Tokens.durationToast / 1000) || 5) * 1000
    readonly property int seconds: Math.ceil(shownLeft / 1000)
    readonly property real padX: Tokens.spaceXl
    readonly property real padY: Tokens.spaceM
    readonly property real headWidth: Math.max(Tokens.tileUnit, word.implicitWidth)
    // Every button has the same baseline; the word's and theirs make the first line.
    readonly property real buttonBaseline: buttons.count > 0 ? (buttons.itemAt(0) as Button)?.baselineOffset ?? 0 : 0
    readonly property real firstBaseline: Math.max(word.baselineOffset, buttonBaseline)
    readonly property real contentHeight: 2 * padY + Math.max(firstBaseline - word.baselineOffset + word.height, firstBaseline - buttonBaseline + row.implicitHeight) + Geometry.hairline

    // It has gone.
    signal closed

    // Opens with the focus on the named action, or on the primary one for any other name; while it leaves, it comes
    // back.
    function show(focusOn: string) {
        if (!open) {
            memo.focused = Window.activeFocusItem;
            open = true;
            entry = 0;
            shade = 0;
        }
        stopCounting();
        shaded = true;
        going.stop();
        comingIn.restart();
        buttonFor(focusOn).forceActiveFocus(Qt.TabFocusReason);
    }

    function close() {
        if (!open || going.running)
            return;
        stopCounting();
        comingIn.stop();
        going.start();
    }

    // It goes, and the action acts; one that ends the session counts down first.
    function choose(action: var) {
        if (action.endsSession)
            countDown(action);
        else
            actNow(action);
    }

    function actNow(action: var) {
        shaded = !action.clearsShading;
        close();
        action.run();
    }

    function countDown(action: var) {
        counting = action;
        deadline = clock() + countdownMs;
        shownLeft = countdownMs;
        tick.interval = 1000;
        tick.restart();
        countdownKeys.forceActiveFocus(Qt.TabFocusReason);
        Accessible.announce(`${action.text} in ${seconds} seconds`, Accessible.Polite);
    }

    // Each step reads the clock, so a late one catches up at once.
    function advance() {
        if (!counting)
            return;
        shownLeft = Math.max(0, deadline - clock());
        if (shownLeft <= 0)
            actNow(takeCounting());
        else
            tick.restart();
    }

    function takeCounting(): var {
        const action = counting;
        stopCounting();
        return action;
    }

    function stopCounting() {
        counting = null;
        tick.stop();
    }

    // Nothing is done; the actions are back with the focus on the one that was chosen.
    function cancelCountdown() {
        buttonFor(takeCounting().name).forceActiveFocus(Qt.TabFocusReason);
    }

    // What Escape, Back and a press on the shading do: take back a countdown, else send the banner away.
    function dismiss() {
        if (counting)
            cancelCountdown();
        else
            close();
    }

    function buttonFor(name: string): Item {
        const named = actions.findIndex(action => action.name === name);
        const index = named >= 0 ? named : Math.max(0, actions.findIndex(action => action.primary));
        return buttons.itemAt(index);
    }

    // ← and → go round the buttons.
    function step(by: int) {
        for (let index = 0; index < buttons.count; index++) {
            if (buttons.itemAt(index).activeFocus) {
                buttons.itemAt((index + by + buttons.count) % buttons.count).forceActiveFocus(Qt.TabFocusReason);
                return;
            }
        }
    }

    function gone() {
        open = false;
        // The focus goes back only to something that still shows (rekta.js:2424).
        if (memo.focused?.visible)
            memo.focused.forceActiveFocus();
        closed();
    }

    visible: open

    // The buttons take Enter and Space first; the rest come here.
    Keys.onPressed: event => {
        if (!open)
            return;
        if (counting && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter))
            actNow(takeCounting());
        else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back)
            dismiss();
        else if (!counting && (event.key === Qt.Key_Left || event.key === Qt.Key_Right))
            step(event.key === Qt.Key_Right ? 1 : -1);
        else
            return;
        event.accepted = true;
    }

    // Holds the keys while the buttons are away, so Enter reaches the banner and not a button.
    Item {
        id: countdownKeys
    }

    Timer {
        id: tick

        objectName: "tick"
        onTriggered: sessionBanner.advance()
    }

    QtObject {
        id: memo

        property Item focused
    }

    ParallelAnimation {
        id: comingIn

        NumberAnimation {
            objectName: "comingIn"
            target: sessionBanner
            property: "entry"
            to: 1
            duration: Tokens.durationShort
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeIn
        }

        NumberAnimation {
            objectName: "shadingIn"
            target: sessionBanner
            property: "shade"
            to: 1
            duration: Tokens.durationShort
        }
    }

    ParallelAnimation {
        id: going

        onFinished: sessionBanner.gone()

        NumberAnimation {
            objectName: "goingUp"
            target: sessionBanner
            property: "entry"
            to: 0
            duration: 0.8 * Tokens.durationShort
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeOut
        }

        // The shading fades linearly as it leaves, as a sheet's does (rekta.js:1540).
        NumberAnimation {
            objectName: "shadingOut"
            target: sessionBanner
            property: "shade"
            to: 0
            duration: 0.8 * Tokens.durationShort
        }
    }

    Rectangle {
        objectName: "shading"
        anchors.fill: parent
        color: Tokens.color.shading
        opacity: sessionBanner.shade
        visible: sessionBanner.shaded

        // Nothing behind reacts while it is open; a press on the shading, not on the banner, or the Back button sends
        // it away.
        MouseArea {
            id: shadingArea

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.BackButton
            onClicked: mouse => {
                if (mouse.button === Qt.BackButton || !banner.contains(shadingArea.mapToItem(banner, mouse.x, mouse.y)))
                    sessionBanner.dismiss();
            }
            onWheel: {}
        }
    }

    // Faded as one, as CSS opacity is, so the shading shows through the whole banner alike.
    Rectangle {
        id: banner

        objectName: "banner"
        width: sessionBanner.width
        height: sessionBanner.contentHeight
        color: Tokens.color.surface
        opacity: sessionBanner.entry
        layer.enabled: sessionBanner.entry < 1
        Accessible.role: Accessible.Dialog
        Accessible.name: word.text
        transform: Translate {
            y: -(1 - sessionBanner.entry) * Geometry.bannerShift
        }

        Hairline {
            objectName: "hairline"
            anchors.bottom: parent.bottom
            width: parent.width
        }

        BannerWord {
            id: word

            objectName: "word"
            x: sessionBanner.padX
            y: sessionBanner.padY + sessionBanner.firstBaseline - baselineOffset
            text: "sitzung"
            placeWidth: sessionBanner.width
        }

        Actions {
            id: row

            objectName: "actions"
            x: sessionBanner.padX + sessionBanner.headWidth + Tokens.spaceS
            y: sessionBanner.padY + sessionBanner.firstBaseline - sessionBanner.buttonBaseline
            width: sessionBanner.width - x - sessionBanner.padX
            opacity: sessionBanner.counting ? 0 : 1
            enabled: !sessionBanner.counting

            Repeater {
                id: buttons

                model: sessionBanner.actions

                Button {
                    required property var modelData
                    required property int index

                    objectName: modelData.name
                    text: modelData.text
                    // The ones that end the session are framed in the error colour, never filled (forms.md:134–140).
                    variant: modelData.primary ? "primary" : modelData.endsSession ? "destructive" : "quiet"
                    // A group stands space-l from the one before it; the flow adds space-s.
                    leftPadding: index > 0 && sessionBanner.actions[index - 1].group !== modelData.group ? Tokens.spaceL - Tokens.spaceS : 0
                    disabledReason: modelData.disabledReason ?? ""
                    onClicked: sessionBanner.choose(modelData)
                }
            }
        }

        Row {
            id: countdown

            objectName: "countdown"
            x: row.x
            y: row.y
            visible: sessionBanner.counting !== null
            spacing: Tokens.spaceS

            Text {
                objectName: "countdownText"
                y: undo.baselineOffset - baselineOffset
                text: `${sessionBanner.counting?.text ?? ""} in ${sessionBanner.seconds} ·`
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.fontSizeS
                font.weight: Tokens.fontWeightSemibold
                font.features: ({ "tnum": 1 })
                color: Tokens.color.textPrimary
            }

            Button {
                id: undo

                objectName: "cancel"
                text: "abbrechen"
                variant: "quiet"
                onClicked: sessionBanner.cancelCountdown()
            }
        }

        // What is left of the window, shrinking toward the cancel side; under reduced motion it stands and the figure counts.
        Rectangle {
            id: undoLine

            objectName: "line"
            x: sessionBanner.padX
            y: parent.height - Geometry.hairline - Geometry.toastLine
            width: parent.width - 2 * sessionBanner.padX
            height: Geometry.toastLine
            visible: sessionBanner.counting !== null
            color: Tokens.color.textPrimary
            transform: Scale {
                origin.x: undoLine.width
                xScale: Tokens.reducedMotion ? 1 : sessionBanner.shownLeft / sessionBanner.countdownMs

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
}
