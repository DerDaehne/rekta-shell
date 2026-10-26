pragma ComponentBehavior: Bound
import QtQuick
import "Status.js" as Status

// The status banner (behaviour.md `banner()`; rekta.css:932–960): one lasting system state at a time, the most severe
// that is on, across the top on its status fill; the neutral state stands on surface with a hairline below. The state's
// word stands large and light in a column one tile-unit wide, the time it started under it, so the sentence starts on
// tile column 2; a remedy may follow. Word, sentence and remedy share a first baseline. A new state fades in 8px once,
// the place below moving with it, then holds still; a new sentence is written in place. A state that ends is an event:
// the toaster says so once the banner has gone. The host puts it in flow at the top of its place, full bleed.
// ponytail: the sideways layout only (desktop screens); the compact one from rekta.css:1087–1092 comes with a phone-
// sized host.
Item {
    id: banner

    // { name: { word, status, alert, text, action, since, until, on, off } }. `alert: true` only for a halt; `since` is
    // the word before the time, `until` a known end in its place; `on` and `off` are the toasts for a state that starts
    // or ends while another holds the banner, or that ends.
    property var bannerStates: ({})
    // Most severe first.
    property var order: Object.keys(bannerStates)
    property Toaster toaster: null
    // remedy(name) runs the shown state's remedy; without it, the remedy turns the state off.
    property var remedy: null
    // The width of the place it spans; the word's fluid size follows it.
    property real placeWidth: Window.width

    // The state that holds the banner, or "" for none. Set by set(), never from outside.
    property string shown: ""
    // What the banner shows; it keeps showing it while it leaves.
    property string status: ""
    property bool alert: false
    property string word
    property string timeLine
    property string sentence
    property string actionLabel
    readonly property string spoken: [word, timeLine, sentence].filter(part => part !== "").join(" ")
    // The app bar follows the banner (behaviour.md, `data-rk-state`): halted for an error, paused for a warning.
    readonly property string appbarState: status === "error" ? "halted" : status === "warning" ? "paused" : ""
    // The live word of the app bar: the state's word while one holds the banner.
    readonly property string liveWord: shown !== "" ? word : "live"
    // On a status fill only the primary text colour clears AA; Status.secondaryInk() reads this (rekta.css:65).
    readonly property bool statusFill: status !== ""
    readonly property bool leaving: going.running

    property var turnedOn: ({})
    property var started: ({})
    // A new sentence for a state that is on, written by update().
    property var sentences: ({})
    // Where focus goes when the banner leaves with it.
    property Item setBy: null
    // The state whose end cleared the banner; the toaster reports it once the banner has gone.
    property string ended: ""

    // Runs from 0 to 1 as a state comes in; leaving runs it back. The curve sits in `entry`, so a leave plays the same
    // curve backwards, as the stylesheet's reversed keyframes do.
    property real phase: 0
    readonly property easingCurve easeIn: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })
    readonly property real entry: easeIn.valueForProgress(phase)
    // The height it glides from: none from clear, the old one for a change of kind.
    property real heightFrom: 0

    readonly property real padX: Tokens.spaceXl
    readonly property real padY: Tokens.spaceM
    // `.rk-banner-live { flex: 1 1 calc(3 × tile-unit + 2 × space-s) }`: below that the remedy takes a line of its own.
    readonly property real liveBasis: 3 * Tokens.tileUnit + 2 * Tokens.spaceS
    readonly property bool hasRemedy: actionLabel !== ""
    readonly property bool remedyBeside: hasRemedy && width - 2 * padX - Tokens.spaceL - remedyButton.width >= liveBasis
    readonly property real liveWidth: width - 2 * padX - (remedyBeside ? Tokens.spaceL + remedyButton.width : 0)
    readonly property real headWidth: Math.max(Tokens.tileUnit, wordText.implicitWidth, timeText.implicitWidth)
    // `.rk-banner-msg { flex: 1 1 calc(2 × tile-unit + space-s); max-width: calc(4 × tile-unit + 3 × space-s) }`
    readonly property real sentenceBasis: 2 * Tokens.tileUnit + Tokens.spaceS
    readonly property real sentenceMax: 4 * Tokens.tileUnit + 3 * Tokens.spaceS
    readonly property bool sentenceBeside: liveWidth - headWidth - Tokens.spaceS >= sentenceBasis
    // The first line's baseline, from the top of the content.
    readonly property real firstBaseline: Math.max(wordText.baselineOffset, sentenceBeside ? sentenceText.baselineOffset : 0, remedyBeside ? remedyButton.baselineOffset : 0)
    readonly property real headHeight: wordText.height + (timeLine !== "" ? Tokens.spaceXs + timeText.height : 0)
    readonly property real headBottom: firstBaseline - wordText.baselineOffset + headHeight
    readonly property real sentenceTop: sentenceBeside ? firstBaseline - sentenceText.baselineOffset : headBottom + Tokens.spaceS
    readonly property real liveBottom: Math.max(headBottom, sentenceTop + sentenceText.height)
    readonly property real remedyTop: remedyBeside ? firstBaseline - remedyButton.baselineOffset : liveBottom + Tokens.spaceM
    readonly property real contentHeight: 2 * padY + Math.max(liveBottom, hasRemedy ? remedyTop + remedyButton.height : 0) + (statusFill ? 0 : Geometry.hairline)

    function set(name: string, on: bool, options: var) {
        const o = Object.assign({ from: null, since: undefined, text: undefined }, options);
        known(name);
        if (!!turnedOn[name] === on) {
            if (on && o.text !== undefined)
                update(name, o.text);
            return;
        }
        if (o.text !== undefined)
            sentences[name] = o.text;
        turnedOn[name] = on;
        if (on)
            started[name] = startOf(o.since);
        sync(name, o.from);
    }

    function toggle(name: string, options: var) {
        set(name, !isOn(name), options);
    }

    function isOn(name: string): bool {
        return !!turnedOn[name];
    }

    // A state that is on gets a new sentence (a figure that changes): written in place, not announced again; its start
    // stays.
    function update(name: string, text: string) {
        known(name);
        sentences[name] = text;
        if (shown === name)
            sentence = text;
    }

    function known(name: string) {
        if (!(name in bannerStates))
            throw new Error(`unknown banner state ${name}`);
    }

    // The start is now, the one given, or unknown (false): then there is no time line rather than a wrong one.
    function startOf(since: var): var {
        if (since === false || since === null)
            return null;
        const start = since === undefined ? new Date() : new Date(since);
        return isNaN(start) ? null : start;
    }

    function textOf(name: string): string {
        return sentences[name] ?? bannerStates[name].text ?? "";
    }

    function wordOf(name: string): string {
        return bannerStates[name].word || name;
    }

    // "since 14:05", with the day when it started on another day; `until` in place of the start for a known end.
    function timeLineOf(name: string): string {
        const s = bannerStates[name];
        const since = s.since || "since";
        if (s.until)
            return `${since} ${s.until}`;
        const start = started[name];
        if (!start)
            return "";
        const today = start.toDateString() === new Date().toDateString();
        return `${since} ${today ? start.toLocaleTimeString(Qt.locale(), Locale.ShortFormat) : start.toLocaleString(Qt.locale(), Locale.ShortFormat)}`;
    }

    function sync(changed: string, from: Item) {
        const name = order.find(n => turnedOn[n]) ?? "";
        if (name === shown) {
            if (toaster)
                toaster.show(`${eventOf(changed)}. The banner keeps showing “${wordOf(name)}” until that ends.`, { key: "state" });
            return;
        }
        const before = shown;
        shown = name;
        if (from)
            setBy = from;
        if (name === "") {
            clear(changed);
            return;
        }
        showState(name);
        if (before !== "" && !turnedOn[changed] && toaster)
            toaster.show(bannerStates[changed].off, { key: "state" });
    }

    // What happened to a state while another holds the banner: its `on` text, or the first sentence of its `off`.
    function eventOf(name: string): string {
        return turnedOn[name] ? bannerStates[name].on : bannerStates[name].off.split(".")[0];
    }

    function showState(name: string) {
        const s = bannerStates[name];
        heightFrom = height;
        going.stop();
        status = s.status ?? "";
        alert = s.alert === true;
        word = wordOf(name);
        timeLine = timeLineOf(name);
        sentence = textOf(name);
        actionLabel = s.action ?? "";
        coming.restart();
        live.Accessible.announce(spoken, alert ? Accessible.Assertive : Accessible.Polite);
    }

    function clear(changed: string) {
        ended = changed;
        if (holdsFocus())
            setBy?.forceActiveFocus();
        heightFrom = 0;
        coming.stop();
        going.start();
    }

    // The banner has gone: an ending state is reported now.
    function cleared() {
        status = "";
        if (toaster && ended !== "")
            toaster.show(bannerStates[ended].off, { key: "state" });
    }

    function holdsFocus(): bool {
        for (let item = Window.activeFocusItem; item; item = item.parent) {
            if (item === banner)
                return true;
        }
        return false;
    }

    function runRemedy() {
        if (remedy)
            remedy(shown);
        else
            set(shown, false, {});
    }

    implicitHeight: heightFrom + (contentHeight - heightFrom) * entry
    visible: shown !== "" || leaving
    clip: true
    // The whole banner fades and moves, its fill too (rekta.css:940, :955); the place below follows only its height.
    opacity: entry
    transform: Translate {
        y: -(1 - banner.entry) * Geometry.bannerShift
    }
    z: Tokens.layerBanner

    NumberAnimation {
        id: coming

        objectName: "coming"
        target: banner
        property: "phase"
        from: 0
        to: 1
        duration: Tokens.durationShort
    }

    NumberAnimation {
        id: going

        objectName: "going"
        target: banner
        property: "phase"
        to: 0
        duration: Tokens.durationShort
        onFinished: banner.cleared()
    }

    Rectangle {
        objectName: "fill"
        anchors.fill: parent
        color: Status.tileFill(banner.status, Tokens.color, Tokens.color.surface)

        Hairline {
            anchors.bottom: parent.bottom
            width: parent.width
            visible: !banner.statusFill
        }
    }

    Item {
        id: content

        width: banner.width
        height: banner.contentHeight

        Item {
            id: live

            objectName: "live"
            x: banner.padX
            y: banner.padY
            width: banner.liveWidth
            height: banner.liveBottom
            Accessible.role: banner.alert ? Accessible.AlertMessage : Accessible.Notification
            Accessible.name: banner.spoken

            Item {
                y: banner.firstBaseline - wordText.baselineOffset
                width: banner.headWidth
                height: banner.headHeight

                BannerWord {
                    id: wordText

                    objectName: "word"
                    text: banner.word
                    placeWidth: banner.placeWidth
                }

                TextRole {
                    id: timeText

                    objectName: "time"
                    y: wordText.height + Tokens.spaceXs
                    visible: text !== ""
                    text: banner.timeLine
                    font.pixelSize: Tokens.fontSizeXs
                    font.features: ({ "tnum": 1 })
                    color: Tokens.color.textPrimary
                }
            }

            Body {
                id: sentenceText

                objectName: "sentence"
                x: banner.sentenceBeside ? banner.headWidth + Tokens.spaceS : 0
                y: banner.sentenceTop
                width: Math.min(banner.sentenceMax, banner.liveWidth - x)
                text: banner.sentence
            }
        }

        Button {
            id: remedyButton

            objectName: "remedy"
            x: banner.remedyBeside ? banner.width - banner.padX - width : banner.padX
            y: banner.padY + banner.remedyTop
            visible: banner.hasRemedy
            text: banner.actionLabel
            onClicked: banner.runRemedy()
        }
    }
}
