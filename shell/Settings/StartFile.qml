import QtQml
import Quickshell
import "Pins.js" as Pins

// The user's start.json, followed live and written by the shell and the settings app alike: each change builds on the
// file as last read and writes it whole, so whoever writes last wins. A broken file is never written over.
UserFile {
    id: file

    // False until the file first loads or fails to load: a change written before would build on nothing.
    property bool settled: false
    readonly property var current: Pins.read(text())
    // The file's list, null without one (the defaults show).
    readonly property var list: current.list
    // "broken" when the file cannot be read as start.json, else "".
    readonly property string fault: current.fault

    // Each change returns whether it was written.
    function pin(id: string): bool {
        return write(Pins.pin(current.content, id));
    }

    function unpin(index: int): bool {
        return write(Pins.unpin(current.content, index));
    }

    function resize(index: int, columns: int, rows: int): bool {
        return write(Pins.resize(current.content, index, columns, rows));
    }

    function move(from: int, to: int): bool {
        return write(Pins.move(current.content, from, to));
    }

    function insert(index: int, entry: var): bool {
        return write(Pins.insert(current.content, index, entry));
    }

    function replace(index: int, entry: var): bool {
        return write(Pins.replace(current.content, index, entry));
    }

    // A copy of the entry at `index`, to put back as it was; null for none.
    function entry(index: int): var {
        return Pins.entry(current.content, index);
    }

    function write(next: var): bool {
        if (!settled || next === null)
            return false;
        setText(next);
        return true;
    }

    function reportFault() {
        if (fault === "broken")
            console.warn("rekta-shell: start.json holds no JSON object with a list of pinned apps; the defaults show and nothing writes over it");
    }

    path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/rekta-shell/start.json`
    // Each write lands before the next change reads the file, so quick changes build on each other.
    blockWrites: true
    atomicWrites: true
    onLoaded: settled = true
    onLoadFailed: settled = true
    onFaultChanged: reportFault()
}
