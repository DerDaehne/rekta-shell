.pragma library
.import Rekta as Rekta
.import "Calc.js" as Calc
.import Settings as Settings

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

// A tile spans one to four units across and one or two down (tiles.md:29–33), at most `most` units.
function span(units, most) {
    return Math.min(most, Math.max(1, Math.round(Number(units) || 1)));
}

// The sizes a pinned app's tile is offered in, by name.
const pinSizes = [
    { name: "klein", columns: 1, rows: 1 },
    { name: "breit", columns: 2, rows: 1 },
    { name: "groß", columns: 2, rows: 2 },
    { name: "sehr groß", columns: 4, rows: 2 }
];

// The pinned tiles from start.json's list (Pins.read), or the defaults without one; only installed apps, as
// `installed(id)` tells. Each keeps its index in that list, which every change to the file counts by.
function pinnedTiles(pinned, installed) {
    const listed = Array.isArray(pinned) ? pinned : Settings.Pins.defaultPinned;
    return listed.map((tile, index) => ({
        id: Settings.Pins.bareId(tile?.id),
        columns: span(tile?.columns, 4),
        rows: span(tile?.rows, 2),
        index: index
    })).filter(tile => tile.id !== "" && installed(tile.id));
}

// The same app as `id`, written with or without ".desktop".
function sameApp(id, other) {
    return Settings.Pins.bareId(id) === Settings.Pins.bareId(other);
}

// The data directories in order of precedence, the user's first (XDG base directories).
function dataDirs(dataHome, home, systemDirs) {
    const first = dataHome || (home ? `${home}/.local/share` : "");
    const rest = (systemDirs || "/usr/local/share:/usr/share").split(":").filter(dir => dir !== "");
    return [first, ...rest].filter(dir => dir !== "");
}

