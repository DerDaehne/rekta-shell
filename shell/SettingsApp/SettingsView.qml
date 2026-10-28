pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// The settings app's window content: the places as a strip along the top (navigation.md, "Pivot"; rekta.css:148–190),
// each place a page of groups in two columns, one on a narrow window. A place change turns like Rekta's, and back goes
// one place back through the places visited (navigation.md, "Places, history and back").
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
    // The same rule as the pivot's: sideways when wide and tall enough, else compact.
    readonly property int columns: Prefs.sizeClass(width, height) === "sideways" ? 2 : 1
    // Two columns of two tile units, with the gap between and the pivot's inset on both sides.
    readonly property real minimumWidth: 4 * Tokens.tileUnit + Tokens.spaceL + 2 * Tokens.spaceXl
    // Taller than Rekta's short viewport, so the window stays sideways (layout.md, size classes), with a space-xl of
    // margin.
    readonly property real minimumHeight: Tokens.bpShortHeight + Tokens.spaceXl
    // The place whose page shows (or turns in), and the places left behind it, newest last.
    property int shownPlace: 0
    property var trail: []

    signal closeRequested

    function showPlace(index: int) {
        if (index === shownPlace)
            return;
        trail.push(shownPlace);
        turnTo(index, index < shownPlace);
    }

    // Back is one place back, in the order visited; at the top place it does nothing and never closes the window.
    function goBack() {
        if (trail.length === 0)
            return;
        const index = trail.pop();
        pivot.currentIndex = index;
        turnTo(index, true);
    }

    function turnTo(index: int, back: bool) {
        turner.go(pages.itemAt(shownPlace), pages.itemAt(index), {
            back: back
        });
        shownPlace = index;
    }

    function goesBack(event: KeyEvent): bool {
        return event.key === Qt.Key_Escape || event.key === Qt.Key_Back || (event.key === Qt.Key_Left && (event.modifiers & Qt.AltModifier) !== 0);
    }

    // The window is a plain item to its content, so the view takes the keys itself.
    focus: true

    // Escape never closes the window: Rekta has no hidden way out. Ctrl+W and the frame do.
    Keys.onPressed: event => {
        if (goesBack(event))
            goBack();
        else if (event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier))
            closeRequested();
        else
            return;
        event.accepted = true;
    }

    // The mouse's back button.
    TapHandler {
        acceptedButtons: Qt.BackButton
        onTapped: view.goBack()
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
