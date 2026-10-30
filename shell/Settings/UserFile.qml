import QtQml
import Quickshell.Io

// A file of the user's that may appear after the shell started, read again whenever it changes.
FileView {
    id: file

    // FileView watches a file's directory only if it exists when the watch starts. Until the file is there, this one
    // watches the directory's parent and starts the file's watch anew once the directory appears.
    // ponytail: only the directory's parent is watched; a missing grandparent (no ~/.config at all) stays unseen.
    property FileView directoryWatch: FileView {
        path: file.loaded ? "" : file.path.replace(/\/[^/]*$/, "")
        preload: false
        watchChanges: true
        printErrors: false
        onFileChanged: file.reload()
    }

    watchChanges: true
    printErrors: false
    onFileChanged: reload()
}
