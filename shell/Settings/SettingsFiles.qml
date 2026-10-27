import QtQml
import Quickshell
import Quickshell.Io

// The settings from their files, followed live: the Nix defaults the package's wrapper names in REKTA_DEFAULTS (none
// when run from a checkout) and the user's settings.json, written only once the gate is open.
Layers {
    id: files

    readonly property string userDirectory: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/rekta-shell`

    // Both files load before the first frame, so the shell starts as it is set.
    property FileView defaultsFile: FileView {
        path: Quickshell.env("REKTA_DEFAULTS") ?? ""
        blockLoading: true
        printErrors: false
    }
    property FileView userFile: FileView {
        path: `${files.userDirectory}/settings.json`
        blockLoading: true
        // Each write lands before the next set() reads the file, so quick changes build on each other.
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    // FileView watches a file's directory only if it exists when the watch starts. Until the file is there, this one
    // watches the directory's parent and starts the file's watch anew once the directory appears.
    property FileView directoryWatch: FileView {
        path: files.userFile.loaded ? "" : files.userDirectory
        preload: false
        watchChanges: true
        printErrors: false
        onFileChanged: files.userFile.reload()
    }

    defaultsText: defaultsFile.text()
    userText: userFile.text()
    onWriteRequested: text => userFile.setText(text)
}
