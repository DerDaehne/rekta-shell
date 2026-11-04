.pragma library

// A calculation typed into the search: numbers with the locale's decimal separator, + \u2212 \u00d7 / ^ %, and brackets. A small
// parser by descent works it out, never eval: the text is the user's, and only arithmetic may come of it.

const signs = { "+": "+", "-": "-", "\u2212": "-", "*": "*", "\u00d7": "*", "/": "/", "\u00f7": "/", "^": "^", "%": "%", "(": "(", ")": ")" };

// What a calculation starts with, so typing it starts a search: a digit, an opening bracket, a minus or the separator.
function canStart(character, decimalPoint) {
    return /^[0-9(\-\u2212]$/.test(character) || character === decimalPoint;
}

function numberPattern(decimalPoint) {
    const separator = decimalPoint.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    return new RegExp(`^(\\d+(${separator}\\d*)?|${separator}\\d+)`);
}

// The numbers and signs of a text, spaces left out; null when it holds anything else.
function tokens(text, decimalPoint) {
    const number = numberPattern(decimalPoint);
    const found = [];
    for (let rest = text.trim(); rest !== ""; ) {
        const digits = number.exec(rest);
        const token = digits !== null ? Number(digits[0].replace(decimalPoint, ".")) : signs[rest[0]];
        if (token === undefined)
            return null;
        found.push(token);
        rest = rest.slice(digits !== null ? digits[0].length : 1).replace(/^\s+/, "");
    }
    return found;
}

function fail() {
    throw new Error("no calculation");
}

// The next token when it is one of `accepted`, taken; undefined otherwise.
function take(parser, accepted) {
    const token = parser.tokens[parser.at];
    if (!accepted.includes(token))
        return undefined;
    parser.at++;
    return token;
}

function sum(parser) {
    let value = product(parser);
    for (let sign = take(parser, ["+", "-"]); sign !== undefined; sign = take(parser, ["+", "-"])) {
        const right = product(parser);
        value = sign === "+" ? value + right : value - right;
        parser.operations++;
    }
    return value;
}

function product(parser) {
    let value = signed(parser);
    for (let sign = take(parser, ["*", "/"]); sign !== undefined; sign = take(parser, ["*", "/"])) {
        const right = signed(parser);
        if (sign === "/" && right === 0)
            fail();
        value = sign === "*" ? value * right : value / right;
        parser.operations++;
    }
    return value;
}

// A sign binds less than a power, as in writing: -2^2 is -4.
function signed(parser) {
    const sign = take(parser, ["+", "-"]);
    if (sign === undefined)
        return power(parser);
    const value = signed(parser);
    return sign === "-" ? -value : value;
}

// A power binds to the right: 2^3^2 is 2^9.
function power(parser) {
    const base = percent(parser);
    if (take(parser, ["^"]) === undefined)
        return base;
    parser.operations++;
    return Math.pow(base, signed(parser));
}

// A percent sign takes a hundredth: 50% is 0.5.
function percent(parser) {
    let value = primary(parser);
    while (take(parser, ["%"]) !== undefined) {
        value /= 100;
        parser.operations++;
    }
    return value;
}

function primary(parser) {
    const token = parser.tokens[parser.at++];
    if (typeof token === "number")
        return token;
    if (token !== "(")
        fail();
    const value = sum(parser);
    if (take(parser, [")"]) === undefined)
        fail();
    return value;
}

// The value of a calculation; null when the text is none: a number alone, a sign it does not know, a bracket left open,
// a division by zero, or a result that is no finite number.
function result(text, decimalPoint) {
    const found = tokens(text, decimalPoint);
    if (found === null)
        return null;
    const parser = { tokens: found, at: 0, operations: 0 };
    let value = NaN;
    try {
        value = sum(parser);
    } catch (error) {
        return null;
    }
    return parser.at === found.length && parser.operations > 0 && Number.isFinite(value) ? value : null;
}

// A result as the search shows and copies it: twelve significant digits, so 0.1 + 0.2 is 0.3, with the locale's
// separator.
function shown(value, decimalPoint) {
    return String(Number(value.toPrecision(12))).replace(".", decimalPoint);
}
