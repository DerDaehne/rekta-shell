pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import org.kde.taskmanager as TaskManager

// The running windows, one model for every surface that shows them: libtaskmanager's TasksModel over KWin's window
// management, every window on its own row, sorted by when the shell saw each activated: after the shell starts only the
// active window has that time.
Scope {
    id: windows

    // The window that has the keyboard, or null.
    readonly property Entry active: {
        for (let i = 0; i < entries.count; i++) {
            const entry = entries.objectAt(i) as Entry;
            if (entry?.active)
                return entry;
        }
        return null;
    }
    // Every window, without the launch notices the model lists beside them.
    readonly property list<Entry> all: {
        const found = [];
        for (let i = 0; i < entries.count; i++) {
            const entry = entries.objectAt(i) as Entry;
            if (entry?.isWindow)
                found.push(entry);
        }
        return found;
    }

    // One window as the surfaces need it.
    component Entry: QtObject {
        required property var model
        required property int index
        required property TaskManager.TasksModel tasks
        readonly property bool isWindow: model.IsWindow === true
        readonly property bool active: model.IsActive === true
        readonly property string app: model.AppName || model.AppId || ""
        // The ID of its app's desktop entry, as "org.kde.konsole".
        readonly property string appId: model.AppId ?? ""
        readonly property string title: model.display ?? ""
        readonly property bool fullScreen: model.IsFullScreen === true
        // The geometry of the screen the window is on.
        readonly property rect screen: model.ScreenGeometry ?? Qt.rect(0, 0, 0, 0)
        // When the shell saw it activated, in ms since the epoch; 0 when it has not.
        readonly property real lastActivated: model.LastActivated?.getTime() || 0
        readonly property int stackingOrder: model.StackingOrder ?? 0
        // The window's UUID, which its live preview asks for.
        readonly property string uuid: model.WinIdList?.[0] ?? ""
        // An image URL for its app's icon from the app's desktop entry, empty without one.
        readonly property string icon: {
            const entry = DesktopEntries.heuristicLookup(model.AppId ?? "");
            return entry ? Quickshell.iconPath(entry.icon, true) : "";
        }

        function isOn(shellScreen: ShellScreen): bool {
            return shellScreen !== null && screen.x === shellScreen.x && screen.y === shellScreen.y;
        }

        // Brings it to the front, on its virtual desktop, out of minimised.
        function activate() {
            tasks.requestActivate(tasks.makeModelIndex(index));
        }
    }

    TaskManager.TasksModel {
        id: tasksModel

        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortLastActivated
    }

    Instantiator {
        id: entries

        model: tasksModel

        delegate: Entry {
            tasks: tasksModel
        }
    }
}
