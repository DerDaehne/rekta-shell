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
    // Set false, the dots are gone but keep their room; set again, they fly in from the start.
    property bool running: true

    // As tall as a dot while they fly (`.rk-dots { height: 4px }`, rekta.css:728), as the words when they stand.
    implicitHeight: Tokens.reducedMotion ? Math.max(Geometry.dotSize, words.implicitHeight) : Geometry.dotSize
    Accessible.role: Accessible.ProgressBar
    Accessible.name: text

    Repeater {
        model: dots.running ? Geometry.dotCount : 0

        delegate: Rectangle {
            id: dot

            required property int index
            // Where the dot is on its flight, as a share of the width.
            property real position: Tokens.dotsFrom
            property bool launched: false

            width: Geometry.dotSize
            height: Geometry.dotSize
            y: (dots.height - height) / 2
            x: Tokens.reducedMotion ? dots.width / 2 - Geometry.dotRestOffset + dot.index * Geometry.dotRestSpacing : dot.position * dots.width
            color: dots.ink
            opacity: Tokens.reducedMotion ? 1 : 0

            Timer {
                interval: dot.index * Tokens.durationDots * Tokens.dotsStagger
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
                        from: Tokens.dotsFrom
                        to: Tokens.dotsMiddleStart
                        duration: Tokens.durationDots * Tokens.dotsMiddleStartAt
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Tokens.dotsEaseArrive
                    }
                    NumberAnimation {
                        target: dot
                        property: "position"
                        to: Tokens.dotsMiddleEnd
                        duration: Tokens.durationDots * (Tokens.dotsMiddleEndAt - Tokens.dotsMiddleStartAt)
                    }
                    NumberAnimation {
                        target: dot
                        property: "position"
                        to: Tokens.dotsTo
                        duration: Tokens.durationDots * (1 - Tokens.dotsMiddleEndAt)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Tokens.dotsEaseLeave
                    }
                }

                SequentialAnimation {
                    NumberAnimation {
                        target: dot
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Tokens.durationDots * Tokens.dotsWholeAt
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Tokens.dotsEaseArrive
                    }
                    PauseAnimation {
                        duration: Tokens.durationDots * (Tokens.dotsFadeAt - Tokens.dotsWholeAt)
                    }
                    // The keyframes from here on take the stylesheet's default timing, ease, which is the base easing.
                    NumberAnimation {
                        target: dot
                        property: "opacity"
                        to: 0
                        duration: Tokens.durationDots * (1 - Tokens.dotsFadeAt)
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
        visible: dots.running && Tokens.reducedMotion && text !== ""
        text: dots.text
    }
}
