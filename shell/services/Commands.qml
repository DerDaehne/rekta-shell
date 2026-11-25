import QtQuick
import Start

// The shell's own commands, defined once for the Start's search and for other programs (ActionsInterface): what the
// session offers, the looks, quiet, sound and the key map. A command says what it will do now ("dunkel an" while light).
// Ending the session goes through the banner, whoever asks, which gives the time to take it back. A command shows its
// key (navigation.md:332) where the session binds one, as kglobalaccel tells it, read only; with no key bound, or no
// kglobalaccel, it shows none. The sound commands are always listed; without an output they cannot run (`available` is
// false, with the reason), and the search leaves them out.
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
    readonly property bool hasOutput: audio !== null
    readonly property string noOutput: "there is no audio output"
    readonly property var soundCommands: [
        {
            id: "mute",
            text: muted ? "stumm aus" : "stumm an",
            keywords: ["mute", "ton"],
            description: "Mutes the default audio output, or unmutes it. The state is true while it is muted.",
            state: () => commands.hasOutput ? commands.muted : undefined,
            becomes: () => !commands.muted,
            available: commands.hasOutput,
            reason: commands.noOutput,
            run: () => commands.audio.muted = !commands.muted
        },
        {
            id: "volume",
            word: "ton",
            description: "Sets the volume of the default audio output to a percent. The state is the volume in percent.",
            state: () => commands.hasOutput ? Math.round(commands.audio.volume * 100) : undefined,
            available: commands.hasOutput,
            reason: commands.noOutput,
            at: percent => ({
                    text: `ton auf ${percent} %`,
                    run: () => commands.audio.volume = percent / 100
                })
        }
    ]
    // {id, text, keywords, description, run}, or {id, word, at(n)} for one that takes an amount: "ton 30" (Rules.commandHits).
    // `readOnly` marks one that changes nothing, `destructive` one that ends the session. `state()` reads what it sets now,
    // `becomes()` what a run will set (a look changes only after Plasma has applied it), `acts()` whether a run really
    // happens, and `available` with a `reason` whether it can run at all; the search shows only those that can.
    readonly property var list: [
        {
            id: "lock",
            text: "sperren",
            keywords: ["lock"],
            description: "Locks the session; the user unlocks it with their password.",
            acts: () => commands.launcher.starts,
            key: shortcuts.lock ?? "",
            run: () => commands.launcher.lock()
        },
        {
            id: "switch-user",
            text: "benutzer wechseln",
            keywords: ["switch", "user"],
            description: "Opens the session bar with the focus on switching user; nothing happens until the user chooses it there.",
            run: () => commands.session.show("switchUser")
        },
        {
            id: "logout",
            text: "abmelden",
            keywords: ["logout"],
            description: "Opens the session bar with the focus on logging out; the session ends only when the user chooses it there.",
            destructive: true,
            key: shortcuts.logout ?? "",
            run: () => commands.session.show("logout")
        },
        {
            id: "reboot",
            text: "neu starten",
            keywords: ["reboot", "restart"],
            description: "Opens the session bar with the focus on restarting; the computer restarts only when the user chooses it there.",
            destructive: true,
            key: shortcuts.reboot ?? "",
            run: () => commands.session.show("reboot")
        },
        {
            id: "shutdown",
            text: "ausschalten",
            keywords: ["shutdown", "power", "off"],
            description: "Opens the session bar with the focus on shutting down; the computer shuts down only when the user chooses it there.",
            destructive: true,
            key: shortcuts.shutdown ?? "",
            run: () => commands.session.show("shutdown")
        },
        {
            id: "dark",
            text: panel.dark ? "dunkel aus" : "dunkel an",
            keywords: ["dark", "theme"],
            description: "Switches the desktop between its light and its dark look. The state is true while it is dark.",
            state: () => commands.panel.dark,
            becomes: () => !commands.panel.dark,
            acts: () => commands.launcher.starts,
            run: () => commands.panel.setDark(!commands.panel.dark)
        },
        {
            id: "do-not-disturb",
            text: panel.doNotDisturb ? "nicht stören aus" : "nicht stören an",
            keywords: ["quiet", "dnd"],
            description: "Silences notifications, or lets them through again. The state is true while they are silenced.",
            state: () => commands.panel.doNotDisturb,
            becomes: () => !commands.panel.doNotDisturb,
            run: () => commands.panel.setDoNotDisturb(!commands.panel.doNotDisturb)
        },
        {
            id: "key-map",
            text: "tastenkürzel",
            keywords: ["shortcuts", "keys", "tasten", "hilfe"],
            description: "Shows the map of the keyboard shortcuts.",
            readOnly: true,
            key: "?",
            run: () => commands.keyMap.show()
        },
        ...soundCommands
    ]
}
