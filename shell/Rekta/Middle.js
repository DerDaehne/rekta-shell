.pragma library
.import "Match.js" as Match

// What the middle of the app bar says (navigation.md, "The middle of the bar"): what runs leads, the window follows.

// The window's words: the app's name, unless the title already holds it as whole words ("KCharSelect" under
// "KCharSelect"), then the title alone.
function windowParts(app, title) {
    const appWords = Match.words(app);
    const titleWords = Match.words(title);
    const named = appWords.length > 0 && titleWords.some((_, start) => appWords.every((word, i) => titleWords[start + i] === word));
    return [named ? "" : app, title].filter(part => part !== "");
}

// "2:14", or "1:02:14" from an hour on; the seconds are whole.
function clock(seconds) {
    const whole = Math.max(0, Math.floor(seconds));
    const pad = number => String(number).padStart(2, "0");
    const hours = Math.floor(whole / 3600);
    const minutes = Math.floor(whole / 60) % 60;
    return hours > 0 ? `${hours}:${pad(minutes)}:${pad(whole % 60)}` : `${minutes}:${pad(whole % 60)}`;
}

// A playing track as "title · artist" and its time "2:14 / 4:03"; a stream of unknown length shows the time played.
function musicParts(title, artist, position, length) {
    const track = [title, artist].filter(part => part !== "").join(" · ");
    const time = length > 0 ? `${clock(position)} / ${clock(length)}` : clock(position);
    return track === "" ? [] : [track, time];
}

// The first source that has something to say, else the window. A source is a list of parts, empty when idle.
function firstRunning(sources, fallback) {
    return sources.find(parts => parts.length > 0) ?? fallback;
}
