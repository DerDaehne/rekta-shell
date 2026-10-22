pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Rekta
import "services"

// The app bar on one screen (navigation.md, "App bar"): along the bottom edge, full width, and windows keep clear of
// it. "go to" and the middle with the active window lead, the clock stands in the centre, the background apps,
// messages and controls trail. Under a full-screen window it slides down out of sight and comes back the same way.
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
    visible: !away || slide.running
    WlrLayershell.namespace: "rekta-appbar"
    // Above the full-screen window while it slides away.
    WlrLayershell.layer: away ? WlrLayer.Overlay : WlrLayer.Top
    // KWin blurs at its own strength; ext-background-effect has no radius for rekta.css:619's blur(12px). The glass
    // slides without it: a region moving out of the window leaves KWin's blur an empty framebuffer.
    BackgroundEffect.blurRegion: Region {
        item: panel.away || slide.running ? null : bar
    }

    AppBar {
        id: bar

        width: parent.width
        viewportHeight: panel.modelData.height
        area: Qt.size(panel.modelData.width, panel.modelData.height)
        centre: clockSlot
        transform: Translate {
            y: panel.away ? Tokens.appbarHeight : 0

            Behavior on y {
                NumberAnimation {
                    id: slide

                    duration: Tokens.durationShort
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.easeOut
                }
            }
        }

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
            priority: 1
            disabledReason: "kommt mit dem panel"
        }

        AppBarButton {
            icon: "tune"
            text: "steuerung"
            priority: 2
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

    Component.onCompleted: {
        bar.menu.parent = popup.contentItem;
        bar.menu.x = 0;
        bar.menu.y = 0;
    }
}
