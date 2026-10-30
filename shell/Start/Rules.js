.pragma library
.import Rekta as Rekta

// The Start's rules as pure functions, apart from its surface, so the tests check them without a compositor.

// The output KWin puts first: the enabled one with the lowest priority, where 0 (never set) is the lowest of all, as
// KWin sorts them (workspace.cpp updateOutputOrder). `json` is what `kscreen-doctor -j` prints; "" when it names none.
function primaryOutput(json) {
    let outputs = [];
    try {
        outputs = JSON.parse(json).outputs ?? [];
    } catch (error) {
        return "";
    }
    const enabled = outputs.filter(output => output.enabled);
    if (enabled.length === 0)
        return "";
    return enabled.reduce((first, output) => output.priority < first.priority ? output : first).name;
}

// The screens with an area: while no output is left, Qt lists a placeholder screen without one (qwaylanddisplay.cpp,
// ensureScreen).
function realScreens(screens) {
    return screens.filter(screen => screen.width > 0 && screen.height > 0);
}

// Of `screens`, the one named `name`, else the first; null when there is none.
function primaryScreen(screens, name) {
    return screens.find(screen => screen.name === name) ?? screens[0] ?? null;
}

// A unit name holds letters, digits, ":", "_" and "."; anything else is written as \xNN, as systemd-escape does.
// Desktop file IDs are ASCII (desktop-entry spec, "Desktop File ID").
function escapeUnitName(text) {
    return text.replace(/[^A-Za-z0-9:_.]/g, character => `\\x${character.charCodeAt(0).toString(16).padStart(2, "0")}`);
}

// Starts an app in a systemd scope of its own, so it outlives a restart of the shell; the unit is named as XDG names an
// app's units: app-<desktop file ID>-<random>.scope.
function scopeCommand(id, command, stamp) {
    return ["systemd-run", "--user", "--scope", `--unit=app-${escapeUnitName(id)}-${stamp}`, "--", ...command];
}

// Plasma's own apps, pinned while the user has pinned nothing.
const defaultPinned = [{ id: "systemsettings" }, { id: "org.kde.dolphin" }, { id: "org.kde.konsole" }];

// A tile spans one or two units (rekta.tokens.json:624, tile-unit).
function span(units) {
    return Math.min(2, Math.max(1, Math.round(Number(units) || 1)));
}

// The list in start.json, {"pinned": [{"id": "org.kde.konsole", "columns": 1, "rows": 1}]}; null when it holds none.
function listedPins(text) {
    try {
        const pinned = JSON.parse(text).pinned;
        return Array.isArray(pinned) ? pinned : null;
    } catch (error) {
        return null;
    }
}

// The pinned tiles from start.json's list, or the defaults without one; only installed apps, as `installed(id)` tells.
function pinnedTiles(pinned, installed) {
    const listed = Array.isArray(pinned) ? pinned : defaultPinned;
    return listed.map(tile => ({
        id: String(tile.id ?? "").replace(/\.desktop$/, ""),
        columns: span(tile.columns),
        rows: span(tile.rows)
    })).filter(tile => tile.id !== "" && installed(tile.id));
}

// Where desktop entries live, in order of precedence, as Quickshell looks for them (desktopentry.cpp, desktopPaths).
function applicationDirs(dataHome, home, dataDirs) {
    const first = dataHome || (home ? `${home}/.local/share` : "");
    const rest = (dataDirs || "/usr/local/share:/usr/share").split(":").filter(dir => dir !== "");
    return [first, ...rest].filter(dir => dir !== "").map(dir => `${dir}/applications`);
}

