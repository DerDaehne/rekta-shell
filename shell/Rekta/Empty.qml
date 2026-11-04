import QtQuick

// An empty region says what is empty and why in one sentence below its first hairline, and the way on, if there is
// one, below the sentence, space-s apart, with space-m of room above and below them (states.md, "Empty";
// rekta.css:890–891).
Item {
    id: empty

    property string text
    // The way on, such as a button that clears the filters.
    default property alias wayOn: way.data

    implicitHeight: Geometry.hairline + Tokens.spaceM + sentence.implicitHeight + (way.implicitHeight > 0 ? Tokens.spaceS + way.implicitHeight : 0) + Tokens.spaceM
    height: implicitHeight

    Hairline {
        objectName: "line"
        width: parent.width
    }

    Body {
        id: sentence

        objectName: "sentence"
        y: Geometry.hairline + Tokens.spaceM
        width: parent.width
        text: empty.text
        color: Tokens.color.textContrastHigh
    }

    Column {
        id: way

        objectName: "wayOn"
        y: sentence.y + sentence.height + Tokens.spaceS
        width: parent.width
    }
}
