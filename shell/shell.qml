pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Settings
import "services"

ShellRoot {
    SystemMotion {}
    SplashEnd {}

    // Read only: the shell never opens the write gate.
    SettingsFiles {
        id: settingsFiles
    }

    Windows {
        id: running
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

    PrimaryScreen {
        id: primary
    }

    Notifications {
        id: notifications

        toaster: toasts.toaster
        windows: running
        launcher: appLauncher
        // A full-screen window on the primary screen, or "nicht stören": only critical ones toast.
        quiet: ((running.active?.fullScreen && running.active.isOn(primary.screen)) ?? false) || sidePanel.doNotDisturb
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
            notices: notifications.board
            tray: backgroundApps
            readout: keys.readout
            primaryScreen: primary.screen
            controlPanel: sidePanel
        }
    }

    StartSurface {
        id: start

        windows: running
        launcher: appLauncher
        primaryScreen: primary.screen
    }

    ControlPanel {
        id: sidePanel

        launcher: appLauncher
        primaryScreen: primary.screen
        startInFront: start.inFront
        sink: keys.sink
        source: keys.source
        notices: notifications.board

        // Under the session banner the Start waits: asked now, KWin would raise the Start over the banner.
        onPanelClosed: {
            if (!session.visible)
                start.takeKeyboardBack();
        }
        onSessionAsked: session.show("")
    }

    SessionSurface {
        id: session

        launcher: appLauncher
        primaryScreen: primary.screen
        toaster: toasts.toaster

        // While the session is left, the surface leaving holds the keyboard; the Start asks again once that one goes.
        onGone: {
            if (!session.leaving)
                start.takeKeyboardBack();
        }
        onLaunched: start.stepAside()
    }

    LeaveSurface {
        primaryScreen: primary.screen
        leaving: session.leaving
        holdsKeyboard: session.windowsBack

        onVisibleChanged: {
            if (!visible)
                start.takeKeyboardBack();
        }
    }

    // The Start is a whole place: a panel open as it opens slides out instead of lying blurred under its glass.
    Connections {
        target: start

        function onOpenedChanged() {
            if (start.opened)
                sidePanel.close();
        }
    }

    // Ctrl+Alt+Del, and KDE's own prompts to log out, restart or shut down. The banner takes the side panel's place, as
    // from "sitzung …": KWin hands the keyboard on to a window or the Start once the banner goes, never to the panel.
    LogoutPrompt {
        sessionDesktop: Quickshell.env("XDG_SESSION_DESKTOP") ?? ""

        onRequested: kind => {
            sidePanel.close();
            session.show(kind);
        }
    }

    // After the Start, so a toast stands above it.
    Toasts {
        id: toasts

        primaryScreen: primary.screen
    }
}
