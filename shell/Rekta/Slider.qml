import QtQuick

// A value on a scale (forms.md, "Inputs"): a 6px track the accent fills up to the value, an ink bar as the thumb, and
// the value shown beside it in tabular figures.
Item {
    id: slider

    property real from: 0
    property real to: 1
    property real stepSize: 0.01
    property real value: 0
    property string valueText: `${Math.round(value * 100) / 100}`
    property string label
    property string disabledReason
    readonly property bool disabled: disabledReason !== ""
    readonly property real position: to > from ? (value - from) / (to - from) : 0

    signal moved

    // Every change goes through here: clamped to the range and snapped to the step.
    function setValue(newValue: real) {
        if (disabled)
            return;
        const stepped = from + Math.round((newValue - from) / stepSize) * stepSize;
        const clamped = Math.min(to, Math.max(from, stepped));
        if (clamped === value)
            return;
        value = clamped;
        moved();
    }

    implicitWidth: 240
    implicitHeight: Tokens.controlHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Accessible.name: label
    Accessible.description: disabled ? disabledReason : valueText

    Keys.onPressed: event => {
        const page = 10 * stepSize;
        const changes = {
            [Qt.Key_Left]: value - stepSize,
            [Qt.Key_Down]: value - stepSize,
            [Qt.Key_Right]: value + stepSize,
            [Qt.Key_Up]: value + stepSize,
            [Qt.Key_PageDown]: value - page,
            [Qt.Key_PageUp]: value + page,
            [Qt.Key_Home]: from,
            [Qt.Key_End]: to
        };
        if (!(event.key in changes))
            return;
        setValue(changes[event.key]);
        event.accepted = true;
    }

    Row {
        anchors.fill: parent
        spacing: Tokens.spaceM

        Item {
            id: rail

            width: parent.width - output.width - parent.spacing
            height: parent.height

            Rectangle {
                id: track

                objectName: "track"
                anchors.verticalCenter: parent.verticalCenter
                width: rail.width
                height: Geometry.sliderTrack
                color: Tokens.color.textContrastLow

                Rectangle {
                    objectName: "fill"
                    width: track.width * slider.position
                    height: track.height
                    color: slider.disabled ? Tokens.color.disabled : Tokens.color.accent
                }
            }

            Rectangle {
                objectName: "thumb"
                anchors.verticalCenter: parent.verticalCenter
                x: slider.position * (rail.width - width)
                width: Geometry.sliderThumbWidth
                height: Geometry.sliderThumbHeight
                color: slider.disabled ? Tokens.color.disabled : Tokens.color.textPrimary

                FocusRing {
                    shown: slider.activeFocus
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: !slider.disabled

                function follow(x: real) {
                    slider.setValue(slider.from + (x / rail.width) * (slider.to - slider.from));
                }

                onPressed: mouse => {
                    slider.forceActiveFocus();
                    follow(mouse.x);
                }
                onPositionChanged: mouse => follow(mouse.x)
            }
        }

        Text {
            id: output

            objectName: "output"
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(implicitWidth, Geometry.sliderOutputWidth * font.pixelSize)
            horizontalAlignment: Text.AlignRight
            text: slider.valueText
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.fontSizeS
            font.weight: Tokens.fontWeightMedium
            font.features: ({ "tnum": 1 })
            color: slider.disabled ? Tokens.color.disabled : Tokens.color.textPrimary
        }
    }
}
