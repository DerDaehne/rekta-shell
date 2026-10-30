import QtQuick
import Rekta
import RektaShell.DBus

// The windows step back behind the Start at the Start's tempo, in the shell's timers and in KWin's fade-back alike. The
// effect runs in KWin's engine, where Prefs must never be created, so the shell tells it the tempo over KWin's bus: as
// it starts and whenever the setting changes. A layer surface cannot carry it: its namespace is fixed once mapped, and
// KWin keeps of its keyboard only whether it takes one.
QtObject {
    id: tempo

    readonly property real startTempo: Prefs.startTempo

    readonly property DBusConnection bus: DBusConnection {}

    readonly property list<Binding> bindings: [
        Binding {
            target: FadeBack
            property: "startTempo"
            value: tempo.startTempo
        }
    ]

    // Outside the rekta session no effect answers, and the call fails unheard.
    function tellKWin() {
        bus.call("org.kde.KWin", "/RektaFadeBack", "org.rekta.FadeBack", "setStartTempo", [startTempo], "d");
    }

    onStartTempoChanged: tellKWin()
    Component.onCompleted: tellKWin()
}
