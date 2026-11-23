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
    // The most a volume key raises a volume to: 100%, or 150% where plasma-pa's settings allow more than 100%.
    property real volumeMax: 1
    property real brightness: 0
    property real brightnessMax: 0
    property string layoutName

    // volume | mic | brightness | layout
    property string kind: "volume"
    readonly property real brightnessShare: brightnessMax > 0 ? Math.min(1, brightness / brightnessMax) : 0
    readonly property var view: describe(kind)
    readonly property string word: view.word
    // One of Rekta's icons.
    readonly property string icon: view.icon
    // -1 where a text stands in place of the meter.
    readonly property real level: view.level
    readonly property string valueText: view.text
    readonly property string spoken: `${word} ${valueText}`
    // The words last given as news, or those that stood when a key came whose value is still to come.
    property string told

    signal pressed
    signal news(string words)

    // The kind each key shows, and which way it moves the volume.
    readonly property var kmixKeys: ({
            increase_volume: { kind: "volume", way: 1 },
            decrease_volume: { kind: "volume", way: -1 },
            increase_volume_small: { kind: "volume", way: 1 },
            decrease_volume_small: { kind: "volume", way: -1 },
            mute: { kind: "volume", way: 0 },
            mic_mute: { kind: "mic", way: 0 },
            increase_microphone_volume: { kind: "mic", way: 1 },
            decrease_microphone_volume: { kind: "mic", way: -1 }
        })

    function percent(fraction: real): string {
        return `${Math.round(fraction * 100)}%`;
    }

    // plasma-pa moves a volume to its target bounded by 0 and `volumeMax`, in whole percent, and mutes it exactly at 0:
    // a key that finds it already at the bound in its way changes nothing, and no new value comes back.
    function stays(fraction: real, isMuted: bool, way: int): bool {
        if (way > 0)
            return !isMuted && percent(fraction) === percent(volumeMax);
        if (way < 0)
            return isMuted && percent(fraction) === "0%";
        return false;
    }

    // Whether plasma-pa's settings (plasmaparc) let the volume keys raise a volume above 100%.
    function raisesAboveFull(plasmaparc: string): bool {
        let inGeneral = false;
        for (const rawLine of plasmaparc.split("\n")) {
            const line = rawLine.trim();
            if (line.startsWith("["))
                inGeneral = line === "[General]";
            else if (inGeneral && /^RaiseMaximumVolume(\[[^\]]*\])*=/.test(line))
                return /^(true|on|yes|1)$/i.test(line.slice(line.indexOf("=") + 1).trim());
        }
        return false;
    }

    // A volume at nothing, muted or not, shows its muted icon, as Rekta's own does (site.js:933).
    function withIcon(view: var, icon: string): var {
        return Object.assign(view, { icon: view.level > 0 ? icon : `${icon}-muted` });
    }

    function describe(kind: string): var {
        switch (kind) {
        case "mic":
            return withIcon({ word: "mikrofon", level: micMuted ? 0 : Math.min(1, micVolume), text: micMuted ? "stumm" : percent(micVolume) }, "microphone");
        case "brightness":
            // ponytail: Rekta has no brightness icon; its "theme", a half-filled circle, stands in until Rekta answers the
            // report of that gap.
            return { word: "helligkeit", icon: "theme", level: brightnessShare, text: percent(brightnessShare) };
        case "layout":
            // ponytail: Rekta has no keyboard icon; its "edit", a pen, stands in until Rekta answers the report of that gap.
            return { word: "tastatur", icon: "edit", level: -1, text: layoutName };
        default:
            return withIcon({ word: "lautstärke", level: muted ? 0 : Math.min(1, volume), text: muted ? "stumm" : percent(volume) }, "speaker");
        }
    }

    // The volume and microphone keys reach the shell before kded6's new value comes back through PipeWire, so what
    // stands at the key is no news.
    function show(shownKind: string) {
        kind = shownKind;
        told = spoken;
        pressed();
    }

    // For a key whose value is already here: it came with the key, or the key cannot change it.
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
        const key = kmixKeys[action];
        if (component !== "kmix" || !key)
            return;
        const atBound = key.kind === "mic" ? stays(micVolume, micMuted, key.way) : stays(volume, muted, key.way);
        if (atBound)
            showWithNews(key.kind);
        else
            show(key.kind);
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

    // With the new name: the handler that sees the switch runs before a binding to the name would have caught up.
    function layoutSwitched(name: string) {
        layoutName = name;
        showWithNews("layout");
    }
}
