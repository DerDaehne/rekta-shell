pragma Singleton
import QtQuick

// The timing of a place change (motion.md:14): when each part of a place starts to turn, how long it takes, the point
// it turns about and the perspective it turns in. A part is a rectangle {x, y, width, height} on the screen; `clip`,
// when given, is the box {x, y, width, height} that clips it, otherwise the screen's top left. It turns around the
// leading edge of that box as Rekta's parts do, or with the edge "bottom" about its own bottom edge in reading order,
// which Rekta does not know: the Start comes up from the edge a swipe starts at, each part folding up as Metro's did.
QtObject {
    // How heavy a part is against Rekta's reference tile, heft-reference square (motion.md:51–52), whatever size the
    // product's tiles are: light parts turn first and quickest, heavy ones later and slower.
    function heft(width: real, height: real): real {
        const tiles = Math.max(1, width * height) / (Tokens.heftReference * Tokens.heftReference);
        const weight = Tokens.heftTile * Math.pow(tiles, Tokens.heftExponent);
        return Math.min(Tokens.heftMax, Math.max(Tokens.heftMin, weight));
    }

    // Parts share a row by their top.
    function rowOf(part: var): int {
        return Math.round(part.y / Tokens.turnstileRow);
    }

    function clipOf(part: var): var {
        return part.clip ?? {
            x: 0,
            y: 0
        };
    }

    // How far a part reaches sideways from the leading edge it turns around.
    function reach(part: var): real {
        return part.x + part.width - clipOf(part).x;
    }

    // The point a part turns about, in its own coordinates: on the edge's line, and across it at the part's own top when
    // it is flush with the box's top, else at its middle.
    function originOf(part: var): var {
        const clip = clipOf(part);
        return {
            x: clip.x - part.x,
            y: Math.abs(part.y - clip.y) < Tokens.turnstileFlush ? 0 : part.height / 2
        };
    }

    // A row turns in one perspective, which grows with how far its parts reach from the edge they turn around.
    function rowPerspectives(parts: var): var {
        const far = new Map();
        for (const part of parts)
            far.set(rowOf(part), Math.max(far.get(rowOf(part)) || 0, reach(part)));
        return parts.map(part => Tokens.turnstilePerspective + Tokens.turnstileReach * far.get(rowOf(part)));
    }

    // Parts at one place keep the order they come in, as the web's stable sort keeps the page's; V4's sort may not.
    function inReadingOrder(parts: var): var {
        const indexOf = new Map(parts.map((part, index) => [part, index]));
        return parts.slice().sort((a, b) => (rowOf(a) - rowOf(b)) || (a.x - b.x) || (indexOf.get(a) - indexOf.get(b)));
    }

    // Every part in its order with its start (ms after `from`) and its time, `duration` being the token's time for a
    // part of heft 1. About Rekta's leading edge the heft leads: parts of one heft follow one another in reading order,
    // half a stagger apart, a few steps at most. With `edge` "bottom" the parts fold up instead (foldPlan), from the
    // last to the first when `backwards`. Each turn names its axis and its origin and perspective.
    function plan(parts: var, duration: real, from: real, edge: var, backwards: var): var {
        if (edge === "bottom")
            return foldPlan(parts, duration, from, backwards === true);
        const ordered = inReadingOrder(parts);
        const perspectives = rowPerspectives(ordered);
        const seen = new Map();
        return ordered.map((part, index) => {
            const weight = heft(part.width, part.height);
            const key = Math.round(weight / Geometry.sameHeftWithin);
            const before = seen.get(key) || 0;
            seen.set(key, before + 1);
            const byHeft = (weight - Tokens.heftMin) * Tokens.heftSpread * Tokens.durationStagger;
            const byOrder = Math.min(before, Geometry.sameHeftSteps) * Geometry.sameHeftStagger * Tokens.durationStagger;
            const origin = originOf(part);
            return {
                part: part,
                at: from + byHeft + byOrder,
                duration: duration * weight,
                axis: Qt.vector3d(0, 1, 0),
                originX: origin.x,
                originY: origin.y,
                perspective: perspectives[index]
            };
        });
    }

    // How many staggers after the first part each part starts, in reading order: a row one after the row above, its
    // parts spread front to back over that one stagger, so none starts before a part in a row above it.
    function readingSteps(ordered: var): var {
        const rows = [...new Set(ordered.map(rowOf))];
        const sizes = new Map();
        for (const part of ordered)
            sizes.set(rowOf(part), (sizes.get(rowOf(part)) || 0) + 1);
        const seen = new Map();
        return ordered.map(part => {
            const row = rowOf(part);
            const inRow = seen.get(row) || 0;
            seen.set(row, inRow + 1);
            return rows.indexOf(row) + inRow / sizes.get(row);
        });
    }

    // Each part turns about its own bottom edge, from its middle across, in a perspective after its own height: it
    // stays within its own box as it comes and goes, so none crosses another. The place reads in as a page does, its
    // heft setting only how long a part takes; backwards the last part in goes first.
    function foldPlan(parts: var, duration: real, from: real, backwards: bool): var {
        const ordered = inReadingOrder(parts);
        const steps = readingSteps(ordered);
        const last = Math.max(0, ...steps);
        return ordered.map((part, index) => ({
                    part: part,
                    at: from + (backwards ? last - steps[index] : steps[index]) * Tokens.durationStagger,
                    duration: duration * heft(part.width, part.height),
                    axis: Qt.vector3d(1, 0, 0),
                    originX: part.width / 2,
                    originY: part.height,
                    perspective: Tokens.turnstilePerspective + Tokens.turnstileReach * part.height
                }));
    }

    // The pressed tile goes last, in a row of its own: when the last of the others starts, and not before `notBefore`
    // (the time it still needs to sink).
    function pressedTurn(part: var, duration: real, others: var, notBefore: real, edge: var): var {
        const turn = plan([part], duration, 0, edge, false)[0];
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
