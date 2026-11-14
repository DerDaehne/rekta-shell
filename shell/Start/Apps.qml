import QtQuick
import Quickshell
import Quickshell.Io

// The installed apps this desktop shows, A–Z, one list for every place that lists or searches them: Quickshell's
// desktop entries, less those whose OnlyShowIn or NotShowIn keeps them from XDG_CURRENT_DESKTOP. Quickshell gives
// neither key to QML, nor DBusActivatable, so grep reads them from the same files whenever the entries change. The
// shell hands it its Launcher and Usage to start apps with; the settings app only lists them and hands neither.
Scope {
    id: apps

    property var launcher: null
    property var usage: null
    // {id, name, genericName, keywords, exec, icon, launch(), actions}; null until the files have been read once. `actions`
    // are the app's desktop actions as the action registry lists them (Rules.desktopActions).
    property var list: null
    // The System Settings pages, shaped alike; they have no place in `list`, their entries carry NoDisplay.
    property var settings: []
    readonly property var dirs: Rules.applicationDirs(Quickshell.env("XDG_DATA_HOME"), Quickshell.env("HOME"), Quickshell.env("XDG_DATA_DIRS"))

    // `file` is what Rules.desktopFileKeys() read of the entry.
    function describe(entry: DesktopEntry, exec: string, file: var): var {
        return {
            id: entry.id,
            name: entry.name,
            genericName: entry.genericName,
            keywords: Array.from(entry.keywords),
            exec: exec,
            icon: Quickshell.iconPath(entry.icon, true),
            actions: Rules.desktopActions(entry, Rules.dbusActivatable(entry.id, file), apps.launcher),
            launch: () => {
                apps.launcher.launch(entry);
                apps.usage.count(entry.id);
            }
        };
    }

    // `files` holds every desktop file the grep read, hidden ones too: the pages are looked up by their IDs.
    function read(files: var) {
        const desktop = Quickshell.env("XDG_CURRENT_DESKTOP");
        const entries = Rules.listedApps(Array.from(DesktopEntries.applications.values), files, desktop);
        list = entries.map(entry => describe(entry, Rules.programName(entry.command), files[entry.id]));
        const pages = Object.keys(files).filter(Rules.isSettingsPage).map(id => DesktopEntries.byId(id)).filter(entry => entry !== null);
        settings = Rules.listedApps(pages, files, desktop).map(entry => describe(entry, "", files[entry.id]));
    }

    Process {
        id: reader

        // -R follows symlinks, as NixOS links its entries into the profiles.
        command: ["grep", "-R", "-s", "--null", "--include=*.desktop", "-E", "^(Type|OnlyShowIn|NotShowIn|DBusActivatable) *=", ...apps.dirs]
        running: true
        stdout: StdioCollector {
            onStreamFinished: apps.read(Rules.desktopFileKeys(text, apps.dirs))
        }
        // A grep that ran has ended its stream before this (Quickshell's Process::onFinished), so only a grep that
        // never started gets here with no list: then every entry counts as shown.
        onRunningChanged: {
            if (!running && apps.list === null)
                apps.read({});
        }
    }

    // Set while grep runs, it runs once more as that run ends: Quickshell's Process::onFinished starts it again when it
    // was asked to run meanwhile, so a change during a run is read too.
    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            reader.running = true;
        }
    }
}
