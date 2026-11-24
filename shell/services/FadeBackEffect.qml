import QtQml
import RektaShell.DBus

// KWin's rekta-fadeback as the shell tells it things. KWin keeps the effect it loaded at login, also after an update has
// brought the shell a newer one, so the shell asks the running effect which methods it has and names a mismatch once
// in the journal. Every call to the effect goes through tell(), which names a failure once per method, as some are
// made on every frame of a fade. It asks again only when an effect comes (its signal "loaded"), never on a timer.
DBusConnection {
    id: effect

    // The version the shell's build gave its effects too; empty where nothing says, as in a checkout run through qs.
    required property string buildVersion
    // The methods of the effect KWin runs; none until it has answered, or without the effect.
    property list<string> methods: []
    // The methods whose failure the journal has, until an effect comes anew.
    property var failed: ({})

    function tell(member: string, args: var, signature: string) {
        call("org.kde.KWin", "/RektaFadeBack", "org.rekta.FadeBack", member, args, signature, error => {
            if (!error || effect.failed[member])
                return;
            effect.failed[member] = true;
            console.warn(`FadeBackEffect: ${member} failed: ${error}`);
        });
    }

    function learn() {
        failed = {};
        call("org.kde.KWin", "/RektaFadeBack", "org.freedesktop.DBus.Introspectable", "Introspect", [], "", (error, values) => {
            const found = effect.methodsIn(typeof values[0] === "string" ? values[0] : "");
            effect.methods = found ?? [];
            if (!effect.methods.includes("version"))
                effect.warnStale(found === null ? "no rekta-fadeback" : "an older rekta-fadeback without a version");
            else
                effect.call("org.kde.KWin", "/RektaFadeBack", "org.rekta.FadeBack", "version", [], "", (error, values) => effect.compareVersion(typeof values[0] === "string" ? values[0] : ""));
        });
    }

    function compareVersion(version: string) {
        if (buildVersion !== "" && version !== buildVersion)
            warnStale(`rekta-fadeback ${version}`);
    }

    function warnStale(running: string) {
        console.warn(`FadeBackEffect: KWin runs ${running}, the shell is ${buildVersion || "a checkout"}: log out and back in to load the shell's`);
    }

    // The method names of org.rekta.FadeBack in introspection XML as QtDBus writes it, or null without that interface.
    function methodsIn(xml: string): var {
        const start = xml.indexOf('<interface name="org.rekta.FadeBack">');
        if (start < 0)
            return null;
        const body = xml.slice(start, xml.indexOf("</interface>", start));
        return body.split('<method name="').slice(1).map(part => part.slice(0, part.indexOf('"')));
    }

    Component.onCompleted: {
        listen("org.rekta.FadeBack", "loaded", "org.kde.KWin", "/RektaFadeBack");
        learn();
    }
    onReceived: learn()
}
