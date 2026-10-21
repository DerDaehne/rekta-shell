import QtQuick
import "Status.js" as Status

// A status as its square and its one fixed word (colour.md, "Status vocabulary"); without a status it is idle.
Row {
    id: tag

    property string status: "" // info | success | warning | error, or "" for none
    property string word: Status.word(status)
    readonly property color mark: {
        switch (status) {
        case "info":
            return Tokens.color.statusInfoFull;
        case "success":
            return Tokens.color.statusSuccessFull;
        case "warning":
            return Tokens.color.statusWarningFull;
        case "error":
            return Tokens.color.statusErrorFull;
        default:
            return Tokens.color.textContrastMedium;
        }
    }

    // An inline mark and its word: a place change turns them as one part (motion.md, "Place change").
    readonly property bool turnsWhole: true

    spacing: Geometry.tagGap
    // A row has no baseline of its own; the word's lines the tag up with running text.
    baselineOffset: wordText.y + wordText.baselineOffset
    Accessible.role: Accessible.StaticText
    Accessible.name: word

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Geometry.tagMark
        height: Geometry.tagMark
        color: tag.mark
    }

    TextRole {
        id: wordText

        objectName: "word"
        text: tag.word
        font.pixelSize: Tokens.fontSizeXs
        font.weight: Tokens.fontWeightSemibold
        lineHeightFactor: Tokens.lineHeightCompact
        color: Tokens.color.textPrimary
    }
}
