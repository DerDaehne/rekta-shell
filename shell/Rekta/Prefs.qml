pragma Singleton
import QtQuick

// The inputs that pick Rekta's values (platforms.md, "Switching"): theme, density, motion, contrast and transparency each
// follow a system source unless overridden, the ground is the person's choice alone; the window-size class follows
// the place. Prefs feeds the first six to Tokens.
QtObject {
    id: prefs

    // Overrides; the override wins over the system.
    property string theme: "system" // system | light | dark
    property string ground: "normal" // normal | black; the person's choice, no system source (colour.md:135–138)
    property string density: "auto" // auto | comfortable | compact
    property string motion: "system" // system | on | off
    property string contrast: "system" // system | more | normal
    property string transparency: "system" // system | reduce | normal

    // System sources. Under Plasma the KDE platform theme feeds the colour scheme; the shell sets reduced motion.
    property int systemColorScheme: Application.styleHints.colorScheme
    property bool systemReducedMotion: false
    // ponytail: Plasma 6.8's portal sends no contrast, so this stays false there; it follows once a platform sets it.
    property bool systemMoreContrast: Application.styleHints.accessibility.contrastPreference === Qt.ContrastPreference.HighContrast
    // ponytail: neither Qt 6.12 nor Plasma 6.8 reports reduced transparency, so this stays false and only the override
    // reduces it; bind it here once a platform reports one.
    property bool systemReducedTransparency: false
    // ponytail: no touch detection yet, so "auto" is compact (a fine pointer); detect touch screens when one appears.
    property bool systemHasTouch: false

    readonly property string resolvedTheme: theme !== "system" ? theme : systemColorScheme === Qt.ColorScheme.Dark ? "dark" : "light"
    // The black ground lies under the dark theme only; the light theme keeps its own (platforms.md:75).
    readonly property bool black: resolvedTheme === "dark" && ground === "black"
    readonly property string resolvedDensity: density === "comfortable" || density === "compact" ? density : systemHasTouch ? "comfortable" : "compact"
    readonly property bool reducedMotion: motion === "off" || (motion === "system" && systemReducedMotion)
    readonly property bool moreContrast: moreContrastFor(contrast)
    readonly property bool reducedTransparency: reducedTransparencyFor(transparency)

    readonly property list<Binding> bindings: [
        Binding {
            target: Tokens
            property: "theme"
            value: prefs.resolvedTheme
        },
        Binding {
            target: Tokens
            property: "ground"
            value: prefs.ground
        },
        Binding {
            target: Tokens
            property: "density"
            value: prefs.resolvedDensity
        },
        Binding {
            target: Tokens
            property: "reducedMotion"
            value: prefs.reducedMotion
        },
        Binding {
            target: Tokens
            property: "moreContrast"
            value: prefs.moreContrast
        },
        Binding {
            target: Tokens
            property: "reducedTransparency"
            value: prefs.reducedTransparency
        }
    ]

    // Whether a contrast setting means more contrast; anything but more and normal follows the system.
    function moreContrastFor(setting: string): bool {
        return setting === "more" || (setting !== "normal" && systemMoreContrast);
    }

    // Whether a transparency setting means less transparency; anything but reduce and normal follows the system.
    function reducedTransparencyFor(setting: string): bool {
        return setting === "reduce" || (setting !== "normal" && systemReducedTransparency);
    }

    // Sideways when the place is wide enough and the viewport not too short, else compact (layout.md, size classes).
    function sizeClass(placeWidth: real, viewportHeight: real): string {
        return placeWidth >= Tokens.bpSidewaysScrollMin && viewportHeight > Tokens.bpShortHeight ? "sideways" : "compact";
    }
}
