.pragma library
.import Rekta as Rekta

// Where floating things go, as pure functions of rectangles in window coordinates. Each returns { x, y, side }; the
// side ("below" or "above") tells the motion which way to come in.

// A floating surface (states.md, "Floating surfaces"; rekta.js place(), :1652–1665): below its control, aligned to its
// leading edge; above it when there is no room below; never outside the window.
function float(control, size, window) {
    const gap = Rekta.Geometry.floatGap;
    const edge = Rekta.Tokens.spaceS;
    const roomBelow = window.height - control.bottom - gap - edge;
    const roomAbove = control.top - gap - edge;
    const side = size.height <= roomBelow || roomBelow >= roomAbove ? "below" : "above";
    const wanted = side === "below" ? control.bottom + gap : control.top - gap - size.height;
    // rekta.js lets one too tall for either side run off the bottom; like rekta-core it stays in, over its control.
    const y = Math.max(edge, Math.min(wanted, window.height - edge - size.height));
    // One too near the trailing edge opens from the control's trailing edge instead.
    const fits = control.left + size.width <= window.width - edge;
    const x = fits ? Math.max(edge, control.left) : Math.max(edge, Math.min(control.right, window.width - edge) - size.width);
    return { x: Math.round(x), y: Math.round(y), side: side };
}

// A tooltip (navigation.md, "Tooltips"; rekta.js placeTip(), :2548–2556): centred above its control, below it when
// there is no room above, kept from the window's sides.
function tip(control, size, window) {
    const gap = Rekta.Geometry.tipGap;
    const edge = Rekta.Tokens.spaceS;
    const above = control.top - gap - size.height >= edge;
    const centred = control.left + control.width / 2 - size.width / 2;
    const x = Math.min(Math.max(edge, centred), window.width - size.width - edge);
    const y = above ? control.top - gap - size.height : control.bottom + gap;
    return { x: Math.round(x), y: Math.round(y), side: above ? "above" : "below" };
}
