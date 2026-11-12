import QtQml
import Quickshell.Io

// A file of the user's that may appear after the shell started, read again whenever it changes.
FileView {
    id: file

    // The file's watch, armed anew before every read. A FileView watching itself re-arms only after its read has
    // started, and drops a reload while a read still runs: a change landing in either gap would never show.
    property FileView watch: FileView {
        path: file.path
        preload: false
        watchChanges: true
        printErrors: false
        onFileChanged: file.follow()
    }

    // FileView watches a file's directory only if it exists when the watch starts. Until the file is there, this one
    // watches the directory's parent and starts the file's watch anew once the directory appears.
    // ponytail: only the directory's parent is watched; a missing grandparent (no ~/.config at all) stays unseen.
    property FileView directoryWatch: FileView {
        path: file.loaded ? "" : file.path.replace(/\/[^/]*$/, "")
        preload: false
        watchChanges: true
        printErrors: false
        onFileChanged: file.follow()
    }

    // Reads the file as it is now: every change after this call reaches the watch.
    function follow() {
        watch.reload();
        waitForJob();
        reload();
    }

    printErrors: false
}
