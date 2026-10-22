import QtQuick

// A short question in a sheet (behaviour.md, `confirm()`; rekta.js:2400–2424): the question as its title, a line under
// it, cancel and ok. The safe answer is the primary button and takes the focus; Escape and the shading answer cancel.
// For an action that cannot be undone the safe answer is cancel, and ok wears the error frame (forms.md, "Dialog
// levels"), where rekta.js leaves it plain. Its own safe answer is its way out, so it has no close button.
Sheet {
    id: confirm

    property string text
    property string ok: "ok"
    property string cancel: "cancel"
    // "ok", or "cancel" for an action that cannot be undone.
    property string safe: "ok"

    signal answered(bool confirmed)

    closeButton: false
    initialFocus: safe === "cancel" ? cancelButton : okButton
    onClosed: answer => answered(answer === "ok")

    Body {
        objectName: "text"
        width: parent.width
        visible: text !== ""
        text: confirm.text
    }

    Actions {
        width: parent.width

        Button {
            id: cancelButton

            objectName: "cancel"
            text: confirm.cancel
            variant: confirm.safe === "cancel" ? "primary" : ""
            onClicked: confirm.request("cancel")
        }

        Button {
            id: okButton

            objectName: "ok"
            text: confirm.ok
            variant: confirm.safe === "cancel" ? "destructive" : "primary"
            onClicked: confirm.close("ok")
        }
    }
}
