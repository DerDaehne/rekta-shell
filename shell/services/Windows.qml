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

    // One window as the surfaces need it.
    component Entry: QtObject {
        required property var model
        readonly property bool active: model.IsActive === true
        readonly property string app: model.AppName || model.AppId || ""
        readonly property string title: model.display ?? ""
        readonly property bool fullScreen: model.IsFullScreen === true
        // The geometry of the screen the window is on.
        readonly property rect screen: model.ScreenGeometry ?? Qt.rect(0, 0, 0, 0)

        function isOn(shellScreen: ShellScreen): bool {
            return screen.x === shellScreen.x && screen.y === shellScreen.y;
        }
    }

    TaskManager.TasksModel {
        id: tasks

        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortLastActivated
    }

    Instantiator {
        id: entries

        model: tasks

        delegate: Entry {}
    }
}
