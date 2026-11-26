import QtQuick

// What the display battery says, in the words of the bar and the panel: from UPower's DisplayDevice the stand, its state
// and the estimate. The sources feed the raw values; the bar's word, the tile's word and the level's rows come from here.
// Rekta shows no fill for a battery: the value is a word beside the icon (shell.md:16–17).
QtObject {
    id: battery

    // UPower's IsPresent, Type (2 is a battery), Percentage, State, TimeToEmpty and TimeToFull (seconds, 0 without an
    // estimate) and WarningLevel (3 is low).
    property bool present: false
    property int kind: 0
    property real percentage: 0
    property int state: 0
    property int timeToEmpty: 0
    property int timeToFull: 0
    property int warningLevel: 0

    // UPower's State values.
    readonly property int charging: 1
    readonly property int discharging: 2
    readonly property int empty: 3
    readonly property int fullyCharged: 4
    readonly property int pendingCharge: 5
    // From here on a charge is nearly done and needs no word in the bar.
    readonly property int nearlyFull: 90

    // A desktop has none: UPower then reports no device present or a type that is not a battery.
    readonly property bool exists: present && kind === 2
    readonly property int percent: Math.round(percentage)
    readonly property bool low: exists && Sources.batteryLow(warningLevel)
    readonly property bool onBattery: exists && (state === discharging || state === empty)
    readonly property bool onCharge: exists && state === charging
    readonly property string stateWord: ({ [charging]: "lädt", [discharging]: "entlädt", [empty]: "entlädt", [fullyCharged]: "voll", [pendingCharge]: "lädt nicht" })[state] ?? ""
    readonly property string tileWord: !exists ? "" : state === fullyCharged ? "voll" : onCharge ? `${percent} % · lädt` : `${percent} %`
    // The tile's name spoken: the dot between the words is no speech.
    readonly property string tileName: tileWord.split(" · ").concat(low ? ["knapp"] : []).join(", ")
    // The bar's neutral word: on battery, and while a charge runs below nearlyFull; nothing when full, held at a charge
    // limit or plugged in and idle. Low has the error word of the status words instead.
    readonly property string note: low ? "" : onBattery ? `akku ${percent} %` : onCharge && percent < nearlyFull ? `akku ${percent} % · lädt` : ""
    // What is left on battery or until full, or "" without an estimate.
    readonly property string estimate: onBattery && timeToEmpty > 0 ? `noch ${duration(timeToEmpty)}` : onCharge && timeToFull > 0 ? `bis voll ${duration(timeToFull)}` : ""

    // "42 min", "3 h 20 min", "2 h"; the minute is the finest step.
    function duration(seconds: int): string {
        const minutes = Math.max(1, Math.round(seconds / 60));
        const hours = Math.floor(minutes / 60);
        if (hours === 0)
            return `${minutes} min`;
        return minutes % 60 === 0 ? `${hours} h` : `${hours} h ${minutes % 60} min`;
    }
}
