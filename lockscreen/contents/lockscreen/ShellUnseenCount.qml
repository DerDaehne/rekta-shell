import QtQuick
import RektaShell.DBus

// UnseenCount from the rekta shell over the session bus: asked once loaded and whenever the shell takes its name,
// followed by its UnseenCountChanged, and none once the shell is gone. Only Unseen loads it.
UnseenCount {
    id: unseen

    readonly property string service: "rekta.Shell"
    readonly property string path: "/rekta/Shell"
    readonly property string interfaceName: "rekta.Shell.Notices"

    readonly property DBusConnection bus: DBusConnection {
        onReceived: (sender, path, iface, member, args) => {
            if (member === "UnseenCountChanged")
                unseen.take(args[0]);
            else if (args[0] === unseen.service)
                unseen.ownerChanged(args[2]);
        }
    }

    function ask() {
        bus.call(service, path, interfaceName, "UnseenCount", [], "", (error, values) => take(error === null ? values[0] : 0));
    }

    function ownerChanged(owner: string) {
        if (owner === "")
            take(0);
        else
            ask();
    }

    Component.onCompleted: {
        // Only the name's owner is heard, so no other program on the bus can speak for the shell.
        bus.listen(interfaceName, "UnseenCountChanged", service, path);
        bus.listen("org.freedesktop.DBus", "NameOwnerChanged", "org.freedesktop.DBus", "/org/freedesktop/DBus");
        ask();
    }
}
