import QtQuick

// The shell's own commands, defined once for the Start's search: what the session offers, the looks, quiet and sound. A
// command says what it will do now ("dunkel an" while light). Ending the session goes through the banner, which gives
// the time to take it back.
QtObject {
    id: commands

    required property var launcher
    required property var panel
    required property var session
    // The default output as PipeWire has it (volume 0 to 1, muted), or null.
    required property var sink

    readonly property bool muted: sink?.audio?.muted ?? false
    // {text, keywords, run}, or {word, at(n)} for one that takes an amount: "ton 30" (Rules.commandHits).
    readonly property var list: [
        {
            text: "sperren",
            keywords: ["lock"],
            run: () => commands.launcher.run(["loginctl", "lock-session"])
        },
        {
            text: "benutzer wechseln",
            keywords: ["switch", "user"],
            run: () => commands.session.show("switchUser")
        },
        {
            text: "abmelden",
            keywords: ["logout"],
            run: () => commands.session.show("logout")
        },
        {
            text: "neu starten",
            keywords: ["reboot", "restart"],
            run: () => commands.session.show("reboot")
        },
        {
            text: "ausschalten",
            keywords: ["shutdown", "power", "off"],
            run: () => commands.session.show("shutdown")
        },
        {
            text: panel.dark ? "dunkel aus" : "dunkel an",
            keywords: ["dark", "theme"],
            run: () => commands.panel.setDark(!commands.panel.dark)
        },
        {
            text: panel.doNotDisturb ? "nicht stören aus" : "nicht stören an",
            keywords: ["quiet", "dnd"],
            run: () => commands.panel.setDoNotDisturb(!commands.panel.doNotDisturb)
        },
        {
            text: muted ? "stumm aus" : "stumm an",
            keywords: ["mute", "ton"],
            run: () => commands.sink.audio.muted = !commands.muted
        },
        {
            word: "ton",
            at: percent => ({
                    text: `ton auf ${percent} %`,
                    run: () => commands.sink.audio.volume = percent / 100
                })
        }
    ]
}
