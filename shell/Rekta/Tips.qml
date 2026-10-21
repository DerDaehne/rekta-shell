pragma Singleton
import QtQuick

// Which control's tip shows, one at a time (navigation.md, "Tooltips"; rekta.js tips(), :2530–2615). A tip shows after
// the pointer has rested on its control for tip-delay, at once when focus arrives by keyboard or when moving on from
// another tip, never on touch: controls report only a mouse or pen. Escape (key layer 45), a press, scrolling or
// leaving hide it; the host reports presses and scrolling anywhere with hide(). A Tooltip draws it.
QtObject {
    id: tips

    // The control whose tip shows, and its words.
    property Item target: null
    property string text
    // The control the pointer rests on while tip-delay runs.
    property Item waiting: null
    property string waitingText
    // When a tip last hid: a pointer that moves on within tip-delay shows the next one at once.
    property double hiddenAt: -Infinity

    readonly property Timer delay: Timer {
        interval: Tokens.durationTipDelay
        onTriggered: tips.show(tips.waiting, tips.waitingText)
    }

    // The pointer (a mouse or pen) came onto a control.
    function rest(control: Item, words: string) {
        if (control === target)
            return;
        if (target || Date.now() - hiddenAt < Tokens.durationTipDelay) {
            show(control, words);
            return;
        }
        waiting = control;
        waitingText = words;
        delay.restart();
    }

    // At once: focus arrived by keyboard, or the pointer moved on from another tip.
    function show(control: Item, words: string) {
        delay.stop();
        waiting = null;
        text = words;
        target = control;
    }

    // The pointer or the focus left a control.
    function leave(control: Item) {
        if (control === target || control === waiting)
            hide();
    }

    function hide() {
        delay.stop();
        waiting = null;
        if (!target)
            return;
        target = null;
        hiddenAt = Date.now();
    }

    Component.onCompleted: KeyLayers.on(45, event => {
        if (event.key !== Qt.Key_Escape || !tips.target)
            return false;
        tips.hide();
        return true;
    })
}
