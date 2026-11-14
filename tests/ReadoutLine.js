.pragma library

// The one line of a level display (ReadoutFace), checked at exact edges: from the control's padding on its icon, its
// meter a tile unit wide when it has a level, and its value, medium in tabular figures, at least four zeros wide and
// end-aligned, space-s apart, each centred on the line's height; the padding again after the value, and no other text.
// `zero` is the advance of a zero in the value's font. Returns the parts.
function verify(test, face, Tokens, Geometry, zero) {
    const icon = test.findChild(face, "icon");
    const meter = test.findChild(face, "meter");
    const value = test.findChild(face, "value");
    const middle = face.height / 2;
    test.compare(icon.x, Geometry.appBarControlPadding, "the icon starts after the padding");
    test.compare(icon.width, Geometry.appBarGlyph);
    test.compare(icon.height, Geometry.appBarGlyph);
    test.compare(icon.y + icon.height / 2, middle, "the icon is centred");
    let valueX = icon.x + icon.width + Tokens.spaceS;
    if (face.level >= 0) {
        test.verify(meter.visible, "a level has its meter");
        test.compare(meter.x, valueX, "the meter is space-s after the icon");
        test.compare(meter.width, Tokens.tileUnit);
        test.compare(meter.height, Geometry.meterHeight);
        test.compare(meter.y + meter.height / 2, middle, "the meter is centred");
        test.compare(meter.color, Tokens.color.textContrastLow);
        test.compare(test.findChild(meter, "fill").color, Tokens.color.textPrimary);
        valueX = meter.x + meter.width + Tokens.spaceS;
    } else {
        test.verify(!meter.visible, "without a level there is no meter");
    }
    test.compare(value.x, valueX, "the value is space-s after the part before it");
    test.compare(value.width, Math.max(value.implicitWidth, 4 * zero), "the value is at least 4ch wide");
    test.compare(value.horizontalAlignment, Qt.AlignRight);
    test.compare(value.font.weight, Tokens.fontWeightMedium);
    test.compare(value.font.pixelSize, Tokens.fontSizeXs);
    test.compare(value.font.features.tnum, 1);
    test.compare(value.color, Tokens.color.textPrimary);
    // Anchors round a centred box to whole pixels.
    test.fuzzyCompare(value.y + value.height / 2, middle, 0.5, "the value is centred");
    test.compare(face.implicitWidth, value.x + value.width + Geometry.appBarControlPadding, "the line ends with the padding");
    test.compare(shownTexts(face), [face.valueText], "the value is the only text, the word is not shown");
    return { icon, meter, value };
}

function shownTexts(item) {
    if (!item.visible)
        return [];
    const own = typeof item.text === "string" && item.font !== undefined ? [item.text] : [];
    return own.concat(...Array.from(item.children).map(shownTexts));
}
