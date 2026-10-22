pragma ComponentBehavior: Bound

import Quickshell
import "services"

ShellRoot {
    SystemMotion {}
    SplashEnd {}

    Windows {
        id: running
    }

    Variants {
        model: Quickshell.screens

        Bar {
            windows: running
        }
    }
}
