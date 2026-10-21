import QtQuick

// The one bold main title of a screen. It never shrinks to fit: it wraps up to three lines, breaking long words,
// then ends in an ellipsis (typography.md, "A long main title").
TextRole {
    // The width of the place that hosts the title; fluid sizes follow it, not the screen.
    property real placeWidth: Window.width

    font.pixelSize: Tokens.fluid(Tokens.fontSizeTitle, placeWidth)
    font.weight: Tokens.fontWeightSemibold
    lineHeightFactor: Tokens.lineHeightTitle
    color: Tokens.color.textPrimary
    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    maximumLineCount: Geometry.titleMaxLines
    elide: Text.ElideRight
}
