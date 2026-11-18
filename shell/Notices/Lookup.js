.pragma library

// The desktop entry a notification belongs to, found by its desktop-entry hint, else by its app name. Quickshell's
// heuristicLookup("") matches an arbitrary entry, so a notification with neither is never looked up.
function entry(entries, desktopEntry, appName) {
    const name = desktopEntry || appName;
    return name ? entries.heuristicLookup(name) : null;
}

// What the app goes by: its app name, else its entry's name; empty when neither is known.
function sender(entries, desktopEntry, appName) {
    return appName || entry(entries, desktopEntry, "")?.name || "";
}
