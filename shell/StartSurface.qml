pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus
import RektaShell.DBus
import Settings
import Start
import Notices
import Rekta
import "services"

// The Start's surface: full screen on the primary screen, above the windows and the app bar, below the toasts. Without
// windows the Start stands.
PanelWindow {
    id: surface

    required property Windows windows
    required property Launcher launcher
    required property NoticeBoard notices
    // What plays: its line stands on its app's tile.
    required property Media media
    required property ShellScreen primaryScreen
    // The room a banner keeps clear at the top: the Start begins below it, as the windows do.
    property real topInset: 0
    // The splash has gone after login (SplashEnd.arrived); until then the Start does not open on its own.
    required property bool arrived
    // Where a change to the pinned apps offers its undo.
    property Toaster toaster: null
    // Its first frame is out: the splash may fade over it.
    property bool drawn: false
    // What Escape does in a search: "close" or "back" (the setting searchEscape).
    property string searchEscape: "close"
    // "zuletzt" shows in the Start (the setting showRecent).
    property bool showRecent: true
    // From the moment it opens until it starts to close.
    readonly property alias opened: place.wanted
    // The window that had the keyboard as the Start opened is full screen: back the way it came, the Start hands it back.
    property bool handsToFullScreen: false
    // The shell's commands, see StartPlace.commands.
    property var commands: []
    // Meta held for the key map (MetaHold), which takes the Meta that follows from the Start.
    property var metaHold: null
    // The list in start.json, null without a usable one.
    readonly property var listedPins: startFile.list
    // The window previews on the Start, and KWin's node of each that streams.
    property list<WindowPreview> previews: []
    readonly property list<int> previewNodes: previews.map(preview => preview.node).filter(node => node > 0)
    // KWin gives the keyboard to the next window when a surface goes, also when the side panel over the open Start goes;
    // it hands it to a layer surface only as that one starts to ask for it (LayerShellV1Window::handleAcceptsFocusChanged).
    property bool askingAgain: false
    // KWin's fade-back takes a single commit without the keyboard for asking anew. Nothing on the Start changes after its
    // hand-over, so it draws one frame more then, to say it let go.
    property bool confirmingHandOver: false

    // Asks for the keyboard anew, one commit without it and one with it, while the Start is open. KWin's fade-back holds
    // the windows through the first, as it would at a hand-over, and the next one keeps them back.
    function takeKeyboardBack() {
        if (place.wanted)
            askingAgain = true;
    }

    // An app started from elsewhere, such as the session banner, comes to the front: the Start turns out forward, as
    // after a choice in it.
    function stepAside() {
        place.leave({
            back: false,
            pressed: null
        });
    }

    // The apps pinned in start.json, or Plasma's own; those installed, as their desktop entries say.
    function pinnedApps(entries: list<DesktopEntry>, listed: var): var {
        const byId = id => entries.find(entry => entry.id === id) ?? null;
        return Rules.pinnedTiles(listed, id => byId(id) !== null).map(tile => {
            const entry = byId(tile.id);
            return {
                id: entry.id,
                name: entry.name,
                icon: Quickshell.iconPath(entry.icon, true),
                glyph: Rules.ownGlyph(entry.id),
                columns: tile.columns,
                rows: tile.rows,
                index: tile.index,
                launch: () => {
                    surface.launcher.launch(entry);
                    usage.count(entry.id);
                }
            };
        });
    }

    screen: primaryScreen
    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // Mapped from the start, so the Start shows in the next frame (a new layer surface takes some 60ms to its first);
    // hidden, it lets every input through. Under a full-screen window it goes, so that window has the screen to itself,
    // and while no screen is left.
    visible: primaryScreen !== null && (place.shown || !windows.fullScreenOn(primaryScreen))
    mask: Region {
        item: place.shown ? place : null
    }
    WlrLayershell.namespace: "rekta-start"
    // A place lies below the toasts (Rekta's layers), so the Start keeps to the top layer: on one layer KWin raises the
    // surface that takes the keyboard over the others, as the Start when it opens. A full-screen window that has the
    // keyboard lies above that layer, so the Start rises as it starts to close when it may hand the keyboard back to one,
    // ahead of KWin activating it, and when KWin reports one active otherwise. Not while it is open: then no window has
    // the keyboard, and the app bar coming back over a full-screen window maps below it.
    // ponytail: over a full-screen window, a toast that stood before the Start opened lies below the glass from the close
    // on, and a full-screen window chosen in the Start lies above it until KWin reports it active; map the toasts anew
    // as the Start rises and tell the surface the chosen window, should either show.
    WlrLayershell.layer: !place.wanted && (handsToFullScreen || windows.fullScreenOn(primaryScreen)) ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: place.holdsKeyboard && !askingAgain ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // A deliberate deviation, as for the app bar: KWin blurs at the strength of its blur effect, not glass's blur(12px).
    BackgroundEffect.blurRegion: Region {
        item: place.shown ? place : null
    }

    StartPlace {
        id: place

        anchors.fill: parent
        anchors.topMargin: surface.topInset
        windows: Array.from(surface.windows.all)
        pinned: surface.pinnedApps(Array.from(DesktopEntries.applications.values), surface.listedPins)
        pinFile: startFile
        toaster: surface.toaster
        apps: installed.list
        settings: installed.settings
        commands: surface.commands
        webSearch: webSearch.query
        openUrl: url => surface.launcher.open(url)
        copy: text => {
            Quickshell.clipboardText = text;
        }
        searchEscape: surface.searchEscape
        showRecent: surface.showRecent
        screenHeight: surface.height
        starts: usage.starts
        unseen: surface.notices.unseenByApp
        lines: Rules.playingLines(surface.media.player, surface.media.appId)
        board: surface.notices
        playerChoice: surface.media.choice
        preview: Component {
            WindowPreview {
                id: windowPreview

                Component.onCompleted: surface.previews = [...surface.previews, windowPreview]
                Component.onDestruction: surface.previews = surface.previews.filter(other => other !== windowPreview)
            }
        }
        onWantedChanged: {
            if (place.wanted)
                surface.handsToFullScreen = surface.windows.fullScreenOn(surface.primaryScreen);
        }
        onHoldsKeyboardChanged: {
            if (!place.holdsKeyboard && place.shown)
                surface.confirmingHandOver = true;
        }
        onWindowsAt: (time, pace) => kwin.call("org.kde.KWin", "/RektaFadeBack", "org.rekta.FadeBack", "setStartAt", [time, pace], "di")
        onWindowsOutAt: (time, pace) => kwin.call("org.kde.KWin", "/RektaFadeBack", "org.rekta.FadeBack", "setStartOutAt", [time, pace], "di")
    }

    // KWin's rekta-fadeback, which holds the bottom edge of the primary screen for a finger that swipes the Start open,
    // and three fingers swiping up or down on the touchpad; outside the rekta session nothing answers.
    DBusConnection {
        id: kwin
    }

    DBus.SignalWatcher {
        service: "org.kde.KWin"
        path: "/RektaFadeBack"
        iface: "org.rekta.FadeBack"

        function dbusfingerMoved(distance: real) {
            place.followFinger(distance);
        }

        function dbusfingerLetGo() {
            place.letFingerGo();
        }

        function dbustouchpadUp(progress: real) {
            place.followSwipe(progress);
        }

        function dbustouchpadUpLetGo() {
            place.letFingerGo();
        }

        function dbustouchpadDown(progress: real) {
            place.followSwipeOut(progress);
        }

        function dbustouchpadDownLetGo() {
            place.letFingerGoOut();
        }
    }

    Usage {
        id: usage
    }

    Apps {
        id: installed

        launcher: surface.launcher
        usage: usage
    }

    WebSearch {
        id: webSearch
    }

    // Meta opens and closes it; in Plasma's own session Meta stays with Kickoff, as there this shortcut is not present.
    GlobalShortcut {
        name: "start"
        text: "Open the Start"
        keys: [Qt.Key_Meta]
        onPressed: {
            if (!(surface.metaHold?.takesStartKey() ?? false))
                place.toggle();
        }
    }

    Connections {
        target: surface.contentItem.Window.window

        function onFrameSwapped() {
            surface.drawn = true;
            surface.askingAgain = false;
            if (surface.confirmingHandOver) {
                surface.confirmingHandOver = false;
                surface.contentItem.Window.window.update();
            }
        }
    }

    // Without windows the Start stands: once the splash has gone after login, and once the last window closes.
    // ponytail: windows that come back with the session after the splash has gone find the Start open; wait for
    // ksmserver's restore if that shows.
    function standWithoutWindows() {
        if (arrived && windows.all.length === 0)
            place.open();
    }

    onArrivedChanged: standWithoutWindows()

    Connections {
        target: surface.windows

        function onAllChanged() {
            surface.standWithoutWindows();
        }
    }

    IpcHandler {
        target: "start"

        function toggle() {
            place.toggle();
        }
    }

    StartFile {
        id: startFile
    }

    // A window's live preview, drawn by KWin into a PipeWire stream while it has its window (StartPlace hands it over
    // only while the Start shows).
    component WindowPreview: Item {
        id: preview

        property var window
        // KWin's PipeWire node for this window, 0 until it streams.
        readonly property int node: request.nodeId
        // The size of the window's picture, 0 × 0 until its first frame; the tile crops it to fill.
        readonly property size pictureSize: stream.streamSize

        TaskManager.ScreencastingRequest {
            id: request

            // KWin finds a window to stream only once it has mapped it; an earlier request fails for good.
            uuid: preview.window?.mapped ? preview.window.uuid : ""
        }

        // Visible before its first frame: kpipewire streams only into a visible item, and until a frame comes it draws
        // nothing, so the tile's surface shows.
        PipeWire.PipeWireSourceItem {
            id: stream

            anchors.fill: parent
            nodeId: request.nodeId
        }
    }
}
