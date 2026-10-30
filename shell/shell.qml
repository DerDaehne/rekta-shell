pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Rekta
import Settings
import "services"

ShellRoot {
    SystemMotion {}
    SplashEnd {}

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

    Binding {
        target: Prefs
        property: "startPace"
        value: settingsFiles.value("startTempo")
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
    }

    PrimaryScreen {
        id: primary
    }

    Commands {
        id: shellCommands

        launcher: appLauncher
        panel: sidePanel
        session: sessionBanner
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
        commands: shellCommands.list
        windows: running
        launcher: appLauncher
        notices: notifications.board
        primaryScreen: primary.screen
    }

    ControlPanel {
        id: sidePanel

        settings: settingsFiles
        launcher: appLauncher
        primaryScreen: primary.screen
        startInFront: start.inFront
        sink: keys.sink
        source: keys.source
        brightness: keys.brightness
        notices: notifications.board
        networkManagerRunning: systemState.networkManagerRunning

        // Under the session banner the Start waits: asked now, KWin would raise the Start over the banner.
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

    // After the Start, so a toast stands above it.
    Toasts {
        id: toasts

        primaryScreen: primary.screen
    }
}
