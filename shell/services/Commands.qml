import QtQuick
import Start

// The shell's own commands, defined once for the Start's search: what the session offers, the looks, quiet and sound. A
// command says what it will do now ("dunkel an" while light). Ending the session goes through the banner, which gives
// the time to take it back. A command shows its key (navigation.md:239) where the session binds one, as kglobalaccel
// tells it, read only; with no key bound, or no kglobalaccel, it shows none. The sound commands are there only while
// there is an output to set.
QtObject {
    id: commands

    required property var launcher
    required property var panel
    required property var session
    // The default output as PipeWire has it, or null.
    required property var sink

    // The keys of the session's own actions, by command: "Meta+L". The session registers them with kglobalaccel under
    // the component ksmserver (kscreenlocker's "Lock Session", plasma-workspace's logout actions).
    property var shortcuts: ({})
    readonly property var actions: ({
            lock: "Lock Session",
            logout: "LogOut",
            reboot: "Reboot",
            shutdown: "Shut Down"
        })

    function readKeys() {
        for (const [command, action] of Object.entries(actions)) {
            launcher.ask("org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel", "shortcutKeys", [["ksmserver", action, "", ""]], "as", values => {
                shortcuts = Object.assign({}, shortcuts, {
                    [command]: Rules.keyText(values)
                });
            });
        }
    }

    Component.onCompleted: readKeys()

    readonly property var audio: sink?.audio ?? null
    readonly property bool muted: audio?.muted ?? false
    readonly property var soundCommands: audio === null ? [] : [
        {
            text: muted ? "stumm aus" : "stumm an",
            keywords: ["mute", "ton"],
            run: () => commands.audio.muted = !commands.muted
        },
        {
            word: "ton",
            at: percent => ({
                    text: `ton auf ${percent} %`,
                    run: () => commands.audio.volume = percent / 100
                })
        }
    ]
    // {text, keywords, run}, or {word, at(n)} for one that takes an amount: "ton 30" (Rules.commandHits).
    readonly property var list: [
        {
            text: "sperren",
            keywords: ["lock"],
            key: shortcuts.lock ?? "",
            run: () => commands.launcher.lock()
        },
        {
            text: "benutzer wechseln",
            keywords: ["switch", "user"],
            run: () => commands.session.show("switchUser")
        },
        {
            text: "abmelden",
            keywords: ["logout"],
            key: shortcuts.logout ?? "",
            run: () => commands.session.show("logout")
        },
        {
            text: "neu starten",
            keywords: ["reboot", "restart"],
            key: shortcuts.reboot ?? "",
            run: () => commands.session.show("reboot")
        },
        {
            text: "ausschalten",
            keywords: ["shutdown", "power", "off"],
            key: shortcuts.shutdown ?? "",
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
        ...soundCommands
    ]
}
