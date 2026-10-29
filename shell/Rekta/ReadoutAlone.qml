import QtQuick

// A short display with no bar to stand in, in a glass of its own along the bottom edge: the word over Rekta's meter
// with its value (ReadoutFace). It comes only while `away` holds, the bar being out of sight. It rises from below the
// glass edge with a fade, as a compact toast does (rekta.css:896–901, :929–930; motion.md:29) and the bar's mode change
// (rekta.css:765–766; motion.md:23), and after the last key and its hold runs the same way back. `press()` is a key: the
// first brings the display, every later one only keeps it, and one during the way back waits until it has gone.
Item {
    id: alone

    property string word
    // 0 to 1, or -1 to show `valueText` alone.
    property real level: -1
    property string valueText
    // The bar is out of sight, so the display has to stand by itself; when it ends the display is gone at once.
    property bool away: false
    // From the first key to the end of the way back: the host maps its surface only then.
    readonly property bool mapped: shown || leaving
    // At rest on screen: the glass does not move, so the compositor may blur behind it.
    readonly property bool settled: shown && progress === 1
    readonly property alias glass: glass
    property bool shown: false
    property bool leaving: false
    // A key came while the display was leaving.
    property bool again: false
    // The time of the way in or out, 0 to 1 and linear; `progress` is what the eye sees.
    property real phase: 1
    readonly property easingCurve ease: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })
    readonly property real eased: ease.valueForProgress(phase)
    readonly property real progress: leaving ? 1 - eased : (shown ? eased : 0)

    function press() {
        if (!away)
            return;
        if (leaving)
            again = true;
        else if (shown)
            hold.restart();
        else
            arrive();
    }

    function arrive() {
        shown = true;
        leaving = false;
        moving.restart();
        hold.restart();
    }

    function depart() {
        shown = false;
        leaving = true;
        moving.restart();
    }

    function vanish() {
        hold.stop();
        moving.stop();
        again = false;
        shown = false;
        leaving = false;
    }

    implicitWidth: Tokens.tileUnit + 2 * Tokens.spaceM
    implicitHeight: Tokens.appbarHeight + Geometry.readoutRise
    Accessible.role: Accessible.StaticText
    Accessible.name: `${word} ${valueText}`

    onAwayChanged: {
        if (!away)
            vanish();
    }

    Timer {
        id: hold

        objectName: "hold"
        interval: Geometry.displayHold

        onTriggered: alone.depart()
    }

    NumberAnimation {
        id: moving

        objectName: "moving"
        target: alone
        property: "phase"
        from: 0
        to: 1
        duration: Tokens.durationShort

        onFinished: {
            if (!alone.leaving)
                return;
            alone.leaving = false;
            if (!alone.again)
                return;
            alone.again = false;
            alone.press();
        }
    }

    Rectangle {
        id: glass

        objectName: "glass"
        visible: alone.mapped
        width: parent.width
        height: Tokens.appbarHeight
        y: parent.height - height + (1 - alone.progress) * Geometry.readoutRise
        opacity: alone.progress
        color: Tokens.color.glass

        Hairline {
            objectName: "hairline"
        }

        ReadoutFace {
            x: Tokens.spaceM
            width: Tokens.tileUnit
            height: parent.height
            word: alone.word
            level: alone.level
            valueText: alone.valueText
        }
    }
}
