pragma ComponentBehavior: Bound

import QtQuick
import Rekta
import Settings

// The settings app's window content: the places as a strip along the top (navigation.md, "Pivot"; rekta.css:148–190),
// each place a page of groups in two columns, one on a narrow window. A place change turns like Rekta's, and back goes
// one place back through the places visited (navigation.md, "Places, history and back").
FocusScope {
    id: view

    // The settings the fields show and write; the app opens the gate to all of them.
    required property Layers settings

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
    readonly property var tempoChoices: [
        {
            value: "fast",
            text: "doppelt so schnell"
        },
        {
            value: "rekta",
            text: "wie rekta"
        }
    ]
    readonly property var escapeChoices: [
        {
            value: "close",
            text: "leert die suche und schließt den start"
        },
        {
            value: "back",
            text: "leert die suche, zurück zum ort davor"
        }
    ]
    // The fields of the groups that have any, by group; a group without one says its fields are still to come.
    readonly property var contents: ({
            "fläche": echoField,
            "öffnen und schließen": tempoField,
            "suche": escapeField
        })
    // Why the fields cannot be changed (forms.md, "Disabled controls say why"): the short cause stands beside each
    // control, as Rekta's disabled examples do, and the hint below says cause and remedy in one sentence.
    readonly property string disabledReason: ({
            broken: "datei nicht lesbar",
            newer: "datei zu neu"
        })[settings.fault] ?? ""
    readonly property string problem: ({
            broken: "settings.json ist kein gültiges json. korrigiere oder lösche die datei, dann lässt sich hier wieder etwas ändern.",
            newer: "settings.json stammt von einer neueren rekta-version. aktualisiere rekta, um hier etwas zu ändern."
        })[settings.fault] ?? ""

    // The place whose page shows (or turns in), and the places left behind it, newest last.
    property int shownPlace: 0
    property var trail: []

    signal closeRequested

    function choiceIndex(key: string, choices: var): int {
        return choices.findIndex(choice => choice.value === settings.value(key));
    }

    // The default's words while the setting differs from it, else "".
    function presetWord(key: string, choices: var): string {
        return settings.differs(key) ? (choices.find(choice => choice.value === settings.preset(key))?.text ?? "") : "";
    }

    function echoOn(): bool {
        return settings.value("background") !== "solid";
    }

    // Escape goes back only when nothing nearer wants it, not from a text field (navigation.md, "Places, history and
    // back"); a field takes its Escape itself.
    function goesBack(event: KeyEvent): bool {
        if (event.key === Qt.Key_Escape)
            return KeyLayers.escapeIsFree(view.Window.activeFocusItem);
        return event.key === Qt.Key_Back || (event.key === Qt.Key_Left && (event.modifiers & Qt.AltModifier) !== 0);
    }

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

    // A choice made in a field ends its binding; it comes back, so a refused write shows what the shell has.
    Component {
        id: tempoField

        Setting {
            label: "tempo des start"
            hint: "wie schnell sich der start öffnet und schließt. rekta selbst dreht im vollen tempo."
            problem: view.problem
            presetWord: view.presetWord("startTempo", view.tempoChoices)

            Segments {
                objectName: "startTempo"
                disabledReason: view.disabledReason
                options: view.tempoChoices.map(choice => choice.text)
                currentIndex: view.choiceIndex("startTempo", view.tempoChoices)
                onActivated: index => {
                    view.settings.set("startTempo", view.tempoChoices[index].value);
                    currentIndex = Qt.binding(() => view.choiceIndex("startTempo", view.tempoChoices));
                }
            }
        }
    }

    Component {
        id: escapeField

        Setting {
            label: "escape in der suche"
            hint: "was escape tut, solange du im start suchst."
            problem: view.problem
            presetWord: view.presetWord("searchEscape", view.escapeChoices)

            Select {
                objectName: "searchEscape"
                disabledReason: view.disabledReason
                width: parent.width
                label: "escape in der suche"
                options: view.escapeChoices
                currentIndex: view.choiceIndex("searchEscape", view.escapeChoices)
                onActivated: index => {
                    view.settings.set("searchEscape", view.escapeChoices[index].value);
                    currentIndex = Qt.binding(() => view.choiceIndex("searchEscape", view.escapeChoices));
                }
            }
        }
    }

    Component {
        id: echoField

        Setting {
            hint: "ein blasser abdruck der kacheln unten rechts im hintergrund."
            problem: view.problem
            presetWord: view.settings.differs("background") ? (view.settings.preset("background") === "rekta" ? "an" : "aus") : ""

            Toggle {
                objectName: "echo"
                disabledReason: view.disabledReason
                label: "kachel-echo"
                onWord: "an"
                offWord: "aus"
                checked: view.echoOn()
                onToggled: {
                    view.settings.set("background", checked ? "rekta" : "solid");
                    checked = Qt.binding(() => view.echoOn());
                }
            }
        }
    }

    Component {
        id: comingSoon

        Hint {
            text: "kommt"
        }
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
                        Loader {
                            width: group.width
                            sourceComponent: view.contents[group.modelData] ?? comingSoon
                        }
                    }
                }
            }
        }
    }
}
