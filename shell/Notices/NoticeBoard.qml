import QtQuick
import Rekta

// Where the notifications the server receives go: one toast at a time, each after the one before has gone
// (platforms.md, "Behaviours to rebuild"), and the list of the notification centre, newest first. A toast runs
// duration-toast; a critical one, or one its app gives no timeout, stays until it is pressed. Low and transient ones
// toast but stay out of the list, as Plasma's defaults have it. While `quiet` only critical ones toast; the others go
// into the list unseen, and none follows as a toast later. A toast that ran out unseen stays in the list too, without
// its actions, as Plasma keeps an expired one in its history. N counts the unseen ones; opening the list sees them all,
// and what comes into the list while it is in sight is seen there.
// Rows removed from the list leave it at once and offer undo in a toast, which takes the place of a notification's
// toast; their notifications close only once that window has run out, as a closed notification cannot come back.
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
    property var waiting: []
    // The record whose toast shows, or `removal` while the undo toast does.
    property var showing: null
    // Removed rows whose undo window is still open.
    property var pending: []
    property int arrivals: 0
    readonly property var removal: ({})

    // A notification without a default action was pressed, or a row that ran out: its app should come forward.
    signal appWanted(string desktopEntry, string appName)
    // Its toast begins, so its sound hint, if any, plays now.
    signal sounding(var notification)

    function arrive(notification: var) {
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
        // Carried over a reload of the shell: it toasted before.
        if (notification.lastGeneration)
            return;
        waiting = [...waiting, record];
        next();
    }

    // What a row shows of its notification: its words as its toast has them, and the picture or else the app's icon.
    function describe(record: var, notification: var) {
        const words = toastWords(notification);
        record.summary = words.title || words.text;
        record.body = words.title ? words.text : "";
        record.icon = notification.image || iconUrl(notification.appIcon);
    }

    function listed(notification: var): bool {
        return notification.urgency !== NoticeBoard.Low && !notification.transient;
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

    function next() {
        while (!showing && waiting.length > 0) {
            const record = waiting[0];
            waiting = waiting.slice(1);
            if (quiet && record.notification.urgency !== NoticeBoard.Critical)
                collect(record);
            else
                show(record);
        }
    }

    // Nobody sees its toast: a listed one waits in the list unseen, any other has expired.
    function collect(record: var) {
        if (!listed(record.notification)) {
            record.notification.expire();
            return;
        }
        record.unseen = !listInSight;
        rows = rows.slice();
    }

    function show(record: var) {
        const notification = record.notification;
        const act = actionOf(notification, false);
        const words = toastWords(notification);
        showing = record;
        record.toast = toaster.show(words.text, {
            title: words.title,
            icon: record.icon,
            stays: notification.urgency === NoticeBoard.Critical || notification.expireTimeout === 0,
            act: act ? { label: act.text, run: () => act.invoke() } : null,
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

    // A pressed text or action has done its work by the time its toast ends; the other ends close the notification.
    // The undo toast took the place of a replaced one, which the list keeps open, as it does one collected quietly.
    function ended(record: var, reason: string) {
        if (showing === record)
            showing = null;
        const notification = record.notification;
        if (notification && reason === "expired") {
            record.unseen = !listInSight;
            notification.expire();
        } else if (notification && reason === "dismissed") {
            notification.dismiss();
        } else if (notification && reason === "replaced" && !listed(notification)) {
            notification.expire();
        }
        next();
    }

    // The server destroys a notification once it has closed; an expired one keeps its row, without actions. One its app
    // closes while it waits out its undo window is gone without undo.
    function whenClosed(record: var, reason: int) {
        waiting = waiting.filter(other => other !== record);
        record.notification = null;
        rows = reason === NoticeBoard.Expired ? rows.slice() : rows.filter(row => row !== record);
        if (showing === record)
            record.toast.leave(false, "dismissed");
        if (!pending.includes(record))
            return;
        pending = pending.filter(other => other !== record);
        if (pending.length === 0)
            toaster.open?.leave(false, "dismissed");
        else
            toaster.open.text = removedWords();
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

    // Takes rows out of the list now and closes their notifications once the undo toast has gone without undo. A
    // removal while that toast is open joins it.
    function remove(removed: var) {
        if (removed.length === 0)
            return;
        rows = rows.filter(row => !removed.includes(row));
        pending = [...pending, ...removed];
        showing = removal;
        toaster.show(removedWords(), {
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

    // A later removal that joined the toast reports its end.
    function undoEnded(reason: string) {
        if (reason === "merged")
            return;
        const removed = pending;
        pending = [];
        showing = null;
        removed.forEach(row => row.notification?.dismiss());
        next();
    }
}
