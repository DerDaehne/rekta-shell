import QtQuick

// A picture in the icon's 20px field, cropped square and keeping its colours: a sender's own picture (an avatar, an
// album cover) or another program's icon (states.md:92–98, rekta.css:1192–1193). Its corners are the tile's, a
// deliberate deviation from Rekta's square crop: a ring in the ground it stands on, whose inner edge is the picture's
// rounded outline (its radius is the outer radius less the ring's width).
Item {
    id: picture

    property alias source: image.source
    readonly property alias status: image.status
    // What it stands on, which the ring is drawn in.
    property color ground: Tokens.color.bg

    implicitWidth: Geometry.iconSize
    implicitHeight: Geometry.iconSize

    Image {
        id: image

        objectName: "image"
        anchors.fill: parent
        sourceSize: Qt.size(width, height)
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        objectName: "corners"
        anchors.centerIn: parent
        width: picture.width + 2 * Tokens.radiusTile
        height: width
        color: "transparent"
        radius: 2 * Tokens.radiusTile
        border.width: Tokens.radiusTile
        border.color: picture.ground
    }
}