// The desktop file ID of a file below an applications directory: its path there with "/" as "-", without ".desktop"
// (desktop-entry spec, "Desktop File ID").
function desktopId(relativePath) {
    return relativePath.replace(/\.desktop$/, "").replace(/\//g, "-");
}

// The OnlyShowIn and NotShowIn lists by desktop file ID, from what
// `grep -R --null -E '^(Type|OnlyShowIn|NotShowIn) *='` prints over `dirs`: a file, a NUL, a line. Each ID keeps the
// file of the first directory that has one, as the entry Quickshell shows is that one; every entry has a Type, so a
// file without either list still claims its ID.
function showIn(text, dirs) {
    const files = {};
    for (const line of text.split("\n")) {
        const [path, entry] = line.split("\0");
        const dir = dirs.find(candidate => path.startsWith(`${candidate}/`));
        const pair = /^(\w+) *= *(.*)$/.exec(entry ?? "");
        if (dir === undefined || pair === null)
            continue;
        const id = desktopId(path.slice(dir.length + 1));
        files[id] = files[id] ?? { path: path };
        if (files[id].path === path && pair[1] !== "Type")
            files[id][pair[1]] = pair[2].split(";").filter(name => name !== "");
    }
    return files;
}

// Whether an entry shows on this desktop: the first of `desktops` (XDG_CURRENT_DESKTOP, in order) that it names in
// OnlyShowIn shows it, in NotShowIn hides it; naming none, it shows unless it has an OnlyShowIn (desktop-entry spec).
function shown(file, desktops) {
    for (const desktop of desktops) {
        if (file.OnlyShowIn?.includes(desktop))
            return true;
        if (file.NotShowIn?.includes(desktop))
            return false;
    }
    return file.OnlyShowIn === undefined;
}

// A–Z whatever the case, in the locale's order.
function byName(a, b) {
    return a.name.toLowerCase().localeCompare(b.name.toLowerCase()) || a.name.localeCompare(b.name);
}

// The entries this desktop shows, A–Z by name; `files` is what showIn() read, `currentDesktop` XDG_CURRENT_DESKTOP.
function listedApps(entries, files, currentDesktop) {
    const desktops = String(currentDesktop ?? "").split(":").filter(name => name !== "");
    return entries.filter(entry => shown(files[entry.id] ?? {}, desktops)).sort(byName);
}

// The program an entry runs, by its name: "konsole" for "/usr/bin/konsole --new-tab".
function programName(command) {
    return String(command[0] ?? "").split("/").pop();
}

// The installed apps that match what was typed, the most often started first, then the best match, A–Z among equals:
// by name, or by a word of their generic name, keywords or program. `starts` counts the starts by app id. Space around
// the text does not count (rekta.js:2192).
function hits(apps, text, starts) {
    const typed = text.trim();
    const ranked = Rekta.Match.ranked(apps, app => Rekta.Match.score(app.name, [app.genericName, ...app.keywords, app.exec].join(" "), typed));
    const startsOf = app => (starts ?? {})[app.id] ?? 0;
    // Decorated with the rank, as QML's sort does not keep equals in order.
    return ranked.map((app, at) => ({ app: app, at: at })).sort((a, b) => (startsOf(b.app) - startsOf(a.app)) || (a.at - b.at)).map(entry => entry.app);
}

// The start counts a usage file holds, by app id; a file that is not an object gives none, an entry that is not a whole
// number from 1 is dropped.
function parseStarts(text) {
    let parsed = null;
    try {
        parsed = JSON.parse(text);
    } catch (error) {
        return {};
    }
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed))
        return {};
    const starts = {};
    for (const id of Object.keys(parsed)) {
        if (Number.isInteger(parsed[id]) && parsed[id] >= 1)
            starts[id] = parsed[id];
    }
    return starts;
}

// `starts` with one start more for `id`.
function counted(starts, id) {
    return Object.assign({}, starts, { [id]: (starts[id] ?? 0) + 1 });
}

// Where the shell keeps what it learns of its user (XDG base directories: the state directory, else ~/.local/state).
function stateDir(stateHome, home) {
    const base = stateHome || (home ? `${home}/.local/state` : "");
    return base === "" ? "" : `${base}/rekta-shell`;
}

// Where a typed key jumps among `names`: the next after `from` that starts with it, whatever the case, round past the
// end; -1 when none does. A tree's rule (collections.md:142; rekta.js:2810–2811), carried over to the apps' row.
function jumpTarget(names, from, key) {
    const typed = key.toLowerCase();
    for (let step = 1; step <= names.length; step++) {
        const at = (from + step) % names.length;
        if (names[at].trim().toLowerCase().startsWith(typed))
            return at;
    }
    return -1;
}

// The steps that turn the list of ids `from` into `to`: first the removals, from the end, then each place in `to`
// filled by moving an id there or inserting it; {remove: at}, {move: from, to: at} or {insert: at, id}.
function steps(from, to) {
    const keep = new Set(to);
    const now = from.slice();
    const found = [];
    for (let at = now.length - 1; at >= 0; at--) {
        if (!keep.has(now[at])) {
            found.push({ remove: at });
            now.splice(at, 1);
        }
    }
    to.forEach((id, at) => {
        const was = now.indexOf(id);
        if (was === at)
            return;
        if (was < 0) {
            found.push({ insert: at, id: id });
        } else {
            found.push({ move: was, to: at });
            now.splice(was, 1);
        }
        now.splice(at, 0, id);
    });
    return found;
}

// The most recently active window first. After the shell starts only the active window has that time; the others
// follow in stacking order, the topmost first.
function recentFirst(windows) {
    return windows.slice().sort((a, b) => (b.lastActivated - a.lastActivated) || (b.stackingOrder - a.stackingOrder));
}

// Whether `other` shares a row (left, right) or a column (up, down) with `from`.
function overlaps(from, other, direction) {
    if (direction === "left" || direction === "right")
        return other.y < from.y + from.height && other.y + other.height > from.y;
    return other.x < from.x + from.width && other.x + other.width > from.x;
}

// How far `other` lies beyond `from` in a direction, and how far it is off to the side; negative `ahead` is behind.
function offset(from, other, direction) {
    switch (direction) {
    case "right":
        return { ahead: other.x - from.x, aside: Math.abs(other.y - from.y) };
    case "left":
        return { ahead: from.x - other.x, aside: Math.abs(other.y - from.y) };
    case "down":
        return { ahead: other.y - from.y, aside: Math.abs(other.x - from.x) };
    default:
        return { ahead: from.y - other.y, aside: Math.abs(other.x - from.x) };
    }
}

