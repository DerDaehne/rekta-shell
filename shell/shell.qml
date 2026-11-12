pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Rekta
import Settings
import "services"

ShellRoot {
    SystemMotion {}

    // The splash fades onto the ground, the Start's surface ready over it; then the bar and the Start come in.
    SplashEnd {
        id: splash

        ready: Array.from(grounds.instances).every(ground => (ground as Ground).drawn) && (start.drawn || !start.visible)
    }

    // The side panel writes the density; every other setting is the app's alone, which the shell only follows.
    SettingsFiles {
        id: settingsFiles

        writableKeys: ["density"]
    }

    Binding {
        target: Prefs
        property: "density"
        value: settingsFiles.value("density")
    }

    Windows {
        id: running
    }

    Media {
        id: music
    }

    Tray {
        id: backgroundApps
    }

    Launcher {
        id: appLauncher
    }

    ReadoutSources {
        id: keys
    }

    SystemState {
        id: systemState

        sink: keys.sink
        doNotDisturb: sidePanel.doNotDisturb
        powerProfiles: sidePanel.hasPowerProfiles
        previewNodes: start.previewNodes
        storageFull: notifications.board.storageFull
        storageText: notifications.board.storageText
    }

    PrimaryScreen {
        id: primary
    }

    Commands {
        id: shellCommands

        launcher: appLauncher
        panel: sidePanel
        session: sessionBanner
        keyMap: shortcutList
        sink: keys.sink
    }

    Notifications {
        id: notifications

        toaster: toasts.toaster
        windows: running
        launcher: appLauncher
        // A full-screen window on the primary screen, or "nicht stören": only critical ones toast.
        quiet: running.fullScreenOn(primary.screen) || sidePanel.doNotDisturb
    }

    Variants {
        id: grounds

        model: primary.screens

        Ground {
            settings: settingsFiles
        }
    }

    Variants {
        model: primary.screens

        Bar {
            windows: running
            media: music
            notices: notifications.board
            tray: backgroundApps
            readout: keys.readout
            status: systemState.words
            primaryScreen: primary.screen
            controlPanel: sidePanel
            arrived: splash.arrived
            toastHost: toasts
            startOpen: start.opened
        }
    }

    ReadoutSurface {
        readout: keys.readout
        windows: running
        primaryScreen: primary.screen
    }

    StartSurface {
        id: start

        searchEscape: settingsFiles.value("searchEscape")
        showRecent: settingsFiles.value("showRecent")
        commands: shellCommands.list
        metaHold: shortcutList.hold
        windows: running
        launcher: appLauncher
        notices: notifications.board
        media: music
        primaryScreen: primary.screen
        topInset: systemBanner.zone
        arrived: splash.arrived
        toaster: toasts.toaster
    }

    ControlPanel {
        id: sidePanel

        settings: settingsFiles
        launcher: appLauncher
        primaryScreen: primary.screen
        sink: keys.sink
        source: keys.source
        brightness: keys.brightness
        notices: notifications.board
        media: music
        networkManagerRunning: systemState.networkManagerRunning

        // Under the session banner the Start waits: asked now, KWin would hand it the banner's keyboard.
        onPanelClosed: {
            if (!sessionBanner.visible)
                start.takeKeyboardBack();
        }
        onSessionAsked: sessionBanner.show("")
    }

    SessionSurface {
        id: sessionBanner

        launcher: appLauncher
        primaryScreen: primary.screen
        toaster: toasts.toaster

        // While the session is left, the surface leaving holds the keyboard; the Start asks again once that one goes.
        onGone: {
            if (!sessionBanner.leaving)
                start.takeKeyboardBack();
        }
        onLaunched: start.stepAside()
    }

    LeaveSurface {
        primaryScreen: primary.screen
        leaving: sessionBanner.leaving
        holdsKeyboard: sessionBanner.windowsBack

        onVisibleChanged: {
            if (!visible)
                start.takeKeyboardBack();
        }
    }

    // The Start is a whole place: a panel open as it opens slides out instead of lying blurred under its glass.
    Connections {
        target: start

        function onOpenedChanged() {
            if (!start.opened)
                return;
            shellCommands.readKeys();
            sidePanel.close();
        }
    }

    // Ctrl+Alt+Del, and KDE's own prompts to log out, restart or shut down. The banner takes the side panel's place, as
    // from "sitzung …": KWin hands the keyboard on to a window or the Start once the banner goes, never to the panel.
    LogoutPrompt {
        sessionDesktop: Quickshell.env("XDG_SESSION_DESKTOP") ?? ""

        onRequested: kind => {
            sidePanel.close();
            sessionBanner.show(kind);
        }
    }

    FreeSpace {
        watching: notifications.board.storageFull

        onChecked: enough => notifications.board.storageChecked(enough)
    }

    SystemBanner {
        id: systemBanner

        states: systemState.banners
        primaryScreen: primary.screen
        fullScreen: running.fullScreenOn(primary.screen)
        controlPanel: sidePanel
        toaster: toasts.toaster

        onCleanUp: notifications.board.cleanUp()
    }

    // `?` in the side panel: the panel goes, as for the session banner, and the key map takes the keyboard.
    KeyMapSurface {
        id: shortcutList

        launcher: appLauncher
        primaryScreen: primary.screen

        onAsked: {
            sidePanel.close();
            shortcutList.show();
        }
    }

    Toasts {
        id: toasts

        primaryScreen: primary.screen
    }
}
