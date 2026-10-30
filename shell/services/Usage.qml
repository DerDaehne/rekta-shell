import QtQuick
import Quickshell
import Quickshell.Io
import Settings
import Start

// How often each app was started from the Start, by desktop file ID, kept in the state directory so it outlives the
// shell. Only the shell's own starts count.
// ponytail: starts from elsewhere (a file manager, a terminal) are not seen; the activity manager would see them.
Scope {
    id: usage

    // Starts by app ID.
    readonly property var starts: Rules.parseStarts(file.text())

    function count(appId: string) {
        file.setText(JSON.stringify(Rules.counted(starts, appId)));
    }

    // Blocking, so the counts are there before the first search; blocking writes, so a start right after another
    // counts on top of it. The directory comes with the first write.
    UserFile {
        id: file

        path: `${Rules.stateDir(Quickshell.env("XDG_STATE_HOME"), Quickshell.env("HOME"))}/usage.json`
        blockLoading: true
        blockWrites: true
        atomicWrites: true
    }
}
