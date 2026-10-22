import QtQuick
import Rekta

// Where the notifications the server receives go: one toast at a time, each after the one before has gone
// (platforms.md, "Behaviours to rebuild"), and a list behind "meldungen N", newest first. A toast runs duration-toast;
// a critical one, or one its app gives no timeout, stays until it is pressed. Low and transient ones toast but stay
// out of the list, as Plasma's defaults have it. While `quiet` only critical ones toast; the others go into the list
// unseen, and none follows as a toast later. A toast that ran out unseen stays in the list too, without its actions,
// as Plasma keeps an expired one in its history. N counts the unseen ones; opening the list sees them all.
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
    // An image URL for an app icon's name or path.
    property var iconUrl: name => name
    // Newest first: { notification (null once it has closed), app, summary, time, unseen, toast }.
    // ponytail: every change hands out a new array, so an open list builds its rows anew and a focused row loses the
    // focus; a ListModel would keep them, should a notification arriving under an open list bother.
    property var rows: []
    readonly property int unseen: rows.filter(row => row.unseen).length
    property var waiting: []
    property var showing: null

    // The text of a notification without a default action was pressed: its app should come forward.
    signal appWanted(var notification)
    // Its toast begins, so its sound hint, if any, plays now.
    signal sounding(var notification)

    function arrive(notification: var) {
        const record = {
            notification,
            app: notification.appName || notification.desktopEntry,
            summary: headline(notification),
            time: new Date(),
            unseen: false,
            toast: null
        };
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

    function canAct(row: var): bool {
        return actionOf(row.notification, true) !== null;
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
        record.unseen = true;
        rows = rows.slice();
    }

    function show(record: var) {
        const notification = record.notification;
        const act = actionOf(notification, false);
        const words = toastWords(notification);
        showing = record;
        record.toast = toaster.show(words.text, {
            title: words.title,
            icon: notification.image || iconUrl(notification.appIcon),
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
        appWanted(notification);
        notification.dismiss();
    }

    // A pressed text or action has done its work by the time its toast ends; the other ends close the notification.
    function ended(record: var, reason: string) {
        showing = null;
        const notification = record.notification;
        if (notification && reason === "expired") {
            record.unseen = true;
            notification.expire();
        } else if (notification && reason === "dismissed") {
            notification.dismiss();
        }
        next();
    }

    // The server destroys a notification once it has closed; an expired one keeps its row, without actions.
    function whenClosed(record: var, reason: int) {
        waiting = waiting.filter(other => other !== record);
        record.notification = null;
        rows = reason === NoticeBoard.Expired ? rows.slice() : rows.filter(row => row !== record);
        if (showing === record)
            record.toast.leave(false, "dismissed");
    }

    // The app replaced it: the same notification, new words.
    function refresh(record: var) {
        const notification = record.notification;
        if (!notification)
            return;
        record.summary = headline(notification);
        rows = rows.slice();
        if (showing !== record)
            return;
        const words = toastWords(notification);
        record.toast.title = words.title;
        record.toast.text = words.text;
    }

    function seen() {
        rows.forEach(row => row.unseen = false);
        rows = rows.slice();
    }

    function choose(row: var) {
        actionOf(row.notification, true)?.invoke();
    }

    function clear() {
        const all = rows;
        rows = [];
        all.forEach(row => row.notification?.dismiss());
    }
}
