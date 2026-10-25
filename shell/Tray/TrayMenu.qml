pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.qmlmodels
import Rekta

// The menu of the background apps, in one floating surface (ADR: in place). It lists the apps, one row each: their icon,
// word and state. A row's menu replaces the list, headed by a back row; an entry with children opens the next level the
// same way. Escape and ← go back one level, Tab closes everything, choosing a leaf triggers it and closes.
//
// `apps` are objects with word, icon, state, hasMenu, onlyMenu, menu and activate(). `opener` makes an object with a
// `menu` property and `children.values`, the entries of that menu (Quickshell's QsMenuOpener), one per level.
Menu {
    id: tray

    property var apps: []
    property Component opener
    // One frame per level in view: the app, its opener, and the index of the row that opened the level.
    property var levels: []
    readonly property var current: levels.length > 0 ? levels[levels.length - 1].opener.children.values : apps
    // What the rows show: `current` once it has entries, so a level whose entries are still loading changes nothing.
    property var shown: []
    // Where the focus goes once a level's rows are there: DBusMenu hands them over a moment after the level opens.
    property var focusOnFill: null

    // Keeps the level in view in sync with what its owner reports.
    function refill() {
        // ponytail: a submenu that never has entries keeps the previous rows in view; back still leaves it.
        if (levels.length > 0 && current.length === 0)
            return;
        const was = focusedIndex();
        shown = current;
        rowKinds.clear();
        for (let at = 0; at < shown.length; at++)
            rowKinds.append({ kind: levels.length === 0 ? "app" : shown[at].isSeparator ? "separator" : "entry", at });
        if (focusOnFill !== null) {
            // Later: the back row's visibility follows `levels` only once its binding has run.
            Qt.callLater(focusOnFill);
            focusOnFill = null;
        } else if (was >= 0) {
            focusAt(was);
        }
    }

    function enter(app: var, handle: var, row: Item) {
        const byKeys = focusedIndex() >= 0;
        const opener = tray.opener.createObject(tray, { menu: handle });
        focusOnFill = byKeys ? focusLevelStart : null;
        levels = [...levels, { app, opener, from: items().indexOf(row) }];
        if (!byKeys)
            forceActiveFocus();
    }

    function leave() {
        const byKeys = focusedIndex() >= 0;
        const frame = levels[levels.length - 1];
        focusOnFill = byKeys ? () => focusAt(frame.from) : null;
        levels = levels.slice(0, -1);
        frame.opener.destroy();
        if (!byKeys)
            forceActiveFocus();
    }

    function reset() {
        focusOnFill = null;
        levels.forEach(frame => frame.opener.destroy());
        levels = [];
    }

    function openMenuOf(row: Item) {
        const app = (row as AppRow)?.app;
        if (app?.hasMenu)
            enter(app, app.menu, row);
        const entry = (row as EntryRow)?.entry;
        if (entry?.hasChildren)
            enter(levels[0].app, entry, row);
    }

    function press(app: var, row: Item) {
        if (!app.onlyMenu)
            app.activate();
        else if (app.hasMenu)
            enter(app, app.menu, row);
    }

    function pressEntry(entry: var, row: Item) {
        if (entry.hasChildren)
            enter(levels[0].app, entry, row);
        else
            entry.triggered();
    }

    back: levels.length > 0 ? leave : null
    backName: levels.length > 0 ? levels[0].app.word : ""
    backWord: "zurück"
    onCurrentChanged: refill()
    // On opening rather than closing: a choice is told after the menu has closed, and its row must still be its own.
    onOpenChanged: {
        if (open)
            reset();
    }
    // → opens the menu of the focused row.
    Keys.onRightPressed: event => {
        const row = items()[focusedIndex()];
        event.accepted = row !== undefined;
        if (row)
            openMenuOf(row);
    }
    onChosen: item => {
        const app = (item as AppRow)?.app;
        if (app)
            press(app, item);
        const entry = (item as EntryRow)?.entry;
        if (entry)
            pressEntry(entry, item);
        items().forEach(row => (row as EntryRow)?.follow());
    }

    // The secondary button opens the menu of the row under the pointer, whether or not its app has a window.
    TapHandler {
        acceptedButtons: Qt.RightButton
        longPressThreshold: 0

        onTapped: eventPoint => {
            const row = parent.childAt(eventPoint.position.x, eventPoint.position.y);
            if (row)
                tray.openMenuOf(row);
        }
    }

    ListModel {
        id: rowKinds
    }

    Repeater {
        model: rowKinds

        delegate: DelegateChooser {
            role: "kind"

            DelegateChoice {
                roleValue: "app"

                AppRow {}
            }

            DelegateChoice {
                roleValue: "entry"

                EntryRow {}
            }

            DelegateChoice {
                roleValue: "separator"

                MenuSeparator {}
            }
        }
    }

    // A running app. Pressing it brings it forward; an app that is only a menu opens its menu in place.
    component AppRow: MenuItem {
        required property int at
        readonly property var app: tray.shown[at] ?? null

        text: app?.word ?? ""
        icon: app?.icon ?? ""
        keyHint: app?.state ?? ""
        opensLevel: app?.onlyMenu ?? false
        Accessible.name: keyHint !== "" ? `${text}, ${keyHint}` : text
    }

    // An entry of an app's menu; its words are the app's own.
    component EntryRow: MenuItem {
        id: row

        required property int at
        readonly property var entry: tray.shown[at] ?? null

        text: entry?.text ?? ""
        kind: entry?.buttonType === 1 ? "checkbox" : entry?.buttonType === 2 ? "radio" : "item"
        checked: entry?.checkState === Qt.Checked
        dimmed: !(entry?.enabled ?? true)
        opensLevel: entry?.hasChildren ?? false

        // The choice flips the box on its own; this lets the app's answer set it right again.
        function follow() {
            checked = Qt.binding(() => entry?.checkState === Qt.Checked);
        }
    }
}
