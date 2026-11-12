pragma ComponentBehavior: Bound

import QtQuick
import Rekta
import Settings
import Start

// The group "angeheftet" of the place "start": one row for every entry of start.json's list, in the file's order, also
// for apps that are not installed. Each row has its grip, the app's icon and name, its size and a quiet "lösen"; below
// them a combobox picks an app and "anheften" pins it at the end. Delete in a row, or pulling it towards the trailing
// edge, unpin it too (collections.md:158–181); the grip orders the list (collections.md:183–192). Every change but a
// move shows a toast with undo (live.md:107–121). The file is read and written only through `file`, so a change made
// in the Start shows here at once and one made here in the Start. A broken file shows the defaults with everything
// disabled and is never written.
Column {
    id: pinned

    // start.json: the app's StartFile, or in a test a stand-in with the same members.
    required property var file
    // The installed apps as "alle apps" lists them, {id, name, icon}; null until they have been read.
    property var apps: null
    property Toaster toaster: null
    readonly property string disabledReason: file.fault === "broken" ? "datei nicht lesbar" : ""
    readonly property string problem: file.fault === "broken" ? "start.json ist kein gültiges json. korrigiere oder lösche die datei, dann lässt sich hier wieder etwas ändern." : ""
    // None until the file has been read, so neither the defaults nor the empty state show before the list does.
    readonly property var entries: !file.settled ? [] : Array.isArray(file.list) ? file.list : Pins.defaultPinned
    readonly property var sizes: Rules.pinSizes.map(size => ({
                value: `${size.columns}×${size.rows}`,
                text: size.name
            }))
    property alias rows: list
    property alias choice: combo
    // Whether the file had been read at the last sync: the rows it first brings do not arrive.
    property bool ready: false
    // Set while this group writes the file, so its own change does not end a pick-up or drag.
    property bool writing: false

    function appOf(id: string): var {
        return (apps ?? []).find(app => Rules.sameApp(app.id, id)) ?? null;
    }

    function rowFor(entry: var, key: string): var {
        const id = Pins.bareId(entry?.id);
        const app = appOf(id);
        return {
            key: key,
            appId: id,
            title: app?.name ?? id,
            icon: app?.icon ?? "",
            missing: apps !== null && app === null,
            // As the tile shows it: "2×1".
            size: `${Rules.span(entry?.columns, 4)}×${Rules.span(entry?.rows, 2)}`
        };
    }

    // One key per entry: its app, and how often that app came before, for a list written by hand.
    function wanted(): var {
        const seen = {};
        return entries.map(entry => {
            const id = Pins.bareId(entry?.id);
            seen[id] = (seen[id] ?? 0) + 1;
            return rowFor(entry, `${id}#${seen[id]}`);
        });
    }

    function keyIndex(key: string, from: int): int {
        for (let at = from; at < model.count; at++) {
            if (model.get(at).key === key)
                return at;
        }
        return -1;
    }

    // Brings the model to the file's list in place: rows of the same entry stay, so focus and a running move stay with
    // them. Rows that came glide in from above, the others glide from where they showed (FLIP).
    function sync() {
        const next = wanted();
        const arrives = ready;
        ready = file.settled;
        const shown = new Map(list.all().map(row => [row.key, row.y]));
        const focused = focusedPart();
        let changed = false;
        next.forEach((row, index) => {
            const at = keyIndex(row.key, index);
            changed = changed || at !== index;
            if (at < 0)
                model.insert(index, row);
            else if (at !== index)
                model.move(at, index, 1);
            model.set(index, row);
        });
        if (model.count > next.length) {
            model.remove(next.length, model.count - next.length);
            changed = true;
        }
        if (!changed)
            return;
        list.layout();
        settle(shown, arrives);
        // The row with the focus went with a change from elsewhere: the focus goes on as on unpinning.
        if (focused && keyIndex(focused.key, 0) < 0)
            focusAfter(focused.index, focused.part);
    }

    function settle(shown: var, arrives: bool) {
        for (const row of list.all()) {
            if (shown.has(row.key))
                row.settleFrom(shown.get(row.key));
            else if (arrives)
                row.arrive();
        }
    }

    // The row holding the focus, its index and the part of it that holds it.
    function focusedPart(): var {
        const row = list.all().find(each => each.holds(Window.activeFocusItem));
        return row ? {
            key: row.key,
            index: row.index,
            part: row.partWithFocus()
        } : null;
    }

    // The focus goes to the same part of the row now at `index`, else of the one before, else to the combobox.
    function focusAfter(index: int, part: string) {
        const row = list.rowAt(Math.min(index, list.count - 1)) as PinnedRow;
        if (row)
            row.focusPart(part);
        else
            combo.forceActiveFocus();
    }

    function write(change: var): bool {
        writing = true;
        const wrote = change();
        writing = false;
        return wrote;
    }

    function tell(text: string, undo: var) {
        toaster?.show(text, {
            undo: undo,
            from: combo
        });
    }

    function indexOf(id: string): int {
        return entries.findIndex(entry => Pins.bareId(entry?.id) === id);
    }

    function countOf(id: string): int {
        return entries.filter(entry => Pins.bareId(entry?.id) === id).length;
    }

    function pin(id: string) {
        const app = appOf(id);
        if (!write(() => file.pin(id)))
            return;
        combo.clear();
        tell(`${app?.name ?? id} angeheftet`, () => {
            const at = indexOf(Pins.bareId(id));
            if (at >= 0)
                write(() => file.unpin(at));
        });
    }

    // The row has left: its entry goes, found by its key, as the file may have changed meanwhile.
    function unpin(key: string, name: string): bool {
        const at = keyIndex(key, 0);
        const entry = file.entry(at);
        const id = Pins.bareId(entry?.id);
        const left = countOf(id) - 1;
        if (at < 0 || !write(() => file.unpin(at)))
            return false;
        tell(`${name} gelöst`, () => {
            // Counted, not searched: the same app may stay pinned more than once, and undo must not bring it twice.
            if (countOf(id) <= left)
                write(() => file.insert(Math.min(at, entries.length), entry));
        });
        return true;
    }

    // Unpinning a row with the focus hands it to the next row, at the end to the one before, without any to the
    // combobox (collections.md:167–169).
    function remove(row: PinnedRow) {
        if (disabledReason !== "" || row.going)
            return;
        const focused = row.holds(Window.activeFocusItem) ? row.partWithFocus() : "";
        if (focused !== "") {
            const next = (list.rowAt(row.index + 1) ?? list.rowAt(row.index - 1)) as PinnedRow;
            if (next)
                next.focusPart(focused);
            else
                combo.forceActiveFocus();
        }
        row.leave();
    }

    // Found by the row's key, not its app: the same app may be pinned more than once.
    function resize(key: string, name: string, value: string, sizeName: string) {
        const at = keyIndex(key, 0);
        const entry = file.entry(at);
        const [columns, rows] = value.split("×").map(Number);
        if (at < 0 || !write(() => file.resize(at, columns, rows)))
            return;
        tell(`${name}: ${sizeName}`, () => {
            const now = keyIndex(key, 0);
            if (now >= 0)
                write(() => file.replace(now, entry));
        });
    }

    // A change from elsewhere ends a drag or a pick-up: the file holds.
    onEntriesChanged: {
        if (!writing)
            list.stop();
        sync();
    }
    onAppsChanged: sync()
    Component.onCompleted: sync()

    ListModel {
        id: model
    }

    // Shown when the list is empty (states.md:12); the way on is the combobox below.
    Empty {
        objectName: "empty"
        width: pinned.width
        visible: pinned.file.settled && model.count === 0
        text: "nichts angeheftet."
    }

    SortableRows {
        id: list

        objectName: "rows"
        width: pinned.width
        visible: model.count > 0
        model: model
        onMoved: (from, to) => pinned.write(() => pinned.file.move(from, to))

        delegate: PinnedRow {
            group: pinned
        }
    }

    Hairline {
        width: pinned.width
        visible: model.count > 0
    }

    Setting {
        objectName: "add"
        width: pinned.width
        topPadding: Tokens.spaceM
        label: "app"
        problem: pinned.problem

        Item {
            width: parent.width
            height: Math.max(combo.height, button.height)

            Combobox {
                id: combo

                objectName: "app"
                width: parent.width - Tokens.spaceS - measure.width
                label: "app"
                placeholder: "app suchen"
                disabledReason: pinned.disabledReason
                noMatch: typed => `keine app passt zu „${typed}“.`
                nothingYet: "noch keine apps gefunden."
                options: (pinned.apps ?? []).map(app => ({
                            label: app.name,
                            value: app.id,
                            disabledReason: pinned.indexOf(Pins.bareId(app.id)) >= 0 ? "angeheftet" : ""
                        }))
            }

            Button {
                id: button

                objectName: "pin"
                x: combo.width + Tokens.spaceS
                text: "anheften"
                disabledReason: pinned.disabledReason || (combo.value === undefined ? "wähle eine app" : "")
                onClicked: pinned.pin(combo.value)
            }

            // The button's widest: with its reason beside it, so the field keeps its width when a choice lifts it.
            Button {
                id: measure

                visible: false
                activeFocusOnTab: false
                text: button.text
                disabledReason: pinned.disabledReason || "wähle eine app"
            }
        }
    }
}
