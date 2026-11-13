import QtQuick

// The whole of a text its box cuts off, as the text's tip (navigation.md:445–447, behaviour.md:1082–1083; rekta.js
// :3020–3023). Declared in a text that elides or stops at maximumLineCount, it offers all of the text's words while the
// text is cut: under a resting mouse or pen as every tip comes, and at once on show(), which a control whose one text
// this is calls when the keyboard brings it focus. Cut or not counts while the tip shows or waits: it follows new
// words and goes once they fit. It offers only inside a host that sets `overflowTips` (the side panel, states.md
// :179–180), a floating surface's within its opener's host; elsewhere no tooltip draws it, and a tip held there would
// take the Escape meant for what holds the text.
Item {
    id: overflow

    readonly property Text words: parent as Text
    readonly property bool hosted: {
        for (let host = parent; host; host = host.opener ?? host.parent) {
            if (offersOverflow(host))
                return true;
        }
        return false;
    }
    readonly property string tip: enabled && hosted && words?.truncated ? words.text.trim() : ""

    // Untyped, as the hosts are of any type.
    function offersOverflow(host: var): bool {
        return host.overflowTips === true;
    }

    function show() {
        if (tip !== "")
            Tips.show(words, tip);
    }

    anchors.fill: parent

    onTipChanged: {
        if (tip === "")
            Tips.leave(words);
        else if (Tips.target === words)
            Tips.show(words, tip);
        else if (Tips.waiting === words)
            Tips.waitingText = tip;
        else if (pointer.hovered)
            Tips.rest(words, tip);
    }

    // Only a mouse or pen hovers, so touch never brings the tip.
    HoverHandler {
        id: pointer

        onHoveredChanged: {
            if (!hovered)
                Tips.leave(overflow.words);
            else if (overflow.tip !== "")
                Tips.rest(overflow.words, overflow.tip);
        }
    }
}
