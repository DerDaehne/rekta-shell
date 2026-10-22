pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Tray

// The apps in the background, from the StatusNotifierItems of the session's own bus: those that are not passive, in
// Quickshell's order (category, id). In the rekta session kded6 owns the watcher and the shell only joins as its host,
// so the items survive a restart of the shell.
Scope {
    id: tray

    readonly property list<App> apps: {
        const found = [];
        for (let i = 0; i < entries.count; i++) {
            const app = entries.objectAt(i) as App;
            if (app?.listed)
                found.push(app);
        }
        return found;
    }

    // One item as the menu needs it.
    component App: QtObject {
        required property SystemTrayItem modelData
        readonly property bool listed: TrayRules.listed(modelData.status)
        readonly property string word: TrayRules.word(modelData.title, modelData.id)
        readonly property string icon: modelData.icon
        readonly property string state: TrayRules.state(modelData.status, modelData.tooltipTitle, modelData.tooltipDescription)
        readonly property bool hasMenu: modelData.hasMenu
        readonly property bool onlyMenu: modelData.onlyMenu
        readonly property var menu: modelData.menu

        // Brings the app forward, over the session's own bus.
        function activate() {
            modelData.activate();
        }
    }

    Instantiator {
        id: entries

        model: SystemTray.items

        delegate: App {}
    }
}
