pragma ComponentBehavior: Bound

import QtQuick

// A short display that takes the place of a bar control, such as the clock, after a key: the word over Rekta's meter
// with its value in tabular figures (data.md, "Meters"), or over a plain text when there is no level. The two swap as a
// live tile flips to a new status (navigation.md, "A short indicator in place of a control"; rekta.js indicate(),
// tileUpdate()): the control turns away about its horizontal middle over half of duration-moderate on ease-out, then
// the display turns in from the other side over the other half on ease-in, whole all the while; after the last key it
// stays duration-level, then runs the same flip the other way round. Under reduced motion the two change at once.
// `press()` is a key: the first brings the display, every later one only keeps it. `say()` announces news politely
// while it shows, as a live region does.
Item {
    id: display

    // The control the display takes the place of.
    required property Item replaces
    property string word
    // 0 to 1, or -1 to show `valueText` alone.
    property real level: -1
    property string valueText
    readonly property string spoken: `${word} ${valueText}`
    // From the first key until the hold after the last one has passed; set by `press()` and the hold alone.
    property bool shown: false
    // False while the display alone speaks in its place: under a full-screen window, even while the bar slides away.
    property bool speaks: true
    // Where the flip stands, 0 to 1, linear in time: the leaving part turns over the first half, the arriving one over
    // the second.
    property real phase: 1
    // The direction of the flip running or last run.
    property bool toDisplay: false
    readonly property bool arrived: phase >= 0.5
    readonly property bool displayStands: arrived === toDisplay
    readonly property easingCurve easeOut: ({ type: Easing.Bezier, bezierCurve: Tokens.easeOut })
    readonly property easingCurve easeIn: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })
    // The part in sight turns from 0 to -90 as it leaves and from 90 to 0 as it arrives (as CSS rotateX).
    readonly property real angle: arrived ? Tokens.flipAngle * (1 - easeIn.valueForProgress(phase * 2 - 1)) : -Tokens.flipAngle * easeOut.valueForProgress(phase * 2)

    signal announced(string words, int politeness)

    // A key; the flip itself follows `shown`.
    function press() {
        shown = true;
        hold.restart();
    }

    function say(words: string) {
        if (!shown || !speaks)
            return;
        display.Accessible.announce(words, Accessible.Polite);
        display.announced(words, Accessible.Polite);
    }

    // A flip in progress ends before the next one starts, so a key during the way back waits for it.
    function swap() {
        if (turning.running || toDisplay === shown)
            return;
        toDisplay = shown;
        turning.restart();
    }

    implicitWidth: Tokens.tileUnit
    implicitHeight: Geometry.appBarControl
    x: replaces.x + (replaces.width - width) / 2
    y: replaces.y + (replaces.height - height) / 2
    visible: displayStands
    transform: Rotation {
        axis {
            x: 1
            y: 0
            z: 0
        }
        origin.x: display.width / 2
        origin.y: display.height / 2
        distanceToPlane: Tokens.turnstilePerspective
        angle: display.angle
    }
    Accessible.role: Accessible.StaticText
    Accessible.name: spoken

    onShownChanged: swap()

    Binding {
        target: display.replaces
        property: "opacity"
        value: display.displayStands ? 0 : 1
    }

    Binding {
        target: display.replaces
        property: "enabled"
        value: !display.shown
    }

    property Rotation replacesTurn: Rotation {
        axis {
            x: 1
            y: 0
            z: 0
        }
        origin.x: display.replaces.width / 2
        origin.y: display.replaces.height / 2
        distanceToPlane: Tokens.turnstilePerspective
        angle: display.displayStands ? 0 : display.angle
    }

    Component.onCompleted: replaces.transform = Array.from(replaces.transform).concat([replacesTurn])

    Timer {
        id: hold

        objectName: "hold"
        interval: Tokens.durationLevel

        onTriggered: display.shown = false
    }

    NumberAnimation {
        id: turning

        objectName: "turning"
        target: display
        property: "phase"
        from: 0
        to: 1
        duration: Tokens.durationModerate

        onRunningChanged: display.swap()
    }

    ReadoutFace {
        anchors.fill: parent
        word: display.word
        level: display.level
        valueText: display.valueText
    }
}
