import QtQuick
import RektaShell.DBus
import Start

// The actions of the running programs that offer them themselves: an app whose desktop file says
// Implements=rekta.Actions1 and which owns its desktop file ID as a bus name lists them at /rekta/Actions (ListActions),
// tells when they change (ActionsChanged) and runs one (Invoke). The shell never starts an app to list it, and an entry
// that drops its name takes its actions away. Another session than rekta's has none.
QtObject {
    id: providers

    // XDG_SESSION_DESKTOP of the session the shell runs in.
    required property string sessionDesktop
    // As Apps.list has them; null until the apps have been read.
    property var apps: null
    // The unique bus name that owns each provider's desktop file ID, "" while nobody does; only those looked up.
    property var owners: ({})
    // The rows its owner's last ListActions gave, by desktop file ID.
    property var rows: ({})
    property bool listening: false
    property int invokeTimeout: Rules.appAnswerWait

    readonly property string path: "/rekta/Actions"
    readonly property string interfaceName: "rekta.Actions1"
    readonly property var providing: sessionDesktop === "rekta" ? (apps ?? []).filter(app => app.implements.includes(interfaceName)) : []
    readonly property var list: [].concat(...providing.filter(app => owners[app.id]).map(app => Rules.providedActions(app, rows[app.id] ?? [], (action, parameters, reply) => invoke(app.id, action, parameters, reply))))

    readonly property DBusConnection bus: DBusConnection {
        onReceived: (sender, path, iface, member, args) => providers.heard(sender, member, args)
    }

    // Calls go to the owner's unique name: a call to the well-known name would start the app from its service file if the
    // owner has quit since the shell last heard.
    // The answer waits for the provider's: what it says, or its error as the reason it was not done. `reply` is the call's
    // answer to give later (DBusConnection.handler).
    function invoke(id: string, action: string, parameters: var, reply: var): var {
        const owner = owners[id] ?? "";
        if (owner === "") {
            console.warn(`ActionProviders: ${id}: ${action}: no owner`);
            return {
                done: false,
                reason: "the app is not running"
            };
        }
        bus.call(owner, path, interfaceName, "Invoke", [action, parameters], "sa{sv}", (error, values) => {
            if (error)
                console.warn(`ActionProviders: ${id}: ${action}: ${error}`);
            reply.send(null, error ? {
                done: false,
                reason: Rules.nonEmptyText(error)
            } : Rules.providedResult(values[0]));
        }, invokeTimeout);
        return reply;
    }

    function heard(sender: string, member: string, args: var) {
        if (member === "NameOwnerChanged" && args[0] in owners)
            own(args[0], args[2]);
        if (member !== "ActionsChanged")
            return;
        Object.keys(owners).filter(key => owners[key] === sender).forEach(read);
    }

    function own(id: string, owner: string) {
        owners = Object.assign({}, owners, {
            [id]: owner
        });
        if (owner !== "")
            return read(id);
        rows = Object.assign({}, rows, {
            [id]: []
        });
    }

    // Asking the bus who owns a name never starts its program.
    function lookUp(id: string) {
        owners = Object.assign({}, owners, {
            [id]: ""
        });
        bus.call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner", [id], "s", (error, values) => {
            if (!error)
                own(id, values[0]);
        });
    }

    // An answer from an owner that has gone since is dropped.
    function read(id: string) {
        const owner = owners[id];
        bus.call(owner, path, interfaceName, "ListActions", [], "", (error, values) => {
            if (owners[id] !== owner)
                return;
            if (error)
                return console.warn(`ActionProviders: ${id}: ListActions: ${error}`);
            rows = Object.assign({}, rows, {
                [id]: Rules.providedRows(values[0])
            });
        });
    }

    function lookUpNew() {
        if (listening)
            providing.filter(app => !(app.id in owners)).forEach(app => lookUp(app.id));
    }

    onProvidingChanged: lookUpNew()

    Component.onCompleted: {
        if (sessionDesktop !== "rekta")
            return;
        bus.listen("org.freedesktop.DBus", "NameOwnerChanged", "org.freedesktop.DBus", "/org/freedesktop/DBus");
        bus.listen(interfaceName, "ActionsChanged", "", path);
        listening = true;
        lookUpNew();
    }
}
