import QtQml

// The settings in three layers, each one winning over the one before: the shell's own values, the defaults of the Nix
// configuration and the user's settings.json. The files come in and go out as text, so a host does the file work.
QtObject {
    id: layers

    // The Nix defaults as JSON, "" without them.
    property string defaultsText: ""
    // The user's settings.json, "" while it does not exist.
    property string userText: ""
    // The write gate: only the settings app opens it, the shell never does.
    property bool writable: false
    // Settings that may be written with the gate closed: the shell's own, as the side panel keeps the density.
    property list<string> writableKeys: []

    readonly property int version: 1
    // Every setting there is, with the value it has without any configuration.
    readonly property var builtIn: ({
            background: "rekta",
            density: "auto",
            startTempo: "fast",
            searchEscape: "close"
        })
    readonly property var nixValues: parsed(defaultsText) ?? {}
    // null when the user's file holds no JSON object.
    readonly property var userContent: userText.trim() === "" ? {} : parsed(userText)
    // Why the user's file is not written: "broken" (it is read as empty), "newer" (a later version, read as it is),
    // or "" when it can be written.
    readonly property string fault: faultOf(userContent)
    readonly property var userValues: fault === "broken" ? {} : userContent

    // The whole new settings.json, for the host to write.
    signal writeRequested(string text)

    function parsed(text: string): var {
        try {
            const content = JSON.parse(text);
            return typeof content === "object" && content !== null && !Array.isArray(content) ? content : null;
        } catch (error) {
            return null;
        }
    }

    function faultOf(content: var): string {
        if (content === null)
            return "broken";
        const fileVersion = content.version ?? version;
        if (!Number.isInteger(fileVersion) || fileVersion < 1)
            return "broken";
        return fileVersion > version ? "newer" : "";
    }

    // A value counts only for a setting there is and only in the type of that setting's own value, so a mistyped file
    // cannot reach the shell.
    function fits(key: string, candidate: var): bool {
        return builtIn.hasOwnProperty(key) && candidate !== undefined && typeof candidate === typeof builtIn[key];
    }

    // What a setting is without the user's file.
    function preset(key: string): var {
        return fits(key, nixValues[key]) ? nixValues[key] : builtIn[key];
    }

    function value(key: string): var {
        return fits(key, userValues[key]) ? userValues[key] : preset(key);
    }

    function differs(key: string): bool {
        return value(key) !== preset(key);
    }

    // Asks the host to write the user's file with the setting changed and every other key kept, also those this version
    // does not know. Refused behind a closed gate (for that key), over a file it cannot read as its own, and for a value that does not fit.
    function set(key: string, newValue: var): bool {
        if (!(writable || writableKeys.includes(key)) || fault !== "" || !fits(key, newValue))
            return false;
        const next = Object.assign({
            version: version
        }, userValues, {
            version: version
        });
        next[key] = newValue;
        writeRequested(JSON.stringify(next, null, 2) + "\n");
        return true;
    }

    function reportFault() {
        if (fault === "broken")
            console.warn("rekta-shell: settings.json holds no JSON object; the defaults apply and nothing writes over it");
    }

    onFaultChanged: reportFault()
    Component.onCompleted: reportFault()
}
