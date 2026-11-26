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

// What Quickshell.execDetached() takes to start `command` for a desktop entry, the entry's own or one of its desktop
// actions': in a scope of the entry's own (scopeCommand), in the entry's working directory if it names one.
// ponytail: Quickshell drops %i, %c and %k from Exec, so an app starts without them (only KMail uses %c today); an own
// Exec parser over execString would expand them, if an app needs it (%k would still need the file path).
function launchContext(entry, command, stamp) {
    const context = { command: scopeCommand(entry.id, command, stamp) };
    if (entry.workingDirectory !== "")
        context.workingDirectory = entry.workingDirectory;
    return context;
}

// The bus name of an app that runs over D-Bus, "" for any other: its file (desktopFileKeys) says DBusActivatable=true,
// and the file's name without ".desktop", not its desktop file ID, is a well-known bus name, which the running app owns
// (desktop-entry spec, "D-Bus Activation"). Otherwise GLib starts it by Exec, and so does the shell.
function busName(file) {
    const name = String(file?.path ?? "").split("/").pop().replace(/\.desktop$/, "");
    const valid = name.length <= 255 && /^[A-Za-z_-][\w-]*(\.[A-Za-z_-][\w-]*)+$/.test(name);
    return file?.DBusActivatable === true && valid ? name : "";
}

// The object path of an app that runs over D-Bus: "/" and its bus name with "." as "/" and "-" as "_" (desktop-entry
// spec, "D-Bus Activation").
function applicationPath(name) {
    return `/${name.replace(/\./g, "/").replace(/-/g, "_")}`;
}

// The desktop actions of an entry ([Desktop Action] groups) as the action registry lists them, in the words the app
// gives them and found by the app's name too. An app that runs over D-Bus under `appBusName` runs each of them there,
// Exec or not, as the spec has a launcher do, and Invoke answers with the app's own answer (activatedResult); any other
// app ("") starts one as it starts itself, so one without an Exec is left out and Invoke answers once it is started.
// One without a name is left out too: the spec requires it.
function desktopActions(entry, appBusName, launcher) {
    const runnable = action => action.name !== "" && (appBusName !== "" || action.command.length > 0);
    const answered = appBusName !== "" ? "; done is false with the app's D-Bus error as the reason if it cannot be reached or fails" : "";
    return Array.from(entry.actions).filter(runnable).map(action => ({
        id: `desktop/${entry.id}/${action.id}`,
        text: action.name,
        keywords: [entry.name],
        app: entry.id,
        appName: entry.name,
        icon: action.icon || entry.icon,
        description: `Runs the "${action.name}" action of ${entry.name}${answered}.`,
        acts: () => launcher.starts,
        invokeWith: appBusName !== "" ? (parameters, reply) => {
            launcher.activateAction(appBusName, action.id, error => reply.send(null, activatedResult(error)));
            return reply;
        } : undefined,
        run: appBusName !== "" ? () => launcher.activateAction(appBusName, action.id) : () => launcher.launchAction(entry, action)
    }));
}

// What Invoke answers for an ActivateAction that ended with `error` (null: the app did it).
function activatedResult(error) {
    return error ? { done: false, reason: nonEmptyText(error) } : { done: true };
}

// What one provider may list: no program can make the shell work through more than this. A launcher's actions are a
// handful to a few dozen; an app with more has the rest dropped. Both limits bound the export on every ActionsChanged.
// ponytail: fixed limits; per-provider settings if a real app needs more.
const maxProvidedActions = 256;
const maxActionKeywords = 32;
const maxProvidedText = 1000;
// How long the shell waits for an app to answer an action it hands on (a provider's Invoke, an ActivateAction): less
// than the 25 s a caller of Invoke waits by default, so the caller gets the shell's answer.
const appAnswerWait = 20000;

// At most `most` elements of a list that came over D-Bus; anything else, an object that only claims a length too, is none.
function boundedList(value, most) {
    return value instanceof Array ? Array.prototype.slice.call(value, 0, most) : [];
}

