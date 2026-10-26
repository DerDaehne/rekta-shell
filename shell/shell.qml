pragma ComponentBehavior: Bound

import Quickshell
import "services"

ShellRoot {
    SystemMotion {}
    SplashEnd {}

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
        model: Quickshell.screens

        Ground {}
    }

    Variants {
        model: Quickshell.screens

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
        onClosed: {
            if (!session.visible)
                start.takeKeyboardBack();
        }
        onSessionAsked: session.show("")
    }

    SessionSurface {
        id: session

        launcher: appLauncher
        primaryScreen: primary.screen

        onGone: start.takeKeyboardBack()
    }

    // After the Start, so a toast stands above it.
    Toasts {
        id: toasts

        screen: primary.screen
    }
}
