import QtQuick
import Rekta

// One setting as a form lays it out (forms.md, "Fields"): the label above, the control, and below it a hint. The hint
// names the Nix default once the user's value differs from it.
Column {
    id: setting

    property string label
    property string hint
    // The default in words, set while the user's value differs from it.
    property string presetWord
    default property alias control: holder.data

    spacing: Tokens.spaceXs

    Text {
        objectName: "label"
        visible: setting.label !== ""
        text: setting.label
        font.family: Tokens.fontSans
        font.pixelSize: Tokens.fontSizeXs
        font.weight: Tokens.fontWeightSemibold
        color: Tokens.color.textContrastHigh
    }

    Item {
        id: holder

        width: setting.width
        height: children.length > 0 ? children[0].height : 0
    }

    Hint {
        objectName: "hint"
        width: setting.width
        text: setting.presetWord === "" ? setting.hint : `${setting.hint} vorgabe: ${setting.presetWord}.`
    }
}
