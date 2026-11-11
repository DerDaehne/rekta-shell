pragma Singleton
import QtQuick

// The timing of a place change (motion.md:14): when each part of a place starts to turn, how long it takes, the point
// it turns about and the perspective it turns in. A part is a rectangle {x, y, width, height} on the screen; `clip`,
// when given, is the box {x, y, width, height} that clips it, otherwise the screen's top left. It turns around the
// leading edge of that box as Rekta's parts do, or with the edge "bottom" around its bottom edge, which Rekta does not
// know: the Start comes up from the edge a swipe starts at.
QtObject {
    // How heavy a part is against Rekta's reference tile, heft-reference square (motion.md:51–52), whatever size the
    // product's tiles are: light parts turn first and quickest, heavy ones later and slower.
    function heft(width: real, height: real): real {
        const tiles = Math.max(1, width * height) / (Tokens.heftReference * Tokens.heftReference);
        const weight = Tokens.heftTile * Math.pow(tiles, Tokens.heftExponent);
        return Math.min(Tokens.heftMax, Math.max(Tokens.heftMin, weight));
    }

    function fromBottom(edge: var): bool {
        return edge === "bottom";
    }

    // Parts share a row by their top, or by their bottom when they turn about the bottom edge.
    function rowOf(part: var, edge: var): int {
        return Math.round((fromBottom(edge) ? part.y + part.height : part.y) / Tokens.turnstileRow);
    }

    function clipOf(part: var): var {
        return part.clip ?? {
            x: 0,
            y: 0
        };
    }

    // How far a part reaches from the edge it turns around: sideways from the leading edge, upwards from the bottom.
    function reach(part: var, edge: var): real {
        const clip = clipOf(part);
        return fromBottom(edge) ? clip.y + clip.height - part.y : part.x + part.width - clip.x;
    }

    // The point a part turns about, in its own coordinates: on the edge's line, and across it at the part's own end
    // when it is flush with the box's end there (its top, or for the bottom edge its leading side), else at its middle.
    function originOf(part: var, edge: var): var {
        const clip = clipOf(part);
        if (fromBottom(edge))
            return {
                x: Math.abs(part.x - clip.x) < Tokens.turnstileFlush ? 0 : part.width / 2,
                y: clip.y + clip.height - part.y
            };
        return {
            x: clip.x - part.x,
            y: Math.abs(part.y - clip.y) < Tokens.turnstileFlush ? 0 : part.height / 2
        };
    }

    // A row turns in one perspective, which grows with how far its parts reach from the edge they turn around.
    function rowPerspectives(parts: var, edge: var): var {
        const far = new Map();
        for (const part of parts)
            far.set(rowOf(part, edge), Math.max(far.get(rowOf(part, edge)) || 0, reach(part, edge)));
        return parts.map(part => Tokens.turnstilePerspective + Tokens.turnstileReach * far.get(rowOf(part, edge)));
    }

    // Every part in its order with its start (ms after `from`) and its time, `duration` being the token's time for a
    // part of heft 1. Parts of one heft follow one another, half a stagger apart, a few steps at most: in reading order,
    // or from the bottom row up when they turn about the bottom edge (`edge` "bottom"; Rekta's leading edge otherwise),
    // front to back within a row. Each turn names its axis and its origin and perspective (originOf, rowPerspectives).
    function plan(parts: var, duration: real, from: real, edge: var): var {
        // Parts at one place keep the order they come in, as the web's stable sort keeps the page's; V4's sort may not.
        const indexOf = new Map(parts.map((part, index) => [part, index]));
        const upwards = fromBottom(edge) ? -1 : 1;
        const ordered = parts.slice().sort((a, b) => upwards * (rowOf(a, edge) - rowOf(b, edge)) || (a.x - b.x) || (indexOf.get(a) - indexOf.get(b)));
        const perspectives = rowPerspectives(ordered, edge);
        const seen = new Map();
        return ordered.map((part, index) => {
            const weight = heft(part.width, part.height);
            const key = Math.round(weight / Geometry.sameHeftWithin);
            const before = seen.get(key) || 0;
            seen.set(key, before + 1);
            const byHeft = (weight - Tokens.heftMin) * Tokens.heftSpread * Tokens.durationStagger;
            const byOrder = Math.min(before, Geometry.sameHeftSteps) * Geometry.sameHeftStagger * Tokens.durationStagger;
            const origin = originOf(part, edge);
            return {
                part: part,
                at: from + byHeft + byOrder,
                duration: duration * weight,
                axis: fromBottom(edge) ? Qt.vector3d(1, 0, 0) : Qt.vector3d(0, 1, 0),
                originX: origin.x,
                originY: origin.y,
                perspective: perspectives[index]
            };
        });
    }

    // The pressed tile goes last, in a row of its own: when the last of the others starts, and not before `notBefore`
    // (the time it still needs to sink).
    function pressedTurn(part: var, duration: real, others: var, notBefore: real, edge: var): var {
        const turn = plan([part], duration, 0, edge)[0];
        turn.at = Math.max(notBefore, ...others.map(other => other.at));
        return turn;
    }

    // The next place starts when the last part of the one leaving is three quarters through.
    function nextPlaceAt(turns: var): real {
        return Math.max(0, ...turns.map(turn => turn.at + Tokens.turnOverlap * turn.duration));
    }

    // The latest a part can start after its turn begins: as heavy as a part gets, behind the most parts of its heft.
    function latestStart(): real {
        const byHeft = (Tokens.heftMax - Tokens.heftMin) * Tokens.heftSpread * Tokens.durationStagger;
        return byHeft + Geometry.sameHeftSteps * Geometry.sameHeftStagger * Tokens.durationStagger;
    }

    // The longest a whole place change can take, whatever its parts: one place leaving in `leaving`, the next one
    // arriving in `arriving` (the tokens' times for a part of heft 1).
    function longestPlaceChange(leaving: real, arriving: real): real {
        const nextPlace = latestStart() + Tokens.turnOverlap * Tokens.heftMax * leaving;
        return nextPlace + latestStart() + Tokens.heftMax * arriving;
    }
}
