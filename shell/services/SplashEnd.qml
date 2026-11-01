import QtQuick
import Rekta
import RektaShell.DBus

// KSplash waits for the desktop stage, which plasmashell reports in Plasma; without it the splash stays until its
// timeout. The shell reports it once, as soon as what stands under the splash has drawn, and KWin's fade-back fades the
// splash onto it in duration-moderate. Then the shell has arrived: what comes after the splash comes in.
QtObject {
    id: splash

    // The surfaces the splash fades onto have drawn their first frame.
    property bool ready: false
    // The splash has faded, or was never there to fade.
    property bool arrived: false
    property bool reported: false

    readonly property DBusConnection bus: DBusConnection {}

    readonly property Timer fading: Timer {
        interval: Tokens.durationModerate
        onTriggered: splash.arrived = true
    }

    // Without a splash, as after a restart of the shell, the call fails unheard.
    function end() {
        if (!ready || reported)
            return;
        reported = true;
        console.info("SplashEnd: the ground and the Start's surface have drawn; the splash ends");
        bus.call("org.kde.KSplash", "/KSplash", "org.kde.KSplash", "setStage", ["desktop"], "s");
        fading.start();
    }

    onReadyChanged: end()
    Component.onCompleted: end()
}
