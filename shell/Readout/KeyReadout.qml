import QtQuick

// What the display in the middle of the bar says after a key: volume, microphone, brightness or keyboard layout. The
// values are the current ones of the system, which the shell's sources keep up to date; only a key shows the display,
// so a change by an app or a slider does not. Plasma's key services (kded6, powerdevil) act on the keys; this only
// reads them. `news` is what a live region says: the value a key brought and every later change of the value shown,
// never the one from before the key, as Rekta sets the words with the new value (behaviour.md, `indicate()`).
QtObject {
    id: readout

    // Volumes as 1 for 100%; brightness in the units of powerdevil, against its maximum.
    property real volume: 0
    property bool muted: false
    property real micVolume: 0
    property bool micMuted: false
    property real brightness: 0
    property real brightnessMax: 0
    property string layoutName

    // volume | mic | brightness | layout
    property string kind: "volume"
    readonly property real brightnessShare: brightnessMax > 0 ? Math.min(1, brightness / brightnessMax) : 0
    readonly property var view: describe(kind)
    readonly property string word: view.word
    // -1 where a text stands in place of the meter.
    readonly property real level: view.level
    readonly property string valueText: view.text
    readonly property string spoken: `${word} ${valueText}`
    // The words last given as news, or those that stood when a key came whose value is still to come.
    property string told

    signal pressed
    signal news(string words)

    readonly property var kmixKinds: ({
            increase_volume: "volume",
            decrease_volume: "volume",
            increase_volume_small: "volume",
            decrease_volume_small: "volume",
            mute: "volume",
            mic_mute: "mic",
            increase_microphone_volume: "mic",
            decrease_microphone_volume: "mic"
        })

    function percent(fraction: real): string {
        return `${Math.round(fraction * 100)}%`;
    }

    function describe(kind: string): var {
        switch (kind) {
        case "mic":
            return { word: "mikrofon", level: micMuted ? 0 : Math.min(1, micVolume), text: micMuted ? "stumm" : percent(micVolume) };
        case "brightness":
            return { word: "helligkeit", level: brightnessShare, text: percent(brightnessShare) };
        case "layout":
            return { word: "tastatur", level: -1, text: layoutName };
        default:
            return { word: "lautstärke", level: muted ? 0 : Math.min(1, volume), text: muted ? "stumm" : percent(volume) };
        }
    }

    // The volume and microphone keys reach the shell before kded6's new value comes back through PipeWire, so what
    // stands at the key is no news; a key at a limit changes nothing and brings none.
    function show(shownKind: string) {
        kind = shownKind;
        told = spoken;
        pressed();
    }

    // For a key whose new value came with it.
    function showWithNews(shownKind: string) {
        show(shownKind);
        tell();
    }

    function tell() {
        told = spoken;
        news(spoken);
    }

    // The parts change one after the other (the word and the value, a volume and its mute); only the whole is news.
    function tellChange() {
        if (spoken !== told)
            tell();
    }

    onSpokenChanged: Qt.callLater(tellChange)

    // A shortcut of kglobalaccel went off; the volume and microphone keys belong to its component "kmix".
    function shortcutPressed(component: string, action: string) {
        const shownKind = kmixKinds[action];
        if (component === "kmix" && shownKind)
            show(shownKind);
    }

    // powerdevil tells every change of brightness; only a key's carries the context "brightness_key". The range is that of
    // the display it changed, so other changes and other displays leave what the readout shows alone.
    function brightnessReported(value: int, max: int, context: string) {
        if (context !== "brightness_key")
            return;
        brightnessMax = max;
        brightness = value;
        showWithNews("brightness");
    }

    function layoutSwitched() {
        showWithNews("layout");
    }
}
