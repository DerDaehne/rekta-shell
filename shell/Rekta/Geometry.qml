pragma Singleton
import QtQuick

// Fixed values Rekta Design keeps as literals rather than tokens: its fixed geometry, the same in every theme and
// density (rekta.css:3–7), and the few numbers of its motion that rekta.css and rekta.js write out. Each value names
// the rule it comes from in Rekta Design at the pinned commit.
QtObject {
    // `.rk-rows > li { border-top: 1px solid var(--rk-text-contrast-low) }` (rekta.css:74)
    readonly property real hairline: 1
    // `.rk :focus-visible { outline: 2px solid var(--rk-focus); outline-offset: 2px }` (rekta.css:44)
    readonly property real focusRingWidth: 2
    readonly property real focusRingOffset: 2
    // `.rk-tile:focus-visible { outline: 2px solid currentColor; outline-offset: -5px }` (rekta.css:107)
    readonly property real focusRingInsetOnFill: 5
    // `.rk-kicker { letter-spacing: 0.02em }` (rekta.css:52), in em of the kicker's own size
    readonly property real kickerLetterSpacing: 0.02
    // `.rk-key { padding: 0 4px; min-width: 1.6em; line-height: 1.5 }` (rekta.css:1049); the width in em of the key's size
    readonly property real keyPadding: 4
    readonly property real keyMinWidth: 1.6
    readonly property real keyLineHeight: 1.5
    // `.rk-clamp { line-clamp: 3 }` on the one main title (rekta.css:120)
    readonly property int titleMaxLines: 3

    // `.rk-region[aria-busy='true']::before { height: 2px }` (rekta.css:874–875)
    readonly property real busyLineHeight: 2
    // `.rk-progress { height: 4px; background: color-mix(in srgb, currentColor 20%, transparent) }` (rekta.css:207)
    readonly property real progressHeight: 4
    readonly property real progressTrackOpacity: 0.2
    // `.rk-meter { height: 6px }` (rekta.css:711)
    readonly property real meterHeight: 6
    // `.rk-tag { gap: 6px }`, `.rk-tag::before { width: 8px; height: 8px }` (rekta.css:790–791)
    // The same square starts a field's error: `.rk-field[data-status='error'] .rk-hint::before { width: 8px; height: 8px;
    // margin-right: 6px }` (rekta.css:407)
    readonly property real tagGap: 6
    readonly property real tagMark: 8
    // In the ink toast: `.rk-toast:not([data-status]) .rk-tag:not(.rk-tag--soft)::before { box-shadow: 0 0 0 1px
    // currentColor }` (rekta.css:1179)
    readonly property real tagEdge: 1
    // `.rk-dots > i { width: 4px; height: 4px }`, five of them (rekta.css:729–733)
    readonly property int dotCount: 5
    readonly property real dotSize: 4
    // Under reduced motion `left: calc(50% - 22px + n × 10px)` (rekta.css:1533)
    readonly property real dotRestOffset: 22
    readonly property real dotRestSpacing: 10
    // `.rk-input { padding: 0 12px; border: 1px solid … }`, in error `padding-inline: 11px; border: 2px solid …` (rekta.css:389, :405)
    readonly property real inputPadding: 12
    readonly property real inputBorder: 1
    readonly property real inputErrorBorder: 2
    // `select.rk-input { padding-right: 36px; background-position: right 18px center, right 14px center }`: the chevron's
    // two 4px arms meet 18px before the end of the padding box (rekta.css:434–436)
    readonly property real selectPaddingEnd: 36
    readonly property real selectChevronEnd: 18
    // A combobox (rekta.css:455–460): `.rk-combo > .rk-input { padding-right: 40px }`; its button `inset: 1px 1px 1px
    // auto; width: 36px`, the chevron's two 4px arms from 14px into it, 8 × 4px in all (forms.md:77)
    readonly property real comboPaddingEnd: 40
    readonly property real comboButton: 36
    readonly property real comboChevronStart: 14
    readonly property real comboChevronWidth: 8
    // An option of a combobox's list (rekta.css:464–465): `::before { width: 10px; height: 6px; margin: -3px 2px 0 0 }`,
    // chosen a tick, `border-width: 0 0 2px 2px; transform: rotate(-45deg)`
    readonly property real optionTickWidth: 10
    readonly property real optionTickHeight: 6
    readonly property real optionTickRaise: 3
    readonly property real optionTickGap: 2
    readonly property real optionTickStroke: 2
    readonly property real optionTickAngle: -45
    // `.rk-toggle-track { width: 46px; height: 22px; padding: 2px; border: 2px }`, the thumb `width: 12px` moving
    // `translateX(34px)`, the fill `calc(100% - 14px)` of the content box (rekta.css:475–485; border-box, :40)
    readonly property real toggleWidth: 46
    readonly property real toggleHeight: 22
    readonly property real togglePadding: 2
    readonly property real toggleBorder: 2
    readonly property real toggleThumb: 12
    // `.rk-toggle-word { min-width: 2.2em }` (rekta.css:492), in em of the word's size
    readonly property real toggleWordWidth: 2.2
    // `.rk-range` track `height: 6px`, thumb `width: 10px; height: 24px` (rekta.css:511, :515); `.rk-range + output
    // { min-width: 3.5em }` (:526), in em of the value's size
    readonly property real sliderTrack: 6
    readonly property real sliderThumbWidth: 10
    readonly property real sliderThumbHeight: 24
    readonly property real sliderOutputWidth: 3.5
    // `.rk-segments > label { border: 2px solid … }`, joined by `margin-left: -2px` (rekta.css:540, :543)
    readonly property real segmentBorder: 2
    // `.rk-btn { border: 2px solid currentColor }` (rekta.css:322)
    readonly property real buttonBorder: 2
    // `.rk-btn[data-rk-pending]::after { inset: auto 0 -6px }` (rekta.css:896): the line runs under the button and ends
    // 6px below its padding box
    readonly property real pendingLineBelow: 6
    // `.rk-btn--icon > svg { width: 20px; height: 20px }` (rekta.css:350)
    readonly property real buttonGlyph: 20
    // `.rk-tile { padding: 12px }` (rekta.css:91); a preview tile's foot, `.rk-tile-foot { padding: var(--rk-space-s) 12px }`
    // (rekta.css:135)
    readonly property real tilePadding: 12
    // `.rk-tile-word { top: 10px; right: 12px }` (rekta.css:108)
    readonly property real tileWordTop: 10
    readonly property real tileWordRight: 12
    // Under more contrast `.rk-tile[data-status] { box-shadow: inset 0 0 0 2px var(--_rk-mark) }` (rekta.css:1552)
    readonly property real tileStatusFrame: 2
    // A press gives up once the pointer moves this far: `> (start.touch ? 8 : 4)` (rekta.js:331)
    readonly property real pressSlopMouse: 4
    readonly property real pressSlopTouch: 8
    // `.rk-stat b { line-height: 1 }` (rekta.css:109)
    readonly property real statLineHeight: 1
    // `.rk-launch-count { line-height: 1 }` (rekta.css:181)
    readonly property real launchCountLineHeight: 1
    // `.rk-launch-peek { line-clamp: 2 }` (rekta.css:183)
    readonly property int launchLineCount: 2
    // `.rk-tile-msg { line-clamp: 4 }`, `.rk-w2 > .rk-tile-msg { line-clamp: 6 }` (rekta.css:122, :125)
    readonly property int tileMessageLines: 4
    readonly property int tileMessageLinesWide: 6
    // `.rk-actions > .rk-why { flex: 1 1 12rem }` (rekta.css:420); the web build writes 16px as 1rem
    readonly property real whyBasis: 192
    // `.rk-float { min-width: 12rem; max-width: min(24rem, …); max-height: min(24rem, 60dvh); border: 1px solid … }`
    // (rekta.css:1005–1006); a rem is 16 logical px, as the web build writes lengths (scripts/build.mjs:82)
    readonly property real floatMinWidth: 192
    readonly property real floatMaxSize: 384
    readonly property real floatMaxHeightShare: 0.6
    readonly property real floatBorder: 1
    // `@keyframes rk-float-in { from { opacity: 0; transform: translateY(var(--_rk-from, -4px)) } }`, 4px from below
    // when above its control (rekta.css:1009–1011; the tip :576–577)
    readonly property real floatShift: 4
    // `.rk-menu-item:focus-visible { outline-offset: -2px }` (rekta.css:1017), the active row of a long list's
    // (rekta.css:631) and the grip's (rekta.css:616)
    readonly property real focusRingInsetInRow: 2
    // A tree branch closes in 0.7 of the time it opens in: `duration: d * 0.7` (rekta.js:3339)
    readonly property real branchCloseShare: 0.7
    // A long list's row: `padding: 0 var(--rk-space-s) 0 calc(14px + var(--rk-space-s))` (rekta.css:627); chosen, a
    // checkmark in that padding: `left: var(--rk-space-xs); top: 50%; width: 11px; height: 6px; margin-top: -5px;
    // border-left: 2px …; border-bottom: 2px …; transform: rotate(-45deg)` (rekta.css:632–634)
    readonly property real listRowLead: 14
    readonly property real listCheckWidth: 11
    readonly property real listCheckHeight: 6
    readonly property real listCheckRaise: 5
    readonly property real listCheckStroke: 2
    readonly property real listCheckAngle: -45
    // Beyond the rows in view, `over = 6` more either side exist (rekta.js:3591)
    readonly property int listRowsAround: 6
    // `.rk-ghost { width: 8em; height: 0.75em }` (rekta.css:888), in em of the text size
    readonly property real ghostWidth: 8
    readonly property real ghostHeight: 0.75
    // `.rk-menu-item[role='menuitemcheckbox']::before { width: 10px; height: 10px; border: 1px solid currentColor }`
    // (rekta.css:1019)
    readonly property real menuCheck: 10
    readonly property real menuCheckBorder: 1
    // `.rk-menu-item[aria-haspopup='menu']::after, .rk-menu-back::before { width: 6px; height: 6px; border-width: 1.6px 1.6px 0 0 }`
    // (rekta.css:1029–1030); the chevron back is turned -135° and set 2px to the trailing side: `.rk-menu-back::before
    // { transform: translateX(2px) rotate(-135deg) }` (rekta.css:1034); the chevron on, at the end of an item with a
    // level, is turned 45° and set 2px to the leading side: `.rk-menu-item[aria-haspopup='menu']::after
    // { transform: translateX(-2px) rotate(45deg) }` (rekta.css:1032)
    readonly property real chevronSize: 6
    readonly property real chevronStroke: 1.6
    readonly property real chevronBackTurn: -135
    readonly property real chevronBackNudge: 2
    readonly property real chevronOnTurn: 45
    readonly property real chevronOnNudge: 2
    // `.rk-tip { max-width: min(20rem, …); padding: 4px var(--rk-space-s) }` (rekta.css:572–573)
    readonly property real tipMaxWidth: 320
    readonly property real tipPaddingY: 4
    // `.rk-ab { gap: 6px; min-width: 48px; min-height: 48px; padding: 0 10px }`, `.rk-ab svg { width: 20px; height: 20px }`
    // (rekta.css:803, :813)
    readonly property real appBarControl: 48
    readonly property real appBarControlPadding: 10
    readonly property real appBarControlGap: 6
    readonly property real appBarGlyph: 20
    // `.rk-ab-mid[data-rk-priority='pinned'] { max-width: 50% }` of the bar (rekta.css:837)
    readonly property real appBarPinnedShare: 0.5

    // rekta-core's month: today 2px inside its day-cell, `in = { cell.x + 2, … }` (core/src/controls.c:928).
    // ponytail: a week column one cell wide and today filled within that inset are the shell's own from before Rekta had
    // a month to look at; 0.6.0 frames today with a 1px line and has no week column (core/src/controls.c:903–905;
    // rekta.css:995–999).
    readonly property real monthTodayInset: 2
    readonly property real monthWeekColumn: Tokens.dayCell

    // Parts of one heft, within 1/20, start in reading order half a duration-stagger apart, six steps at most:
    // `Math.round(h * 20)`, `Math.min(n, 6) * step / 2` (rekta.js:410–421)
    readonly property int sameHeftSteps: 6
    readonly property real sameHeftStagger: 0.5
    readonly property real sameHeftWithin: 0.05

    // ponytail: the build-in is Rekta 0.5.0's, a 6px rise delayed by `min(var(--rk-i, 0), 10) * duration-stagger`; 0.6.0
    // rises arrive-distance, duration-greet apart and four steps at most (rekta.css:97–104, :188).
    readonly property real buildInRise: 6
    readonly property int buildInStaggerCap: 10
    // Coming and going in a list or a grid (rekta.js:4085–4086, :4093, :4096–4097, :4117): a tile arrives from
    // `translateY(6px) scale(0.96)`, a row from `translateY(-6px)`; both leave over `duration-short * 0.6`, a tile to
    // `scale(0.9)`, a row to `translateX(12px)`; past `going.length + coming.length > 60` the change applies at once.
    readonly property real arriveShift: 6
    readonly property real arriveTileScale: 0.96
    readonly property real leaveShare: 0.6
    readonly property real leaveTileScale: 0.9
    readonly property real leaveRowDrift: 12
    readonly property int presenceAtOnceAbove: 60
    // A resized box's content stays hidden to `{ opacity: 0, offset: 0.55 }` of its glide, then fades in (rekta.js:4074)
    readonly property real resizeContentFrom: 0.55
    // A context menu opened by the keys stands at `r.left + Math.min(24, r.width / 2)`, `r.top + Math.min(r.height, 32)`
    // of its item; a long press gives up past `> 8`px; a scroll that moves the item `> 2`px closes the menu
    // (rekta.js:3151, :3175, :3193)
    readonly property real contextMenuAtX: 24
    readonly property real contextMenuAtY: 32
    readonly property real longPressSlop: 8
    readonly property real contextMenuScrollSlop: 2
    // A peek over d, duration-moderate: the old content leaves over `d * 0.6` (rekta.js:4211), the new one comes over
    // `d * 0.8` after `delay: d * 0.2` (rekta.js:4212)
    readonly property real peekOutShare: 0.6
    readonly property real peekInDelay: 0.2
    readonly property real peekInShare: 0.8
    // `.rk-spark polyline { stroke-width: 2; stroke-linejoin: round }` in the sparkline's 200 × 28 box (rekta.css:222,
    // :225); `[data-rk-live='stale'] .rk-spark { opacity: 0.35 }` (rekta.css:660)
    readonly property real sparkBoxWidth: 200
    readonly property real sparkBoxHeight: 28
    readonly property real sparkStroke: 2
    readonly property real sparkStaleOpacity: 0.35

    // `.rk-icon { width: 20px; height: 20px }` (rekta.css:580)
    readonly property real iconSize: 20
    // `.rk-toast { max-width: 32rem }` sideways (rekta.css:1418)
    readonly property real toastMaxWidth: 512
    // A toast rises 12px from the app bar, compact: `.rk-toasts { --_rk-from: 12px }` (rekta.css:1407) in `@keyframes
    // rk-toast-in { from { opacity: 0; transform: translateY(var(--_rk-from)) } }` (rekta.css:1235). A level display is a
    // toast (`.rk-toast--level`, rekta.css:1229) and arrives as one (motion.md:37), so a display alone rises the same.
    readonly property real toastRise: 12
    // A notification's toast leaves over `calc(0.6 * var(--rk-duration-short))` (rekta.css:1201)
    readonly property real toastEdgeOutShare: 0.6
    // The action's divider: `border-left: 1px solid color-mix(in srgb, currentColor 20%, transparent)` (rekta.css:1213)
    readonly property real toastDividerOpacity: 0.2
    // `.rk-toast-act:focus-visible { outline: 2px solid currentColor; outline-offset: -10px }` (rekta.css:1216)
    readonly property real toastFocusInset: 10
    // The undo window's line: `border-top: 2px solid` (rekta.css:1223)
    readonly property real toastLine: 2
    // `@keyframes rk-banner-in { from { opacity: 0; transform: translateY(-8px) } }` (rekta.css:1261)
    readonly property real bannerShift: 8
    // The button that says how many updates wait: `.rk-live-more { padding: 2px var(--rk-space-s) }` (rekta.css:662); it
    // arrives with `@keyframes rk-arrive { from { opacity: 0; transform: translateY(-8px) } }` (rekta.css:1119)
    readonly property real liveMorePadding: 2
    readonly property real arriveDrop: 8

    // The Start is a place called up many times an hour, so it turns at half the pace of a place change, `called ? 0.5
    // : 1` (motion.md:15; rekta.js:571), and the windows step back and forward with it. Every time and stagger of these
    // turns is its token's times this.
    readonly property real startTempo: 0.5

    // enter(): a row arrives from `translateY(-6px)` (rekta.js:4086); leave(): a row drifts to `translateX(12px)` over
    // `duration-short × 0.6` (rekta.js:4093, :4097)
    readonly property real rowEnterShift: 6
    readonly property real rowLeaveDrift: 12
    readonly property real rowLeaveShare: 0.6
    // A row dragged towards its trailing edge past half its width goes when let go (motion.md:25).
    readonly property real rowPullAway: 0.5

    // `.rk-sheet { width: min(32rem, 100%) }` (rekta.css:1066), a rem being 16 logical px
    readonly property real sheetMaxWidth: 512
    // `@keyframes rk-from-top { from { opacity: 0; transform: translateY(-16px) } }` (rekta.css:1117); a sheet leaves
    // back up the same way (rekta.js:1826)
    readonly property real sheetShift: 16

    // `.rk-grip { width: 24px }`, its six squares `center / 20px` (rekta.css:614–615)
    readonly property real gripWidth: 24
    readonly property real gripGlyph: 20
    // A grip's drag starts once the pointer has moved 4px up or down: `if (Math.abs(dy) < 4) return` (rekta.js:3426)
    readonly property real gripDragStart: 4
    // The lifted item: `outline: 1px solid var(--rk-text-contrast-medium); outline-offset: -1px` (rekta.css:618)
    readonly property real liftedEdge: 1

    // A wheel line counts 16 px (`deltaMode === 1 ? 16`, rekta.js:1025, :1127)
    readonly property real wheelLinePixels: 16

    // A panorama fits with 1px to spare, `before(n) + (n - 1) * g <= edge + 1`; the window's edge is inside a section
    // within half a pixel, `… + xl <= edge + 0.5 && edge - 0.5 <= … - xl` (rekta.js spread(), :1053–1054)
    readonly property real panoramaFitSlack: 1
    readonly property real panoramaEdgeSlack: 0.5
}
