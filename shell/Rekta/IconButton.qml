import QtQuick

// A button with a glyph and no words (forms.md, "The icon button"): square at the control's height, the row's in a row,
// never below the touch target under a coarse pointer. Having no words, it is read by its label and shows it as its
// tip (navigation.md, "Tooltips"); without one it warns.
Button {
    // The name it is read by, like aria-label.
    property string label

    tip: label
    Accessible.name: label

    Component.onCompleted: {
        if (Accessible.name === "")
            console.warn(`IconButton "${icon}": no label; a button without words needs one to be read by (forms.md)`);
    }
}
