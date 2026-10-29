import QtQuick

// What a short display says: the word over Rekta's meter with its value in tabular figures (data.md, "Meters"), or
// over a plain text when there is no level.
Item {
    id: face

    property string word
    // 0 to 1, or -1 to show `valueText` alone.
    property real level: -1
    property string valueText

    Meter {
        id: meter

        objectName: "meter"
        visible: face.level >= 0
        anchors.verticalCenter: parent.verticalCenter
        x: Geometry.appBarControlPadding
        width: face.width - 2 * Geometry.appBarControlPadding
        label: face.word
        value: face.level
        valueText: face.valueText
    }

    Item {
        id: plain

        objectName: "plain"
        visible: face.level < 0
        x: Geometry.appBarControlPadding
        y: (face.height - height) / 2
        width: face.width - 2 * Geometry.appBarControlPadding
        height: wordLine.height + nameLine.height

        Meta {
            id: wordLine

            width: plain.width
            lineHeightFactor: Tokens.lineHeightCompact
            wrapMode: Text.NoWrap
            text: face.word
        }

        TextRole {
            id: nameLine

            y: wordLine.height
            width: plain.width
            lineHeightFactor: Tokens.lineHeightCompact
            elide: Text.ElideRight
            text: face.valueText
            font.pixelSize: Tokens.fontSizeXs
            font.weight: Tokens.fontWeightSemibold
            color: Tokens.color.textPrimary
        }
    }
}
