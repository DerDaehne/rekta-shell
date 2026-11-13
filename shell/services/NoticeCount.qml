import QtQuick
import RektaShell.DBus

// The number of unseen notifications, the one "meldungen N" shows, for the lock screen of the rekta session, which runs
// in a process of its own: rekta.Shell answers UnseenCount() at /rekta/Shell and sends UnseenCountChanged on each
// change. Only the number leaves the shell, nothing of a notification. In any other session it owns nothing.
QtObject {
    id: notices

    // XDG_SESSION_DESKTOP of the session the shell runs in.
    required property string sessionDesktop
    property int count: 0
    property bool exported: false

    readonly property string path: "/rekta/Shell"
    readonly property string interfaceName: "rekta.Shell.Notices"

    readonly property DBusConnection bus: DBusConnection {
        handler: () => notices.count
    }

    onCountChanged: {
        if (exported)
            bus.emitSignal(path, interfaceName, "UnseenCountChanged", [count], "u");
    }

    Component.onCompleted: {
        if (sessionDesktop !== "rekta")
            return;
        exported = bus.own("rekta.Shell", path, `
            <interface name="${interfaceName}">
              <method name="UnseenCount">
                <arg type="u" direction="out"/>
              </method>
              <signal name="UnseenCountChanged">
                <arg type="u"/>
              </signal>
            </interface>`);
    }
}
