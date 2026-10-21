pragma Singleton
import QtQuick

// Fixed geometry Rekta Design keeps as literals rather than tokens: the same in every theme and density
// (rekta.css, header). Each value names the rule it comes from in rekta.css at the pinned commit.
QtObject {
    // `.rk-rows > li { border-top: 1px solid var(--rk-text-contrast-low) }` (rekta.css:69)
    readonly property real hairline: 1
    // `.rk :focus-visible { outline: 2px solid var(--rk-focus); outline-offset: 2px }` (rekta.css:42)
    readonly property real focusRingWidth: 2
    readonly property real focusRingOffset: 2
    // `.rk-tile:focus-visible { outline: 2px solid currentColor; outline-offset: -5px }` (rekta.css:93)
    readonly property real focusRingInsetOnFill: 5
    // `.rk-kicker { letter-spacing: 0.02em }` (rekta.css:50), in em of the kicker's own size
    readonly property real kickerLetterSpacing: 0.02
}
