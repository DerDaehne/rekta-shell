import QtQuick
import Rekta

// Meta held alone: KWin says when Meta goes down alone and when that ends, and once it has been held for long-press
// the key map shows until it ends. Meta released after that would open the Start, as on any release of Meta alone;
// the Start asks first, and that one press is taken from it. The two reach the shell apart, in either order.
QtObject {
    id: hold

    property bool showing: false
    property bool startKeyTaken: false

    function alone() {
        startKeyTaken = false;
        waiting.restart();
    }

    function ended() {
        waiting.stop();
        showing = false;
    }

    // Whether the Start's Meta belongs to the hold that showed the map; it does once.
    function takesStartKey(): bool {
        const taken = startKeyTaken;
        startKeyTaken = false;
        return taken;
    }

    // A key held this long without another is a press held, as a touch held this long is (timing.long-press).
    property Timer waiting: Timer {
        interval: Tokens.durationLongPress
        onTriggered: {
            hold.showing = true;
            hold.startKeyTaken = true;
        }
    }
}
