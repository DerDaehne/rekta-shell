import QtQuick

// The base of every text role: lines as tall as Rekta's. A line-height token is a multiple of the font size, and half
// the leading sits above the glyphs, half below (CSS line-height). Qt's proportional mode would scale the font's own
// height instead, and Qt puts all the leading below the line; the paddings move its lines into those line boxes.
Text {
    id: role

    // Every text inherits line-height-body unless its role sets another (rekta.css:35).
    property real lineHeightFactor: Tokens.lineHeightBody
    // Half the leading, above the first line's glyphs; negative where the line box is lower than the glyphs, which then
    // reach past it, as in CSS.
    readonly property real lineBoxTop: (lineHeight - metrics.height) / 2
    // Where the glyphs are higher than the line, Qt adds the difference to the text's height, from the glyph height
    // rounded up and cut to whole pixels (QQuickTextPrivate::lineHeightOffset); the box ends with its last line.
    readonly property real lineBoxBottom: -lineBoxTop - Math.max(0, Math.floor(Math.ceil(metrics.height) - lineHeight))

    font.family: Tokens.fontSans
    lineHeightMode: Text.FixedHeight
    lineHeight: lineHeightFactor * font.pixelSize
    topPadding: lineBoxTop
    bottomPadding: lineBoxBottom

    FontMetrics {
        id: metrics

        font: role.font
    }
}
