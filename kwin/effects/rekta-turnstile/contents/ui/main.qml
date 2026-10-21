import QtQuick
import org.kde.kwin as KWin
import org.kde.kirigami as Kirigami
import Rekta

// A virtual desktop switch as Rekta's place change: the windows of the desktop left behind turn out around the
// screen's leading edge, then those of the next desktop turn in from the other side.
KWin.SceneEffect {
    id: effect

    property int turn: 0
    property KWin.VirtualDesktop leaving: null
    property KWin.VirtualDesktop arriving: null
    property bool back: false
    property int landedViews: 0

    function land() {
        landedViews += 1;
        if (landedViews >= KWin.Workspace.screens.length)
            finish();
    }

    function finish() {
        overrun.stop();
        visible = false;
    }

    delegate: PlaceTurn {
        turn: effect.turn
        leaving: effect.leaving
        arriving: effect.arriving
        back: effect.back
        onLanded: effect.land()
    }

    // KWin hands its animation speed to QML only through Kirigami's units, which turn "instant" into 1 ms.
    Binding {
        target: Tokens
        property: "reducedMotion"
        value: Kirigami.Units.longDuration <= 1
    }

    // While the effect runs it holds the screen and its input, so no turn may outlast the longest a place change takes.
    Timer {
        id: overrun

        interval: Turnstile.longestPlaceChange(Tokens.durationShort, Tokens.durationModerate)
        onTriggered: effect.finish()
    }

    Connections {
        target: KWin.Workspace

        function onCurrentDesktopChanged(previous: KWin.VirtualDesktop) {
            const current = KWin.Workspace.currentDesktop;
            if (!previous || previous === current || Tokens.reducedMotion)
                return;
            effect.leaving = previous;
            effect.arriving = current;
            // An earlier desktop in the order is the way back, which turns the other way round.
            effect.back = current.x11DesktopNumber < previous.x11DesktopNumber;
            effect.landedViews = 0;
            effect.turn += 1;
            effect.visible = true;
            overrun.restart();
        }
    }
}
