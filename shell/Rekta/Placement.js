.pragma library
.import Rekta as Rekta

// Where floating things go, as pure functions of rectangles in window coordinates. Each returns { x, y, side }; the
// side ("below" or "above") tells the motion which way to come in.

// A floating surface (states.md, "Floating surfaces"; rekta.js place(), :2012–2034): space-xs from its control and
// space-m from the window's edges; below it when it fits there, else above when it fits there, else on the side with
// more room, kept inside the window where it may cover its control. Aligned to the control's leading edge, or centred
// on it with align "centre".
function float(control, size, window, align = "start") {
    const gap = Rekta.Tokens.spaceXs;
    const edge = Rekta.Tokens.spaceM;
    const roomBelow = window.height - control.bottom - gap - edge;
    const roomAbove = control.top - gap - edge;
    const side = size.height <= roomBelow ? "below" : size.height <= roomAbove ? "above" : roomBelow >= roomAbove ? "below" : "above";
    const wanted = side === "below" ? control.bottom + gap : control.top - gap - size.height;
    const y = Math.max(edge, Math.min(wanted, window.height - edge - size.height));
    const x = align === "centre" ? centredX(control, size, window) : leadingX(control, size, window);
    return { x: Math.round(x), y: Math.round(y), side: side };
}

// A tooltip (navigation.md, "Tooltips"; rekta.js placeTip(), :3025–3033): centred above its control, below it when
// there is no room above, kept from the window's sides.
function tip(control, size, window) {
    const gap = Rekta.Tokens.tipGap;
    const edge = Rekta.Tokens.spaceM;
    const above = control.top - gap - size.height >= edge;
    const centred = control.left + control.width / 2 - size.width / 2;
    const x = Math.min(Math.max(edge, centred), window.width - size.width - edge);
    const y = above ? control.top - gap - size.height : control.bottom + gap;
    return { x: Math.round(x), y: Math.round(y), side: above ? "above" : "below" };
}

function centredX(control, size, window) {
    const edge = Rekta.Tokens.spaceM;
    return Math.max(edge, Math.min(control.left + (control.width - size.width) / 2, window.width - edge - size.width));
}

// One too near the trailing edge opens from the control's trailing edge instead.
function leadingX(control, size, window) {
    const edge = Rekta.Tokens.spaceM;
    const fits = control.left + size.width <= window.width - edge;
    return fits ? Math.max(edge, control.left) : Math.max(edge, Math.min(control.right, window.width - edge) - size.width);
}

// A context menu at a point (rekta.js placeAt(), :3107–3114): its top leading corner there, turned to the other side
// of the point on each axis where it would come within space-m of the window's edge.
function at(point, size, window) {
    const edge = Rekta.Tokens.spaceM;
    const left = point.x + size.width > window.width - edge ? Math.max(edge, point.x - size.width) : point.x;
    const top = point.y + size.height > window.height - edge ? Math.max(edge, point.y - size.height) : point.y;
    return { x: Math.round(left), y: Math.round(top), side: top < point.y ? "above" : "below" };
}
