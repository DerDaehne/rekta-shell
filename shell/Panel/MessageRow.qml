pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// One notification in the centre, a row on a hairline (rekta.css:73–75): the picture or the app's icon, square with a
// tile's corners, the summary in semibold, how long ago and a quiet "entfernen" button at the end, one line of the
// body, cut, and under it up to two of the notification's actions as quiet buttons. A click, Enter or Space presses the
// row, tinted on hover and press like a toast's text. A removable row always has the button; Delete, or pulling it
// towards the trailing edge, are shortcuts to it (collections.md:164–166). Let go past half its width the pulled row leaves,
// else it glides back. Leaving, it drifts and fades as a row that leaves a list does (motion.md, "Arriving, leaving");
// then it has gone.
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
    // False where the row is only a view of the centre's: no button, no Delete, no pull.
    property bool removable: true
    // What the row stands on, which the picture's corners are drawn in (Picture.ground).
    property color ground: Tokens.color.bg
    readonly property string time: Calendar.ago(new Date(stamp), now, locale)
    readonly property var actionList: JSON.parse(actions)
    // The focus is in it, also on a button of its own.
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
        if (event.key === Qt.Key_Delete && row.removable) {
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

        Picture {
            objectName: "icon"
            y: heading.y + (heading.height - height) / 2
            source: row.icon
            ground: row.ground
        }

        Body {
            id: heading

            objectName: "summary"
            x: Geometry.iconSize + Tokens.spaceS
            y: Geometry.hairline + Tokens.spaceS
            width: when.x - Tokens.spaceM - x
            text: row.summary
            textFormat: Text.PlainText
            font.weight: Tokens.fontWeightSemibold
            wrapMode: Text.NoWrap
            elide: Text.ElideRight

            OverflowTip {}
        }

        Meta {
            id: when

            objectName: "time"
            // The parts of a row stand space-m apart (rekta.css:74).
            x: (row.removable ? remove.x - Tokens.spaceM : row.width) - width
            anchors.baseline: heading.baseline
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

            OverflowTip {}
        }

        // Hover and press lay `hover` over the row, as over a toast's text (rekta.css:1215).
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
            id: remove

            objectName: "remove"
            visible: row.removable
            x: row.width - width
            y: heading.y + (heading.height - height) / 2
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
        enabled: !row.going && row.removable

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
