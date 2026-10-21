import QtQuick
import org.kde.kwin as KWin
import Rekta

// One screen's turn. Each window is a part of the place: it turns around the screen's left edge in a time that
// follows its size (its heft), light parts first, parts of one heft in reading order.
Item {
    id: view

    required property KWin.VirtualDesktop leaving
    required property KWin.VirtualDesktop arriving
    required property bool back

    readonly property KWin.Output screen: KWin.SceneView.screen
    readonly property var leavingParts: plan(partsOn(leaving), Tokens.durationShort, 0)
    readonly property real arrivalAt: Math.max(0, ...leavingParts.map(part => part.at + Geometry.turnOverlap * part.duration))
    readonly property var arrivingParts: plan(partsOn(arriving), Tokens.durationModerate, arrivalAt)
    property int partsTurning: leavingParts.length + arrivingParts.length

    signal landed

    function isPart(window: KWin.Window): bool {
        return (window.normalWindow || window.dialog) && !window.onAllDesktops && !window.minimized && window.output === screen;
    }

    function partsOn(desktop: KWin.VirtualDesktop): var {
        return KWin.Workspace.windowList().filter(window => isPart(window) && window.desktops.includes(desktop));
    }

    function heft(window: KWin.Window): real {
        const area = Math.max(1, window.width * window.height) / (Tokens.tileUnit * Tokens.tileUnit);
        const weight = Geometry.heftAtTile * Math.pow(area, Geometry.heftExponent);
        return Math.min(Geometry.heftMax, Math.max(Geometry.heftMin, weight));
    }

    function readingRow(window: KWin.Window): int {
        return Math.round((window.y - screen.geometry.y) / Geometry.turnRowStep);
    }

    function inReadingOrder(windows: var): var {
        return windows.slice().sort((a, b) => (readingRow(a) - readingRow(b)) || (a.x - b.x));
    }

    // The perspective of a row grows with how far its parts reach from the edge they turn around.
    function rowPerspectives(windows: var): var {
        const farthest = new Map();
        for (const window of windows) {
            const reach = window.x + window.width - screen.geometry.x;
            farthest.set(readingRow(window), Math.max(farthest.get(readingRow(window)) || 0, reach));
        }
        return windows.map(window => Tokens.turnstilePerspective + Geometry.turnPerspectivePerReach * farthest.get(readingRow(window)));
    }

    function plan(windows: var, duration: real, from: real): var {
        const ordered = inReadingOrder(windows);
        const perspectives = rowPerspectives(ordered);
        const seen = new Map();
        return ordered.map((window, index) => {
            const weight = heft(window);
            const key = Math.round(weight / Geometry.sameHeftWithin);
            const before = seen.get(key) || 0;
            seen.set(key, before + 1);
            const at = (weight - Geometry.heftMin) * Geometry.heftStaggerSteps * Tokens.durationStagger + Math.min(before, Geometry.sameHeftSteps) * Tokens.durationStagger * Geometry.sameHeftStagger;
            return {
                window: window,
                at: from + at,
                duration: duration * weight,
                originY: Math.abs(window.y - screen.geometry.y) < Geometry.turnFlushTop ? 0 : window.height / 2,
                perspective: perspectives[index]
            };
        });
    }

    function partLanded() {
        partsTurning -= 1;
        if (partsTurning === 0)
            landed();
    }

    Component.onCompleted: {
        if (partsTurning === 0)
            landed();
    }

    Repeater {
        model: KWin.Workspace.windowList().filter(window => window.output === view.screen && window.onAllDesktops && !window.minimized)

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
        model: view.leavingParts

        TurningWindow {
            screen: view.screen
            leaving: true
            back: view.back
            onLanded: view.partLanded()
        }
    }

    Repeater {
        model: view.arrivingParts

        TurningWindow {
            screen: view.screen
            leaving: false
            back: view.back
            onLanded: view.partLanded()
        }
    }
}
