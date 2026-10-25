.pragma library

// Plasma's pair of global themes for light and dark, and its defaults where kdeglobals names none
// (plasma-workspace kcms/lookandfeel/lookandfeelsettings.kcfg).
const defaults = {
    light: "org.kde.breeze.desktop",
    dark: "org.kde.breezedark.desktop"
};

const keys = {
    DefaultLightLookAndFeel: "light",
    DefaultDarkLookAndFeel: "dark"
};

// The pair a kdeglobals text names in its [KDE] group, also with KConfig flags such as [$i].
function pair(ini) {
    const themes = Object.assign({}, defaults);
    let inKdeGroup = false;
    for (const rawLine of ini.split("\n")) {
        const line = rawLine.trim();
        if (line.startsWith("[")) {
            inKdeGroup = /^\[KDE\](\[\$[^\]]*\])*$/.test(line);
            continue;
        }
        const entry = /^(\w+)(\[[^\]]*\])*\s*=\s*(.*)$/.exec(line);
        if (inKdeGroup && entry && entry[1] in keys && entry[3] !== "")
            themes[keys[entry[1]]] = entry[3];
    }
    return themes;
}

// Applies the pair's dark or light theme. Plasma's tool also turns its automatic switch between the two off, as the
// user has chosen (plasma-workspace kcms/lookandfeel/tool/lnftool.cpp).
function command(dark, ini) {
    const themes = pair(ini);
    return ["plasma-apply-lookandfeel", "--apply", dark ? themes.dark : themes.light];
}
