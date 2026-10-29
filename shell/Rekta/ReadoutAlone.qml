import QtQuick

// A short display with no bar to stand in, in a glass of its own along the bottom edge: the word over Rekta's meter
// with its value (ReadoutFace). It comes only while `away` holds, the bar being out of sight. It rises from below the
// glass edge with a fade, as a compact toast does (rekta.css:896–901, :929–930, :1096; motion.md:29) and the bar's mode
// change (rekta.css:765–766; motion.md:23), and after the last key and its hold runs the same curve backwards, as the
// stylesheet's reversed keyframes do (rekta.css:901). `press()` is a key: the first brings the display, every later one
// only keeps it, and one during the way back waits until it has gone.
// ponytail: a new layer surface takes some 60ms to its first frame, so the way in starts with that frame; should no frame
// ever come the display stays at its start until its hold runs out, then goes.
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
    // The way in runs `phase` from 0 to 1 and the way out from 1 to 0, linear in time; the curve sits in `progress`.
    property real phase: 0
    // A new surface has no frame yet; the way in waits for its first.
    property bool awaitsFrame: false
    readonly property easingCurve ease: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })
    readonly property real progress: ease.valueForProgress(phase)

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

    // `mapped` stays true across every change of state: the one that ends is left last.
    function arrive() {
        const fresh = !mapped;
        shown = true;
        leaving = false;
        moving.restart();
        hold.restart();
        if (!fresh || !Window.window || !moving.running)
            return;
        moving.pause();
        awaitsFrame = true;
    }

    function depart() {
        leaving = true;
        shown = false;
        moving.restart();
    }

    function vanish() {
        hold.stop();
        moving.stop();
        awaitsFrame = false;
        again = false;
        phase = 0;
        shown = false;
        leaving = false;
    }

    implicitWidth: Tokens.tileUnit + 2 * Tokens.spaceM
    implicitHeight: Tokens.appbarHeight
    Accessible.role: Accessible.StaticText
    Accessible.name: `${word} ${valueText}`

    onAwayChanged: {
        if (!away)
            vanish();
    }

    Connections {
        target: alone.Window.window

        function onFrameSwapped() {
            if (!alone.awaitsFrame)
                return;
            alone.awaitsFrame = false;
            moving.resume();
        }
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
        from: alone.shown ? 0 : 1
        to: alone.shown ? 1 : 0
        duration: Tokens.durationShort

        onFinished: {
            if (!alone.leaving)
                return;
            if (alone.again) {
                alone.again = false;
                alone.arrive();
                return;
            }
            alone.leaving = false;
        }
    }

    Rectangle {
        id: glass

        objectName: "glass"
        visible: alone.mapped
        width: parent.width
        height: Tokens.appbarHeight
        y: (1 - alone.progress) * Geometry.readoutRise
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
