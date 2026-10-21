import QtQuick

// A toggle switch, the Metro way (forms.md, "Inputs"): it acts at once. A square frame, the accent fill growing from
// the leading edge when on, a solid ink bar as the thumb, and the state word beside it.
Item {
    id: toggle

    property bool checked: false
    property string label
    property string onWord: "on"
    property string offWord: "off"
    property string disabledReason
    readonly property bool disabled: disabledReason !== ""
    readonly property color frame: disabled ? Tokens.color.disabled : Tokens.color.textPrimary

    signal toggled

    function activate() {
        if (disabled)
            return;
        checked = !checked;
        toggled();
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(Tokens.controlHeight, row.implicitHeight)
    activeFocusOnTab: true
    Accessible.role: Accessible.Switch
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.name: label
    Accessible.description: disabledReason
    Accessible.onToggleAction: activate()
    Accessible.onPressAction: activate()
    Keys.onSpacePressed: activate()

    TapHandler {
        onTapped: toggle.activate()
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spaceS

        Text {
            objectName: "label"
            anchors.verticalCenter: parent.verticalCenter
            visible: toggle.label !== ""
            // `.rk-toggle-label { margin-right: space-s }` on top of the row's gap (rekta.css:333, :350)
            rightPadding: Tokens.spaceS
            text: toggle.label
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.fontSizeS
            font.weight: Tokens.fontWeightSemibold
            color: toggle.disabled ? Tokens.color.disabled : Tokens.color.textPrimary
        }

        Rectangle {
            id: track

            objectName: "track"
            anchors.verticalCenter: parent.verticalCenter
            width: Geometry.toggleWidth
            height: Geometry.toggleHeight
            color: "transparent"
            border.width: Geometry.toggleBorder
            border.color: toggle.frame

            Rectangle {
                objectName: "fill"
                readonly property real inset: Geometry.toggleBorder + Geometry.togglePadding

                x: inset
                y: inset
                width: toggle.checked ? track.width - 2 * inset - (Geometry.toggleThumb + Geometry.togglePadding) : 0
                height: track.height - 2 * inset
                color: Tokens.color.accent

                Behavior on width {
                    NumberAnimation {
                        duration: Tokens.durationShort
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Tokens.easeBase
                    }
                }
            }

            Rectangle {
                objectName: "thumb"
                x: toggle.checked ? track.width - width : 0
                width: Geometry.toggleThumb
                height: track.height
                color: toggle.frame

                Behavior on x {
                    NumberAnimation {
                        duration: Tokens.durationShort
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Tokens.easeBase
                    }
                }
            }

            FocusRing {
                shown: toggle.activeFocus
            }
        }

        Text {
            id: word

            objectName: "word"
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(implicitWidth, Geometry.toggleWordWidth * font.pixelSize)
            text: toggle.checked ? toggle.onWord : toggle.offWord
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.fontSizeS
            font.weight: Tokens.fontWeightRegular
            // The word keeps its colour when disabled (rekta.css:351 outranks :349).
            color: Tokens.color.textContrastHigh
        }

        Hint {
            objectName: "why"
            anchors.baseline: word.baseline
            visible: toggle.disabled
            text: toggle.disabledReason
        }
    }
}
