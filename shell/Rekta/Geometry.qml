pragma Singleton
import QtQuick

// Fixed values Rekta Design keeps as literals rather than tokens: its fixed geometry, the same in every theme and
// density (rekta.css, header), and the motion of the loading line and the dots, which has no tokens yet. Each value
// names the rule it comes from in rekta.css at the pinned commit.
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
    // `.rk-clamp { line-clamp: 3 }` on the one main title (rekta.css:102)
    readonly property int titleMaxLines: 3

    // `.rk-region[aria-busy='true']::before { height: 2px; background: … no-repeat -50% 0 / 30% 100% }` with
    // `@keyframes rk-busy { from { background-position: -50% 0 } to { background-position: 150% 0 } }` (rekta.css:666–671)
    readonly property real busyLineHeight: 2
    readonly property real busySegment: 0.3
    readonly property real busyFrom: -0.5
    readonly property real busyTo: 1.5
    // `.rk-progress { height: 4px; background: color-mix(in srgb, currentColor 20%, transparent) }` (rekta.css:128)
    readonly property real progressHeight: 4
    readonly property real progressTrackOpacity: 0.2
    // `.rk-meter { height: 6px }` (rekta.css:552)
    readonly property real meterHeight: 6
    // `.rk-tag { gap: 6px }`, `.rk-tag::before { width: 8px; height: 8px }` (rekta.css:609–610)
    // The same square starts a field's error: `.rk-field[data-status='error'] .rk-hint::before { width: 8px; height: 8px;
    // margin-right: 6px }` (rekta.css:277)
    readonly property real tagGap: 6
    readonly property real tagMark: 8
    // `.rk-dots > i { width: 4px; height: 4px; animation-delay: calc(n × duration-dots × 0.07) }` (rekta.css:569–573)
    readonly property int dotCount: 5
    readonly property real dotSize: 4
    readonly property real dotStagger: 0.07
    // `@keyframes rk-dots` (rekta.css:574–581): where a dot is, as a share of the width, at each share of its flight.
    readonly property real dotStart: -0.02
    readonly property real dotVisibleAt: 0.06
    readonly property real dotSlowFrom: 0.35
    readonly property real dotSlowFromAt: 0.44
    readonly property real dotSlowUntil: 0.62
    readonly property real dotSlowUntilAt: 0.56
    readonly property real dotFadeFrom: 0.9
    readonly property real dotEnd: 1.02
    readonly property var dotEaseIn: [0.1, 0.7, 0.4, 1, 1, 1]
    readonly property var dotEaseOut: [0.6, 0, 0.9, 0.3, 1, 1]
    // Under reduced motion `left: calc(50% - 22px + n × 10px)` (rekta.css:1214)
    readonly property real dotRestOffset: 22
    readonly property real dotRestSpacing: 10
    // `.rk-input { padding: 0 12px; border: 1px solid … }`, in error `padding-inline: 11px; border: 2px solid …` (rekta.css:266, :275)
    readonly property real inputPadding: 12
    readonly property real inputBorder: 1
    readonly property real inputErrorBorder: 2
    // `.rk-toggle-track { width: 46px; height: 22px; padding: 2px; border: 2px }`, the thumb `width: 12px` moving
    // `translateX(34px)`, the fill `calc(100% - 14px)` of the content box (rekta.css:335–345; border-box, :38)
    readonly property real toggleWidth: 46
    readonly property real toggleHeight: 22
    readonly property real togglePadding: 2
    readonly property real toggleBorder: 2
    readonly property real toggleThumb: 12
    // `.rk-toggle-word { min-width: 2.2em }` (rekta.css:351), in em of the word's size
    readonly property real toggleWordWidth: 2.2
    // `.rk-range` track `height: 6px`, thumb `width: 10px; height: 24px` (rekta.css:368, :372); `.rk-range + output
    // { min-width: 3.5em }` (:378), in em of the value's size
    readonly property real sliderTrack: 6
    readonly property real sliderThumbWidth: 10
    readonly property real sliderThumbHeight: 24
    readonly property real sliderOutputWidth: 3.5
    // `.rk-segments > label { border: 2px solid … }`, joined by `margin-left: -2px` (rekta.css:390, :393)
    readonly property real segmentBorder: 2
    // `.rk-btn { border: 2px solid currentColor }` (rekta.css:213)
    readonly property real buttonBorder: 2
    // `.rk-btn[data-rk-pending]::after { inset: auto 0 -6px }` (rekta.css:681): the line runs under the button and ends
    // 6px below its padding box
    readonly property real pendingLineBelow: 6
    // `.rk-btn--icon > svg { width: 20px; height: 20px }` (rekta.css:229)
    readonly property real buttonGlyph: 20
    // `.rk-tile { padding: 12px }` (rekta.css:83)
    readonly property real tilePadding: 12
    // `.rk-tile-word { top: 10px; right: 12px }` (rekta.css:94)
    readonly property real tileWordTop: 10
    readonly property real tileWordRight: 12
    // A press gives up once the pointer moves this far: `> (start.touch ? 8 : 4)` (rekta.js:301)
    readonly property real pressSlopMouse: 4
    readonly property real pressSlopTouch: 8
    // The pivot's size and step change use the CSS keyword `ease-in-out` (rekta.css:165, :187), which CSS defines as
    // cubic-bezier(0.42, 0, 0.58, 1)
    readonly property var easeInOut: [0.42, 0, 0.58, 1, 1, 1]
}