// The rows of a provider's ListActions answer: [id, properties] lists, at most maxProvidedActions of them.
function providedRows(answer) {
    return boundedList(answer, maxProvidedActions);
}

// Whether text is a JSON Schema as rekta.Actions1 has it: a JSON object.
function isSchema(text) {
    try {
        const parsed = JSON.parse(text);
        return parsed !== null && typeof parsed === "object" && !Array.isArray(parsed);
    } catch (error) {
        return false;
    }
}

// A row the registry may list: an id, a title, parameters that are no schema at all or one, and no claim to be
// destructive or irreversible (anything but a missing or false one counts as a claim).
function usableRow(row) {
    if (!(row instanceof Array) || typeof row[0] !== "string" || row[0] === "")
        return false;
    const properties = row[1];
    if (typeof properties?.title !== "string" || properties.destructive || properties.consequence === "irreversible")
        return false;
    const parameters = properties.parameters ?? "";
    return typeof parameters === "string" && (parameters === "" || isSchema(parameters));
}

// A non-empty text capped at maxProvidedText characters, else nothing: a provider's words go on to every client.
function nonEmptyText(value) {
    return typeof value === "string" && value !== "" ? value.slice(0, maxProvidedText) : undefined;
}

// A state a client can read: true or false, a finite number or a text.
function isScalar(value) {
    return typeof value === "boolean" || typeof value === "string" || (typeof value === "number" && Number.isFinite(value));
}

// The state as a client gets it: a text is capped like every other text a provider gives; nothing for a non-state.
function scalarState(value) {
    if (!isScalar(value))
        return undefined;
    return typeof value === "string" ? value.slice(0, maxProvidedText) : value;
}

// What a provider's Invoke answered, as the shell reports it: `done` (an older provider's `{}` says it was done), its `state`
// and `reason`, each only with the type they must have; a failure always has a reason.
function providedResult(answer) {
    const result = { done: typeof answer?.done === "boolean" ? answer.done : true };
    const state = scalarState(answer?.state);
    if (state !== undefined)
        result.state = state;
    const reason = nonEmptyText(answer?.reason);
    if (reason !== undefined || !result.done)
        result.reason = reason ?? "the app did not do it";
    return result;
}

