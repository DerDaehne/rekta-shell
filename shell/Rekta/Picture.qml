import QtQuick

// A picture in the icon's 20px field, cropped square and keeping its colours: a sender's own picture (an avatar, an
// album cover) or another program's icon (states.md:92–98, rekta.css:1192–1193). One smaller than the field is never
// stretched up: it stands at its own size in the field's middle (shell.md:42–46). Its corners are the tile's, a
// deliberate deviation from Rekta's square crop: a ring in the ground it stands on, whose inner edge is the picture's
// rounded outline (its radius is the outer radius less the ring's width).
Item {
    id: picture

    property alias source: own.source
    readonly property alias status: own.status
    // What it stands on, which the ring is drawn in.
    property color ground: Tokens.color.bg
    // Smaller on both sides, it came at its own size; at the field's size it may have been loaded down to it.
    readonly property bool fits: own.ownWidth < width && own.ownHeight < height

    implicitWidth: Geometry.iconSize
    implicitHeight: Geometry.iconSize

    PictureIcon {
        id: own

        anchors.fill: parent
        visible: picture.fits
    }

    // ponytail: one that reaches the field's size on one side only is cropped too, its shorter side stretched up;
    // sparing it needs the picture's own size, which loading it down to the field loses.
    Image {
        objectName: "image"
        anchors.fill: parent
        source: own.status === Image.Ready && !picture.fits ? own.source : ""
        sourceSize: Qt.size(width, height)
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        objectName: "corners"
        anchors.centerIn: parent
        width: (picture.fits ? own.ownWidth : picture.width) + 2 * Tokens.radiusTile
        height: (picture.fits ? own.ownHeight : picture.height) + 2 * Tokens.radiusTile
        color: "transparent"
        radius: 2 * Tokens.radiusTile
        border.width: Tokens.radiusTile
        border.color: picture.ground
    }
}
