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
// out of sight and comes back the same way; after login it comes that way once the splash has gone.
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
    // The toasts rise from the bar of the primary screen, above "meldungen"; it gives way to a notification's toast.
    required property Toasts toastHost
    readonly property Toaster toaster: toastHost.toaster
    required property bool startOpen
    // The splash has gone after login (SplashEnd.arrived).
    required property bool arrived
    readonly property bool showsReadout: modelData === primaryScreen
    readonly property bool showsToasts: modelData === primaryScreen
    // The active window, when it is on this screen.
    readonly property var front: windows?.active?.isOn(modelData) ? windows.active : null
    readonly property bool away: !arrived || (windows?.fullScreenOn(modelData) ?? false)
    readonly property var middleLine: Middle.barLine(
        controlPanel.quiet.middleParts,
        Middle.musicParts(media?.title ?? "", media?.artist ?? "", media?.position ?? 0, media?.length ?? 0),
        front ? Middle.windowParts(front.app, front.title) : [])
    readonly property bool floatOpen: bar.menu.open || background.menu.open || clock.calendar.open || tip.open
    readonly property bool panelOpenHere: controlPanel.visible && controlPanel.screen === modelData

    screen: modelData
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    implicitHeight: Tokens.appbarHeight
    exclusiveZone: Tokens.appbarHeight
    color: "transparent"
    // Unmapped once out of sight, so a full-screen window has the screen to itself. Mapped under the splash already: a
    // new layer surface takes some 60ms to its first frame, which the slide in would lose.
    visible: !away || bar.sliding || !arrived
    // A dock to KWin: a namespace it does not know makes a normal window, which tiling scripts move into the work area,
    // out of the zone the surface keeps clear itself.
    WlrLayershell.namespace: "dock"
    // Above the full-screen window while it slides away.
    WlrLayershell.layer: away ? WlrLayer.Overlay : WlrLayer.Top
    // A deliberate deviation: KWin blurs at the strength of its blur effect, as ext-background-effect has no radius for
    // rekta.css:800's blur(12px). The glass slides without it: a region moving out of the window leaves KWin's blur an
    // empty framebuffer.
    BackgroundEffect.blurRegion: Region {
        item: panel.away || bar.sliding ? null : bar
    }

    // A status word opens its place in the controls; the background word opens the menu of the background apps instead.
    // ponytail: without a background app (a capture without a tray entry) the press does nothing.
    function openWord(word: var) {
        if (word.opens !== "background")
            controlPanel.openAt(modelData, word.opens);
        else if (background.present)
            background.menu.openAt(0);
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
            kind: panel.middleLine.kind
            parts: panel.middleLine.parts
            figuresPart: panel.middleLine.figuresPart

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
            iconKnown: name => Quickshell.iconPath(name, true) !== ""
        }

        AppBarButton {
            id: bell

            icon: "bell"
            text: "meldungen"
            count: panel.notices.unseen
            away: panel.showsToasts && panel.toaster.countAway
            priority: 2
            onClicked: panel.controlPanel.toggle(panel.modelData, 1, !bell.activeFocus)
        }

        AppBarStatus {
            keys: panel.status.keys
            words: panel.status.deviations
            more: panel.status.more

            onActivated: word => panel.openWord(word)
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

    // A toast stands flush with the trailing edge of "meldungen", or of "mehr" while that holds it; the bar spans the
    // screen as the toasts' surface does, so its x is theirs.
    Binding {
        when: panel.showsToasts
        target: panel.toaster
        property: "trailingEdge"
        value: bell.overflowed ? bar.more.x + bar.more.width : bell.x + bell.width
    }

    Binding {
        when: panel.showsToasts
        target: panel.toaster
        property: "countInSight"
        value: !panel.away && !bell.overflowed
    }

    // Rekta lays floating surfaces above the toasts, but KWin keeps the bar's popups below the overlay layer the toasts
    // are on, so the toasts step back to the top layer while one is open. Not while the side panel is open on this
    // screen or the Start is: on their layer a toast could lie under the panel, whose foot it covers, and KWin raises
    // the Start as it opens, before the popups it closes then have gone.
    // ponytail: with the panel open, a floating surface of the bar lies under a toast; upgrade: host the floating
    // surfaces on the overlay layer and have KWin activate them, which costs the popups' grab.
    Binding {
        when: panel.showsToasts
        target: panel.toastHost
        property: "stepsBack"
        value: panel.floatOpen && !panel.startOpen && !panel.panelOpenHere
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
