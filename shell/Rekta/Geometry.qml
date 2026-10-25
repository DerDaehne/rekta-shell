pragma Singleton
import QtQuick

// Fixed values Rekta Design keeps as literals rather than tokens: its fixed geometry, the same in every theme and
// density (rekta.css, header), the motion of the loading line, the dots, the place change and live tile news, which
// has no tokens yet, and the CSS timing keywords Rekta uses where it has no curve token (ease-in-out). Each value names
// the rule it comes from in rekta.css (or rekta.js) at the pinned commit.
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
    // `.rk-stat b { line-height: 1 }` (rekta.css:95)
    readonly property real statLineHeight: 1
    // `.rk-tile-msg { line-clamp: 4 }`, `.rk-w2 > .rk-tile-msg { line-clamp: 6 }` (rekta.css:104, :107)
    readonly property int tileMessageLines: 4
    readonly property int tileMessageLinesWide: 6
    // `.rk-actions > .rk-why { flex: 1 1 12rem }` (rekta.css:290); the web build writes 16px as 1rem
    readonly property real whyBasis: 192
    // `.rk-float { min-width: 12rem; max-width: min(24rem, …); max-height: min(24rem, 60dvh); border: 1px solid … }`
    // (rekta.css:781–782); a rem is 16 logical px, as the web build writes lengths (scripts/build.mjs:74)
    readonly property real floatMinWidth: 192
    readonly property real floatMaxSize: 384
    readonly property real floatMaxHeightShare: 0.6
    readonly property real floatBorder: 1
    // `@keyframes rk-float-in { from { opacity: 0; transform: translateY(var(--_rk-from, -4px)) } }`, 4px from below
    // when above its control (rekta.css:785–787; the tip :421–422)
    readonly property real floatShift: 4
    // place(): `gap = 4` between a control and its floating surface (rekta.js:1655)
    readonly property real floatGap: 4
    // `.rk-menu-item:focus-visible { outline-offset: -2px }` (rekta.css:793)
    readonly property real focusRingInsetInRow: 2
    // `.rk-menu-item[role='menuitemcheckbox']::before { width: 10px; height: 10px; border: 1px solid currentColor }`
    // (rekta.css:795)
    readonly property real menuCheck: 10
    readonly property real menuCheckBorder: 1
    // `.rk-tip { max-width: min(20rem, …); padding: 4px var(--rk-space-s) }` (rekta.css:417–418)
    readonly property real tipMaxWidth: 320
    readonly property real tipPaddingY: 4
    // placeTip(): `gap = 6` between a control and its tip (rekta.js:2549)
    readonly property real tipGap: 6
    // `.rk-ab { gap: 6px; min-width: 48px; min-height: 48px; padding: 0 10px }`, `.rk-ab svg { width: 20px; height: 20px }`
    // (rekta.css:622, :629)
    readonly property real appBarControl: 48
    readonly property real appBarControlPadding: 10
    readonly property real appBarControlGap: 6
    readonly property real appBarGlyph: 20
    // `.rk-ab-mid[data-rk-priority='pinned'] { max-width: 50% }` of the bar (rekta.css:645)
    readonly property real appBarPinnedShare: 0.5

    // rekta-core's month, the one Rekta draws (core/src/controls.c): `#define CELL 36.0f` (:754); today in a 1px frame
    // 2px inside its cell, `in = { cell.x + 2, … }`, `rk_canvas_stroke_rect(c, in, 1, ink)` (:929, :932)
    readonly property real monthCell: 36
    readonly property real monthTodayInset: 2
    readonly property real monthTodayFrame: 1

    // The place change (motion.md:11), whose angles, curves and shares have no tokens yet.
    // `:root { --_rk-turn-out: 60deg; --_rk-turn-in: 70deg; --_rk-ease-turn-out: cubic-bezier(0.35, 0, 0.65, 0.6);
    // --_rk-ease-turn-in: cubic-bezier(0.22, 0.9, 0.6, 0.98) }` (rekta.css:975)
    readonly property real turnOutAngle: 60
    readonly property real turnInAngle: 70
    readonly property var easeTurnOut: [0.35, 0, 0.65, 0.6, 1, 1]
    readonly property var easeTurnIn: [0.22, 0.9, 0.6, 0.98, 1, 1]
    // `@keyframes rk-turn-out { 40% { opacity: 1 } }`, `@keyframes rk-turn-in { 35% { opacity: 1 } }` (rekta.css:988–1011)
    readonly property real turnOutWhole: 0.4
    readonly property real turnInWhole: 0.35
    // `heft(r) = min(1.4, max(0.5, 0.8 × (area / 22500)^0.35))`, 22500 being a tile-unit square (rekta.js:375)
    readonly property real heftAtTile: 0.8
    readonly property real heftExponent: 0.35
    readonly property real heftMin: 0.5
    readonly property real heftMax: 1.4
    // A part starts `(h - 0.5) × 6 × stagger + min(n, 6) × stagger / 2` after the turn, the n-th of its heft, which
    // rounds to 1/20 (rekta.js:378–386)
    readonly property real heftStaggerSteps: 6
    readonly property int sameHeftSteps: 6
    readonly property real sameHeftStagger: 0.5
    readonly property real sameHeftWithin: 0.05
    // A row is the parts whose tops round alike to 8px; one flush with the clipping top (within 2px) turns from its top
    // (rekta.js:399, 432, 438)
    readonly property real turnRowStep: 8
    readonly property real turnFlushTop: 2
    // `perspective = turnstile-perspective + 1.2 × the row's reach from the edge` (rekta.js:443)
    readonly property real turnPerspectivePerReach: 1.2
    // The next place starts when the last part of the one leaving is 75% through (rekta.js:489)
    readonly property real turnOverlap: 0.75

    // `@keyframes rk-build-in { from { opacity: 0; transform: translateY(6px) } }`, delayed by
    // `min(var(--rk-i, 0), 10) * var(--rk-duration-stagger)` (rekta.css:110, :91)
    readonly property real buildInRise: 6
    readonly property int buildInStaggerCap: 10
    // A peek moves the stat by `translateY(40%)` of its own height (rekta.js:3473–3474); a flip turns the tile to
    // `rotateX(-90deg)` and back from `rotateX(90deg)` (rekta.js:3456, :3460)
    readonly property real peekShift: 0.4
    readonly property real flipAngle: 90
    // A display takes a bar control's place by turning it away and itself in, as a tile flips (rekta.js:3456, :3460),
    // 200ms each way, and stays 1.7s after the last key; Rekta has no tokens for these yet
    readonly property int flipDuration: 200
    readonly property int displayHold: 1700
    // `.rk-spark polyline { stroke-width: 2; stroke-linejoin: round }` in the sparkline's 200 × 28 box (rekta.css:140,
    // :143); `[data-rk-live='stale'] .rk-spark { opacity: 0.35 }` (rekta.css:501)
    readonly property real sparkBoxWidth: 200
    readonly property real sparkBoxHeight: 28
    readonly property real sparkStroke: 2
    readonly property real sparkStaleOpacity: 0.35

    // `.rk-icon { width: 20px; height: 20px }` (rekta.css:425)
    readonly property real iconSize: 20
    // `.rk-toast { max-width: 32rem }` sideways (rekta.css:1106)
    readonly property real toastMaxWidth: 512
    // The action's divider: `border-left: 1px solid color-mix(in srgb, currentColor 20%, transparent)` (rekta.css:914)
    readonly property real toastDividerOpacity: 0.2
    // `.rk-toast-act:focus-visible { outline: 2px solid currentColor; outline-offset: -10px }` (rekta.css:917)
    readonly property real toastFocusInset: 10
    // The undo window's line: `border-top: 2px solid` (rekta.css:924)
    readonly property real toastLine: 2
    // `@keyframes rk-banner-in { from { opacity: 0; transform: translateY(-8px) } }` (rekta.css:955)
    readonly property real bannerShift: 8

    // `.rk-sheet { width: min(32rem, 100%) }` (rekta.css:826), a rem being 16 logical px
    readonly property real sheetMaxWidth: 512
    // `@keyframes rk-from-top { from { opacity: 0; transform: translateY(-16px) } }` (rekta.css:846); a sheet leaves
    // back up the same way (rekta.js:1539)
    readonly property real sheetShift: 16
}
