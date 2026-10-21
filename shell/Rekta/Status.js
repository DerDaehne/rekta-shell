.pragma library

// The status vocabulary (colour.md, "Status vocabulary"): one fixed word per status; without a status, idle.
const words = { "": "idle", info: "active", success: "done", warning: "waiting", error: "failed" };

function word(status) {
    return words[status] ?? "";
}

// The secondary text colour where an item stands. On a status fill only the primary text colour clears AA, so text
// that is text-contrast-high on the ground takes text-primary there (rekta.css:64–66). A status fill says so with
// `statusFill: true`; the walk reads every parent, so it runs again when the item moves or the fill changes.
function secondaryInk(item, colors) {
    for (let p = item.parent; p; p = p.parent) {
        if (p.statusFill === true)
            return colors.textPrimary;
    }
    return colors.textContrastHigh;
}
