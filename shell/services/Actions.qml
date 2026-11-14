import QtQuick

// The action registry: what the shell offers other programs to run (ActionsInterface). First the shell's own commands as
// Commands.list has them, then the desktop actions of the apps the Start lists, which also name their app: `app` (its
// desktop file ID), `appName` and `icon` (as the desktop file names it). Their ids are desktop/<desktop file ID>/<action
// id>; the shell's own have no "/".
QtObject {
    required property var commands
    // As Apps.list has them; null until the apps have been read.
    property var apps: null

    // Qt's JavaScript has no flatMap.
    readonly property var list: [].concat(commands, ...(apps ?? []).map(app => app.actions))
}
