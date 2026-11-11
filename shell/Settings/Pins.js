.pragma library

// start.json as pure functions, for the shell and the settings app alike:
// {"pinned": [{"id": "org.kde.konsole", "columns": 1, "rows": 1}]}. Each change works on the file's whole list, also
// on the entries of apps that are not installed, keeps every key it does not change and returns the new file text, or
// null when it changes nothing.

// Plasma's own apps, pinned while the user has pinned nothing.
const defaultPinned = [{ id: "systemsettings" }, { id: "org.kde.dolphin" }, { id: "org.kde.konsole" }];

// The file's content, its list (null without one: the defaults show) and why it may not be written: "broken" when it
// holds no JSON object or a "pinned" that is no list, else "". An empty text is a file that does not exist.
function read(text) {
    if (text.trim() === "")
        return { content: {}, list: null, fault: "" };
    const content = parsed(text);
    if (content === null || !(content.pinned === undefined || Array.isArray(content.pinned)))
        return { content: null, list: null, fault: "broken" };
    return { content: content, list: content.pinned ?? null, fault: "" };
}

function parsed(text) {
    try {
        const content = JSON.parse(text);
        return isEntry(content) ? content : null;
    } catch (error) {
        return null;
    }
}

function isEntry(value) {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}

function bareId(id) {
    return String(id ?? "").replace(/\.desktop$/, "");
}

function holds(list, index) {
    return Number.isInteger(index) && index >= 0 && index < list.length;
}

// The text of `content` with its list changed by `change`, which edits a copy of the whole list (of the defaults while
// the file has none) and returns false when it changes nothing. Nothing is written over a broken file (content null).
function edited(content, change) {
    if (content === null)
        return null;
    const copy = JSON.parse(JSON.stringify(content));
    const list = Array.isArray(copy.pinned) ? copy.pinned : JSON.parse(JSON.stringify(defaultPinned));
    if (!change(list))
        return null;
    copy.pinned = list;
    return JSON.stringify(copy, null, 2) + "\n";
}

// Pins an app at the end, unless it is listed already.
function pin(content, id) {
    return edited(content, list => {
        if (bareId(id) === "" || list.some(entry => bareId(entry?.id) === bareId(id)))
            return false;
        list.push({ id: bareId(id), columns: 1, rows: 1 });
        return true;
    });
}

function unpin(content, index) {
    return edited(content, list => holds(list, index) && list.splice(index, 1).length === 1);
}

function resize(content, index, columns, rows) {
    return edited(content, list => {
        if (!holds(list, index) || !isEntry(list[index]))
            return false;
        list[index].columns = columns;
        list[index].rows = rows;
        return true;
    });
}

function move(content, from, to) {
    return edited(content, list => {
        if (!holds(list, from) || !holds(list, to) || from === to)
            return false;
        list.splice(to, 0, list.splice(from, 1)[0]);
        return true;
    });
}

// Puts an entry back at its place, as an undo does.
function insert(content, index, entry) {
    return edited(content, list => {
        if (!Number.isInteger(index) || index < 0 || index > list.length || !isEntry(entry))
            return false;
        list.splice(index, 0, entry);
        return true;
    });
}

// Puts an entry back in place of the one at `index`, as undoing a resize does.
function replace(content, index, entry) {
    return edited(content, list => {
        if (!holds(list, index) || !isEntry(entry))
            return false;
        list.splice(index, 1, entry);
        return true;
    });
}

// A copy of the entry at `index` of the file's list, or of the defaults while it has none; null for none.
function entry(content, index) {
    const list = Array.isArray(content?.pinned) ? content.pinned : defaultPinned;
    return holds(list, index) && isEntry(list[index]) ? JSON.parse(JSON.stringify(list[index])) : null;
}
