pragma ComponentBehavior: Bound

import Quickshell
import "services"

ShellRoot {
    SystemMotion {}
    SplashEnd {}

    Windows {
        id: running
    }

    Launcher {
        id: appLauncher
    }

    PrimaryScreen {
        id: primary
    }

    Variants {
        model: Quickshell.screens

        Ground {}
    }

    Variants {
        model: Quickshell.screens

        Bar {
            windows: running
        }
    }

    StartSurface {
        windows: running
        launcher: appLauncher
        primaryScreen: primary.screen
    }
}
