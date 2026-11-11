import QtQml
import Notices

// Notifications as the server hands them over, in plain JS, as QML reserves "transient". `actions` are [identifier,
// text] pairs; invoking one tells the app and closes the notification, as the server does for one that is not
// resident. The server closes a notification once; a second close is a mistake the calls show.
QtObject {
    id: fakes

    // What the apps were told, oldest first.
    property var calls: []

    // A signal as a notification has them, to connect() to; the test emit()s it.
    function signal(): var {
        const handlers = [];
        return {
            connect: handler => handlers.push(handler),
            emit: (...args) => handlers.forEach(handler => handler(...args))
        };
    }

    function make(properties: var, actions: var): var {
        const fake = Object.assign({
            lastGeneration: false,
            appName: "chat",
            appIcon: "",
            summary: "anna",
            body: "lunch at noon?",
            urgency: NoticeBoard.Normal,
            expireTimeout: -1,
            transient: false,
            desktopEntry: "org.example.chat",
            image: "",
            hints: {},
            closedWith: 0,
            closed: signal(),
            summaryChanged: signal(),
            bodyChanged: signal()
        }, properties);
        fake.close = reason => {
            fakes.calls = [...fakes.calls, `${fake.summary} closed ${fake.closedWith ? "again " : ""}${reason}`];
            if (fake.closedWith)
                return;
            fake.closedWith = reason;
            fake.closed.emit(reason);
        };
        fake.expire = () => fake.close(NoticeBoard.Expired);
        fake.dismiss = () => fake.close(NoticeBoard.Dismissed);
        fake.actions = (actions ?? []).map(([identifier, text]) => ({
            identifier,
            text,
            invoke: () => {
                fakes.calls = [...fakes.calls, `${fake.summary} invoked ${identifier}`];
                fake.dismiss();
            }
        }));
        return fake;
    }
}
