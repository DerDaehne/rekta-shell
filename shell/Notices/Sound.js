.pragma library

// A notification's sound as Plasma plays it (plasma-workspace, libnotificationmanager/notifications.cpp,
// playSoundHint()): its sound-name or sound-file hint, in the sound theme kdeglobals names, never with suppress-sound.

// The value of [Sounds] Theme in a kdeglobals text, also with KConfig flags such as [$i]; Plasma's default is ocean.
function theme(ini) {
    let inSounds = false;
    for (const rawLine of ini.split("\n")) {
        const line = rawLine.trim();
        if (line.startsWith("["))
            inSounds = line === "[Sounds]";
        else if (inSounds && /^Theme(\[[^\]]*\])*=/.test(line))
            return line.slice(line.indexOf("=") + 1).trim() || "ocean";
    }
    return "ocean";
}

// The command that plays it through libcanberra, or [] when it asks for no sound.
function command(hints, themeName) {
    const name = String(hints["sound-name"] ?? "");
    const file = String(hints["sound-file"] ?? "");
    if (hints["suppress-sound"] || (name === "" && file === ""))
        return [];
    const args = ["canberra-gtk-play", `--property=canberra.xdg-theme.name=${themeName}`, "--cache-control=volatile"];
    if (name !== "")
        args.push(`--id=${name}`);
    if (file !== "")
        args.push(`--file=${file}`);
    return args;
}