// Where an arrow key moves the focus among tiles ({x, y, width, height}): the nearest one ahead in that row or column,
// and of those the one most in line. -1 when there is none.
function neighbour(from, rects, direction) {
    let best = -1;
    let bestOffset = null;
    rects.forEach((rect, index) => {
        const off = offset(from, rect, direction);
        if (off.ahead <= 0 || !overlaps(from, rect, direction))
            return;
        if (bestOffset === null || off.ahead < bestOffset.ahead || (off.ahead === bestOffset.ahead && off.aside < bestOffset.aside)) {
            best = index;
            bestOffset = off;
        }
    });
    return best;
}

// The System Settings pages: the desktop entries named kcm_<page>, which carry NoDisplay and so are no apps.
function isSettingsPage(id) {
    return id.startsWith("kcm_");
}

// The shell's commands that match what was typed, as the palette filters them (navigation.md, "Go to"): every word
// must start a word of the command's text or its keywords. {text, keywords, run}, or {word, at(n)} for one that takes
// an amount: "ton 30" says the one whose word starts with "ton" at 30 (up to 100), and comes first.
function commandHits(commands, text) {
    const typed = text.trim();
    const amount = /^(\S+)\s+(\d{1,3})\s*%?$/.exec(typed);
    const said = commands.filter(command => command.at !== undefined && amount !== null && command.word.startsWith(amount[1].toLowerCase())).map(command => command.at(Math.min(100, Number(amount[2]))));
    const plain = commands.filter(command => command.at === undefined);
    return [...said, ...Rekta.Match.ranked(plain, command => Rekta.Match.score(command.text, (command.keywords ?? []).join(" "), typed))];
}

// The windows whose title or app matches, the most recent first among equals.
function windowHits(windows, text) {
    const typed = text.trim();
    return Rekta.Match.ranked(recentFirst(windows), entry => Rekta.Match.score(entry.title, entry.app ?? "", typed));
}

// What the search finds besides apps, in the palette's groups, empty ones left out: windows, settings pages and
// commands as rows {text, lead, icon, run, best}. The first row is the best hit when no app matches (`noApp`).
function rowGroups(sources, text, starts, noApp) {
    const groups = [
        {
            name: "fenster",
            rows: windowHits(sources.windows, text).map(entry => ({ text: entry.title, lead: entry.app ?? "", icon: entry.icon, run: () => entry.activate() }))
        },
        {
            name: "einstellungen",
            rows: hits(sources.settings, text, starts).map(page => ({ text: page.name, lead: "", icon: page.icon, run: () => page.launch() }))
        },
        {
            name: "befehle",
            rows: commandHits(sources.commands, text).map(command => ({ text: command.text, lead: "", icon: "", key: command.key ?? "", run: () => command.run() }))
        }
    ].filter(group => group.rows.length > 0);
    if (noApp && groups.length > 0)
        groups[0].rows[0].best = true;
    return groups;
}

const keyModifiers = [[0x10000000, "Meta"], [0x04000000, "Ctrl"], [0x08000000, "Alt"], [0x02000000, "Shift"]];
const namedKeys = {
    0x20: "Space",
    0x01000000: "Esc",
    0x01000001: "Tab",
    0x01000003: "Backspace",
    0x01000004: "Return",
    0x01000005: "Enter",
    0x01000006: "Ins",
    0x01000007: "Del",
    0x01000010: "Home",
    0x01000011: "End",
    0x01000012: "Left",
    0x01000013: "Up",
    0x01000014: "Right",
    0x01000015: "Down",
    0x01000016: "PgUp",
    0x01000017: "PgDown",
    0x01000009: "Print"
};

// The whole numbers in nested lists, in order; the reply's struct and array levels do not matter here.
function numbersIn(value) {
    if (Number.isInteger(value))
        return [value];
    if (value === null || typeof value !== "object")
        return [];
    return Array.from(value).reduce((numbers, item) => numbers.concat(numbersIn(item)), []);
}

// The text of the first key combination kglobalaccel's `shortcutKeys` replied, such as "Meta+L"; the reply is a list of
// key sequences, each a list of Qt key codes. "" when it holds none (no key is bound) or only a key this does not name.
function keyText(values) {
    const code = numbersIn(values).find(number => number > 0);
    if (code === undefined)
        return "";
    const key = code & 0x01ffffff;
    const name = namedKeys[key] ?? (key >= 0x01000030 && key <= 0x0100004b ? `F${key - 0x01000030 + 1}` : (key >= 0x21 && key <= 0x7e ? String.fromCharCode(key) : ""));
    if (name === "")
        return "";
    return [...keyModifiers.filter(([flag]) => (code & flag) !== 0).map(([, word]) => word), name].join("+");
}
