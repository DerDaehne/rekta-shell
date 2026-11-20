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

// Characters of a tooltip text that are looked at; the rest is never read.
const readLength = 1000;
const tag = /<\/?[a-zA-Z][^>]*(?:>|$)/g;
const lineBreak = /<br\s*\/?>|<\/(?:p|div|li|h[1-6])\s*>/gi;
const entities = { "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "#39": "'", "nbsp": " " };

// The words of an app's tooltip, which the StatusNotifierItem specification lets carry a small set of HTML tags and
// entities. Never markup: tags go, entities become their characters, and a decoded "<" stays text.
function plainWords(markup) {
    if (typeof markup !== "string")
        return "";
    const withoutTags = markup.slice(0, readLength).replace(lineBreak, " ").replace(tag, "");
    const decoded = withoutTags.replace(/&(amp|lt|gt|quot|#39|nbsp);/g, (_, name) => entities[name]);
    return decoded.replace(/\s+/g, " ").trim();
}

// The tooltip's title, else its description, as words and cut short; an app that wants attention says "wartet" first.
function state(status, tooltipTitle, tooltipDescription) {
    const title = plainWords(tooltipTitle);
    const said = title !== "" ? title : plainWords(tooltipDescription);
    const cut = said.length > stateLength ? said.slice(0, stateLength - 1) + "…" : said;
    if (status !== needsAttention)
        return cut;
    return cut !== "" ? `wartet · ${cut}` : "wartet";
}

// An icon name as Quickshell hands it over without the app's own icon directory: image://icon/<name>. With one
// (?path=<directory>) its provider also loads <directory>/<name> with any image suffix, as libappindicator apps expect.
const themeIcon = /^image:\/\/icon\/([^?]*)$/;

// The icon a row may show: none for a name the icon theme does not know (`known` asks it), so it is never loaded; any
// other picture, a name with the app's own directory among them, as it comes, for `checkerboard` to look at.
function shownIcon(url, known) {
    const named = themeIcon.exec(url);
    return named === null || known(named[1]) ? url : "";
}

// What Quickshell draws for a picture it cannot get (missingPixmap in its iconimageprovider.cpp): black, its top
// trailing and bottom leading quarters in this purple, all opaque. Its colours are Quickshell's, not Rekta's.
const missingBlack = [0, 0, 0, 255];
const missingPurple = [0xd9, 0x00, 0xd8, 255];

// Whether a loaded picture (width, height and RGBA data, as a canvas hands it over) is that checkerboard, by its corners.
function checkerboard(picture) {
    const is = (x, y, colour) => colour.every((channel, at) => picture.data[4 * (y * picture.width + x) + at] === channel);
    const right = picture.width - 1;
    const bottom = picture.height - 1;
    return is(0, 0, missingBlack) && is(right, 0, missingPurple)
        && is(0, bottom, missingPurple) && is(right, bottom, missingBlack);
}
