import QtQuick

// A menu's chevron (rekta.css:1029–1030): a 6px box with a stroke on its top and right edge, turned about its centre.
// The row that carries it sets it aside by moving `x`. It takes the colour of its row's words.
Item {
    property color color: Tokens.color.textPrimary

    implicitWidth: Geometry.chevronSize
    implicitHeight: Geometry.chevronSize

    Rectangle {
        objectName: "top"
        width: parent.width
        height: Geometry.chevronStroke
        color: parent.color
        antialiasing: true
    }

    Rectangle {
        objectName: "right"
        x: parent.width - width
        width: Geometry.chevronStroke
        height: parent.height
        color: parent.color
        antialiasing: true
    }
}
