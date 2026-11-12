import QtQml
import Settings

// start.json on a text, written as StartFile writes the file: each change builds on the text and replaces it whole.
// `wrote` tells a second stand-in that shares the file, as two processes share one.
QtObject {
    property string text
    property bool settled: true
    readonly property var current: Pins.read(text)
    readonly property var list: current.list
    readonly property string fault: current.fault

    signal wrote(string next)

    function write(next: var): bool {
        if (!settled || next === null)
            return false;
        text = next;
        wrote(next);
        return true;
    }

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

    function entry(index: int): var {
        return Pins.entry(current.content, index);
    }
}
