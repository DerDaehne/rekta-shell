import QtQuick

// What deviates from normal, as the words the app bar shows: a choice the user made (muted, do not disturb) is neutral,
// a privacy matter or a real problem (microphone in use, battery low, offline) takes the error colour and comes first.
// At most two words stand; the rest are counted in a "+N". The sources feed the flags; this only orders and names.
QtObject {
    id: state

    property bool muted: false
    property bool doNotDisturb: false
    property bool microphoneInUse: false
    property bool batteryLow: false
    property int batteryPercent: 0
    property bool offline: false

    readonly property int limit: 2
    // Every word there can be, in the order they stand.
    readonly property var keys: ["microphone", "battery", "offline", "muted", "doNotDisturb", "more"]
    // The deviations in order of weight: errors, then choices; each names the part of the controls panel it opens.
    readonly property var deviations: [
        microphoneInUse ? word("microphone", "mikrofon an", "error", "sound", "ton") : null,
        batteryLow ? word("battery", `akku ${batteryPercent} %`, "error", "power", "energie") : null,
        offline ? word("offline", "offline", "error", "connections", "verbindungen") : null,
        muted ? word("muted", "stumm", "", "sound", "ton") : null,
        doNotDisturb ? word("doNotDisturb", "nicht stören", "", "doNotDisturb", "anzeige") : null
    ].filter(deviation => deviation !== null)
    readonly property int hidden: Math.max(0, deviations.length - limit)
    // The words on the bar, the last one "+N" for those left out; it opens the controls at the top.
    readonly property var words: hidden > 0 ? deviations.slice(0, limit).concat([word("more", `+${hidden}`, "", "", "steuerung")]) : deviations

    // `opens` names the place in the controls, `place` what it is called; the name reads both.
    function word(key: string, text: string, status: string, opens: string, place: string): var {
        return { key, word: text, status, opens, name: `${text}, öffnet ${place}` };
    }
}
