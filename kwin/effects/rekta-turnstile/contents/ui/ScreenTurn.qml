import QtQuick
import org.kde.kwin as KWin
import Rekta

// One screen's turn. Each window of a desktop is a part of its place and turns around the screen's left edge; windows
// on every desktop (panels, the background) stay where they are.
Item {
    id: view

    // Which switch this view shows. A new one during a turn ends the running turn where it stands, its arriving windows
    // at rest, and starts the next from there.
    required property int turn
    required property KWin.VirtualDesktop leaving
    required property KWin.VirtualDesktop arriving
    required property bool back

    readonly property KWin.Output screen: KWin.SceneView.screen
    property int begunTurn: -1
    property var windows: []
    property var leavingTurns: []
    property var arrivingTurns: []
    property int partsTurning: 0

    signal landed

    function begin() {
        if (begunTurn === turn)
            return;
        begunTurn = turn;
        // KWin's window list notifies no changes, so it is read as each turn begins.
        windows = KWin.Workspace.stackingOrder;
        const out = Turnstile.plan(partsOn(leaving), Tokens.durationShort, 0);
        const into = Turnstile.plan(partsOn(arriving), Tokens.durationModerate, Turnstile.nextPlaceAt(out));
        // Counted before the parts exist, so a part that lands at once already finds its count.
        partsTurning = out.length + into.length;
        leavingTurns = out;
        arrivingTurns = into;
        if (partsTurning === 0)
            landed();
    }

    function isPart(window: KWin.Window): bool {
        return (window.normalWindow || window.dialog) && !window.onAllDesktops && !window.minimized && window.output === screen;
    }

    // The windows of a desktop as rectangles within the screen, which clips them.
    function partsOn(desktop: KWin.VirtualDesktop): var {
        return windows.filter(window => isPart(window) && window.desktops.includes(desktop)).map(window => ({
                    window: window,
                    x: window.x - screen.geometry.x,
                    y: window.y - screen.geometry.y,
                    width: window.width,
                    height: window.height
                }));
    }

    function partLanded() {
        partsTurning -= 1;
        if (partsTurning === 0)
            landed();
    }

    onTurnChanged: begin()
    Component.onCompleted: begin()

    Repeater {
        model: view.windows.filter(window => window.output === view.screen && window.onAllDesktops && !window.minimized)

        KWin.WindowThumbnail {
            required property KWin.Window modelData

            client: modelData
            x: modelData.x - view.screen.geometry.x
            y: modelData.y - view.screen.geometry.y
            width: modelData.width
            height: modelData.height
            z: modelData.desktopWindow ? -1 : modelData.stackingOrder
        }
    }

    Repeater {
        model: view.leavingTurns

        TurningWindow {
            leaving: true
            back: view.back
            onLanded: view.partLanded()
        }
    }

    Repeater {
        model: view.arrivingTurns

        TurningWindow {
            leaving: false
            back: view.back
            onLanded: view.partLanded()
        }
    }
}
