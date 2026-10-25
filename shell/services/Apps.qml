import QtQuick
import Quickshell
import Quickshell.Io
import Start

// The installed apps this desktop shows, A–Z, one list for every place that lists or searches them: Quickshell's
// desktop entries, less those whose OnlyShowIn or NotShowIn keeps them from XDG_CURRENT_DESKTOP. Quickshell gives
// neither key to QML, so grep reads them from the same files whenever the entries change.
Scope {
    id: apps

    required property Launcher launcher
    // {id, name, genericName, keywords, exec, icon, launch()}; null until the files have been read once.
    property var list: null
    readonly property var dirs: Rules.applicationDirs(Quickshell.env("XDG_DATA_HOME"), Quickshell.env("HOME"), Quickshell.env("XDG_DATA_DIRS"))

    function read(files: var) {
        const entries = Rules.listedApps(Array.from(DesktopEntries.applications.values), files, Quickshell.env("XDG_CURRENT_DESKTOP"));
        list = entries.map(entry => ({
                    id: entry.id,
                    name: entry.name,
                    genericName: entry.genericName,
                    keywords: Array.from(entry.keywords),
                    exec: Rules.programName(entry.command),
                    icon: Quickshell.iconPath(entry.icon, true),
                    launch: () => apps.launcher.launch(entry)
                }));
    }

    Process {
        id: reader

        // -R follows symlinks, as NixOS links its entries into the profiles.
        command: ["grep", "-R", "-s", "--null", "--include=*.desktop", "-E", "^(Type|OnlyShowIn|NotShowIn) *=", ...apps.dirs]
        running: true
        stdout: StdioCollector {
            onStreamFinished: apps.read(Rules.showIn(text, apps.dirs))
        }
        // Without grep every entry counts as shown.
        onRunningChanged: {
            if (!running && apps.list === null)
                apps.read({});
        }
    }

    // Setting it while grep runs reads once more after it.
    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            reader.running = true;
        }
    }
}