// The actions a running provider of rekta.Actions1 lists (`listed`: the rows of its ListActions) as the action registry
// has them, named for its app. Every value is checked, as the registry exports them under the signatures it promises:
// a row that fails is left out (usableRow), a wrong icon or keyword is dropped. A destructive row is left out because,
// until the shell can ask first, an app's own may not run from outside. `invoke(id, parameters, reply)` calls the provider's Invoke.
function providedActions(app, listed, invoke) {
    return listed.filter(usableRow).map(([id, properties]) => ({
        id: `provider/${app.id}/${id}`,
        text: properties.title,
        keywords: boundedList(properties.keywords, maxActionKeywords).filter(word => typeof word === "string"),
        parameters: properties.parameters ?? "",
        readOnly: properties.readOnly === true,
        app: app.id,
        appName: app.name,
        icon: typeof properties.icon === "string" && properties.icon !== "" ? properties.icon : app.iconName,
        description: nonEmptyText(properties.description) ?? `Runs the "${properties.title}" action of ${app.name}.`,
        consequence: ["none", "undoable"].includes(properties.consequence) ? properties.consequence : undefined,
        available: properties.available !== false,
        reason: nonEmptyText(properties.reason) ?? "the app gave no reason",
        state: scalarState(properties.state) === undefined ? undefined : () => scalarState(properties.state),
        invokeWith: (parameters, reply) => invoke(id, parameters, reply)
    }));
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

// What Quickshell does not give QML, by desktop file ID: the OnlyShowIn, NotShowIn and Implements lists and whether DBusActivatable
// is true, from what `grep -R --null -E '^(Type|OnlyShowIn|NotShowIn|DBusActivatable|Implements) *='` prints over `dirs`: a file, a
// NUL, a line. Each ID keeps the file of the first directory that has one, as the entry Quickshell shows is that one;
// every entry has a Type, so a file without any of the others still claims its ID.
function desktopFileKeys(text, dirs) {
    const files = {};
    for (const line of text.split("\n")) {
        const [path, entry] = line.split("\0");
        const dir = dirs.find(candidate => path.startsWith(`${candidate}/`));
        const pair = /^(\w+) *= *(.*)$/.exec(entry ?? "");
        if (dir === undefined || pair === null)
            continue;
        const id = desktopId(path.slice(dir.length + 1));
        files[id] = files[id] ?? { path: path };
        if (files[id].path !== path || pair[1] === "Type")
            continue;
        files[id][pair[1]] = pair[1] === "DBusActivatable" ? pair[2].trim() === "true" : pair[2].split(";").filter(name => name !== "");
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

// The entries this desktop shows, A–Z by name; `files` is what desktopFileKeys() read, `currentDesktop` XDG_CURRENT_DESKTOP.
function listedApps(entries, files, currentDesktop) {
    const desktops = String(currentDesktop ?? "").split(":").filter(name => name !== "");
    return entries.filter(entry => shown(files[entry.id] ?? {}, desktops)).sort(byName);
}

// What a read makes of a desktop entry, {item, json}: `item` as described, or the item of `last` (the last read's, or
// undefined) when that holds the same data, with the new item's functions. Quickshell may hold a new object for the same
// entry, as it makes one on every scan for an ID that two directories hold, and the new functions call that one.
function reread(last, item) {
    const json = JSON.stringify(item);
    if (last === undefined || last.json !== json)
        return {
            item: item,
            json: json
        };
    takeFunctions(last.item, item);
    return last;
}

// Puts the functions of `from` in place of those of `into`, which holds the same data.
function takeFunctions(into, from) {
    for (const key of Object.keys(from)) {
        if (typeof from[key] === "function")
            into[key] = from[key];
        else if (from[key] !== null && typeof from[key] === "object")
            takeFunctions(into[key], from[key]);
    }
}

// Whether two lists hold the same items in the same order; null is no list.
function sameItems(list, other) {
    return Array.isArray(list) && Array.isArray(other) && list.length === other.length && list.every((item, k) => item === other[k]);
}

// How many of the last lists of `lists` hold the same items as the last ones of `others`, from the end.
function sameTail(lists, others) {
    let count = 0;
    while (count < lists.length && count < others.length && sameItems(lists[lists.length - 1 - count], others[others.length - 1 - count]))
        count++;
    return count;
}

// The program an entry runs, by its name: "konsole" for "/usr/bin/konsole --new-tab".
function programName(command) {
    return String(command[0] ?? "").split("/").pop();
}

// The words an app or settings page is found by, its name, generic name, keywords and program, in one line
// (Match.wordLine): the one its item carries, made once as the app list reads its entry, or read now.
function wordLineOf(app) {
    return app.wordLine ?? Rekta.Match.wordLine(`${app.name} ${[app.genericName, ...app.keywords, app.exec].join(" ")}`);
}

// The installed apps that match what was typed, the most often started first, then the best match, A–Z among equals:
// by name, or by a word of their generic name, keywords or program. `starts` counts the starts by app id. Space around
// the text does not count (rekta.js:2678).
function hits(apps, text, starts) {
    const typed = text.trim();
    const ranked = Rekta.Match.ranked(apps, app => Rekta.Match.scoreLine(app.name, wordLineOf(app), typed));
    const startsOf = app => (starts ?? {})[app.id] ?? 0;
    // Decorated with the rank, as QML's sort does not keep equals in order.
    return ranked.map((app, at) => ({ app: app, at: at })).sort((a, b) => (startsOf(b.app) - startsOf(a.app)) || (a.at - b.at)).map(entry => entry.app);
}

// The hits as the search shows them: tiles for the apps whose name has a word each typed word starts (Rekta's filter,
// navigation.md:329–330), as many as one row of `units` holds beside the wide best hit, and rows for the rest, the apps
// that match only by their generic name, keywords or program or hold the text inside a word of their name, and the
// names past that row, in the hits' order.
function appHits(apps, text, starts, units) {
    const found = hits(apps, text, starts);
    const typed = text.trim();
    const tiles = found.filter(app => Rekta.Match.score(app.name, "", typed) >= Rekta.Match.wordStart).slice(0, Math.max(1, units - 1));
    return {
        tiles: tiles,
        rows: found.filter(app => !tiles.includes(app))
    };
}

// The shell's own apps carry Rekta's icon inside it; their desktop entries keep a theme icon for other desktops.
function ownGlyph(id) {
    return id === "rekta-settings" ? "tune" : "";
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
// wide as its apps need in `rows` rows, at most six. Neighbouring initials whose apps together fill no more than the
// rows share one section, named by its first and last initial ("a–c"), so that a short letter leaves no rows empty
// (layout.md:198–200). An initial with more apps than six units hold splits into near equal parts, the larger first,
// each named by the first two letters of its first and its last app ("ka–km"). Each is {title, first, count, units},
// `first` and `count` counted in `names`. With `rows` Infinity (stacked) none joins or splits and each is one unit
// wide, as one column holds all its apps.
function letterSections(names, rows) {
    const sections = [];
    for (let first = 0, count = 0; first < names.length; first += count) {
        const initial = initialOf(names[first]);
        count = 1;
        while (first + count < names.length && initialOf(names[first + count]) === initial)
            count++;
        const last = sections[sections.length - 1];
        if (Number.isFinite(rows) && last && last.count + count <= rows) {
            last.title = `${initialOf(names[last.first])}–${initial}`;
            last.count += count;
        } else {
            sections.push(...letterParts(names, initial, first, count, rows));
        }
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

// The System Settings pages: the desktop entries named kcm_<page>, which carry NoDisplay and so are no apps.
function isSettingsPage(id) {
    return id.startsWith("kcm_");
}

// The shell's commands that match what was typed, as the palette filters them (navigation.md, "Go to"): every word
// must start a word of the command's text or its keywords. {text, keywords, run}, or {word, at(n)} for one that takes
// an amount: "ton 30" says the one whose word starts with "ton" at 30 (up to 100), and comes first. One that cannot run now
// (`available` false) is no hit.
function commandHits(listed, text) {
    const commands = listed.filter(command => command.available !== false);
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

// A window's app before its title, unless the title only says the app's name again.
function windowLead(entry) {
    const app = entry.app ?? "";
    return app.toLowerCase() === String(entry.title).toLowerCase() ? "" : app;
}

// The palette's groups of rows, in the order the search shows them.
const rowGroupNames = ["rechnen", "apps", "fenster", "einstellungen", "befehle"];

// What the search shows as rows, in the palette's groups, empty ones left out: a calculation's result, the apps without
// a tile (`sources.apps`, see appHits), windows, settings pages and commands as rows {text, lead, icon, glyph, run,
// best}. The first row is the best hit when no app has a tile (`noApp`). `sources` also gives the locale's decimal
// separator and how a result is copied.
function rowGroups(sources, text, starts, noApp) {
    const rows = {
        rechnen: calculationRows(text, sources.decimalPoint, sources.copy),
        apps: (sources.apps ?? []).map(app => ({ text: app.name, lead: "", icon: app.icon, glyph: ownGlyph(app.id), run: () => app.launch() })),
        fenster: windowHits(sources.windows, text).map(entry => ({ text: entry.title, lead: windowLead(entry), icon: entry.icon, run: () => entry.activate() })),
        einstellungen: hits(sources.settings, text, starts).map(page => ({ text: page.name, lead: "", icon: page.icon, run: () => page.launch() })),
        befehle: commandHits(sources.commands, text).map(command => ({ text: command.text, lead: "", icon: "", key: command.key ?? "", run: () => command.run() }))
    };
    const groups = rowGroupNames.map(name => ({
                name: name,
                rows: rows[name]
            })).filter(group => group.rows.length > 0);
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
// name (navigation.md:525–539; rekta.js:3074–3094).
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
