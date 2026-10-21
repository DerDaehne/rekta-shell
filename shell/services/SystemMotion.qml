import QtQuick
import Quickshell
import Quickshell.Io
import Rekta

// Follows KDE's animation speed: a factor of 0 ("instant") means the user asked for no motion.
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
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/kdeglobals`
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: systemMotion.follow(systemMotion.animationFactor(text()) === 0)
        onLoadFailed: systemMotion.follow(false)
    }
}
