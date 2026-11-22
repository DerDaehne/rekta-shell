.pragma library

// Where a key moves the focus among tiles (navigation.md, "A grid of tiles"), as pure functions of their rectangles or
// names.

// Where a typed key jumps among `names`: the next after `from` that starts with it, whatever the case, round past the
// end; -1 when none does (navigation.md:534–541).
// ponytail: one key at a time; Rekta joins letters typed within duration-type-ahead into a prefix
// (rekta.js:173–190).
function jumpTarget(names, from, key) {
    const typed = key.toLowerCase();
    for (let step = 1; step <= names.length; step++) {
        const at = (from + step) % names.length;
        if (names[at].trim().toLowerCase().startsWith(typed))
            return at;
    }
    return -1;
}

// Whether `other` shares a row (left, right) or a column (up, down) with `from`.
function overlaps(from, other, direction) {
    if (direction === "left" || direction === "right")
        return other.y < from.y + from.height && other.y + other.height > from.y;
    return other.x < from.x + from.width && other.x + other.width > from.x;
}

// How far `other` lies beyond `from` in a direction, and how far it is off to the side; negative `ahead` is behind.
function offset(from, other, direction) {
    switch (direction) {
    case "right":
        return { ahead: other.x - from.x, aside: Math.abs(other.y - from.y) };
    case "left":
        return { ahead: from.x - other.x, aside: Math.abs(other.y - from.y) };
    case "down":
        return { ahead: other.y - from.y, aside: Math.abs(other.x - from.x) };
    default:
        return { ahead: from.y - other.y, aside: Math.abs(other.x - from.x) };
    }
}

// Where an arrow key moves the focus among tiles ({x, y, width, height}): the nearest one ahead in that row or column,
// and of those the one most in line. -1 when there is none.
function neighbour(from, rects, direction) {
    let best = -1;
    let bestOffset = null;
    rects.forEach((rect, index) => {
        const off = offset(from, rect, direction);
        if (off.ahead <= 0 || !overlaps(from, rect, direction))
            return;
        if (bestOffset === null || off.ahead < bestOffset.ahead || (off.ahead === bestOffset.ahead && off.aside < bestOffset.aside)) {
            best = index;
            bestOffset = off;
        }
    });
    return best;
}
