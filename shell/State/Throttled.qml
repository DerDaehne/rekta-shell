import QtQuick

// A text that follows `source` at most once per `interval`: the first change after quiet shows at once, later ones wait
// for the interval's end and show the newest. A new `owner` (the active window) shows its text at once. The timer runs
// only while a change is waiting.
QtObject {
    id: throttled

    property string source
    property var owner: null
    property int interval: 1000
    property string value

    property var seenOwner
    property bool ready: false

    function follow() {
        if (!ready)
            return;
        if (owner !== seenOwner) {
            seenOwner = owner;
            hold.stop();
            value = source;
            return;
        }
        if (value === source || hold.running)
            return;
        value = source;
        hold.start();
    }

    Component.onCompleted: {
        seenOwner = owner;
        value = source;
        ready = true;
    }
    onSourceChanged: follow()
    onOwnerChanged: follow()

    property Timer hold: Timer {
        interval: throttled.interval

        onTriggered: {
            if (throttled.value === throttled.source)
                return;
            throttled.value = throttled.source;
            start();
        }
    }
}
