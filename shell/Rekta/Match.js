.pragma library

// How well a name matches what was typed (navigation.md, "Go to"; rekta.js matchScore(), :2576–2584): every typed word
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

// The words of the texts read so far: a search ranks the same names and keywords at every key, and splitting them is
// most of its work. Emptied when it holds many, as window titles come and go.
var wordsRead = new Map();
const mostWordsRead = 5000;

// The runs of letters and digits in a text, lower case. The list is shared: do not change it.
function words(text) {
    let found = wordsRead.get(text);
    if (found === undefined) {
        if (wordsRead.size >= mostWordsRead)
            wordsRead.clear();
        found = splitIntoWords(text);
        wordsRead.set(text, found);
    }
    return found;
}

function splitIntoWords(text) {
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
        return inside;
    const typed = text.toLowerCase();
    const known = words(`${name} ${keywords}`);
    if (!words(text).every(word => known.some(candidate => candidate.startsWith(word))))
        return name.toLowerCase().includes(typed) ? inside : 0;
    return name.toLowerCase().startsWith(typed) ? nameStart : wordStart;
}

// The items that match, the best first; equals keep the order they came in (rekta.js:2608–2609).
function ranked(items, scoreOf) {
    return items.map((item, index) => ({
                item: item,
                index: index,
                score: scoreOf(item)
            })).filter(hit => hit.score > 0).sort((a, b) => b.score - a.score || a.index - b.index).map(hit => hit.item);
}
