pragma Singleton
import QtQuick

// The timing of a place change (motion.md:11): when each part of a place starts to turn, how long it takes, the point
// it turns about and the perspective it turns in. A part is a rectangle {x, y, width, height} on the screen; `clip`,
// when given, is the top left {x, y} of the box that clips it, otherwise the screen's. It turns around the leading
// edge of that box.
QtObject {
    // How heavy a part is against a tile: light parts turn first and quickest, heavy ones later and slower.
    function heft(width: real, height: real): real {
        const tiles = Math.max(1, width * height) / (Tokens.tileUnit * Tokens.tileUnit);
        const weight = Geometry.heftAtTile * Math.pow(tiles, Geometry.heftExponent);
        return Math.min(Geometry.heftMax, Math.max(Geometry.heftMin, weight));
    }

    function readingRow(part: var): int {
        return Math.round(part.y / Geometry.turnRowStep);
    }

    function clipOf(part: var): var {
        return part.clip ?? {
            x: 0,
            y: 0
        };
    }

    // How far a part reaches from the edge it turns around.
    function reach(part: var): real {
        return part.x + part.width - clipOf(part).x;
    }

    // A row turns in one perspective, which grows with how far its parts reach from the edge they turn around.
    function rowPerspectives(parts: var): var {
        const far = new Map();
        for (const part of parts)
            far.set(readingRow(part), Math.max(far.get(readingRow(part)) || 0, reach(part)));
        return parts.map(part => Tokens.turnstilePerspective + Geometry.turnPerspectivePerReach * far.get(readingRow(part)));
    }

    // Every part in reading order with its start (ms after `from`) and its time, `duration` being the token's time
    // for a part of heft 1. Parts of one heft follow one another, half a stagger apart, a few steps at most. A part
    // turns about its clipping box's leading edge (originX, in the part's own coordinates), from its top when it is
    // flush with that box's top, otherwise from its middle (originY).
    function plan(parts: var, duration: real, from: real): var {
        const ordered = parts.slice().sort((a, b) => (readingRow(a) - readingRow(b)) || (a.x - b.x));
        const perspectives = rowPerspectives(ordered);
        const seen = new Map();
        return ordered.map((part, index) => {
            const weight = heft(part.width, part.height);
            const key = Math.round(weight / Geometry.sameHeftWithin);
            const before = seen.get(key) || 0;
            seen.set(key, before + 1);
            const byHeft = (weight - Geometry.heftMin) * Geometry.heftStaggerSteps * Tokens.durationStagger;
            const byOrder = Math.min(before, Geometry.sameHeftSteps) * Geometry.sameHeftStagger * Tokens.durationStagger;
            return {
                part: part,
                at: from + byHeft + byOrder,
                duration: duration * weight,
                originX: clipOf(part).x - part.x,
                originY: Math.abs(part.y - clipOf(part).y) < Geometry.turnFlushTop ? 0 : part.height / 2,
                perspective: perspectives[index]
            };
        });
    }

    // The pressed tile goes last, in a row of its own: when the last of the others starts, and not before `notBefore`
    // (the time it still needs to sink).
    function pressedTurn(part: var, duration: real, others: var, notBefore: real): var {
        const turn = plan([part], duration, 0)[0];
        turn.at = Math.max(notBefore, ...others.map(other => other.at));
        return turn;
    }

    // The next place starts when the last part of the one leaving is three quarters through.
    function nextPlaceAt(turns: var): real {
        return Math.max(0, ...turns.map(turn => turn.at + Geometry.turnOverlap * turn.duration));
    }

    // The latest a part can start after its turn begins: as heavy as a part gets, behind the most parts of its heft.
    function latestStart(): real {
        const byHeft = (Geometry.heftMax - Geometry.heftMin) * Geometry.heftStaggerSteps * Tokens.durationStagger;
        return byHeft + Geometry.sameHeftSteps * Geometry.sameHeftStagger * Tokens.durationStagger;
    }

    // The longest a whole place change can take, whatever its parts: one place leaving in `leaving`, the next one
    // arriving in `arriving` (the tokens' times for a part of heft 1).
    function longestPlaceChange(leaving: real, arriving: real): real {
        const nextPlace = latestStart() + Geometry.turnOverlap * Geometry.heftMax * leaving;
        return nextPlace + latestStart() + Geometry.heftMax * arriving;
    }
}
