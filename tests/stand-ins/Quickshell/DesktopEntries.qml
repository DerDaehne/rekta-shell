pragma Singleton

import QtQml

// Quickshell's desktop entries, as far as the shell looks one up: the entries the tests know, found by their id or by
// the name of their program.
QtObject {
    readonly property var idsByName: ({
            "elisa": "org.kde.elisa",
            "Elisa": "org.kde.elisa"
        })

    function heuristicLookup(name: string): var {
        const id = idsByName[name];
        return id ? { id } : null;
    }
}
