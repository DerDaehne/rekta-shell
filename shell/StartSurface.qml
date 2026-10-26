pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager
import Start
import "services"

// The Start's surface: full screen on the primary screen, above the windows and the app bar. Without windows the Start
// stands.
PanelWindow {
    id: surface

    required property Windows windows
    required property Launcher launcher
    required property ShellScreen primaryScreen
    // From its opening to its hand-over, when the glass starts to go: in front of everything on the primary screen.
    readonly property alias inFront: place.holdsKeyboard
    // From the moment it opens until it starts to close.
    readonly property alias opened: place.wanted
    // The list in start.json, null without a usable one.
    property var listedPins: null
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
                name: entry.name,
                icon: Quickshell.iconPath(entry.icon, true),
                columns: tile.columns,
                rows: tile.rows,
                launch: () => surface.launcher.launch(entry)
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
    // hidden, it lets every input through. Under a full-screen window it goes, so that window has the screen to itself.
    visible: place.shown || !(windows.active?.fullScreen && windows.active.isOn(primaryScreen))
    mask: Region {
        item: place.shown ? place : null
    }
    WlrLayershell.namespace: "rekta-start"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: place.holdsKeyboard && !askingAgain ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // A deliberate deviation, as for the app bar: KWin blurs at the strength of its blur effect, not glass's blur(12px).
    BackgroundEffect.blurRegion: Region {
        item: place.shown ? place : null
    }

    StartPlace {
        id: place

        anchors.fill: parent
        windows: Array.from(surface.windows.all)
        pinned: surface.pinnedApps(Array.from(DesktopEntries.applications.values), surface.listedPins)
        apps: installed.list
        preview: Component {
            WindowPreview {}
        }
        onHoldsKeyboardChanged: {
            if (!place.holdsKeyboard && place.shown)
                surface.confirmingHandOver = true;
        }
    }

    Apps {
        id: installed

        launcher: surface.launcher
    }

    // Meta opens and closes it; in Plasma's own session Meta stays with Kickoff, as there this shortcut is not present.
    GlobalShortcut {
        name: "start"
        text: "Open the Start"
        keys: [Qt.Key_Meta]
        onPressed: place.toggle()
    }

    Connections {
        target: surface.contentItem.Window.window

        function onFrameSwapped() {
            surface.askingAgain = false;
            if (surface.confirmingHandOver) {
                surface.confirmingHandOver = false;
                surface.contentItem.Window.window.update();
            }
        }
    }

    // Without windows the Start stands: after login and once the last window closes.
    Connections {
        target: surface.windows

        function onAllChanged() {
            if (surface.windows.all.length === 0)
                place.open();
        }
    }

    // ponytail: the window list fills a moment after the shell starts, so a shell restarted over open windows opens the
    // Start too; check once the list has its first answer, if that bothers.
    Component.onCompleted: {
        if (windows.all.length === 0)
            place.open();
    }

    IpcHandler {
        target: "start"

        function toggle() {
            place.toggle();
        }
    }

    FileView {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/rekta-shell/start.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: surface.listedPins = Rules.listedPins(text())
        onLoadFailed: surface.listedPins = null
    }

    // A window's live preview, drawn by KWin into a PipeWire stream while the Start shows it.
    component WindowPreview: Item {
        id: preview

        property var window

        TaskManager.ScreencastingRequest {
            id: request

            uuid: preview.window?.uuid ?? ""
        }

        PipeWire.PipeWireSourceItem {
            anchors.fill: parent
            nodeId: request.nodeId
            visible: ready
        }
    }
}
