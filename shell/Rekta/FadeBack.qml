pragma Singleton
import QtQuick

// How far the windows have stepped back, 0 in front and 1 all the way back, and how a window looks that far back.
// Behind the Start they step back with ease-in and come forward with ease-out (motion.md:125–135), at the Start's tempo;
// as the session is left they step back with ease-out at Rekta's own (shell.md:172) and come forward with ease-in. A
// change on the way turns them round from where they are, with the curve of the new way. After login the splash fades
// onto the ground as they step back, at Rekta's tempo.
QtObject {
    readonly property easingCurve easeIn: ({ type: Easing.Bezier, bezierCurve: Tokens.easeIn })
    readonly property easingCurve easeOut: ({ type: Easing.Bezier, bezierCurve: Tokens.easeOut })
    readonly property real duration: Geometry.startTempo * Tokens.durationModerate
    readonly property real leaveDuration: Tokens.durationModerate

    // Where the windows behind the Start are `elapsed` ms after they set off from `from` towards `to`; exactly `to` once
    // there.
    function progress(from: real, to: real, elapsed: real): real {
        return along(from, to, elapsed, duration, to > from ? easeIn : easeOut);
    }

    // How long the windows behind the Start take to step `share` of their way back, found on their curve by halving.
    function stepBackTime(share: real): real {
        let low = 0;
        let high = 1;
        for (let step = 0; step < 30; step++) {
            const middle = (low + high) / 2;
            if (easeIn.valueForProgress(middle) < share)
                low = middle;
            else
                high = middle;
        }
        return high * duration;
    }

    // The same for the windows of every screen as the session is left.
    function leaveProgress(from: real, to: real, elapsed: real): real {
        return along(from, to, elapsed, leaveDuration, to > from ? easeOut : easeIn);
    }

    // How much of the splash still shows `elapsed` ms after it closed: all of it as it closes, nothing once gone.
    // ponytail: ease-out, as the windows once stepped back, is the shell's from before Rekta had this transition; 0.6.0
    // fades the loading screen to the ground with ease-in (motion.md:118).
    function splashOpacity(elapsed: real): real {
        return 1 - along(0, 1, elapsed, Tokens.durationModerate, easeOut);
    }

    function along(from: real, to: real, elapsed: real, span: real, curve: easingCurve): real {
        const share = span > 0 ? Math.min(1, elapsed / span) : 1;
        return to - (to - from) * (1 - curve.valueForProgress(share));
    }

    function scale(progress: real): real {
        return 1 - (1 - Tokens.stepBackScale) * progress;
    }

    function brightness(progress: real): real {
        return 1 - (1 - Tokens.stepBackBrightness) * progress;
    }
}
