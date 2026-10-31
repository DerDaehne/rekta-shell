.pragma library

// What the system's own values say about the status words, apart from the services that deliver them.

const microphoneClass = "Stream/Input/Audio";
const screencastPrefix = "kwin-screencast-";
// UPower's WarningLevel: 3 is low, 4 critical, 5 action.
const lowWarning = 3;
const criticalWarning = 4;

// Whether a program records from a microphone: a capture stream that does not listen to an output's monitor and is not
// the shell's own, so a level meter of the shell can never show it. `nodes` are PipeWire nodes: `isStream`, `properties`.
// ponytail: a connected but paused stream counts too; PwNode has no state to tell.
function microphoneInUse(nodes, ownProcessId) {
    return nodes.some(node => node.isStream
        && node.properties["media.class"] === microphoneClass
        && node.properties["stream.capture.sink"] !== "true"
        && Number(node.properties["application.process.id"]) !== ownProcessId);
}

// Whether a program receives a screencast: a link from one of KWin's screencast nodes (portal, direct clients and the
// shell's own previews alike, their media named "kwin-screencast-…") that is not one of the shell's own previews.
// PipeWire keeps the receiving process on the client, not on the node, so the shell's previews are told by their source.
// `linkGroups` have `source.id` and `source.properties`.
// ponytail: the portal chooser's previews count while it is open, and a paused receiver counts too; leave out the
// portal's receivers (their node name) and read PwLinkGroup.state when that matters.
function screenShared(linkGroups, ownSources) {
    return linkGroups.some(group => (group.source.properties["media.name"] ?? "").startsWith(screencastPrefix)
        && !ownSources.includes(group.source.id));
}

// The sources of the shell's own previews: those running and those that ended while PipeWire still links them, as a
// closing preview leaves its list before its link goes and must not show as a share meanwhile.
function ownScreencasts(previews, kept, linkGroups) {
    const linked = linkGroups.map(group => group.source.id);
    return Array.from(new Set([...previews, ...kept.filter(id => linked.includes(id))]));
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

function batteryCritical(warningLevel) {
    return (warningLevel ?? 0) >= criticalWarning;
}

// A KDE program names itself and its event in the hints it sends (knotifications, notifybypopup.cpp).
function fromKdeEvent(hints, appName, eventId) {
    return hints["x-kde-appname"] === appName && hints["x-kde-eventId"] === eventId;
}

// freespacenotifier's notice stays open until a disk has room again.
function freeSpaceNotice(hints) {
    return fromKdeEvent(hints, "freespacenotifier", "freespacenotif");
}

// freespacenotifier.kcfg: the defaults of its two limits, which its freespacenotifierrc may change.
const defaultMinimumMebibytes = 200;
const defaultMinimumPercent = 5;

// The limits freespacenotifier warns at, from its config file's text (empty or missing: its defaults).
function freeSpaceLimits(configText) {
    const value = (key, fallback) => Number((new RegExp(`^${key}=(\\d+)`, "m").exec(configText ?? "") ?? [])[1] ?? fallback);
    return { mebibytes: value("minimumSpace", defaultMinimumMebibytes), percent: value("minimumSpacePercentage", defaultMinimumPercent) };
}

// Whether every filesystem in `df -B1 --output=avail,size` (header or not) has more free than the smaller of the two
// limits. Without a single reading, nothing is known, so not enough.
function enoughSpace(dfText, limits) {
    const readings = dfText.split("\n").map(line => line.trim().split(/\s+/).map(Number)).filter(cells => cells.length === 2 && cells.every(Number.isFinite));
    const enough = ([available, size]) => available >= Math.min(limits.mebibytes * 1048576, size * limits.percent / 100);
    return readings.length > 0 && readings.every(enough);
}

// powerdevil's persistent notice for a low battery, which the status word already says. Its "criticalbattery" is
// another event: it announces the action in 60 seconds.
function lowBatteryNotice(hints) {
    return fromKdeEvent(hints, "powerdevil", "lowbattery");
}
