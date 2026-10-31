pragma ComponentBehavior: Bound

import QtQuick

// Two to five options seen at a glance (forms.md, "Inputs"; rekta.css:382–399): joined buttons, the chosen one in the
// accent. On a choice made here the accent block slides over from the old one and the chosen label turns light
// halfway (motion.md, segments). Disabled, the frames and words grey but the chosen one keeps its accent (rekta.css:397,
// :399), and the reason stands beside it on the words' line while it fits the width, else below, wrapped within the
// width (the hint is inline after the control, forms.md, "Disabled controls say why").
Item {
    id: segments

    property list<string> options
    property int currentIndex: 0
    property string disabledReason
    readonly property bool disabled: disabledReason !== ""
    // True while a choice made here slides; the first drawing and a choice set from outside stand still.
    property bool sliding: false

    signal activated(int index)

    function choose(index: int) {
        if (disabled || index < 0 || index >= options.length || index === currentIndex)
            return;
        sliding = true;
        slideEnd.restart();
        currentIndex = index;
        activated(index);
    }

    // Beside the options as wide as the reason runs; the width it is given decides where the reason stands.
    readonly property bool whyBeside: group.width + Tokens.spaceS + why.implicitWidth <= width

    implicitWidth: group.width + (disabled ? Tokens.spaceS + why.implicitWidth : 0)
    implicitHeight: disabled && !whyBeside ? why.y + why.height : group.height
    activeFocusOnTab: true
    Accessible.role: Accessible.RadioButton
    Accessible.name: options[currentIndex] ?? ""
    Accessible.description: disabledReason
    Accessible.checkable: true
    Accessible.checked: true

    onOptionsChanged: {
        if (options.length > 5)
            console.warn(`Segments: ${options.length} options; more than five belong in a select (forms.md)`);
    }

    Keys.onPressed: event => {
        const moves = {
            [Qt.Key_Left]: currentIndex - 1,
            [Qt.Key_Up]: currentIndex - 1,
            [Qt.Key_Right]: currentIndex + 1,
            [Qt.Key_Down]: currentIndex + 1,
            [Qt.Key_Home]: 0,
            [Qt.Key_End]: options.length - 1
        };
        if (!(event.key in moves))
            return;
        choose(moves[event.key]);
        event.accepted = true;
    }

    Timer {
        id: slideEnd

        interval: Tokens.durationShort
        onTriggered: segments.sliding = false
    }

    Item {
        id: group

        // The words' baseline, so the reason beside it sits on the same line.
        baselineOffset: repeater.count > 0 ? (repeater.itemAt(0) as Item).baselineOffset : 0
        implicitWidth: row.implicitWidth
        implicitHeight: Tokens.controlHeight

        Rectangle {
            id: slide

            readonly property Rectangle chosen: repeater.count > 0 ? repeater.itemAt(segments.currentIndex) as Rectangle : null

            objectName: "slide"
            visible: chosen !== null
            x: chosen ? chosen.x : 0
            width: chosen ? chosen.width : 0
            height: parent.height
            topLeftRadius: chosen ? chosen.topLeftRadius : 0
            bottomLeftRadius: chosen ? chosen.bottomLeftRadius : 0
            topRightRadius: chosen ? chosen.topRightRadius : 0
            bottomRightRadius: chosen ? chosen.bottomRightRadius : 0
            color: Tokens.color.accent

            Behavior on x {
                enabled: segments.sliding

                NumberAnimation {
                    duration: Tokens.durationShort
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.easeBase
                }
            }
            Behavior on width {
                enabled: segments.sliding

                NumberAnimation {
                    duration: Tokens.durationShort
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.easeBase
                }
            }
        }

        Row {
            id: row

            objectName: "options"
            spacing: -Geometry.segmentBorder

            Repeater {
                id: repeater

                model: segments.options

                delegate: Rectangle {
                    id: option

                    baselineOffset: word.y + word.baselineOffset
                    required property string modelData
                    required property int index
                    readonly property bool chosen: index === segments.currentIndex
                    readonly property bool first: index === 0
                    readonly property bool last: index === segments.options.length - 1
                    // The chosen label waits for the sliding block and turns light halfway; the one left turns dark at once.
                    property bool lit: false

                    onChosenChanged: {
                        if (chosen && segments.sliding && Tokens.durationShort > 0)
                            lightUp.restart();
                        else
                            lit = chosen;
                    }
                    Component.onCompleted: lit = chosen

                    implicitWidth: word.implicitWidth + 2 * (Tokens.controlPadding + Geometry.segmentBorder)
                    height: Tokens.controlHeight
                    color: "transparent"
                    border.width: Geometry.segmentBorder
                    border.color: segments.disabled ? Tokens.color.disabled : chosen ? Tokens.color.accent : Tokens.color.textPrimary
                    topLeftRadius: first ? Tokens.radiusS : 0
                    bottomLeftRadius: first ? Tokens.radiusS : 0
                    topRightRadius: last ? Tokens.radiusS : 0
                    bottomRightRadius: last ? Tokens.radiusS : 0
                    z: chosen ? 1 : 0
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData
                    Accessible.checked: chosen

                    Text {
                        id: word

                        anchors.centerIn: parent
                        text: option.modelData
                        font.family: Tokens.fontSans
                        font.pixelSize: Tokens.fontSizeS
                        font.weight: Tokens.fontWeightSemibold
                        color: segments.disabled ? Tokens.color.disabled : option.lit ? Tokens.color.textOnAccent : Tokens.color.textPrimary
                    }

                    Timer {
                        id: lightUp

                        interval: Tokens.durationShort / 2
                        onTriggered: option.lit = option.chosen
                    }

                    // A pointer gives no focus, so the ring shows only for the keyboard, like :focus-visible.
                    TapHandler {
                        onTapped: segments.choose(option.index)
                    }
                }
            }
        }

        FocusRing {
            shown: segments.activeFocus
        }
    }

    Hint {
        id: why

        objectName: "why"
        x: segments.whyBeside ? group.width + Tokens.spaceS : 0
        y: segments.whyBeside ? group.baselineOffset - baselineOffset : group.height + Tokens.spaceXs
        width: segments.whyBeside ? implicitWidth : segments.width
        visible: segments.disabled
        text: segments.disabledReason
    }
}
