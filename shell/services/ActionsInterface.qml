import QtQuick
import RektaShell.DBus

// The action registry for other programs on the session bus: rekta.Actions1 at /rekta/Actions lists its actions as they
// read now (ListActions, each with its state, a description for machines, its consequence and whether it can run), runs
// one (Invoke, which answers whether it was done, the state it set and why not) and sends ActionsChanged when what it
// lists changes. The shell's own are the Start's commands, run as the search runs them, so one that ends the session
// only opens the banner; an app's desktop action starts as the app does. The names are working names. In any other
// session it owns nothing.
// A call with "dry-run": true among its parameters (the property DryRunKey names it) does nothing and answers what the
// real one would: {done: false, would: whether it would be done, state?, reason?}.
// ponytail: any program on the bus may invoke; a portal with permissions per client is to guard it.
QtObject {
    id: actions

    // XDG_SESSION_DESKTOP of the session the shell runs in.
    required property string sessionDesktop
    // As the registry (Actions.list) has them.
    required property var entries
    // The shell's version as its starter was built with it.
    property string shellVersion: ""
    property bool exported: false
    // What ListActions answered when ActionsChanged was last sent, as JSON.
    property string announced: ""

    readonly property int version: 1
    readonly property string path: "/rekta/Actions"
    readonly property string interfaceName: "rekta.Actions1"
    // The key of Invoke's parameters that asks for a dry run; it is no parameter of any action.
    readonly property string dryRunKey: "dry-run"
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
        handler: (path, iface, member, args, reply) => actions.answer(member, args, reply)
    }

    // What an action is to a caller that cannot see the screen: none for one that only shows, irreversible for one that
    // ends the session, else undoable (forms.md, "Can be undone").
    function consequenceOf(command: var): string {
        if (command.consequence)
            return command.consequence;
        if (command.destructive)
            return "irreversible";
        return command.readOnly ? "none" : "undoable";
    }

    function described(command: var): var {
        const available = command.available !== false;
        const properties = {
            title: command.text ?? command.word,
            readOnly: command.readOnly ?? false,
            destructive: command.destructive ?? false,
            description: command.description ?? "",
            consequence: consequenceOf(command),
            available: available
        };
        if (!available)
            properties.reason = command.reason ?? "";
        const state = command.state?.();
        if (state !== undefined)
            properties.state = state;
        if (command.keywords?.length > 0)
            properties.keywords = command.keywords;
        if (command.key)
            properties.key = command.key;
        if (command.app)
            properties.app = command.app;
        if (command.icon)
            properties.icon = command.icon;
        if (command.parameters)
            properties.parameters = command.parameters;
        if (command.at !== undefined)
            properties.parameters = amountSchema;
        return [command.id, properties];
    }

    function listed(): var {
        return entries.map(described);
    }

    // What a JSON Schema type names, for a value that came over D-Bus; a type not listed here is not checked.
    readonly property var typeChecks: ({
            string: value => typeof value === "string",
            boolean: value => typeof value === "boolean",
            integer: value => Number.isInteger(value),
            number: value => typeof value === "number" && Number.isFinite(value),
            array: value => value instanceof Array,
            object: value => value !== null && typeof value === "object" && !(value instanceof Array)
        })

    // A type that typeChecks does not name is not checked.
    function fits(type: var, value: var): bool {
        const check = typeChecks[type];
        return check === undefined || check(value);
    }

    // A call may carry only the keys the action's JSON Schema names (any with additionalProperties: true, none without a
    // schema), each of the type the schema gives it. An amount's percent is checked by checkedPercent.
    function refuseBadParameters(command: var, parameters: var) {
        const schema = JSON.parse((command.at !== undefined ? amountSchema : command.parameters) || "{}");
        const properties = schema.properties ?? {};
        const names = Object.keys(properties);
        const unknown = schema.additionalProperties === true ? [] : Object.keys(parameters).filter(key => !names.includes(key));
        if (unknown.length > 0)
            throw new Error(`${command.id} takes ${names.length > 0 ? `only ${names.join(", ")}` : "no parameters"}, not ${unknown.join(", ")}`);
        if (command.at !== undefined)
            return;
        const wrong = Object.keys(parameters).find(key => !fits(properties[key]?.type, parameters[key]));
        if (wrong !== undefined)
            throw new Error(`${command.id} takes ${wrong} as ${properties[wrong].type}`);
    }

    function checkedPercent(command: var, parameters: var): int {
        const percent = parameters.percent;
        if (!Number.isInteger(percent) || percent < 0 || percent > 100)
            throw new Error(`${command.id} takes {"percent": a whole number from 0 to 100}`);
        return percent;
    }

    // `state` is what the command sets, when it has one. Where the shell only logs what it would do (Launcher), the
    // command still runs and the answer says nothing was done. A dry run runs nothing.
    function ran(command: var, run: var, state: var, dry: bool): var {
        if (!dry)
            run();
        if (command.acts?.() === false)
            return {
                done: false,
                reason: "the shell runs without REKTA_SHELL_LAUNCH=systemd and only logs what it would do"
            };
        return state === undefined ? {
            done: true
        } : {
            done: true,
            state: state
        };
    }

    function dryRunAsked(command: var, parameters: var): bool {
        const asked = parameters[dryRunKey];
        if (asked !== undefined && typeof asked !== "boolean")
            throw new Error(`${command.id} takes ${dryRunKey} as boolean`);
        return asked === true;
    }

    function withoutDryRun(parameters: var): var {
        const rest = {};
        Object.keys(parameters).filter(key => key !== dryRunKey).forEach(key => rest[key] = parameters[key]);
        return rest;
    }

    // What the real run would have answered, as a dry run says it: nothing was done, `would` tells whether it would be.
    function wouldBe(command: var, outcome: var): var {
        const answer = Object.assign({}, outcome, {
            done: false,
            would: outcome.done
        });
        console.info(`ActionsInterface: would invoke ${command.id} (dry run): ${JSON.stringify(answer)}`);
        return answer;
    }

    // What a run of the action ends in. An action that answers later (a provider's) returns `reply` and sends its answer
    // through it, unless the run is dry.
    function outcomeOf(command: var, parameters: var, reply: var, dry: bool): var {
        refuseBadParameters(command, parameters);
        const percent = command.at === undefined ? undefined : checkedPercent(command, parameters);
        if (command.available === false)
            return {
                done: false,
                reason: command.reason ?? "not available now"
            };
        if (command.invokeWith !== undefined && command.acts?.() !== false)
            return command.invokeWith(parameters, reply, dry);
        if (command.at === undefined)
            return ran(command, command.run, command.becomes?.(), dry);
        return ran(command, command.at(percent).run, percent, dry);
    }

    // The answer of Invoke: {done, state?, reason?}. A call that cannot be understood (an unknown action, an unknown or
    // wrongly typed parameter) is an error; an action that exists but does not go is done: false with its reason. With
    // "dry-run": true the checks are the same and the answer is wouldBe's.
    function invoke(id: string, parameters: var, reply: var): var {
        const command = entries.find(candidate => candidate.id === id);
        if (command === undefined)
            throw new Error(`there is no action ${id}`);
        const dry = dryRunAsked(command, parameters);
        const outcome = outcomeOf(command, withoutDryRun(parameters), reply, dry);
        return dry ? wouldBe(command, outcome) : outcome;
    }

    function answer(member: string, args: var, reply: var): var {
        switch (member) {
        case "ListActions":
            return listed();
        case "Invoke":
            return invoke(args[0], args[1], reply);
        case "Version":
            return version;
        case "ShellVersion":
            return shellVersion;
        case "DryRunKey":
            return dryRunKey;
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
              <property name="ShellVersion" type="s" access="read">
                <annotation name="org.freedesktop.DBus.Property.EmitsChangedSignal" value="const"/>
              </property>
              <property name="DryRunKey" type="s" access="read">
                <annotation name="org.freedesktop.DBus.Property.EmitsChangedSignal" value="const"/>
              </property>
            </interface>`);
    }
}
