pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The settings app's window content: the places as a strip along the top (navigation.md, "Pivot"; rekta.css:148–190),
// each place a page of groups in two columns, one on a narrow window. A place change turns like Rekta's.
FocusScope {
    id: view

    readonly property var places: [
        {
            title: "aussehen",
            groups: ["farben", "fläche"]
        },
        {
            title: "start",
            groups: ["öffnen und schließen", "suche", "angeheftet"]
        },
        {
            title: "sitzung",
            groups: ["problem melden"]
        }
    ]
    readonly property int place: pivot.currentIndex
    // The window's title is the place's, then the app (navigation.md, "Places, history and back").
    readonly property string windowTitle: `${places[place].title} · rekta einstellungen`
    readonly property int columns: width >= Tokens.bpSidewaysScrollMin ? 2 : 1
    // Two columns of two tile units, with the gap between and the pivot's inset on both sides.
    readonly property real minimumWidth: 4 * Tokens.tileUnit + Tokens.spaceL + 2 * Tokens.spaceXl
    readonly property real minimumHeight: 3 * Tokens.tileUnit

    // The page on show; it lags the pivot while a turn runs.
    property int shownPlace: 0

    signal closeRequested

    function showPlace(index: int) {
        if (index === shownPlace)
            return;
        turner.go(pages.itemAt(shownPlace), pages.itemAt(index), {
            back: index < shownPlace
        });
        shownPlace = index;
    }

    // Escape does not close the window: Rekta has no hidden way out. Ctrl+W and the frame do.
    Keys.onPressed: event => {
        if (event.key !== Qt.Key_W || !(event.modifiers & Qt.ControlModifier))
            return;
        closeRequested();
        event.accepted = true;
    }

    PlaceTurn {
        id: turner

        objectName: "turn"
    }

    Pivot {
        id: pivot

        objectName: "pivot"
        focus: true
        x: Tokens.spaceXl
        width: view.width - 2 * Tokens.spaceXl
        level: "nav"
        titles: view.places.map(place => place.title)
        placeWidth: view.width
        viewportHeight: view.height
        onSelected: index => view.showPlace(index)
    }

    Repeater {
        id: pages

        model: view.places

        delegate: Flickable {
            id: page

            required property var modelData
            required property int index
            readonly property real columnWidth: (width - (view.columns - 1) * Tokens.spaceL) / view.columns

            objectName: `page-${index}`
            x: Tokens.spaceXl
            y: pivot.height
            width: view.width - 2 * Tokens.spaceXl
            height: view.height - y
            visible: index === 0
            clip: true
            topMargin: Tokens.spaceL
            bottomMargin: Tokens.spaceL
            contentHeight: grid.height
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Grid {
                id: grid

                columns: view.columns
                columnSpacing: Tokens.spaceL
                rowSpacing: Tokens.spaceL

                Repeater {
                    model: page.modelData.groups

                    delegate: Column {
                        id: group

                        required property string modelData

                        objectName: `group-${modelData}`
                        width: page.columnWidth
                        spacing: Tokens.spaceXs

                        GroupHeading {
                            width: group.width
                            placeWidth: view.width
                            text: group.modelData
                        }
                        Hint {
                            width: group.width
                            text: "kommt"
                        }
                    }
                }
            }
        }
    }
}
