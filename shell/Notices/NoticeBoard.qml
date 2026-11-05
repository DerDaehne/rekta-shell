import QtQuick
import Rekta
import State

// Where the notifications the server receives go: the list of the notification centre, newest first, and a toast as
// each arrives, which takes the place of the toast open (live.md:83–85; behaviour.md `toaster()`). No toast waits for
// another, so none follows one that has gone. A toast runs duration-toast, whatever timeout its app gives; a critical
// one stays until it is pressed, and what arrives meanwhile, a critical one too, goes into the list only
// (live.md:86–88). A low one goes to the list only, open and without a toast (live.md:86), and is never unseen; a
// transient one toasts but stays out of the list, as Plasma's defaults have it. While `quiet` only critical ones toast;
// the others go into the list unseen, and none follows as a toast later. A toast that ran out unseen stays in the list
// too, without its actions, as Plasma keeps an expired one in its history; one whose app gives it no timeout (0) never
// expires, so it keeps its actions there, as one collected quietly or one whose toast another replaced does. N counts
// the unseen ones; opening the list sees them all, and what comes into the list while it is in sight is seen there.
// Rows removed from the list leave it at once and offer undo in a toast; their notifications close only once that
// window has run out, as a closed notification cannot come back. A toast that takes the undo toast's place leaves the
// window running, and Ctrl+Z still brings the rows back until it ends (states.md:67–69; live.md:115–116).
// A notification here is the server's: appName, appIcon, summary, body, urgency, actions ({ identifier, text,
// invoke() }), image, desktopEntry, transient, expireTimeout, lastGeneration, expire(), dismiss() and closed(reason).
QtObject {
    id: board

    enum Urgency {
        Low,
        Normal,
        Critical
    }

    enum CloseReason {
        Expired = 1,
        Dismissed,
        CloseRequested
    }

    required property Toaster toaster
    property bool quiet: false
    property bool listInSight: false
    // An image URL for an app icon's name or path.
    property var iconUrl: name => name
    // Newest first: { notification (null once it has closed), order (by arrival), appName, desktopEntry, summary,
    // body, icon, time, unseen, toast }. Every change hands out a new array.
    property var rows: []
    readonly property int unseen: rows.filter(row => row.unseen).length
    // The id of the app a notification belongs to, from its desktop-entry hint and its app name.
    property var appOf: (desktopEntry, appName) => desktopEntry || appName
    // The unseen ones by app: { appId: count }.
    readonly property var unseenByApp: {
        const counts = {};
        for (const row of rows.filter(row => row.unseen)) {
            const app = appOf(row.desktopEntry, row.appName);
            if (app)
                counts[app] = (counts[app] ?? 0) + 1;
        }
        return counts;
    }
    // The record whose toast shows; null while none does.
    property var showing: null
    // Removed rows whose undo window is still open.
    property var pending: []
    // The undo toast while it is open.
    property Toast undoToast: null
    // When the window of a replaced undo toast ends, in the toaster's wall-clock time.
    property double undoUntil: 0
    // Runs out with that window.
    readonly property Timer undoLeft: Timer {
        onTriggered: board.waitOutUndo()
    }
    property var removeUndoLayer: null
    property int arrivals: 0
    // freespacenotifier's notice starts a state the system banner shows, so it is neither toast nor row. The notice's
    // closing does not end it (Quickshell closes it after any action): only `storageChecked` does, once enough is free.
    // ponytail: one such notice at a time; a second one replaces the first. Once the notice has gone, the remedy has no
    // action to call until freespacenotifier warns again, and the banner's sentence keeps the notice's last figures.
    // Upgrade: remember the action and check the disk the notice names, so that the remedy opens the file manager.
    property var storageNotice: null
    property string storageText: ""
    property bool storageFull: false

    // A notification without a default action was pressed, or a row that ran out: its app should come forward.
    signal appWanted(string desktopEntry, string appName)
    // Its toast begins, so its sound hint, if any, plays now.
    signal sounding(var notification)

    function arrive(notification: var) {
        const hints = notification.hints ?? {};
        if (Sources.lowBatteryNotice(hints))
            return;
        if (Sources.freeSpaceNotice(hints)) {
            holdStorage(notification);
            return;
        }
        const record = {
            notification,
            order: ++arrivals,
            appName: notification.appName,
            desktopEntry: notification.desktopEntry,
            time: new Date(),
            unseen: false,
            toast: null
        };
        describe(record, notification);
        notification.closed.connect(reason => whenClosed(record, reason));
        notification.summaryChanged.connect(() => refresh(record));
        notification.bodyChanged.connect(() => refresh(record));
        if (listed(notification))
            rows = [record, ...rows];
        if (!toasts(notification)) {
            // Neither toast nor row: nobody sees it.
            if (!listed(notification))
                notification.expire();
            return;
        }
        if (silenced(notification))
            collect(record);
        else
            show(record);
    }

    // Carried over a reload of the shell, it toasted before; a low one never has a toast.
    function toasts(notification: var): bool {
        return !notification.lastGeneration && notification.urgency !== NoticeBoard.Low;
    }

    function holdStorage(notification: var) {
        storageNotice = notification;
        storageFull = true;
        storageText = notification.body || notification.summary;
        notification.closed.connect(() => {
            if (storageNotice === notification)
                storageNotice = null;
        });
        const reword = () => {
            if (storageNotice === notification)
                storageText = notification.body || notification.summary;
        };
        notification.summaryChanged.connect(reword);
        notification.bodyChanged.connect(reword);
    }

    // What the shell's own look at the free space found: the state ends only when enough is free again and the
    // notice has gone (freespacenotifier closes it itself when its disk has room, and may mean another disk).
    function storageChecked(enough: bool) {
        if (enough && storageNotice === null)
            storageFull = false;
    }

    // The remedy of the storage state: the notice's first action, which opens the program that clears space.
    function cleanUp() {
        storageNotice?.actions.find(action => action.identifier !== "default")?.invoke();
    }

    // What a row shows of its notification: its words as its toast has them, and the picture or else the app's icon.
    function describe(record: var, notification: var) {
        const words = toastWords(notification);
        record.summary = words.title || words.text;
        record.body = words.title ? words.text : "";
        record.icon = notification.image || iconUrl(notification.appIcon);
    }

    function listed(notification: var): bool {
        return !notification.transient;
    }

    // Some apps send their words as the body alone.
    function headline(notification: var): string {
        return notification.summary || notification.body;
    }

    // A summary over a body; either alone is the toast's one sentence.
    function toastWords(notification: var): var {
        const titled = notification.summary !== "" && notification.body !== "";
        return { title: titled ? notification.summary : "", text: titled ? notification.body : headline(notification) };
    }

    function actionOf(notification: var, isDefault: bool): var {
        return notification?.actions.find(action => (action.identifier === "default") === isDefault) ?? null;
    }

    // The actions a row offers besides the default one, at most two, as { identifier, text }; none once it has run out.
    function actionsOf(row: var): var {
        const actions = row.notification?.actions ?? [];
        const offered = actions.filter(action => action.identifier !== "default").slice(0, 2);
        return offered.map(action => ({ identifier: action.identifier, text: action.text }));
    }

    // A press on one of a row's actions does what a press on a toast's action does.
    function invokeAction(row: var, identifier: string) {
        row?.notification?.actions.find(action => action.identifier === identifier)?.invoke();
    }

    // While `quiet` only critical ones toast, and behind a critical toast that stands none does (live.md:87–88).
    function silenced(notification: var): bool {
        const critical = notification.urgency === NoticeBoard.Critical;
        return (quiet && !critical) || showing?.notification?.urgency === NoticeBoard.Critical;
    }

    // No toast shows it (any more), yet nothing closed it: a listed one waits in the list unseen, any other has expired.
    function collect(record: var) {
        if (!listed(record.notification)) {
            record.notification.expire();
            return;
        }
        record.unseen = !listInSight;
        rows = rows.slice();
    }

    // A critical one says so in a neutral tag, without a status colour: urgency is not a status (live.md:86–91).
    function show(record: var) {
        const notification = record.notification;
        const act = actionOf(notification, false);
        const words = toastWords(notification);
        const critical = notification.urgency === NoticeBoard.Critical;
        showing = record;
        record.toast = toaster.show(words.text, {
            title: words.title,
            icon: record.icon,
            tag: critical ? "dringend" : "",
            stays: critical,
            act: act ? { label: act.text, run: () => act.invoke() } : null,
            notification: true,
            open: { run: () => pressed(notification) },
            onEnd: reason => ended(record, reason)
        });
        sounding(notification);
    }

    function pressed(notification: var) {
        const defaultAction = actionOf(notification, true);
        if (defaultAction) {
            defaultAction.invoke();
            return;
        }
        appWanted(notification.desktopEntry, notification.appName);
        notification.dismiss();
    }

    // A pressed text or action has done its work by the time its toast ends; a dismissed one closes, and a run-out one
    // expires unless its app says it never does. The list keeps one whose toast another replaced open, as it does one
    // collected quietly.
    function ended(record: var, reason: string) {
        if (showing === record)
            showing = null;
        const notification = record.notification;
        if (!notification)
            return;
        if (reason === "replaced" || (reason === "expired" && notification.expireTimeout === 0)) {
            collect(record);
        } else if (reason === "expired") {
            record.unseen = !listInSight;
            notification.expire();
        } else if (reason === "dismissed") {
            notification.dismiss();
        }
    }

    // The server destroys a notification once it has closed; an expired one keeps its row, without actions. One its app
    // closes while it waits out its undo window is gone without undo.
    function whenClosed(record: var, reason: int) {
        record.notification = null;
        rows = reason === NoticeBoard.Expired ? rows.slice() : rows.filter(row => row !== record);
        if (showing === record)
            record.toast.leave(false, "dismissed");
        if (!pending.includes(record))
            return;
        pending = pending.filter(other => other !== record);
        if (undoToast && pending.length > 0)
            undoToast.text = removedWords();
        else if (undoToast)
            undoToast.leave(false, "dismissed");
    }

    // The app replaced it: the same notification, new words. A removed one stays removed, for good.
    function refresh(record: var) {
        const notification = record.notification;
        if (!notification)
            return;
        if (pending.includes(record)) {
            notification.dismiss();
            return;
        }
        describe(record, notification);
        rows = rows.slice();
        if (showing !== record)
            return;
        const words = toastWords(notification);
        record.toast.title = words.title;
        record.toast.text = words.text;
    }

    onListInSightChanged: {
        if (listInSight)
            seen();
    }

    function seen() {
        rows.forEach(row => row.unseen = false);
        rows = rows.slice();
    }

    // A press on a row does what a press on its toast does; a row that ran out has no actions left, so its app comes
    // forward and the row goes.
    function press(row: var) {
        if (row.notification) {
            pressed(row.notification);
            return;
        }
        rows = rows.filter(other => other !== row);
        appWanted(row.desktopEntry, row.appName);
    }

    // Takes rows out of the list now and closes their notifications once their undo window has run out without undo. A
    // removal while that toast is open joins it, and one while a replaced toast's window runs takes its rows along.
    function remove(removed: var) {
        if (removed.length === 0)
            return;
        rows = rows.filter(row => !removed.includes(row));
        pending = [...pending, ...removed];
        undoToast = toaster.show(removedWords(), {
            key: "removed",
            undo: () => restore(),
            onEnd: reason => undoEnded(reason)
        });
    }

    function removedWords(): string {
        return pending.length === 1 ? "meldung entfernt" : `${pending.length} meldungen entfernt`;
    }

    // Undo puts the rows back where they were: the list keeps the order of arrival.
    function restore() {
        rows = [...rows, ...pending].sort((a, b) => b.order - a.order);
        pending = [];
    }

    // A later removal that joined the toast reports its end. A replaced toast leaves the rows the rest of their window,
    // as much as its figure last showed.
    function undoEnded(reason: string) {
        if (reason === "merged")
            return;
        const left = undoToast.shownLeft;
        undoToast = null;
        if (reason !== "replaced") {
            closeRemoved();
            return;
        }
        undoUntil = toaster.now() + left;
        waitOutUndo();
    }

    // Each step reads the wall clock, so a late timer closes them at once. An undo toast open again holds them in its
    // own window.
    function waitOutUndo() {
        if (undoToast)
            return;
        const left = undoUntil - toaster.now();
        if (left <= 0) {
            closeRemoved();
            return;
        }
        undoLeft.interval = left;
        undoLeft.restart();
    }

    function closeRemoved() {
        const removed = pending;
        pending = [];
        removed.forEach(row => row.notification?.dismiss());
    }

    // Ctrl+Z after a replaced undo toast, while its window lasts (KeyLayers: undo 4). An open one takes it first.
    function undoOnCtrlZ(event: KeyEvent): bool {
        if (pending.length === 0 || toaster.now() >= undoUntil || !toaster.isUndoKey(event))
            return false;
        restore();
        return true;
    }

    Component.onCompleted: removeUndoLayer = KeyLayers.on(4, event => undoOnCtrlZ(event))
    Component.onDestruction: removeUndoLayer()
}
