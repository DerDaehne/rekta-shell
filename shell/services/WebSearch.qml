import QtQuick
import Quickshell
import Quickshell.Io
import Settings
import Start

// Where KDE searches the web for typed text that is no address, as KRunner does: the search address of the default web
// shortcut (System Settings, Web Search Keywords), read from kuriikwsfilterrc and the provider's file among KIO's search
// providers, the user's own first.
// ponytail: only the user's kuriikwsfilterrc is read; a default a distribution puts in XDG_CONFIG_DIRS goes unseen.
Scope {
    id: webSearch

    // The provider's search address with \{@} for the text; "" without one.
    property string query: ""
    // The default provider's name, the name of its file; "" for none.
    property string provider: ""
    readonly property var files: provider === "" ? [] : Rules.dataDirs(Quickshell.env("XDG_DATA_HOME"), Quickshell.env("HOME"), Quickshell.env("XDG_DATA_DIRS")).map(dir => `${dir}/kf6/searchproviders/${provider}.desktop`)

    // The command is set here, not bound: a binding on `files` may lag behind this handler, and grep would then read the
    // provider files of the default before.
    onFilesChanged: {
        query = "";
        reader.command = ["grep", "-s", "-H", "--null", "-E", "^Query(\\[[^]]*\\])? *=", ...files];
        reader.running = files.length > 0;
    }

    UserFile {
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/kuriikwsfilterrc`
        onLoaded: webSearch.provider = Rules.defaultWebShortcut(text())
        onLoadFailed: webSearch.provider = Rules.defaultWebShortcut("")
    }

    Process {
        id: reader

        stdout: StdioCollector {
            onStreamFinished: webSearch.query = Rules.providerQuery(text, webSearch.files, Qt.locale().name)
        }
    }
}
