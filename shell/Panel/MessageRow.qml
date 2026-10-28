pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// One notification in the centre, a row on a hairline (rekta.css:68–70): the picture or the app's icon, square with a
// tile's corners, the summary in semibold with how long ago at the end, one line of the body, cut, and under it up to two
// of the notification's actions as quiet buttons. A click, Enter or Space presses the row, tinted on hover and press like
// a toast's text. While the pointer is on the row or the focus is in it, a quiet "entfernen" button takes the place of
// the time; Delete, or pulling the row towards the trailing edge, are shortcuts to it. Let go past half its width the pulled
// row leaves, else it glides back. Leaving, it drifts and fades as a row that leaves a list does (motion.md, "Arriving,
// leaving"); then it has gone.
Item {
    id: row

    required property int index
    required property int order
    required property string app
    required property string summary
    required property string body
    required property string icon
    // When it arrived, in ms, and the time it is told against; the words follow `now`.
    required property double stamp
    // JSON: [{ identifier, text }], the actions beside the default one.
    required property string actions
    property var now: new Date()
    property var locale: Qt.locale()
    readonly property string time: Calendar.ago(new Date(stamp), now, locale)
    readonly property var actionList: JSON.parse(actions)
    // The pointer is on it, or the focus is in it (also on a button of its own).
    readonly property bool engaged: hover.hovered || holdsFocus
    readonly property bool holdsFocus: {
        let item = Window.window?.activeFocusItem;
        while (item && item !== row)
            item = item.parent;
        return item === row;
    }
    // How far the pointer has pulled it towards the trailing edge.
    property real pulled: 0
    // Runs from 0 to 1 as it leaves.
    property real leaving: 0
    readonly property bool going: leaving > 0 || goingOut.running

    signal pressed
    signal actionPressed(string identifier)
    // Delete was pressed on it, or it was pulled away: it should leave.
    signal removing
    // It has left.
    signal gone

    function leave() {
        if (going)
            return;
        glidingBack.stop();
        goingOut.start();
    }

    function letGo() {
        if (pulled > Geometry.rowPullAway * width)
            removing();
        else
            glidingBack.start();
    }

    width: parent ? parent.width : 0
    implicitHeight: Geometry.hairline + 2 * Tokens.spaceS + heading.height + (detail.visible ? detail.height : 0) + (offers.visible ? offers.height : 0)
    activeFocusOnTab: !going
    Accessible.role: Accessible.Button
    Accessible.name: [app, summary, body, time].filter(part => part !== "").join(", ")
    Accessible.onPressAction: pressed()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Delete) {
            removing();
        } else if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)) {
            // A held key presses once.
            if (!event.isAutoRepeat)
                pressed();
        } else {
            return;
        }
        event.accepted = true;
    }

    NumberAnimation {
        id: goingOut

        target: row
        property: "leaving"
        to: 1
        duration: Geometry.rowLeaveShare * Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeOut
        onFinished: row.gone()
    }

    // Let go short of half, it settles back as a state change does (motion.md, "State changes").
    NumberAnimation {
        id: glidingBack

        target: row
        property: "pulled"
        to: 0
        duration: Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeBase
    }

    Item {
        id: content

        objectName: "content"
        x: row.pulled + row.leaving * Geometry.rowLeaveDrift
        width: row.width
        height: row.height
        opacity: 1 - row.leaving

        Hairline {
            width: row.width
        }

        Image {
            objectName: "icon"
            y: heading.y + (heading.height - height) / 2
            width: Geometry.iconSize
            height: Geometry.iconSize
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            source: row.icon
        }

        // A ring in the panel's ground, whose inner edge is the picture's rounded outline, as in a toast.
        Rectangle {
            x: -Tokens.radiusTile
            y: heading.y + (heading.height - height) / 2
            width: Geometry.iconSize + 2 * Tokens.radiusTile
            height: width
            color: "transparent"
            radius: 2 * Tokens.radiusTile
            border.width: Tokens.radiusTile
            border.color: Tokens.color.bg
        }

        Body {
            id: heading

            objectName: "summary"
            x: Geometry.iconSize + Tokens.spaceS
            y: Geometry.hairline + Tokens.spaceS
            width: row.width - x - when.width - Tokens.spaceM
            text: row.summary
            textFormat: Text.PlainText
            font.weight: Tokens.fontWeightSemibold
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }

        Meta {
            id: when

            objectName: "time"
            x: row.width - width
            anchors.baseline: heading.baseline
            visible: !row.engaged
            text: row.time
            wrapMode: Text.NoWrap
        }

        Body {
            id: detail

            objectName: "body"
            x: heading.x
            y: heading.y + heading.height
            width: row.width - x
            visible: text !== ""
            text: row.body
            textFormat: Text.PlainText
            wrapMode: Text.NoWrap
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        // Hover and press lay `hover` over the row, as over a toast's text (rekta.css:916).
        Rectangle {
            objectName: "tint"
            anchors.fill: parent
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

        IconButton {
            objectName: "remove"
            x: row.width - width
            y: heading.y + (heading.height - height) / 2
            visible: row.engaged
            variant: "quiet"
            icon: "close"
            label: "entfernen"
            onClicked: row.removing()
        }

        Row {
            id: offers

            objectName: "offers"
            x: heading.x - Tokens.controlPadding - Geometry.buttonBorder
            y: (detail.visible ? detail.y + detail.height : heading.y + heading.height)
            visible: row.actionList.length > 0

            Repeater {
                model: row.actionList

                delegate: Button {
                    required property var modelData

                    variant: "quiet"
                    text: modelData.text
                    onClicked: row.actionPressed(modelData.identifier)
                }
            }
        }

        FocusRing {
            shown: row.activeFocus
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        // A slow click is still a click.
        longPressThreshold: 0
        enabled: !row.going
        onTapped: row.pressed()
    }

    DragHandler {
        id: pull

        target: null
        yAxis.enabled: false
        enabled: !row.going

        onActiveTranslationChanged: {
            if (active)
                row.pulled = Math.max(0, activeTranslation.x);
        }
        onActiveChanged: {
            if (active)
                glidingBack.stop();
            else
                row.letGo();
        }
    }
}
