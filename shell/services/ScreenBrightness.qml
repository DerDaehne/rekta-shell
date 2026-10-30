import QtQuick
import RektaShell.DBus

// The displays powerdevil can dim, with their label, brightness and maximum, kept current from its signals. It lists
// none while powerdevil is not on the bus and picks them up once it appears. powerdevil names no screen a display
// belongs to, so a display is known by its label.
// The key readout and the side panel share this one source.
QtObject {
    id: source

    readonly property string service: "org.kde.ScreenBrightness"
    readonly property string rootInterface: "org.kde.ScreenBrightness"
    readonly property string rootPath: "/org/kde/ScreenBrightness"
    readonly property string displayInterface: "org.kde.ScreenBrightness.Display"
    readonly property string propertiesInterface: "org.freedesktop.DBus.Properties"

    // Rows of name (the D-Bus name), title (powerdevil's label), brightness and max, in powerdevil's order; updated in place.
    readonly property ListModel displays: ListModel {}

    // Every change powerdevil tells, with the client and context that asked for it; the display is listed already.
    signal changed(string display, int brightness, string source, string context)

    // Display names as powerdevil lists them: what a late answer is checked against.
    property var names: []

    readonly property DBusConnection bus: DBusConnection {
        onReceived: (sender, path, iface, member, args) => source.heard(member, args)
    }

    function indexOf(name: string): int {
        for (let row = 0; row < displays.count; ++row) {
            if (displays.get(row).name === name)
                return row;
        }
        return -1;
    }

    function maxOf(name: string): int {
        return displays.get(indexOf(name))?.max ?? 0;
    }

    // One step of the scale of a display; the flag keeps powerdevil from showing its own indicator.
    function setBrightness(name: string, value: int) {
        if (indexOf(name) < 0)
            return;
        const silent = 1;
        bus.call(service, `${rootPath}/${name}`, displayInterface, "SetBrightness", [value, silent], "iu", error => {
            if (error)
                console.warn(`ScreenBrightness: ${name}: ${error}`);
        });
    }

    function refresh() {
        bus.call(service, rootPath, propertiesInterface, "Get", [rootInterface, "DisplaysDBusNames"], "ss", (error, values) => {
            names = error ? [] : values[0];
            for (let row = displays.count - 1; row >= 0; --row) {
                if (!names.includes(displays.get(row).name))
                    displays.remove(row);
            }
            names.forEach(load);
        });
    }

    function load(name: string) {
        bus.call(service, `${rootPath}/${name}`, propertiesInterface, "GetAll", [displayInterface], "s", (error, values) => {
            if (!error && names.includes(name))
                store(name, values[0]);
        });
    }

    function store(name: string, properties: var) {
        const row = { name, title: properties.Label, brightness: properties.Brightness, max: properties.MaxBrightness };
        const at = indexOf(name);
        if (at >= 0)
            displays.set(at, row);
        else
            displays.insert(Math.min(Math.max(names.indexOf(name), 0), displays.count), row);
    }

    function heard(member: string, args: var) {
        switch (member) {
        case "NameOwnerChanged":
            if (args[0] === service)
                refresh();
            break;
        case "DisplayAdded":
            if (!names.includes(args[0]))
                names = names.concat(args[0]);
            load(args[0]);
            break;
        case "DisplayRemoved":
            names = names.filter(name => name !== args[0]);
            if (indexOf(args[0]) >= 0)
                displays.remove(indexOf(args[0]));
            break;
        case "BrightnessChanged":
            if (indexOf(args[0]) >= 0)
                displays.setProperty(indexOf(args[0]), "brightness", args[1]);
            changed(args[0], args[1], args[2], args[3]);
            break;
        case "BrightnessRangeChanged":
            if (indexOf(args[0]) < 0)
                break;
            displays.setProperty(indexOf(args[0]), "max", args[1]);
            displays.setProperty(indexOf(args[0]), "brightness", args[2]);
            break;
        }
    }

    Component.onCompleted: {
        for (const member of ["DisplayAdded", "DisplayRemoved", "BrightnessChanged", "BrightnessRangeChanged"])
            bus.listen(rootInterface, member, service, rootPath);
        bus.listen("org.freedesktop.DBus", "NameOwnerChanged", "org.freedesktop.DBus", "/org/freedesktop/DBus");
        refresh();
    }
}
