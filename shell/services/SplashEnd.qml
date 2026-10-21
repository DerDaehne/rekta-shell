import QtQuick
import org.kde.plasma.workspace.dbus as DBus

// KSplash waits for the desktop stage, which plasmashell reports in Plasma; without it the splash stays until its
// timeout.
// ponytail: reported once the shell has loaded, as it has no surface yet, and through plasma-workspace's DBus module;
// move it to the first surface's first frame, and to the shell's own DBus module once there is one.
QtObject {
    Component.onCompleted: DBus.SessionBus.asyncCall({
        service: "org.kde.KSplash",
        path: "/KSplash",
        iface: "org.kde.KSplash",
        member: "setStage",
        arguments: [new DBus.string("desktop")],
        signature: "(s)"
    })
}
