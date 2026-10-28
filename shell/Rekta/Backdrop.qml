pragma ComponentBehavior: Bound

import QtQuick

// The backdrop of one screen: the colour `bg` (colour.md:3–8), and, unless it is to stay plain, the echo in the bottom
// right corner, `space-xl` from the right edge and from the top of the app bar.
Rectangle {
    id: backdrop

    // Only `bg`, without the echo.
    property bool solid: false

    color: Tokens.color.bg

    Loader {
        active: !backdrop.solid

        sourceComponent: Echo {
            objectName: "echo"
            x: backdrop.width - Tokens.spaceXl - width
            y: backdrop.height - Tokens.appbarHeight - Tokens.spaceXl - height
        }
    }
}
