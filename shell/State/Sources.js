.pragma library

// What the system's own values say about the status words, apart from the services that deliver them.

const microphoneClass = "Stream/Input/Audio";
// UPower's WarningLevel: 3 is low, 4 critical, 5 action.
const lowWarning = 3;

// Whether a program records from a microphone: a capture stream that does not listen to an output's monitor and is not
// the shell's own, so a level meter of the shell can never show it. `nodes` are PipeWire nodes: `isStream`, `properties`.
// ponytail: a connected but paused stream counts too; PwNode has no state to tell.
function microphoneInUse(nodes, ownProcessId) {
    return nodes.some(node => node.isStream
        && node.properties["media.class"] === microphoneClass
        && node.properties["stream.capture.sink"] !== "true"
        && Number(node.properties["application.process.id"]) !== ownProcessId);
}

function batteryLow(warningLevel) {
    return (warningLevel ?? 0) >= lowWarning;
}

// `none` is the value of Networking's "no connectivity"; limited, portal and unknown count as online.
// ponytail: with NetworkManager's connectivity check off it reports unknown and never offline; count the connected
// devices then.
function offline(connectivity, none) {
    return connectivity === none;
}
