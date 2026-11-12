import QtQuick

// An empty region says what is empty and why in one sentence below its first hairline, and the way on, if there is
// one, below the sentence, space-s apart, with space-m of room above and below them (states.md, "Empty";
// rekta.css:890–891). A failed one says cause and remedy the same way, in text-primary after the error square, and the
// way on is its retry (states.md, "Failed"; rekta.css:892–893).
Item {
    id: empty

    property string text
    property alias lineHeightFactor: sentence.lineHeightFactor
    property bool failed: false
    // The way on, such as a button that clears the filters.
    default property alias wayOn: way.data

    implicitHeight: Geometry.hairline + Tokens.spaceM + sentence.implicitHeight + (way.implicitHeight > 0 ? Tokens.spaceS + way.implicitHeight : 0) + Tokens.spaceM
    height: implicitHeight

    Hairline {
        objectName: "line"
        width: parent.width
    }

    // The tag's 8px square, 6px before the words, as a field's error starts.
    Rectangle {
        objectName: "errorMark"
        // An inline-block sits on the baseline of the first line.
        y: sentence.y + sentence.baselineOffset - height
        visible: empty.failed
        width: Geometry.tagMark
        height: Geometry.tagMark
        color: Tokens.color.statusErrorFull
    }

    Body {
        id: sentence

        objectName: "sentence"
        x: empty.failed ? Geometry.tagMark + Geometry.tagGap : 0
        y: Geometry.hairline + Tokens.spaceM
        width: parent.width - x
        text: empty.text
        color: empty.failed ? Tokens.color.textPrimary : Tokens.color.textContrastHigh
    }

    Column {
        id: way

        objectName: "wayOn"
        y: sentence.y + sentence.height + Tokens.spaceS
        width: parent.width
    }
}
