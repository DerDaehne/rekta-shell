pragma Singleton
import QtQuick

// The inputs that pick Rekta's values (platforms.md, "Switching"): theme, density, motion and contrast each follow a
// system source unless overridden; the window-size class follows the place. Prefs feeds the first four to Tokens.
QtObject {
    id: prefs

    // Overrides; the override wins over the system.
    property string theme: "system" // system | light | dark
    property string density: "auto" // auto | comfortable | compact
    property string motion: "system" // system | on | off
    property string contrast: "system" // system | more | normal

    // System sources. Under Plasma the KDE platform theme feeds the colour scheme; the shell sets reduced motion.
    property int systemColorScheme: Application.styleHints.colorScheme
    property bool systemReducedMotion: false
    // ponytail: Plasma 6.8's portal sends no contrast, so this stays false there; it follows once a platform sets it.
    property bool systemMoreContrast: Application.styleHints.accessibility.contrastPreference === Qt.ContrastPreference.HighContrast
    // ponytail: no touch detection yet, so "auto" is compact (a fine pointer); detect touch screens when one appears.
    property bool systemHasTouch: false

    readonly property string resolvedTheme: theme !== "system" ? theme : systemColorScheme === Qt.ColorScheme.Dark ? "dark" : "light"
    readonly property string resolvedDensity: density === "comfortable" || density === "compact" ? density : systemHasTouch ? "comfortable" : "compact"
    readonly property bool reducedMotion: motion === "off" || (motion === "system" && systemReducedMotion)
    readonly property bool moreContrast: moreContrastFor(contrast)

    readonly property list<Binding> bindings: [
        Binding {
            target: Tokens
            property: "theme"
            value: prefs.resolvedTheme
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
        }
    ]

    // Whether a contrast setting means more contrast; anything but more and normal follows the system.
    function moreContrastFor(setting: string): bool {
        return setting === "more" || (setting !== "normal" && systemMoreContrast);
    }

    // Sideways when the place is wide enough and the viewport not too short, else compact (layout.md, size classes).
    function sizeClass(placeWidth: real, viewportHeight: real): string {
        return placeWidth >= Tokens.bpSidewaysScrollMin && viewportHeight > Tokens.bpShortHeight ? "sideways" : "compact";
    }
}
