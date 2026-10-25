import QtQuick
import RektaShell.DBus

// Ctrl+Alt+Del and KDE's logout, shut down and restart commands ask org.kde.LogoutPrompt for the session prompt. In
// the rekta session the shell answers in place of Plasma's logout greeter; in any other session it leaves the name to
// Plasma.
QtObject {
    id: prompt

    // XDG_SESSION_DESKTOP of the session the shell runs in.
    required property string sessionDesktop

    // "logout", "shutdown", "reboot" or "all".
    signal requested(string kind)

    readonly property var kinds: ({
            promptLogout: "logout",
            promptShutDown: "shutdown",
            promptReboot: "reboot",
            promptAll: "all"
        })

    readonly property DBusConnection bus: DBusConnection {
        handler: (path, iface, member) => prompt.requested(prompt.kinds[member])
    }

    Component.onCompleted: {
        if (sessionDesktop !== "rekta")
            return;
        bus.own("org.kde.LogoutPrompt", "/LogoutPrompt", `
            <interface name="org.kde.LogoutPrompt">
              <method name="promptLogout"/>
              <method name="promptShutDown"/>
              <method name="promptReboot"/>
              <method name="promptAll"/>
            </interface>`);
    }
}
