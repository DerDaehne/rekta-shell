.pragma library

// What the background apps' list says about a StatusNotifierItem, from its plain properties.

// StatusNotifierItem's status, as Quickshell's Status enum numbers it.
const passive = 0;
const needsAttention = 2;
// Characters of the app's own words that the state keeps.
const stateLength = 24;

// A passive item conveys nothing and the specification lets the host hide it.
function listed(status) {
    return status !== passive;
}

function word(title, id) {
    return title !== "" ? title : id;
}

// The tooltip's title, else its description, cut short; an app that wants attention says "wartet" first.
function state(status, tooltipTitle, tooltipDescription) {
    const said = tooltipTitle !== "" ? tooltipTitle : tooltipDescription;
    const cut = said.length > stateLength ? said.slice(0, stateLength - 1) + "…" : said;
    if (status !== needsAttention)
        return cut;
    return cut !== "" ? `wartet · ${cut}` : "wartet";
}
