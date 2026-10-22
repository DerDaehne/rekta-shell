pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Rekta
import "services"

// The app bar on one screen (navigation.md, "App bar"): along the bottom edge, full width, and windows keep clear of
// it. "go to" and the middle with the active window lead, the clock stands in the centre, the background apps,
// messages and controls trail; those whose features come later stand disabled, their reason in their tooltip. Under a
// full-screen window it slides down out of sight and comes back the same way.
PanelWindow {
    id: panel

    required property ShellScreen modelData
    required property Windows windows
    // The active window, when it is on this screen.
    readonly property var front: windows?.active?.isOn(modelData) ? windows.active : null
    // ponytail: only the active window hides the bar; a full-screen window on this screen that lost the keyboard to
    // another screen stays above the bar anyway. Follow every screen's front window when that shows wrongly.
    readonly property bool away: front?.fullScreen ?? false

    screen: modelData
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    implicitHeight: Tokens.appbarHeight
    exclusiveZone: Tokens.appbarHeight
    color: "transparent"
    // Unmapped once out of sight, so a full-screen window has the screen to itself.
    visible: !away || bar.sliding
    WlrLayershell.namespace: "rekta-appbar"
    // Above the full-screen window while it slides away.
    WlrLayershell.layer: away ? WlrLayer.Overlay : WlrLayer.Top
    // A deliberate deviation: KWin blurs at the strength of its blur effect, as ext-background-effect has no radius for
    // rekta.css:619's blur(12px). The glass slides without it: a region moving out of the window leaves KWin's blur an
    // empty framebuffer.
    BackgroundEffect.blurRegion: Region {
        item: panel.away || bar.sliding ? null : bar
    }

    AppBar {
        id: bar

        width: parent.width
        viewportHeight: panel.modelData.height
        area: Qt.size(panel.modelData.width, panel.modelData.height)
        centre: clockSlot
        away: panel.away

        AppBarButton {
            icon: "search"
            text: "go to"
            priority: 3
            disabledReason: "kommt mit der palette"
        }

        AppBarMiddle {
            parts: panel.front ? [panel.front.app, panel.front.title] : []
        }

        // The clock's place.
        Item {
            id: clockSlot
        }

        AppBarButton {
            icon: "window"
            text: "im hintergrund"
            priority: 0
            disabledReason: "kommt mit dem tray"
        }

        AppBarButton {
            icon: "bell"
            text: "meldungen"
            priority: 2
            disabledReason: "kommt mit dem panel"
        }

        AppBarButton {
            icon: "tune"
            text: "steuerung"
            priority: 1
            disabledReason: "kommt mit dem panel"
        }
    }

    // "more" rises past the bar's own window, so its menu lives in a popup; the compositor closes it on a click outside.
    PopupWindow {
        id: popup

        // The linter cannot see PopupAnchor's members: Quickshell and its window module depend on each other.
        anchor.window: panel // qmllint disable missing-property
        anchor.rect: Qt.rect(bar.menuPlace.x, bar.menuPlace.y, 1, 1) // qmllint disable missing-property
        implicitWidth: bar.menu.width
        implicitHeight: bar.menu.height
        visible: bar.menu.open
        grabFocus: true
        color: "transparent"

        onVisibleChanged: {
            if (!visible)
                bar.menu.close(false);
        }
    }

    // A tooltip rises past the bar's own window too. It never takes the pointer, so its popup lets every click through.
    PopupWindow {
        id: tipHost

        readonly property var place: {
            if (!tip.target)
                return { x: 0, y: 0, side: "above" };
            return bar.tipPlace(tip.target, Qt.size(tip.width, tip.height));
        }

        anchor.window: panel // qmllint disable missing-property
        anchor.rect: Qt.rect(place.x, place.y, 1, 1) // qmllint disable missing-property
        implicitWidth: tip.width
        implicitHeight: tip.height
        visible: tip.open
        color: "transparent"
        mask: Region {}

        Tooltip {
            id: tip

            // Each bar's tip, from a control in the bar's window rather than in the popup's own.
            target: Tips.target?.Window.window === bar.Window.window ? Tips.target : null
            area: bar.area
            side: tipHost.place.side
        }
    }

    Component.onCompleted: {
        bar.menu.parent = popup.contentItem;
        bar.menu.x = 0;
        bar.menu.y = 0;
    }
}
