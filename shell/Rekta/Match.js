.pragma library

// How well a name matches what was typed (navigation.md, "Go to"; rekta.js matchScore(), :2605–2613): every typed word
// starts a word of the name or its keywords, `nameStart` when the name also starts with the text and `wordStart`
// otherwise; failing that, `inside` when the name contains the text; 0 is no match. Case never counts, and an empty text
// matches everything as `inside`. The better match has the higher level.
var nameStart = 3;
var wordStart = 2;
var inside = 1;

// A letter is what has a case, as QML's regular expressions know no \p{L}; scripts without one have no words here. Plain
// lower-case letters and digits, most of what is read, are told without asking for a case.
function isWordCharacter(character) {
    return (character >= "a" && character <= "z") || (character >= "0" && character <= "9") || character.toLowerCase() !== character.toUpperCase();
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

// The words of a text in one line, each after a space: " konsole terminal shell". A typed word starts one of them where
// the line holds it after a space. One string is far smaller than a list of words, so a search may keep the line of each
// thing it ranks again and again.
function wordLine(text) {
    return words(text).map(word => ` ${word}`).join("");
}

function score(name, keywords, text) {
    return scoreLine(name, wordLine(`${name} ${keywords}`), text);
}

// score(), with the name and its keywords already read into a wordLine().
function scoreLine(name, line, text) {
    if (text === "")
        return inside;
    const typed = text.toLowerCase();
    if (!words(text).every(word => line.includes(` ${word}`)))
        return name.toLowerCase().includes(typed) ? inside : 0;
    return name.toLowerCase().startsWith(typed) ? nameStart : wordStart;
}

// The items that match, the best first; equals keep the order they came in (rekta.js:2637–2638).
function ranked(items, scoreOf) {
    return items.map((item, index) => ({
                item: item,
                index: index,
                score: scoreOf(item)
            })).filter(hit => hit.score > 0).sort((a, b) => b.score - a.score || a.index - b.index).map(hit => hit.item);
}
