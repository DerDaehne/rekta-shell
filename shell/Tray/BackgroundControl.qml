import QtQuick
import Rekta

// "im hintergrund N" in the app bar: a glyph, the word and the number of apps (navigation.md, "App bar"), opening the menu
// of the background apps. With no app in the background the control is gone from the bar until one comes. The number
// changes in place: nothing moves when an app comes or goes.
AppBarButton {
    id: background

    property var apps: []
    property alias opener: list.opener
    property alias area: list.area
    readonly property alias menu: list

    icon: "window"
    text: `im hintergrund ${apps.length}`
    present: apps.length > 0
    onClicked: {
        if (list.open)
            list.close(true);
        else
            list.openAt(0);
    }

    TrayMenu {
        id: list

        control: background
        apps: background.apps
    }
}