// Where desktop entries live, in order of precedence, as Quickshell looks for them (desktopentry.cpp, desktopPaths).
function applicationDirs(dataHome, home, systemDirs) {
    return dataDirs(dataHome, home, systemDirs).map(dir => `${dir}/applications`);
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
// the text does not count (rekta.js:2604).
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
// end; -1 when none does. A tree's rule, carried over to the apps' row (collections.md:142–143).
// ponytail: one key at a time is Rekta 0.5.0's; 0.6.0 joins letters typed within duration-type-ahead into a prefix
// (rekta.js:173–190).
function jumpTarget(names, from, key) {
    const typed = key.toLowerCase();
    for (let step = 1; step <= names.length; step++) {
        const at = (from + step) % names.length;
        if (names[at].trim().toLowerCase().startsWith(typed))
            return at;
    }
    return -1;
}

// Text folded for filing by letter: lower case, its accents dropped ("Ä" as "a").
function folded(text) {
    return String(text).normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}

// A letter has a case (QML's regular expressions know no \p{L}).
function isLetter(character) {
    return character.toLowerCase() !== character.toUpperCase();
}

// The section of "alle apps" a name files under: its first letter, folded, or "#" when it starts with a digit or a sign.
function initialOf(name) {
    const first = folded(name.trim()).charAt(0);
    return isLetter(first) ? first : "#";
}

// The first two letters of a name, folded, anything else left out: "kb" for "K3b".
function twoLetters(name) {
    return [...folded(name)].filter(isLetter).slice(0, 2).join("");
}

// The sections of "alle apps" over `names`, in the app model's order: one per initial (initialOf), as many tile units
// wide as its apps need in `rows` rows, at most six. An initial with more apps than six units hold splits into near
// equal parts, the larger first, each named by the first two letters of its first and its last app ("ka–km"). Each is
// {title, first, count, units}, `first` and `count` counted in `names`. With `rows` Infinity (stacked) none splits and
// each is one unit wide, as one column holds all its apps.
function letterSections(names, rows) {
    const sections = [];
    for (let first = 0, count = 0; first < names.length; first += count) {
        const initial = initialOf(names[first]);
        count = 1;
        while (first + count < names.length && initialOf(names[first + count]) === initial)
            count++;
        sections.push(...letterParts(names, initial, first, count, rows));
    }
    return sections;
}

function letterParts(names, initial, first, count, rows) {
    const parts = Math.max(1, Math.ceil(count / (6 * rows)));
    const parted = [];
    for (let k = 0, at = first; k < parts; k++) {
        const size = Math.floor(count / parts) + (k < count % parts ? 1 : 0);
        parted.push({
            title: parts === 1 ? initial : `${twoLetters(names[at])}–${twoLetters(names[at + size - 1])}`,
            first: at,
            count: size,
            units: Math.max(1, Math.ceil(size / rows))
        });
        at += size;
    }
    return parted;
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

// What was typed, worked out (Calc.js), as a row that copies the result through `copy`; none when it is no calculation.
function calculationRows(text, decimalPoint, copy) {
    const value = Calc.result(text, decimalPoint);
    if (value === null)
        return [];
    const result = Calc.shown(value, decimalPoint);
    return [{ text: `= ${result}`, lead: "", icon: "", run: () => copy(result) }];
}

// What the search finds besides apps, in the palette's groups, empty ones left out: a calculation's result, windows,
// settings pages and commands as rows {text, lead, icon, run, best}. The first row is the best hit when no app matches
// (`noApp`). `sources` also gives the locale's decimal separator and how a result is copied.
function rowGroups(sources, text, starts, noApp) {
    const groups = [
        {
            name: "rechnen",
            rows: calculationRows(text, sources.decimalPoint, sources.copy)
        },
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

// The ways on when nothing matches (states.md, "Empty"), as rows: a search of the web for the text through `openUrl`,
// where the desktop has a web search (`webQuery`, see providerQuery). The first is the best hit.
function waysOut(text, webQuery, openUrl) {
    if (webQuery === "")
        return [];
    return [{ text: `„${text}“ im web suchen`, lead: "", icon: "", best: true, run: () => openUrl(webSearchUrl(webQuery, text)) }];
}

// The address that searches for `text`: the provider's search address with the text, encoded, in place of \{@}.
function webSearchUrl(webQuery, text) {
    return webQuery.split("\\{@}").join(encodeURIComponent(text));
}

// A KConfig value as written: \s, \t, \n and \r stand for their characters, a backslash before any other for that one.
function unescaped(value) {
    const named = { s: " ", t: "\t", n: "\n", r: "\r" };
    return value.replace(/\\(.)/g, (escape, character) => named[character] ?? character);
}

// The entries of one group of a KConfig or desktop file, their values unescaped; KConfig's flags such as [$i] are
// dropped from a key, a locale such as [de] stays part of it.
function iniGroup(text, name) {
    const entries = {};
    let inGroup = false;
    for (const rawLine of text.split("\n")) {
        const line = rawLine.trim();
        const at = line.indexOf("=");
        if (line.startsWith("["))
            inGroup = line === `[${name}]`;
        else if (inGroup && at > 0)
            entries[line.slice(0, at).trim().replace(/\[\$[^\]]*\]/g, "")] = unescaped(line.slice(at + 1).trim());
    }
    return entries;
}

// The provider KDE searches the web with when what was typed is no address (Web Search Keywords in System Settings), by
// the name of its file: kuriikwsfilterrc's [General] DefaultWebShortcut, or "duckduckgo", KIO's own while none is set
// (kuriikwsfiltereng.cpp, loadConfig). "" when web shortcuts are off or the user chose none.
function defaultWebShortcut(config) {
    const general = iniGroup(config, "General");
    if (general.EnableWebShortcuts === "false")
        return "";
    return general.DefaultWebShortcut ?? "duckduckgo";
}

// A provider's search address, from what `grep -H --null '^Query'` printed over its files in `files`, the first in
// order of precedence that is there: its Query for the locale ("de_DE", then "de"), else its own. "" when there is
// none or it has no place for the text.
// ponytail: \{@} only, the whole text; KIO's word and range references (\{1}, \{name,…}) appear in a few providers.
function providerQuery(grepped, files, locale) {
    const lines = grepped.split("\n").map(line => line.split("\0")).filter(pair => pair.length === 2);
    const file = files.find(path => lines.some(([from]) => from === path));
    const entries = iniGroup(["[Desktop Entry]", ...lines.filter(([from]) => from === file).map(([, line]) => line)].join("\n"), "Desktop Entry");
    const query = entries[`Query[${locale}]`] ?? entries[`Query[${locale.split("_")[0]}]`] ?? entries.Query ?? "";
    return query.includes("\\{@}") ? query : "";
}

// Rekta writes a combination one way: the modifiers in the order Ctrl, Alt, Shift, Meta, then the key, joined by "+".
// Meta is "Super" off Apple and Windows, Escape "Esc", the arrows glyphs, a letter a capital and any other key its web
// name (navigation.md:481–494; rekta.js:3000–3018).
const keyModifiers = [[0x04000000, "Ctrl"], [0x08000000, "Alt"], [0x02000000, "Shift"], [0x10000000, "Super"]];
// A modifier that is the whole shortcut, as Meta is the Start's, by its flag.
const modifierKeys = {
    0x01000020: 0x02000000,
    0x01000021: 0x04000000,
    0x01000022: 0x10000000,
    0x01000023: 0x08000000
};
const namedKeys = {
    0x20: "Space",
    0x01000000: "Esc",
    0x01000001: "Tab",
    0x01000003: "Backspace",
    0x01000004: "Enter",
    0x01000005: "Enter",
    0x01000006: "Insert",
    0x01000007: "Delete",
    0x01000010: "Home",
    0x01000011: "End",
    0x01000012: "←",
    0x01000013: "↑",
    0x01000014: "→",
    0x01000015: "↓",
    0x01000016: "PageUp",
    0x01000017: "PageDown",
    0x01000009: "PrintScreen"
};

function keyName(key) {
    if (key in namedKeys)
        return namedKeys[key];
    if (key >= 0x01000030 && key <= 0x0100004b)
        return `F${key - 0x01000030 + 1}`;
    return key >= 0x21 && key <= 0x7e ? String.fromCharCode(key) : "";
}

// The whole numbers in nested lists, in order; the reply's struct and array levels do not matter here.
function numbersIn(value) {
    if (Number.isInteger(value))
        return [value];
    if (value === null || typeof value !== "object")
        return [];
    return Array.from(value).reduce((numbers, item) => numbers.concat(numbersIn(item)), []);
}

// The text of the first key combination kglobalaccel's `shortcutKeys` replied, such as "Super+L"; the reply is a list of
// key sequences, each a list of Qt key codes. "" when it holds none (no key is bound) or only a key this does not name.
function keyText(values) {
    const code = numbersIn(values).find(number => number > 0);
    if (code === undefined)
        return "";
    const key = code & 0x01ffffff;
    const name = keyName(key);
    if (name === "" && !(key in modifierKeys))
        return "";
    const flags = code | (modifierKeys[key] ?? 0);
    const modifiers = keyModifiers.filter(([flag]) => (flags & flag) !== 0).map(([, word]) => word);
    return [...modifiers, name].filter(word => word !== "").join("+");
}

// The newest line, by app id, of the app whose player plays: what it plays, as Rekta's music tile says it ("Playing:
// Calm, side B"). `player` is an MPRIS player as Quickshell has it, or null; `appId` its app, "" for none known.
function playingLines(player, appId) {
    const track = [player?.trackTitle ?? "", player?.trackArtist ?? ""].filter(part => part !== "").join(" · ");
    return appId !== "" && track !== "" ? { [appId]: `Läuft gerade: ${track}` } : {};
}
