.pragma library

// Brings an item of the given height whole into the scroller it stands in, its top first, as focus does on the web.
function intoView(item, height) {
    let view = item.parent;
    while (view && !(view.contentItem && view.contentY !== undefined))
        view = view.parent;
    if (!view)
        return;
    const top = item.mapToItem(view.contentItem, 0, 0).y;
    view.contentY = Math.min(top, Math.max(view.contentY, top + height - view.height));
}

// The same sideways: brings an item whole into the flickable, its left edge first, with `padding` clear of the edge
// it comes from (a browser's `scroll-padding-inline`, rekta.css:1169), the position held within 0 to `most`.
function alongInto(view, item, padding, most) {
    const left = item.mapToItem(view.contentItem, 0, 0).x;
    const to = Math.min(left - padding, Math.max(view.contentX, left + item.width + padding - view.width));
    view.contentX = Math.max(0, Math.min(most, to));
}
