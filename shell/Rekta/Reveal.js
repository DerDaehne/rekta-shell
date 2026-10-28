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
