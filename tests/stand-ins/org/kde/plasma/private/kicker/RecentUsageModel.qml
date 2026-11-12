import QtQuick

// Kickoff's model of the recently used, without kactivitymanagerd: the rows a test puts in, with the roles a file has
// there (display, decoration, description, url) and `modified`, the last use in seconds, which the real one keeps in its
// source model (PlasmaActivitiesStats' ResultModel, LastUpdateRole).
ListModel {
    id: model

    enum IncludeUsage {
        AppsAndDocs,
        OnlyApps,
        OnlyDocs,
        OnlyFolders
    }

    enum Ordering {
        Recent,
        Popular
    }

    property int ordering: RecentUsageModel.Recent
    property int shownItems: RecentUsageModel.AppsAndDocs
    readonly property QtObject sourceModel: QtObject {
        function index(row: int, column: int): int {
            return row;
        }

        function data(row: int, role: int): var {
            return role === Qt.UserRole + 4 ? model.get(row).modified : undefined;
        }
    }
}
