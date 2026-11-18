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

    readonly property string path: "/rekta/Actions"
    readonly property string interfaceName: "rekta.Actions1"
    readonly property var providing: sessionDesktop === "rekta" ? (apps ?? []).filter(app => app.implements.includes(interfaceName)) : []
    readonly property var list: [].concat(...providing.filter(app => owners[app.id]).map(app => Rules.providedActions(app, rows[app.id] ?? [], (action, parameters) => invoke(app.id, action, parameters))))

    readonly property DBusConnection bus: DBusConnection {
        onReceived: (sender, path, iface, member, args) => providers.heard(sender, member, args)
    }

    function invoke(id: string, action: string, parameters: var): var {
        bus.call(id, path, interfaceName, "Invoke", [action, parameters], "sa{sv}", error => {
            if (error)
                console.warn(`ActionProviders: ${id}: ${action}: ${error}`);
        });
        return {};
    }

    function heard(sender: string, member: string, args: var) {
        if (member === "NameOwnerChanged" && args[0] in owners)
            own(args[0], args[2]);
        if (member !== "ActionsChanged")
            return;
        const id = Object.keys(owners).find(key => owners[key] === sender);
        if (id !== undefined)
            read(id);
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
        bus.call(id, path, interfaceName, "ListActions", [], "", (error, values) => {
            if (owners[id] !== owner)
                return;
            if (error)
                return console.warn(`ActionProviders: ${id}: ListActions: ${error}`);
            rows = Object.assign({}, rows, {
                [id]: Array.from(values[0] ?? [])
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
