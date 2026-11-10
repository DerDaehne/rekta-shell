import QtQuick
import Quickshell
import Quickshell.Io
import Rekta
import RektaShell.DBus

// Follows KDE's animation speed: a factor of 0 ("instant") means the user asked for no motion. Like KWin, which steps
// the windows back, it reads kdeglobals as it starts and again when KDE announces a change there, never on a mere change
// of the file: a factor KWin has not taken would split reduced motion between the shell and the windows.
Scope {
    id: systemMotion

    // The value of [KDE] AnimationDurationFactor in a kdeglobals text, also with KConfig flags such as [$i]; KDE's
    // default is 1.
    function animationFactor(ini: string): real {
        let inKdeGroup = false;
        for (const rawLine of ini.split("\n")) {
            const line = rawLine.trim();
            if (line.startsWith("["))
                inKdeGroup = line === "[KDE]";
            else if (inKdeGroup && /^AnimationDurationFactor(\[[^\]]*\])*=/.test(line))
                return Number(line.slice(line.indexOf("=") + 1));
        }
        return 1;
    }

    function follow(reduced: bool) {
        if (Prefs.systemReducedMotion !== reduced)
            console.info(`Reduced motion from KDE's animation speed: ${reduced}`);
        Prefs.systemReducedMotion = reduced;
    }

    FileView {
        id: kdeglobals

        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/kdeglobals`
        printErrors: false

        onLoaded: systemMotion.follow(systemMotion.animationFactor(text()) === 0)
        onLoadFailed: systemMotion.follow(false)
    }

    DBusConnection {
        id: kconfig

        onReceived: kdeglobals.reload()
        Component.onCompleted: kconfig.listen("org.kde.kconfig.notify", "ConfigChanged", "", "/kdeglobals")
    }
}
