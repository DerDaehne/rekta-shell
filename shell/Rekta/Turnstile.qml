pragma Singleton
import QtQuick

// The timing of a place change (motion.md:11): when each part of a place starts to turn, how long it takes, the height
// it turns about and the perspective it turns in. A part is a rectangle {x, y, width, height} within the box that clips
// it, which it turns around the leading edge of.
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

    // A row turns in one perspective, which grows with how far its parts reach from the edge they turn around.
    function rowPerspectives(parts: var): var {
        const reach = new Map();
        for (const part of parts)
            reach.set(readingRow(part), Math.max(reach.get(readingRow(part)) || 0, part.x + part.width));
        return parts.map(part => Tokens.turnstilePerspective + Geometry.turnPerspectivePerReach * reach.get(readingRow(part)));
    }

    // Every part in reading order with its start (ms after `from`) and its time, `duration` being the token's time
    // for a part of heft 1. Parts of one heft follow one another, half a stagger apart, a few steps at most.
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
                originY: Math.abs(part.y) < Geometry.turnFlushTop ? 0 : part.height / 2,
                perspective: perspectives[index]
            };
        });
    }

    // The next place starts when the last part of the one leaving is three quarters through.
    function nextPlaceAt(turns: var): real {
        return Math.max(0, ...turns.map(turn => turn.at + Geometry.turnOverlap * turn.duration));
    }
}
