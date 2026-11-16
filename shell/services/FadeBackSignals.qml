import QtQml
import RektaShell.DBus

// A connection to KWin's rekta-fadeback that runs handlers[member](...args) for the signals named in handlers and
// subscribes to no others, so the effect's other signals never wake the shell (a SignalWatcher takes them all and warns
// about each one without a handler). Outside the rekta session nothing answers.
DBusConnection {
    // Signal name to function; read once, when the connection is made.
    required property var handlers

    Component.onCompleted: Object.keys(handlers).forEach(member => listen("org.rekta.FadeBack", member, "org.kde.KWin", "/RektaFadeBack"))
    onReceived: (sender, path, interfaceName, member, args) => handlers[member](...args)
}
