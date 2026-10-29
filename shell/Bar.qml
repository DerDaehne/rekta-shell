pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Notices
import Readout
import State
import Rekta
import Tray
import "services"

// The app bar on one screen (navigation.md, "App bar"): along the bottom edge, full width, and windows keep clear of
// it. The middle with the active window leads, the clock stands in the centre, the background apps (gone
// while none runs), messages and controls trail, each opening the side panel on this screen on its facet; those
// whose features come later stand disabled, their reason in their tooltip. Under a full-screen window it slides down
// out of sight and comes back the same way.
PanelWindow {
    id: panel

    required property ShellScreen modelData
    required property Windows windows
    required property Media media
    required property NoticeBoard notices
    required property Tray tray
    required property ControlPanel controlPanel
    // The keys' readout and the screen that shows it: the display stands in the bar of the primary screen only.
    required property KeyReadout readout
    // What deviates from normal, as the words before "steuerung".
    required property StatusWords status
    required property ShellScreen primaryScreen
    readonly property bool showsReadout: modelData === primaryScreen
    // The active window, when it is on this screen.
    readonly property var front: windows?.active?.isOn(modelData) ? windows.active : null
    readonly property bool away: windows?.fullScreenOn(modelData) ?? false
    // What the middle says, the first of these that has something: the music that plays, else the window.
    readonly property var musicParts: Middle.musicParts(media?.title ?? "", media?.artist ?? "", media?.position ?? 0, media?.length ?? 0)
    readonly property bool playing: musicParts.length > 0
    readonly property var windowParts: front ? Middle.windowParts(front.app, front.title) : []

    screen: modelData
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    implicitHeight: Tokens.appbarHeight
    exclusiveZone: Tokens.appbarHeight
    color: "transparent"
    // Unmapped once out of sight, so a full-screen window has the screen to itself.
    visible: !away || bar.sliding
    // A dock to KWin: a namespace it does not know makes a normal window, which tiling scripts move into the work area,
    // out of the zone the surface keeps clear itself.
    WlrLayershell.namespace: "dock"
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
        // A screen that has gone is null here until its bar goes too.
        viewportHeight: panel.modelData?.height ?? 0
        area: Qt.size(panel.modelData?.width ?? 0, panel.modelData?.height ?? 0)
        centre: clock
        centreReserve: panel.showsReadout ? display.implicitWidth : 0
        away: panel.away

        AppBarMiddle {
            kind: panel.playing ? "music" : "window"
            parts: Middle.firstRunning([panel.musicParts], panel.windowParts)
            figuresPart: panel.playing ? 1 : -1

            onTapped: panel.controlPanel.toggle(panel.modelData, 0, true)
        }

        AppBarClock {
            id: clock

            area: bar.area
        }

        AppBarDisplay {
            id: display

            replaces: clock
            word: panel.readout.word
            level: panel.readout.level
            valueText: panel.readout.valueText
        }

        BackgroundControl {
            id: background

            apps: panel.tray.apps
            area: bar.area
            priority: 0
            opener: Component {
                QsMenuOpener {}
            }
        }

        AppBarButton {
            id: bell

            icon: "bell"
            text: "meldungen"
            count: panel.notices.unseen
            priority: 2
            onClicked: panel.controlPanel.toggle(panel.modelData, 1, !bell.activeFocus)
        }

        AppBarStatus {
            keys: panel.status.keys
            words: panel.status.deviations
            more: panel.status.more

            onActivated: word => panel.controlPanel.openAt(panel.modelData, word.opens)
        }

        AppBarButton {
            id: tune

            icon: "tune"
            text: "steuerung"
            priority: 1
            onClicked: panel.controlPanel.toggle(panel.modelData, 0, !tune.activeFocus)
        }
    }

    Connections {
        target: panel.showsReadout ? panel.readout : null

        function onPressed() {
            display.press();
        }
    }

    FloatPopup {
        barWindow: panel
        surface: bar.menu
        place: bar.menuPlace

        onDismissed: bar.menu.close(false)
    }

    FloatPopup {
        barWindow: panel
        surface: background.menu
        place: bar.floatPlace(background.overflowed ? bar.more : background, Qt.size(background.menu.width, background.menu.height))

        onDismissed: background.menu.close(false)
    }

    FloatPopup {
        barWindow: panel
        surface: clock.calendar
        place: bar.floatPlace(clock, Qt.size(clock.calendar.width, clock.calendar.height), "centre")

        onDismissed: clock.closeCalendar(false)
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

    // A floating surface of the bar rises past the bar's own window, so it lives in a popup of its own, placed where the
    // bar places it; the compositor closes it on a click outside.
    component FloatPopup: PopupWindow {
        id: host

        required property QtObject barWindow
        required property FloatSurface surface
        // From AppBar.floatPlace: where it goes in the bar's window, and on which side of its control.
        required property var place

        signal dismissed

        // The linter cannot see PopupAnchor's members: Quickshell and its window module depend on each other.
        anchor.window: barWindow // qmllint disable missing-property
        anchor.rect: Qt.rect(place.x, place.y, 1, 1) // qmllint disable missing-property
        implicitWidth: surface.width
        implicitHeight: surface.height
        visible: remap.mapped
        grabFocus: true
        color: "transparent"

        onVisibleChanged: {
            if (!visible && !remap.remapping)
                dismissed();
        }

        PopupRemap {
            id: remap

            surface: host.surface
            wanted: host.surface.open
        }

        Component.onCompleted: {
            surface.parent = contentItem;
            surface.x = 0;
            surface.y = 0;
            surface.side = Qt.binding(() => host.place.side);
        }
    }
}
