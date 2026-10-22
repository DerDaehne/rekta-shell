.pragma library

// The status vocabulary (colour.md, "Status vocabulary"): one fixed word per status; without a status, idle.
const words = { "": "idle", info: "active", success: "done", warning: "waiting", error: "failed" };

function word(status) {
    return words[status] ?? "";
}

// The fill a toast or banner takes for its status (`[data-status] { --_rk-fill: var(--rk-status-*-tile) }`,
// rekta.css:58–61); `otherwise` without one.
function tileFill(status, colors, otherwise) {
    const fills = { info: colors.statusInfoTile, success: colors.statusSuccessTile, warning: colors.statusWarningTile, error: colors.statusErrorTile };
    return fills[status] ?? otherwise;
}

// Whether the item stands on a status fill: an ancestor says so with `statusFill: true`. The walk reads every parent,
// so it runs again when the item moves or the fill changes.
function onStatusFill(item) {
    for (let p = item.parent; p; p = p.parent) {
        if (p.statusFill === true)
            return true;
    }
    return false;
}

// The secondary text colour where an item stands. On a status fill only the primary text colour clears AA, so text
// that is text-contrast-high on the ground takes text-primary there (rekta.css:63–65).
function secondaryInk(item, colors) {
    return onStatusFill(item) ? colors.textPrimary : colors.textContrastHigh;
}
