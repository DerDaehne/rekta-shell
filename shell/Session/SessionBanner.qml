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
FocusScope {
    id: sessionBanner

    // { name, text, primary, disabledReason, run }, in their order.
    property var actions: []
    // From show() until it has gone; a host shows its surface while this holds.
    property bool open: false
    // Runs from 0 to 1 as it comes in, and back to 0 as it leaves; the shading's opacity runs alongside.
    property real entry: 1
    property real shade: 1
    // The screen behind lies shaded, and blurred by the host, until an action that clears the shading is chosen.
    property bool shaded: true
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
        shaded = true;
        going.stop();
        comingIn.restart();
        buttonFor(focusOn).forceActiveFocus(Qt.TabFocusReason);
    }

    function close() {
        if (!open || going.running)
            return;
        comingIn.stop();
        going.start();
    }

    // It goes, and the action acts.
    function choose(action: var) {
        shaded = !action.clearsShading;
        close();
        action.run();
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
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back)
            close();
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right)
            step(event.key === Qt.Key_Right ? 1 : -1);
        else
            return;
        event.accepted = true;
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
                    sessionBanner.close();
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

            Repeater {
                id: buttons

                model: sessionBanner.actions

                Button {
                    required property var modelData

                    objectName: modelData.name
                    text: modelData.text
                    variant: modelData.primary ? "primary" : "quiet"
                    disabledReason: modelData.disabledReason ?? ""
                    onClicked: sessionBanner.choose(modelData)
                }
            }
        }
    }
}
