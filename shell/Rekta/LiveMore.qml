import QtQuick

// The quiet button of a held live region that says how many updates wait; pressing it shows them (live.md, "Holding
// still"; rekta.js:3744–3770, `.rk-live-more` rekta.css:662). It is there only while updates wait, and arrives as
// `rk-arrive` does over duration-short (rekta.css:1119).
Item {
    id: more

    property int count: 0
    property real entry: 1

    signal clicked

    function click() {
        if (visible)
            clicked();
    }

    width: label.implicitWidth + 2 * (Tokens.spaceS + Geometry.buttonBorder)
    height: label.implicitHeight + 2 * (Geometry.liveMorePadding + Geometry.buttonBorder)
    visible: count > 0
    opacity: entry
    transform: Translate {
        y: -(1 - more.entry) * Geometry.arriveDrop
    }
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label.text
    Accessible.onPressAction: click()

    onVisibleChanged: {
        if (visible)
            arrive.restart();
    }

    Keys.onPressed: event => {
        if (![Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].includes(event.key))
            return;
        event.accepted = true;
        // A held key acts once.
        if (!event.isAutoRepeat)
            more.click();
    }

    NumberAnimation {
        id: arrive

        objectName: "arrive"
        target: more
        property: "entry"
        from: 0
        to: 1
        duration: Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
    }

    // Hover and press lay `hover` under the words, as on every button.
    Rectangle {
        anchors.fill: parent
        radius: Tokens.radiusS
        color: Tokens.color.hover
        opacity: hover.hovered || tap.pressed ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.durationShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeBase
            }
        }
    }

    Text {
        id: label

        objectName: "label"
        anchors.centerIn: parent
        text: more.count === 1 ? "1 aktualisierung wartet · zeigen" : `${more.count} aktualisierungen warten · zeigen`
        font.family: Tokens.fontSans
        font.pixelSize: Tokens.fontSizeXs
        font.weight: Tokens.fontWeightSemibold
        color: hover.hovered ? Tokens.color.textPrimary : Tokens.color.textContrastHigh
    }

    FocusRing {
        shown: more.activeFocus
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        // A slow click is still a click.
        longPressThreshold: 0
        onTapped: more.click()
    }
}
