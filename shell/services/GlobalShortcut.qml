import QtQuick
import Quickshell
import org.kde.plasma.workspace.dbus as DBus

// A global shortcut of the shell in KWin's kglobalaccel, component "rekta-shell". KWin holds the keys from the first
// registration until KWin itself ends, so they survive reloads and restarts of the shell. System Settings lists the
// shortcut and may give it other keys; those then win over the defaults given here.
// ponytail: through plasma-workspace's DBus module, which reaches kglobalaccel's fixed name and path; move it to the
// shell's own DBus module once there is one.
Scope {
    id: shortcut

    required property string name
    required property string text
    // Qt key combinations: Qt.Key_Meta alone, or Qt.MetaModifier | Qt.Key_Tab.
    required property list<int> keys

    signal pressed

    readonly property string component: "rekta-shell"
    readonly property list<string> actionId: [component, name, component, text]

    function callKGlobalAccel(member: string, signature: string, args: list<var>) {
        DBus.SessionBus.asyncCall({
            service: "org.kde.kglobalaccel",
            path: "/kglobalaccel",
            iface: "org.kde.KGlobalAccel",
            member: member,
            arguments: args,
            signature: signature
        });
    }

    // The order of KGlobalAccel's own client: register, give the defaults, then take the keys the user chose, if any.
    Component.onCompleted: {
        const isDefault = 8;
        const setPresent = 2;
        callKGlobalAccel("doRegister", "(as)", [actionId]);
        callKGlobalAccel("setShortcut", "(asaiu)", [actionId, keys, isDefault]);
        callKGlobalAccel("setShortcut", "(asaiu)", [actionId, keys, setPresent]);
    }

    DBus.SignalWatcher {
        service: "org.kde.kglobalaccel"
        // kglobalaccel's object path for the component: its name with every character outside [A-Za-z0-9_] as "_".
        path: "/component/rekta_shell"
        iface: "org.kde.kglobalaccel.Component"

        function dbusglobalShortcutPressed(component: string, action: string, timestamp: real) {
            if (action === shortcut.name)
                shortcut.pressed();
        }
    }
}
