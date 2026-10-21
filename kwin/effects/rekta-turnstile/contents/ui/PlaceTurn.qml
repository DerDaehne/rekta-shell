import QtQuick
import org.kde.kwin as KWin
import Rekta

// One screen's turn. Each window of a desktop is a part of its place and turns around the screen's left edge; windows
// on every desktop (panels, the background) stay where they are.
Item {
    id: view

    required property KWin.VirtualDesktop leaving
    required property KWin.VirtualDesktop arriving
    required property bool back

    readonly property KWin.Output screen: KWin.SceneView.screen
    // The windows as the turn begins: KWin's window list notifies no changes, so it is read once.
    property var windows: []
    readonly property var leavingTurns: Turnstile.plan(partsOn(leaving), Tokens.durationShort, 0)
    readonly property var arrivingTurns: Turnstile.plan(partsOn(arriving), Tokens.durationModerate, Turnstile.nextPlaceAt(leavingTurns))
    property int partsTurning: leavingTurns.length + arrivingTurns.length

    signal landed

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

    Component.onCompleted: {
        windows = KWin.Workspace.stackingOrder;
        if (partsTurning === 0)
            landed();
    }

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
