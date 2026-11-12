.pragma library

// Where a grabbed picture shows ink of one colour on a ground: antialiased thin strokes cover few pixels completely, so a
// pixel counts once it is closer to the ink than to the ground. Returns the bounds { left, right, top, bottom } of those
// pixels inside `area` ({ x, y, width, height } in whole pixels of the picture), or null when there are none.
function bounds(image, area, ink, ground) {
    const distance = (a, b) => Math.abs(a.r - b.r) + Math.abs(a.g - b.g) + Math.abs(a.b - b.b);
    const full = distance(ink, ground);
    const inked = [];
    for (let at = 0; at < area.width * area.height; at++) {
        const x = area.x + at % area.width;
        const y = area.y + Math.floor(at / area.width);
        if (distance(image.pixel(x, y), ink) < full / 2)
            inked.push({ x, y });
    }
    if (inked.length === 0)
        return null;
    const xs = inked.map(pixel => pixel.x);
    const ys = inked.map(pixel => pixel.y);
    return { left: Math.min(...xs), right: Math.max(...xs), top: Math.min(...ys), bottom: Math.max(...ys) };
}
