import QtQuick

// The lasting system states the banner at the top shows, most severe first, in the shape Rekta's Banner takes. The
// sources feed the flags; `apply` hands them on to a banner. The status words in the app bar say the same states and stay.
QtObject {
    id: banners

    property bool batteryCritical: false
    property int batteryPercent: 0
    property bool offline: false
    property bool storageFull: false
    // The words of the notice that says it.
    property string storageText: ""

    readonly property var order: ["battery", "offline", "storage"]
    readonly property var states: ({
            battery: { word: "akku", status: "error", text: "", action: "energieprofil", on: "Akku kritisch", off: "Akku nicht mehr kritisch." },
            offline: { word: "offline", status: "error", text: "Keine Verbindung zum Netz.", action: "verbindungen", on: "Verbindung verloren", off: "Wieder verbunden." },
            storage: { word: "speicher", status: "warning", text: "", action: "aufräumen", on: "Speicher fast voll", off: "Wieder genug Speicher frei." }
        })
    // Where the remedy goes in the controls panel; a state without a place has its own remedy.
    readonly property var places: ({ battery: "power", offline: "connections" })
    // The state that stays over a full-screen window.
    readonly property string urgent: "battery"
    readonly property var active: ({ battery: batteryCritical, offline: offline, storage: storageFull })
    readonly property var sentences: ({
            battery: `Noch ${batteryPercent} %. Schließ das Netzteil an.`,
            offline: states.offline.text,
            storage: storageText
        })

    // Over a full-screen window only the urgent state shows; `word` is the one on the banner.
    function mayShow(word: string, fullScreen: bool): bool {
        return !fullScreen || word === states[urgent].word;
    }


    // Turns the states on or off at the banner and writes their current sentences.
    function apply(banner: var) {
        for (const name of order)
            banner.set(name, active[name], { text: sentences[name] });
    }
}
