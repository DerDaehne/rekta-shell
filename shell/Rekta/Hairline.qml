import QtQuick

// A 1px separator line, decorative only (colour.md: text-contrast-low is for hairlines, never text).
Rectangle {
    implicitWidth: parent ? parent.width : 0
    implicitHeight: Geometry.hairline
    color: Tokens.color.textContrastLow
}
