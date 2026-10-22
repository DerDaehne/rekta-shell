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

    PrimaryScreen {
        id: primary
    }

    Notifications {
        id: notifications

        toaster: toasts.toaster
        windows: running
        launcher: appLauncher
        quiet: (running.active?.fullScreen && running.active.isOn(primary.screen)) ?? false
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
        }
    }

    StartSurface {
        windows: running
        launcher: appLauncher
        primaryScreen: primary.screen
    }

    // After the Start, so a toast stands above it.
    Toasts {
        id: toasts

        screen: primary.screen
    }
}
