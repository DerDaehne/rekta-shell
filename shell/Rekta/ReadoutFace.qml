import QtQuick

// What a short display shows, in one line as Rekta's own indicator in the bar (site.js:924–936, site.css:175): its
// icon, the meter a tile unit wide (rekta.css:852–854) and the value, medium in tabular figures, at least 4ch wide and
// end-aligned (rekta.css:1233), space-s apart within the padding of the control it stands in for. Without a level the
// icon and the value alone. The word is only heard. Laid out by hand: a Row would size itself only at polish.
Item {
    id: face

    property string icon
    // 0 to 1, or -1 to show `valueText` alone.
    property real level: -1
    property string valueText
    readonly property bool metered: level >= 0
    readonly property real meterX: glyph.x + glyph.width + Tokens.spaceS
    readonly property real valueX: metered ? meterX + meter.width + Tokens.spaceS : meterX

    implicitWidth: valueX + value.width + Geometry.appBarControlPadding
    implicitHeight: Geometry.appBarControl

    Icon {
        id: glyph

        objectName: "icon"
        x: Geometry.appBarControlPadding
        anchors.verticalCenter: parent.verticalCenter
        name: face.icon
        size: Geometry.appBarGlyph
    }

    MeterTrack {
        id: meter

        objectName: "meter"
        visible: face.metered
        x: face.meterX
        anchors.verticalCenter: parent.verticalCenter
        width: Tokens.tileUnit
        value: face.level
    }

    TextRole {
        id: value

        objectName: "value"
        x: face.valueX
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(implicitWidth, Geometry.levelValueMinChars * zero.advanceWidth)
        horizontalAlignment: Text.AlignRight
        text: face.valueText
        font.pixelSize: Tokens.fontSizeXs
        font.weight: Tokens.fontWeightMedium
        font.features: ({ "tnum": 1 })
        color: Tokens.color.textPrimary
    }

    // CSS's `ch`: the advance of the digit zero in the value's own font.
    TextMetrics {
        id: zero

        font: value.font
        text: "0"
    }
}
