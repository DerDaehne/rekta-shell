import QtQuick
import RektaShell.DBus

// The action registry for other programs on the session bus: rekta.Actions1 at /rekta/Actions lists its actions as they
// read now (ListActions), runs one (Invoke) and sends ActionsChanged when what it lists changes. The shell's own are the
// Start's commands, run as the search runs them, so one that ends the session only opens the banner; an app's desktop
// action starts as the app does. The names are working names. In any other session it owns nothing.
// ponytail: any program on the bus may invoke; a portal with permissions per client is to guard it.
QtObject {
    id: actions

    // XDG_SESSION_DESKTOP of the session the shell runs in.
    required property string sessionDesktop
    // As the registry (Actions.list) has them.
    required property var entries
    property bool exported: false
    // What ListActions answered when ActionsChanged was last sent, as JSON.
    property string announced: ""

    readonly property int version: 1
    readonly property string path: "/rekta/Actions"
    readonly property string interfaceName: "rekta.Actions1"
    // The amount of a command that takes one is a percent, as the search reads "ton 30" (Rules.commandHits).
    readonly property string amountSchema: JSON.stringify({
        type: "object",
        properties: {
            percent: {
                type: "integer",
                minimum: 0,
                maximum: 100
            }
        },
        required: ["percent"]
    })

    readonly property DBusConnection bus: DBusConnection {
        handler: (path, iface, member, args) => actions.answer(member, args)
    }

    function described(command: var): var {
        const properties = {
            title: command.text ?? command.word,
            readOnly: command.readOnly ?? false,
            destructive: command.destructive ?? false
        };
        if (command.keywords?.length > 0)
            properties.keywords = command.keywords;
        if (command.key)
            properties.key = command.key;
        if (command.app)
            properties.app = command.app;
        if (command.icon)
            properties.icon = command.icon;
        if (command.at !== undefined)
            properties.parameters = amountSchema;
        return [command.id, properties];
    }

    function listed(): var {
        return entries.map(described);
    }

    function invoke(id: string, parameters: var): var {
        const command = entries.find(candidate => candidate.id === id);
        if (command === undefined)
            throw new Error(`there is no action ${id}`);
        if (command.at === undefined) {
            command.run();
            return {};
        }
        const percent = parameters.percent;
        if (!Number.isInteger(percent) || percent < 0 || percent > 100)
            throw new Error(`${id} takes {"percent": a whole number from 0 to 100}`);
        command.at(percent).run();
        return {};
    }

    function answer(member: string, args: var): var {
        switch (member) {
        case "ListActions":
            return listed();
        case "Invoke":
            return invoke(args[0], args[1]);
        case "Version":
            return version;
        }
        throw new Error(`${member} is not part of ${interfaceName}`);
    }

    function announce() {
        const now = JSON.stringify(listed());
        if (!exported || now === announced)
            return;
        announced = now;
        bus.emitSignal(path, interfaceName, "ActionsChanged", [], "");
    }

    onEntriesChanged: announce()

    Component.onCompleted: {
        if (sessionDesktop !== "rekta")
            return;
        announced = JSON.stringify(listed());
        exported = bus.own("rekta.Actions", path, `
            <interface name="${interfaceName}">
              <method name="ListActions">
                <arg name="actions" type="a(sa{sv})" direction="out"/>
              </method>
              <method name="Invoke">
                <arg name="id" type="s" direction="in"/>
                <arg name="parameters" type="a{sv}" direction="in"/>
                <arg name="result" type="a{sv}" direction="out"/>
              </method>
              <signal name="ActionsChanged"/>
              <property name="Version" type="u" access="read">
                <annotation name="org.freedesktop.DBus.Property.EmitsChangedSignal" value="const"/>
              </property>
            </interface>`);
    }
}
