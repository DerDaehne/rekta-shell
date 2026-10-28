import QtQuick

// What deviates from normal, as the words the app bar shows: a choice the user made (muted, do not disturb) is neutral,
// a privacy matter or a real problem (microphone in use, battery low, offline) takes the error colour and comes first.
// The bar decides how many of them it has room for and counts the rest in a "+N"; the sources feed the flags, this only
// orders and names.
QtObject {
    id: state

    property bool muted: false
    property bool doNotDisturb: false
    property bool microphoneInUse: false
    property bool batteryLow: false
    property int batteryPercent: 0
    property bool offline: false
    // Whether the panel offers the energy profile, the place the battery word opens; else its group.
    property bool powerProfiles: false

    // Every word there can be, in the order they stand.
    readonly property var keys: ["microphone", "battery", "offline", "muted", "doNotDisturb", "more"]
    // The deviations in order of weight: errors, then choices; each names the part of the controls panel it opens.
    readonly property var deviations: [
        microphoneInUse ? word("microphone", "mikrofon an", "error", "sound", "ton") : null,
        batteryLow ? word("battery", `akku ${batteryPercent} %`, "error", "power", powerProfiles ? "energieprofil" : "sitzung") : null,
        offline ? word("offline", "offline", "error", "connections", "verbindungen") : null,
        muted ? word("muted", "stumm", "", "sound", "ton") : null,
        doNotDisturb ? word("doNotDisturb", "nicht stören", "", "doNotDisturb", "anzeige") : null
    ].filter(deviation => deviation !== null)

    // The word for the deviations a bar has no room for; it opens the controls at the top, and has the error square when
    // one of them is an error.
    function more(hidden: var): var {
        const text = `+${hidden.length}`;
        const status = hidden.some(deviation => deviation.status === "error") ? "error" : "";
        return word("more", text, status, "", "steuerung");
    }

    // `opens` names the place in the controls, `place` what it is called; the name reads both.
    function word(key: string, text: string, status: string, opens: string, place: string): var {
        return { key, word: text, status, opens, name: `${text}, öffnet ${place}` };
    }
}
