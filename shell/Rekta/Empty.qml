import QtQuick

// An empty region says what is empty and why in one sentence below its first hairline, with space-m of room above and
// below the sentence (states.md, "Empty"; rekta.css:675).
Item {
    id: empty

    property string text

    implicitHeight: Geometry.hairline + Tokens.spaceM + sentence.implicitHeight + Tokens.spaceM
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
}
