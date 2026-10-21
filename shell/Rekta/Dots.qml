pragma ComponentBehavior: Bound

import QtQuick

// The dots, the Metro way (data.md, "Progress"), for a wait that holds the whole screen: five small squares fly in
// from the leading edge, bunch up through the middle and speed off, one after another. Under reduced motion they
// stand still in the middle with the words beside them.
Item {
    id: dots

    // What is happening; said beside the dots when they stand still, and to assistive technology always.
    property string text
    property color ink: Tokens.color.textPrimary

    implicitHeight: Math.max(Geometry.dotSize, words.implicitHeight)
    Accessible.role: Accessible.ProgressBar
    Accessible.name: text

    Repeater {
        model: Geometry.dotCount

        delegate: Rectangle {
            id: dot

            required property int index
            // Where the dot is on its flight, as a share of the width.
            property real position: Geometry.dotStart
            property bool launched: false

            width: Geometry.dotSize
            height: Geometry.dotSize
            y: (dots.height - height) / 2
            x: Tokens.reducedMotion ? dots.width / 2 - Geometry.dotRestOffset + dot.index * Geometry.dotRestSpacing : dot.position * dots.width
            color: dots.ink
            opacity: Tokens.reducedMotion ? 1 : 0

            Timer {
                interval: dot.index * Tokens.durationDots * Geometry.dotStagger
                running: !Tokens.reducedMotion && !dot.launched
                onTriggered: dot.launched = true
            }

            Connections {
                target: Tokens

                function onReducedMotionChanged() {
                    if (Tokens.reducedMotion)
                        dot.launched = false;
                }
            }

            ParallelAnimation {
                running: dot.launched && !Tokens.reducedMotion
                loops: Animation.Infinite

                SequentialAnimation {
                    NumberAnimation {
                        target: dot
                        property: "position"
                        from: Geometry.dotStart
                        to: Geometry.dotSlowFromAt
                        duration: Tokens.durationDots * Geometry.dotSlowFrom
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Geometry.dotEaseIn
                    }
                    NumberAnimation {
                        target: dot
                        property: "position"
                        to: Geometry.dotSlowUntilAt
                        duration: Tokens.durationDots * (Geometry.dotSlowUntil - Geometry.dotSlowFrom)
                    }
                    NumberAnimation {
                        target: dot
                        property: "position"
                        to: Geometry.dotEnd
                        duration: Tokens.durationDots * (1 - Geometry.dotSlowUntil)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Geometry.dotEaseOut
                    }
                }

                SequentialAnimation {
                    NumberAnimation {
                        target: dot
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Tokens.durationDots * Geometry.dotVisibleAt
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Geometry.dotEaseIn
                    }
                    PauseAnimation {
                        duration: Tokens.durationDots * (Geometry.dotFadeFrom - Geometry.dotVisibleAt)
                    }
                    // The keyframes from here on take the stylesheet's default timing, ease, which is the base easing.
                    NumberAnimation {
                        target: dot
                        property: "opacity"
                        to: 0
                        duration: Tokens.durationDots * (1 - Geometry.dotFadeFrom)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Tokens.easeBase
                    }
                }
            }
        }
    }

    Body {
        id: words

        x: dots.width / 2 + Geometry.dotRestOffset + Tokens.spaceS
        anchors.verticalCenter: parent.verticalCenter
        visible: Tokens.reducedMotion && text !== ""
        text: dots.text
    }
}
