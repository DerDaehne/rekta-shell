import QtQuick
import Start

// The shell's own commands, defined once for the Start's search and for other programs (ActionsInterface): what the
// session offers, the looks, quiet, sound and the key map. A command says what it will do now ("dunkel an" while light).
// Ending the session goes through the banner, whoever asks, which gives the time to take it back. A command shows its key (navigation.md:303) where the session binds
// one, as kglobalaccel tells it, read only; with no key bound, or no kglobalaccel, it shows none. The sound commands
// are there only while there is an output to set.
QtObject {
    id: commands

    required property var launcher
    required property var panel
    required property var session
    // Shows the key map: the surface, with show().
    required property var keyMap
    // The default output as PipeWire has it, or null.
    required property var sink

    // The keys of the session's own actions, by command: "Meta+L". The session registers them with kglobalaccel under
    // the component ksmserver (kscreenlocker's "Lock Session", plasma-workspace's logout actions).
    property var shortcuts: ({})
    readonly property var actions: ({
            lock: "Lock Session",
            logout: "Log Out",
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
            id: "mute",
            text: muted ? "stumm aus" : "stumm an",
            keywords: ["mute", "ton"],
            run: () => commands.audio.muted = !commands.muted
        },
        {
            id: "volume",
            word: "ton",
            at: percent => ({
                    text: `ton auf ${percent} %`,
                    run: () => commands.audio.volume = percent / 100
                })
        }
    ]
    // {id, text, keywords, run}, or {id, word, at(n)} for one that takes an amount: "ton 30" (Rules.commandHits). `readOnly`
    // marks one that changes nothing, `destructive` one that ends the session.
    readonly property var list: [
        {
            id: "lock",
            text: "sperren",
            keywords: ["lock"],
            key: shortcuts.lock ?? "",
            run: () => commands.launcher.lock()
        },
        {
            id: "switch-user",
            text: "benutzer wechseln",
            keywords: ["switch", "user"],
            run: () => commands.session.show("switchUser")
        },
        {
            id: "logout",
            text: "abmelden",
            keywords: ["logout"],
            destructive: true,
            key: shortcuts.logout ?? "",
            run: () => commands.session.show("logout")
        },
        {
            id: "reboot",
            text: "neu starten",
            keywords: ["reboot", "restart"],
            destructive: true,
            key: shortcuts.reboot ?? "",
            run: () => commands.session.show("reboot")
        },
        {
            id: "shutdown",
            text: "ausschalten",
            keywords: ["shutdown", "power", "off"],
            destructive: true,
            key: shortcuts.shutdown ?? "",
            run: () => commands.session.show("shutdown")
        },
        {
            id: "dark",
            text: panel.dark ? "dunkel aus" : "dunkel an",
            keywords: ["dark", "theme"],
            run: () => commands.panel.setDark(!commands.panel.dark)
        },
        {
            id: "do-not-disturb",
            text: panel.doNotDisturb ? "nicht stören aus" : "nicht stören an",
            keywords: ["quiet", "dnd"],
            run: () => commands.panel.setDoNotDisturb(!commands.panel.doNotDisturb)
        },
        {
            id: "key-map",
            text: "tastenkürzel",
            keywords: ["shortcuts", "keys", "tasten", "hilfe"],
            readOnly: true,
            key: "?",
            run: () => commands.keyMap.show()
        },
        ...soundCommands
    ]
}
