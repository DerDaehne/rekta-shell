pragma Singleton

import QtQml

// Quickshell's desktop entries, as far as the shell looks one up: the entries the tests know, found by their id or by
// the name of their program, and those a test installs, the shown ones in `applications` and the hidden ones, which only
// byId() finds.
QtObject {
    readonly property var idsByName: ({
            "elisa": "org.kde.elisa",
            "Elisa": "org.kde.elisa"
        })
    property var applications: ({
            values: []
        })
    property var hidden: []

    function heuristicLookup(name: string): var {
        // As Quickshell 0.3: the empty name matches an arbitrary entry.
        if (name === "")
            return { id: "org.quickshell", name: "Quickshell" };
        const id = idsByName[name];
        return id ? { id } : null;
    }

    function byId(id: string): var {
        return [...applications.values, ...hidden].find(entry => entry.id === id) ?? null;
    }
}
