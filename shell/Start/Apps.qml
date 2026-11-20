import QtQuick
import Quickshell
import Quickshell.Io

// The installed apps this desktop shows, A–Z, one list for every place that lists or searches them: Quickshell's
// desktop entries, less those whose OnlyShowIn or NotShowIn keeps them from XDG_CURRENT_DESKTOP. Quickshell gives
// neither key to QML, nor DBusActivatable or Implements, so grep reads them from the same files whenever the entries change. The
// shell hands it its Launcher and Usage to start apps with; the settings app only lists them and hands neither.
Scope {
    id: apps

    property var launcher: null
    property var usage: null
    // {id, name, genericName, keywords, exec, icon, iconName, implements, launch(), actions}; null until the files have been
    // read once. `iconName` is the icon as the file names it, `implements` the D-Bus interfaces its Implements key lists, `actions`
    // are the app's desktop actions as the action registry lists them (Rules.desktopActions).
    property var list: null
    // The System Settings pages, shaped alike; they have no place in `list`, their entries carry NoDisplay.
    property var settings: []
    readonly property var dirs: Rules.applicationDirs(Quickshell.env("XDG_DATA_HOME"), Quickshell.env("HOME"), Quickshell.env("XDG_DATA_DIRS"))
    // What the last read made of each app and each page, by desktop file ID (Rules.reread).
    property var appRecords: new Map()
    property var pageRecords: new Map()
    // The icon path of each name looked up, by name; empty where no theme has the icon.
    property var iconPaths: new Map()

    // `file` is what Rules.desktopFileKeys() read of the entry; `paths` gathers the icons this read looked up.
    function describe(entry: DesktopEntry, exec: string, file: var, paths: var): var {
        return {
            id: entry.id,
            name: entry.name,
            genericName: entry.genericName,
            keywords: Array.from(entry.keywords),
            exec: exec,
            icon: iconPath(entry.icon, paths),
            iconName: entry.icon,
            implements: file?.Implements ?? [],
            actions: Rules.desktopActions(entry, Rules.busName(file), apps.launcher),
            launch: () => {
                apps.launcher.launch(entry);
                apps.usage.count(entry.id);
            }
        };
    }

    // Quickshell looks an icon up in the theme on the GUI thread, so a name looked up once is not looked up again while an
    // entry names it, found or not: a missing name walks every directory of every theme, some 20 ms, once Qt's cache of
    // 100 icons has let it go, as one search in the Start with many hits already does.
    // ponytail: an icon a theme gains while its app stays listed shows once the app is listed anew or the shell
    // restarts; look missing names up again when the apps change, should that show.
    function iconPath(name: string, paths: var): string {
        const path = iconPaths.get(name) ?? Quickshell.iconPath(name, true);
        paths.set(name, path);
        return path;
    }

    // The entries as describe() makes them, each keeping what the last read made of it when it reads the same:
    // {items, records}, `records` this read's by desktop file ID.
    function describeAll(entries: var, files: var, execOf: var, records: var, paths: var): var {
        const next = new Map();
        for (const entry of entries)
            next.set(entry.id, Rules.reread(records.get(entry.id), describe(entry, execOf(entry), files[entry.id], paths)));
        return {
            items: Array.from(next.values(), record => record.item),
            records: next
        };
    }

    // `files` holds every desktop file the grep read, hidden ones too: the pages are looked up by their IDs. Quickshell
    // rescans on a change in the entries' directories or any of their parents and reports each scan, changed or not, so
    // the lists change only when what they hold does.
    function read(files: var) {
        const desktop = Quickshell.env("XDG_CURRENT_DESKTOP");
        const paths = new Map();
        const entries = Rules.listedApps(Array.from(DesktopEntries.applications.values), files, desktop);
        const listed = describeAll(entries, files, entry => Rules.programName(entry.command), appRecords, paths);
        const pages = Object.keys(files).filter(Rules.isSettingsPage).map(id => DesktopEntries.byId(id)).filter(entry => entry !== null);
        const shown = describeAll(Rules.listedApps(pages, files, desktop), files, () => "", pageRecords, paths);
        appRecords = listed.records;
        pageRecords = shown.records;
        iconPaths = paths;
        if (!Rules.sameItems(listed.items, list))
            list = listed.items;
        if (!Rules.sameItems(shown.items, settings))
            settings = shown.items;
    }

    Process {
        id: reader

        // -R follows symlinks, as NixOS links its entries into the profiles.
        command: ["grep", "-R", "-s", "--null", "--include=*.desktop", "-E", "^(Type|OnlyShowIn|NotShowIn|DBusActivatable|Implements) *=", ...apps.dirs]
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
