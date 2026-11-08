import QtQuick

// "nicht stören" and how long it lasts: until it is switched off ("open"), for an hour ("hour"), or until the next
// morning at 07:00 on the wall clock ("morning"), today's if switched on before then. The hour ends at an instant; the
// morning is kept as a day of the wall clock, so its end follows a change of time zone. `saved` is all it holds, as
// text for a file, and `restore` reads it back; an end that has passed meanwhile is off.
QtObject {
    id: quiet

    readonly property list<string> choices: ["open", "hour", "morning"]
    readonly property int morningHour: 7
    // One of `choices`, or "" while off.
    property string choice: ""
    // The hour's end in ms since the epoch.
    property real until: 0
    // The morning's day on the wall clock, "2026-11-09".
    property string day: ""
    // The clock, which tests replace: ms since the epoch, and the local zone's offset east of UTC in minutes at an
    // instant. `now` is read from it on every choice and every second while an end runs.
    property var clock: () => Date.now()
    property var zoneOffset: instant => -new Date(instant).getTimezoneOffset()
    property real now: clock()
    // When it ends, in ms since the epoch; 0 for no end. The morning's is found anew on every tick, so it follows a change
    // of time zone.
    readonly property real endsAt: choice === "hour" ? until : choice === "morning" ? morningEnd(day, now) : 0
    readonly property bool on: choice !== "" && (endsAt === 0 || now < endsAt)
    // Which of `choices` holds, -1 while off.
    readonly property int chosen: on ? choices.indexOf(choice) : -1
    readonly property bool ending: on && endsAt > 0
    // The button's state word while an end runs: "bis 14:30".
    readonly property string endWord: ending ? `bis ${wallTime(endsAt)}` : ""
    // Whole minutes left, a part of one counting as one.
    readonly property int minutesLeft: ending ? Math.ceil((endsAt - now) / 60000) : 0
    // The bar's middle while an end runs, in the words of Rekta's staleFor: "noch 42 min", from an hour on "bis 14:30".
    readonly property list<string> middleParts: ending ? ["nicht stören", minutesLeft < 60 ? `noch ${minutesLeft} min` : endWord] : []
    readonly property string saved: JSON.stringify({ choice, until, day })

    property Timer ticker: Timer {
        interval: 1000
        repeat: true
        running: quiet.ending
        onTriggered: quiet.tick()
    }

    function tick() {
        now = clock();
    }

    function choose(name: string) {
        tick();
        until = name === "hour" ? now + 3600000 : 0;
        day = name === "morning" ? nextMorning() : "";
        choice = choices.includes(name) ? name : "";
    }

    function stop() {
        choose("");
    }

    function restore(text: string) {
        let state = {};
        try {
            state = JSON.parse(text);
        } catch (error) {
            console.warn(`DoNotDisturb: kept nothing, as the file is not JSON: ${error}`);
        }
        tick();
        until = Number(state.until) || 0;
        day = typeof state.day === "string" ? state.day : "";
        choice = choices.includes(state.choice) ? state.choice : "";
    }

    // The wall clock at an instant, its fields read as UTC.
    function wall(instant: real): date {
        return new Date(instant + zoneOffset(instant) * 60000);
    }

    function wallTime(instant: real): string {
        const at = wall(instant);
        const pad = number => String(number).padStart(2, "0");
        return `${pad(at.getUTCHours())}:${pad(at.getUTCMinutes())}`;
    }

    // Today's day if the morning hour is still to come, else tomorrow's.
    function nextMorning(): string {
        const at = wall(now);
        const later = at.getUTCHours() < morningHour ? 0 : 1;
        return new Date(Date.UTC(at.getUTCFullYear(), at.getUTCMonth(), at.getUTCDate() + later)).toISOString().slice(0, 10);
    }

    // The instant of the morning hour on that day of the wall clock: from the offset at `from`, then from the one at that
    // instant, as the night may change it.
    function morningEnd(dayWords: string, from: real): real {
        const [year, month, date] = dayWords.split("-").map(Number);
        const wallInstant = Date.UTC(year, month - 1, date, morningHour);
        const guess = wallInstant - zoneOffset(from) * 60000;
        return wallInstant - zoneOffset(guess) * 60000;
    }
}
