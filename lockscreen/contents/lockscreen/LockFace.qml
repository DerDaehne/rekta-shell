import QtQuick
import Rekta

// What one monitor shows while the session is locked, on the plain ground, everything a space-xl from the edges: the
// time as a large light title top left with the date as its fact line, bottom left the name over the password field
// and "entsperren", bottom right a status area over "benutzer wechseln". Only the active monitor shows it all; the
// others show the clock alone, as an inactive title, and the rest comes and goes as a state change (motion.md).
Rectangle {
    id: face

    // The monitor the user is at.
    property bool active: true
    property date now: new Date()
    property var locale: Qt.locale()
    property string userName
    // What was typed is being checked; field and button take nothing meanwhile.
    property bool checking: false
    property string error
    // PAM's own information, said at the field unless Caps Lock is on.
    property string info
    property bool capsLock: false
    // The keyboard layouts' short names; the choice shows only when there are several.
    property list<string> layouts
    property int layoutIndex: 0
    property bool canSwitchUser: true

    signal submitted(string secret)
    signal layoutChosen(int index)
    signal switchUser

    // A refused password stays, all of it selected, so typing replaces it (forms.md, "When the server says no").
    function reject() {
        field.selectAll();
    }

    color: Tokens.color.bg

    onActiveChanged: {
        if (active)
            field.selectAll();
    }
    Component.onCompleted: {
        if (active)
            field.selectAll();
    }

    // The clock wakes once a minute, when the minute changes; a new interval restarts it.
    Timer {
        objectName: "tick"
        interval: Calendar.untilNextMinute(face.now)
        running: true
        repeat: true
        onTriggered: face.now = new Date()
    }

    LockClock {
        id: clock

        objectName: "clock"
        x: Tokens.spaceXl
        y: Tokens.spaceXl
        active: face.active
        text: Calendar.timeWords(face.now, face.locale)
    }

    Item {
        objectName: "rest"
        anchors.fill: parent
        opacity: face.active ? 1 : 0
        enabled: face.active

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.durationShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeBase
            }
        }

        Facts {
            objectName: "date"
            x: Tokens.spaceXl
            y: clock.y + clock.height
            text: Calendar.longDateWords(face.now, face.locale)
        }

        Column {
            objectName: "signIn"
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.spaceXl
            spacing: Tokens.spaceS

            PivotTitle {
                objectName: "name"
                text: face.userName
            }

            // The layouts stand beside the field, level with its input (forms.md: segments for two to five options).
            Item {
                width: field.width + (face.layouts.length > 1 ? Tokens.spaceM + layoutChoice.width : 0)
                height: field.height

                Field {
                    id: field

                    objectName: "password"
                    width: 2 * Tokens.tileUnit + Tokens.spaceS
                    label: "passwort"
                    echoMode: TextInput.Password
                    readOnly: face.checking
                    error: face.error
                    hint: face.capsLock ? "Die Feststelltaste ist an." : face.info
                    onAccepted: face.submitted(field.text)
                }

                Segments {
                    id: layoutChoice

                    objectName: "layouts"
                    x: field.width + Tokens.spaceM
                    y: field.inputY
                    visible: face.layouts.length > 1
                    options: face.layouts
                    currentIndex: face.layoutIndex
                    onActivated: index => face.layoutChosen(index)
                }
            }

            // The dots keep their room while they rest, so field and button never move (states.md, "Loading": what
            // was there stays); they are as wide as the field (data.md, "Progress").
            Dots {
                objectName: "dots"
                width: field.width
                running: face.checking
                text: "wird geprüft …"
            }

            Button {
                objectName: "unlock"
                variant: "primary"
                text: "entsperren"
                onClicked: face.submitted(field.text)
            }
        }

        Column {
            objectName: "corner"
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.spaceXl
            spacing: Tokens.spaceXs

            // What is going on, right-aligned; it takes no room while it holds nothing.
            Column {
                objectName: "status"
                x: parent.width - width
                visible: children.length > 0
                spacing: Tokens.spaceXs
            }

            Button {
                objectName: "switchUser"
                x: parent.width - width
                visible: face.canSwitchUser
                variant: "quiet"
                text: "benutzer wechseln"
                onClicked: face.switchUser()
            }
        }
    }
}
