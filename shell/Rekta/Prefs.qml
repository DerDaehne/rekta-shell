pragma Singleton
import QtQuick

// The four inputs that pick Rekta's values (platforms.md, "Switching"): theme, density and motion each follow a
// system source unless overridden; the window-size class follows the place. Prefs feeds the first three to Tokens.
QtObject {
    id: prefs

    // Overrides; the override wins over the system.
    property string theme: "system" // system | light | dark
    property string density: "auto" // auto | comfortable | compact
    property string motion: "system" // system | on | off

    // System sources. Under Plasma the KDE platform theme feeds the colour scheme; the shell sets reduced motion.
    property int systemColorScheme: Application.styleHints.colorScheme
    property bool systemReducedMotion: false
    // ponytail: no touch detection yet, so "auto" is compact (a fine pointer); detect touch screens when one appears.
    property bool systemHasTouch: false

    readonly property string resolvedTheme: theme !== "system" ? theme : systemColorScheme === Qt.ColorScheme.Dark ? "dark" : "light"
    readonly property string resolvedDensity: density !== "auto" ? density : systemHasTouch ? "comfortable" : "compact"
    readonly property bool reducedMotion: motion === "off" || (motion === "system" && systemReducedMotion)

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
        }
    ]

    // Sideways when the place is wide enough and the viewport not too short, else compact (layout.md, size classes).
    function sizeClass(placeWidth: real, viewportHeight: real): string {
        return placeWidth >= Tokens.bpSidewaysScrollMin && viewportHeight > Tokens.bpShortHeight ? "sideways" : "compact";
    }
}
