import QtQuick
import Rekta

// The password of a secured network in a sheet (forms.md, "A form in a sheet"): one field, "verbinden" and a way out in
// the corner. Enter in the field submits; an empty password is refused at the field. `ask` opens it for a network
// from the control that opened it, and `submitted` carries the network and its password once it has gone.
Sheet {
    id: sheet

    // What the question is about, kept to hand back with the password.
    property var network: null

    signal submitted(var network, string password)

    function ask(forNetwork: var, from: Item) {
        network = forNetwork;
        field.text = "";
        field.error = "";
        opener = from;
        show();
    }

    function submit() {
        if (!network) {
            close("gone");
            return;
        }
        if (field.text === "") {
            field.error = "passwort fehlt";
            return;
        }
        sheet.close("connect");
    }

    kicker: "wlan"
    dirty: field.text !== ""
    askKicker: "nicht verbunden"
    askTitle: "passwort verwerfen?"
    keepWord: "weiter eingeben"
    discardWord: "verwerfen"
    title: `passwort für ${network?.name ?? ""}`
    onClosed: answer => {
        if (answer === "connect")
            submitted(network, field.text);
        field.text = "";
    }

    Field {
        id: field

        objectName: "password"
        width: parent.width
        label: "passwort"
        echoMode: TextInput.Password
        onTextChanged: error = ""
        onAccepted: sheet.submit()
    }

    Actions {
        width: parent.width

        Button {
            objectName: "connect"
            variant: "primary"
            text: "verbinden"
            onClicked: sheet.submit()
        }
    }
}
