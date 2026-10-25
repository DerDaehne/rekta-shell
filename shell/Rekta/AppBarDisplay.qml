pragma ComponentBehavior: Bound

import QtQuick

// A short display that takes the place of a bar control, such as the clock, after a key: the word over Rekta's meter
// with its value in tabular figures (data.md, "Meters"), or over a plain text when there is no level. The control turns
// away around its bottom edge and the display turns in, from the other side, once the control is three quarters
// through; after the last key it stays, then runs the same turn the other way round. The turns use the place change's
// curves and shares (rekta.css:975, :988–1011, rekta.js:489). Under reduced motion the two change at once; the display
// still stays its time. `press()` is a key: the first brings the display, every later one only keeps it.
Item {
    id: display

    // The control the display takes the place of.
    required property Item replaces
    property string word
    // 0 to 1, or -1 to show `valueText` alone.
    property real level: -1
    property string valueText
    // From the first key until the hold after the last one has passed; set by `press()` and the hold alone.
    property bool shown: false
    // Where the swap stands, in turn durations: the leaving part runs 0 to 1, the arriving one 0.75 to 1.75.
    property real phase: span
    // The direction of the swap running or last run.
    property bool toDisplay: false
    readonly property real span: 1 + Geometry.turnOverlap
    readonly property real turnTime: Tokens.reducedMotion ? 0 : Geometry.flipDuration
    readonly property real leaving: Math.min(1, phase)
    readonly property real arriving: Math.min(1, Math.max(0, phase - Geometry.turnOverlap))
    readonly property easingCurve easeOut: ({ type: Easing.Bezier, bezierCurve: Geometry.easeTurnOut })
    readonly property easingCurve easeIn: ({ type: Easing.Bezier, bezierCurve: Geometry.easeTurnIn })
    // The leaving part is whole for its first share, then fades; the arriving one is whole after its first share.
    readonly property real leaveFade: 1 - easeOut.valueForProgress(Math.max(0, (leaving - Geometry.turnOutWhole) / (1 - Geometry.turnOutWhole)))
    readonly property real arriveFade: easeIn.valueForProgress(Math.min(1, arriving / Geometry.turnInWhole))
    readonly property real turnedOut: Geometry.flipAngle * easeOut.valueForProgress(leaving)
    readonly property real turnedIn: Geometry.flipAngle * (1 - easeIn.valueForProgress(arriving))
    // The control turns toward one side, the display toward the other: -90 at its start in, and on its way out.
    readonly property real replacesAngle: toDisplay ? turnedOut : turnedIn
    readonly property real displayAngle: -(toDisplay ? turnedIn : turnedOut)
    readonly property real replacesFade: toDisplay ? leaveFade : arriveFade
    readonly property real displayFade: toDisplay ? arriveFade : leaveFade

    // A key; the swap itself follows `shown`.
    function press() {
        shown = true;
        hold.restart();
    }

    // A swap in progress ends before the next one starts, so a key during the way back waits for it.
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
    opacity: displayFade
    visible: opacity > 0
    transform: Rotation {
        axis {
            x: 1
            y: 0
            z: 0
        }
        origin.x: display.width / 2
        origin.y: display.height
        distanceToPlane: Tokens.turnstilePerspective
        angle: display.displayAngle
    }
    Accessible.role: Accessible.StaticText
    Accessible.name: `${word} ${valueText}`

    onShownChanged: swap()

    Binding {
        target: display.replaces
        property: "opacity"
        value: display.replacesFade
    }

    Binding {
        target: display.replaces
        property: "enabled"
        value: !display.shown
    }

    // The control turns about the middle of its bottom edge.
    property Rotation replacesTurn: Rotation {
        axis {
            x: 1
            y: 0
            z: 0
        }
        origin.x: display.replaces.width / 2
        origin.y: display.replaces.height
        distanceToPlane: Tokens.turnstilePerspective
        angle: display.replacesAngle
    }

    Component.onCompleted: replaces.transform = Array.from(replaces.transform).concat([replacesTurn])

    Timer {
        id: hold

        objectName: "hold"
        interval: Geometry.displayHold

        onTriggered: display.shown = false
    }

    NumberAnimation {
        id: turning

        objectName: "turning"
        target: display
        property: "phase"
        from: 0
        to: display.span
        duration: display.span * display.turnTime

        onRunningChanged: display.swap()
    }

    Meter {
        id: meter

        objectName: "meter"
        visible: display.level >= 0
        anchors.verticalCenter: parent.verticalCenter
        x: Geometry.appBarControlPadding
        width: display.width - 2 * Geometry.appBarControlPadding
        label: display.word
        value: display.level
        valueText: display.valueText
    }

    Item {
        id: plain

        objectName: "plain"
        visible: display.level < 0
        x: Geometry.appBarControlPadding
        y: (display.height - height) / 2
        width: display.width - 2 * Geometry.appBarControlPadding
        height: wordLine.height + nameLine.height

        Meta {
            id: wordLine

            width: plain.width
            lineHeightFactor: Tokens.lineHeightCompact
            wrapMode: Text.NoWrap
            text: display.word
        }

        TextRole {
            id: nameLine

            y: wordLine.height
            width: plain.width
            lineHeightFactor: Tokens.lineHeightCompact
            elide: Text.ElideRight
            text: display.valueText
            font.pixelSize: Tokens.fontSizeXs
            font.weight: Tokens.fontWeightSemibold
            color: Tokens.color.textPrimary
        }
    }
}
