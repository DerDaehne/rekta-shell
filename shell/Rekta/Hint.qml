import QtQuick

// The line below a control: a hint, the error that replaces it, or why the control cannot act (rekta.css `.rk-hint`).
Text {
    font.family: Tokens.fontSans
    font.pixelSize: Tokens.fontSizeXs
    lineHeightMode: Text.ProportionalHeight
    lineHeight: Tokens.lineHeightBody
    color: Tokens.color.textContrastHigh
    wrapMode: Text.Wrap
}
