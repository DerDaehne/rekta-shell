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

// An icon name as Quickshell hands it over without the app's own icon directory: image://icon/<name>. With one
// (?path=<directory>) its provider also loads <directory>/<name> with any image suffix, as libappindicator apps expect.
const themeIcon = /^image:\/\/icon\/([^?]*)$/;

// The icon a row shows: none for a name the icon theme does not know (`known` asks it), where Quickshell's provider
// would draw a checkerboard; any other picture, a name with the app's own directory among them, as it comes.
// ponytail: a name found neither in the theme nor in the app's directory still shows the checkerboard; telling it apart
// needs a look into that directory.
function shownIcon(url, known) {
    const named = themeIcon.exec(url);
    return named === null || known(named[1]) ? url : "";
}
