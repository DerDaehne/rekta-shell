.pragma library

// How well a name matches what was typed (navigation.md, "Go to"; rekta.js matchScore(), :2164–2172): every typed word
// starts a word of the name or its keywords, 3 when the name also starts with the text and 2 otherwise; failing that,
// 1 when the name contains the text; 0 is no match. Case never counts.

// A letter is what has a case, as QML's regular expressions know no \p{L}; scripts without one have no words here.
function isWordCharacter(character) {
    return character.toLowerCase() !== character.toUpperCase() || (character >= "0" && character <= "9");
}

// The runs of letters and digits in a text, lower case.
function words(text) {
    const found = [];
    let word = "";
    for (const character of text.toLowerCase()) {
        if (isWordCharacter(character)) {
            word += character;
        } else if (word !== "") {
            found.push(word);
            word = "";
        }
    }
    return word !== "" ? [...found, word] : found;
}

function score(name, keywords, text) {
    if (text === "")
        return 1;
    const typed = text.toLowerCase();
    const known = words(`${name} ${keywords}`);
    if (!words(text).every(word => known.some(candidate => candidate.startsWith(word))))
        return name.toLowerCase().includes(typed) ? 1 : 0;
    return name.toLowerCase().startsWith(typed) ? 3 : 2;
}

// The items that match, the best first; equals keep the order they came in (rekta.js:2196–2197).
function ranked(items, scoreOf) {
    return items.map((item, index) => ({
                item: item,
                index: index,
                score: scoreOf(item)
            })).filter(hit => hit.score > 0).sort((a, b) => b.score - a.score || a.index - b.index).map(hit => hit.item);
}
