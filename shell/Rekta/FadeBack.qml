pragma Singleton
import QtQuick

// How far the windows have stepped back, 0 in front and 1 all the way back, and how a window looks that far back. They
// step back with ease-out and come forward with ease-in, each way in duration-moderate: behind the Start at the Start's
// tempo, as the session is left at Rekta's own. A change on the way turns them round from where they are.
QtObject {
    readonly property easingCurve stepBack: ({ type: Easing.Bezier, bezierCurve: Tokens.easeOut })
    readonly property easingCurve comeForward: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })
    // The Start's tempo, Prefs.startTempo: the shell binds it, KWin's fade-back sets it from what the shell tells it.
    // Never Prefs itself: KWin loads this singleton into the engine its other effects share, and Prefs there would
    // override their Tokens.
    property real startTempo: Geometry.startTempo
    readonly property real duration: startTempo * Tokens.durationModerate
    readonly property real leaveDuration: Tokens.durationModerate

    // Where the windows behind the Start are `elapsed` ms after they set off from `from` towards `to`; exactly `to` once
    // there.
    function progress(from: real, to: real, elapsed: real): real {
        return along(from, to, elapsed, duration);
    }

    // The same for the windows of every screen as the session is left.
    function leaveProgress(from: real, to: real, elapsed: real): real {
        return along(from, to, elapsed, leaveDuration);
    }

    function along(from: real, to: real, elapsed: real, span: real): real {
        const curve = to > from ? stepBack : comeForward;
        const share = span > 0 ? Math.min(1, elapsed / span) : 1;
        return to - (to - from) * (1 - curve.valueForProgress(share));
    }

    function scale(progress: real): real {
        return 1 - (1 - Geometry.fadeBackScale) * progress;
    }

    function brightness(progress: real): real {
        return 1 - (1 - Geometry.fadeBackBrightness) * progress;
    }
}
