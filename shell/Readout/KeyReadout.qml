import QtQuick

// What the display in the middle of the bar says after a key: volume, microphone, brightness or keyboard layout. The
// values are the current ones of the system, which the shell's sources keep up to date; only a key shows the display,
// so a change by an app or a slider does not. Plasma's key services (kded6, powerdevil) act on the keys; this only
// reads them.
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

    signal pressed

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

    function show(shownKind: string) {
        kind = shownKind;
        pressed();
    }

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
        show("brightness");
    }

    function layoutSwitched() {
        show("layout");
    }
}
