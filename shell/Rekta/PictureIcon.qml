import QtQuick

// Another program's icon as a picture in its field, 20px in rows and menus, never stretched up (shell.md:42–46). One
// smaller than the field stands at its own size in the field's middle, where Rekta's stylesheet places a picture in its
// box (rekta.css:585); a larger one is fitted into the field, its proportions kept. Its own size counts in logical px,
// as a picture's pixels count on the web.
Item {
    id: field

    property alias source: picture.source
    readonly property alias status: picture.status
    // Qt loads an image provider's picture at the window's pixel ratio once sourceSize is set and divides its size by
    // that ratio; any other raster picture keeps its own pixels (QQuickImageBase::loadPixmap).
    readonly property real loadedRatio: picture.source.toString().startsWith("image:") ? (Window.window?.devicePixelRatio ?? 1) : 1
    // As loaded: a picture larger than the field may already come down to the field's size.
    readonly property real ownWidth: picture.implicitWidth * loadedRatio
    readonly property real ownHeight: picture.implicitHeight * loadedRatio
    readonly property real shrink: Math.min(1, width / ownWidth, height / ownHeight)

    implicitWidth: Geometry.iconSize
    implicitHeight: Geometry.iconSize

    Image {
        id: picture

        objectName: "picture"
        anchors.centerIn: parent
        width: field.ownWidth * field.shrink
        height: field.ownHeight * field.shrink
        sourceSize: Qt.size(field.width, field.height)
    }
}
