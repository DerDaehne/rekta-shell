import QtQuick

// A key as on the keyboard, in hints and shortcut lists (rekta.css:809): a hairline box in the medium contrast colour,
// the key's name in the primary text colour.
Rectangle {
    id: key

    property alias text: label.text

    implicitWidth: Math.max(label.implicitWidth + 2 * Geometry.keyPadding, Geometry.keyMinWidth * label.font.pixelSize)
    implicitHeight: label.implicitHeight
    color: "transparent"
    radius: Tokens.radiusS
    border.width: Geometry.hairline
    border.color: Tokens.color.textContrastMedium

    TextRole {
        id: label

        anchors.centerIn: parent
        font.pixelSize: Tokens.fontSizeXxs
        font.weight: Tokens.fontWeightSemibold
        lineHeightFactor: Geometry.keyLineHeight
        color: Tokens.color.textPrimary
    }
}
