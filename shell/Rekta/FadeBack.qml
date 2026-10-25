pragma Singleton
import QtQuick

// How far the windows have stepped back behind the Start, 0 in front and 1 all the way back, and how a window looks
// that far back. They step back in duration-moderate with ease-out as the Start opens and come forward with ease-in
// from its hand-over; a change on the way turns them round from where they are.
QtObject {
    readonly property easingCurve stepBack: ({ type: Easing.Bezier, bezierCurve: Tokens.easeOut })
    readonly property easingCurve comeForward: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })

    // Where the windows are `elapsed` ms after they set off from `from` towards `to`; exactly `to` once there.
    function progress(from: real, to: real, elapsed: real): real {
        const curve = to > from ? stepBack : comeForward;
        const share = Tokens.durationModerate > 0 ? Math.min(1, elapsed / Tokens.durationModerate) : 1;
        return to - (to - from) * (1 - curve.valueForProgress(share));
    }

    function scale(progress: real): real {
        return 1 - (1 - Geometry.fadeBackScale) * progress;
    }

    function brightness(progress: real): real {
        return 1 - (1 - Geometry.fadeBackBrightness) * progress;
    }
}
