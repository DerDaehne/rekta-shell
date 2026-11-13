import QtQuick
import "Status.js" as Status

// The line below a control: a hint, the error that replaces it, or why the control cannot act (rekta.css `.rk-hint`).
TextRole {
    id: role

    font.pixelSize: Tokens.fontSizeXs
    color: Status.secondaryInk(role, Tokens.color)
    wrapMode: Text.Wrap
}
