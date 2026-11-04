import QtQuick
import "Status.js" as Status

// A status as its square and its one fixed word (colour.md, "Status vocabulary"); without a status it is idle.
Row {
    id: tag

    property string status: "" // info | success | warning | error, or "" for none
    property string word: Status.word(status)
    // Tabular figures, for a word whose digits change.
    property bool figures: false
    // In the plain, ink toast the word takes the toast's text colour and the square an edge in it, since a status colour
    // may sink into the ink; under more contrast the neutral square takes that colour too (rekta.css:1178–1179, :1554,
    // :1558).
    property bool inInkToast: false
    readonly property color ink: inInkToast ? Tokens.color.bg : Tokens.color.textPrimary
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
        objectName: "mark"
        anchors.verticalCenter: parent.verticalCenter
        width: Geometry.tagMark
        height: Geometry.tagMark
        color: tag.inInkToast && tag.status === "" && Tokens.moreContrast ? tag.ink : tag.mark

        // Outside the square, as a box-shadow is drawn.
        Rectangle {
            objectName: "edge"
            anchors.fill: parent
            anchors.margins: -Geometry.tagEdge
            visible: tag.inInkToast
            color: "transparent"
            border.width: Geometry.tagEdge
            border.color: tag.ink
        }
    }

    TextRole {
        id: wordText

        objectName: "word"
        text: tag.word
        font.pixelSize: Tokens.fontSizeXs
        font.weight: Tokens.fontWeightSemibold
        font.features: ({ "tnum": tag.figures ? 1 : 0 })
        lineHeightFactor: Tokens.lineHeightCompact
        color: tag.ink
    }
}
