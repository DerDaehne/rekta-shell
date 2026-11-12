.pragma library

// The scroller an item stands in, or null.
function scrollerOf(item) {
    let view = item.parent;
    while (view && !(view.contentItem && view.contentY !== undefined))
        view = view.parent;
    return view;
}

// Brings an item of the given height whole into the scroller it stands in, its top first, as focus does on the web,
// with `padding` clear of the view's edges.
function intoView(item, height, padding = 0) {
    const view = scrollerOf(item);
    if (!view)
        return;
    const top = item.mapToItem(view.contentItem, 0, 0).y - padding;
    view.contentY = Math.max(0, Math.min(top, Math.max(view.contentY, top + height + 2 * padding - view.height)));
}

// The same sideways: brings an item whole into the flickable, its left edge first, with `padding` clear of the edge
// it comes from (a browser's `scroll-padding-inline`, rekta.css:1488), the position held within 0 to `most`.
function alongInto(view, item, padding, most) {
    const left = item.mapToItem(view.contentItem, 0, 0).x;
    const to = Math.min(left - padding, Math.max(view.contentX, left + item.width + padding - view.width));
    view.contentX = Math.max(0, Math.min(most, to));
}
