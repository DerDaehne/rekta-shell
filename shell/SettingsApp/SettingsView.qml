pragma ComponentBehavior: Bound

import QtQuick
import Rekta
import Settings
import "../Panel/LookAndFeel.js" as LookAndFeel

// The settings app's window content: the places as a strip along the top (navigation.md, "Pivot"; rekta.css:240–288),
// each place a page of groups in two columns, one on a narrow window. A place change turns like Rekta's, and back goes
// one place back through the places visited (navigation.md, "Places, history and back").
FocusScope {
    id: view

    // The settings the fields show and write; the app opens the gate to all of them.
    required property Layers settings
    // start.json, which "angeheftet" lists and changes: the app's StartFile.
    required property var startFile
    // The installed apps as the Start lists them, {id, name, icon}; null until they have been read.
    property var apps: null
    // The text of kdeglobals, which names Plasma's pair of light and dark global themes.
    property string kdeglobals
    readonly property alias toaster: toaster
    // A name a row cuts off shows whole as its tip (OverflowTip).
    readonly property bool overflowTips: true
    // Where the lists of its selects and comboboxes float (FloatAnchor).
    readonly property Item floatLayer: floats

    readonly property var places: [
        {
            title: "aussehen",
            groups: ["farben", "fläche"]
        },
        {
            title: "start",
            groups: ["suche", "angeheftet", "zuletzt"]
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
    // The pivot and the pages stand space-xl in sideways and space-m in compact (rekta.css:1154; Panorama.inset).
    readonly property real inset: columns === 2 ? Tokens.spaceXl : Tokens.spaceM
    // Two columns of two tile units, with the gap between and the pivot's inset on both sides.
    readonly property real minimumWidth: 4 * Tokens.tileUnit + Tokens.spaceXl + 2 * Tokens.spaceXl
    // Taller than Rekta's short viewport, so the window stays sideways (layout.md, size classes), with a space-xl of
    // margin.
    readonly property real minimumHeight: Tokens.bpShortHeight + Tokens.spaceXl
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
            "farben": colourFields,
            "fläche": surfaceFields,
            "suche": escapeField,
            "angeheftet": pinnedField,
            "zuletzt": recentField
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

    // What the host runs: Plasma's tool for the colour scheme, a list of words.
    signal run(var command)
    signal closeRequested

    function choiceIndex(key: string, choices: var): int {
        return choices.findIndex(choice => choice.value === settings.value(key));
    }

    // The default's words while the setting differs from it, else "".
    function presetWord(key: string, choices: var): string {
        return settings.differs(key) ? (choices.find(choice => choice.value === settings.preset(key))?.text ?? "") : "";
    }

    // On where the shell takes more contrast: set so, or following a system that asks for it.
    function contrastOn(): bool {
        return Prefs.moreContrastFor(settings.value("contrast"));
    }

    function contrastWord(value: string): string {
        return ({
                more: "an",
                normal: "aus"
            })[value] ?? "wie das system";
    }

    // On where the shell takes less transparency: set so, or following a system that asks for it.
    function transparencyReduced(): bool {
        return Prefs.reducedTransparencyFor(settings.value("transparency"));
    }

    function transparencyWord(value: string): string {
        return ({
                reduce: "an",
                normal: "aus"
            })[value] ?? "wie das system";
    }

    readonly property var themeSteps: ["hell", "dunkel", "schwarz"]
    // The step the shell shows, or the one just chosen while Plasma has not yet switched its scheme.
    readonly property int shownStep: chosenStep >= 0 ? chosenStep : themeStep()
    property int chosenStep: -1

    // The step of the system's scheme and the ground: black counts only while the scheme is dark, as the black ground
    // lies under the dark theme alone (platforms.md:75).
    function themeStep(): int {
        if (Prefs.resolvedTheme === "light")
            return 0;
        return settings.value("ground") === "black" ? 2 : 1;
    }

    // The scheme is Plasma's, the same switch as the panel's "dunkel": the shell follows the system. "schwarz" is the
    // dark scheme on the black ground; the others leave the ground.
    function chooseTheme(step: int) {
        const dark = step !== 0;
        // Against the step already asked for, so a change of mind before Plasma has switched is sent too.
        if (dark !== (shownStep !== 0))
            run(LookAndFeel.command(dark, kdeglobals));
        chosenStep = dark !== (Prefs.resolvedTheme === "dark") ? step : -1;
        settings.set("ground", step === 2 ? "black" : "normal");
    }

    function echoOn(): bool {
        return settings.value("background") === "rekta";
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

    // Open lists and tips take their keys first (the key layers), then the place. Escape never closes the window:
    // Rekta has no hidden way out. Ctrl+W and the frame do.
    Keys.onPressed: event => {
        if (KeyLayers.dispatch(event, Window.activeFocusItem))
            return;
        if (goesBack(event))
            goBack();
        else if (event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier))
            closeRequested();
        else
            return;
        event.accepted = true;
    }

    // The mouse's back button; Qt on Wayland reports every wl_pointer event, the mouse's too, as a TouchPad, never a finger.
    TapHandler {
        acceptedButtons: Qt.BackButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onTapped: view.goBack()
    }

    // A choice made in a field ends its binding; it comes back, so a refused write shows what the shell has.
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

    // Two fields, a default block gap apart (the token space-m).
    Component {
        id: colourFields

        Column {
            spacing: Tokens.spaceM

            Setting {
                width: parent.width
                label: "thema"
                hint: "schwarz legt das dunkle thema auf #000000, für oled-bildschirme; im hellen thema bleibt der eigene grund."
                problem: view.problem
                presetWord: view.settings.differs("ground") ? (view.settings.preset("ground") === "black" ? "schwarz" : "nicht schwarz") : ""

                Segments {
                    objectName: "theme"
                    disabledReason: view.disabledReason
                    options: view.themeSteps
                    currentIndex: view.shownStep
                    onActivated: index => {
                        view.chooseTheme(index);
                        currentIndex = Qt.binding(() => view.shownStep);
                    }
                }
            }

            Setting {
                width: parent.width
                hint: "jeder text hebt sich stärker ab, statuskacheln tragen einen rahmen in ihrer farbe, glas wird deckend."
                problem: view.problem
                presetWord: view.settings.differs("contrast") ? view.contrastWord(view.settings.preset("contrast")) : ""

                Toggle {
                    objectName: "contrast"
                    width: parent.width
                    disabledReason: view.disabledReason
                    label: "mehr kontrast"
                    onWord: "an"
                    offWord: "aus"
                    checked: view.contrastOn()
                    onToggled: {
                        view.settings.set("contrast", checked ? "more" : "normal");
                        checked = Qt.binding(() => view.contrastOn());
                    }
                }
            }
        }
    }

    // Two fields, a default block gap apart (the token space-m).
    Component {
        id: surfaceFields

        Column {
            spacing: Tokens.spaceM

            Setting {
                width: parent.width
                hint: "ein blasser abdruck der kacheln unten rechts im hintergrund."
                problem: view.problem
                presetWord: view.settings.differs("background") ? (view.settings.preset("background") === "rekta" ? "an" : "aus") : ""

                Toggle {
                    objectName: "echo"
                    width: parent.width
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

            Setting {
                width: parent.width
                hint: "glas wird deckend wie der grund, und nichts dahinter verschwimmt."
                problem: view.problem
                presetWord: view.settings.differs("transparency") ? view.transparencyWord(view.settings.preset("transparency")) : ""

                Toggle {
                    objectName: "transparency"
                    width: parent.width
                    disabledReason: view.disabledReason
                    label: "weniger transparenz"
                    onWord: "an"
                    offWord: "aus"
                    checked: view.transparencyReduced()
                    onToggled: {
                        view.settings.set("transparency", checked ? "reduce" : "normal");
                        checked = Qt.binding(() => view.transparencyReduced());
                    }
                }
            }
        }
    }

    Component {
        id: recentField

        Setting {
            hint: "die zuletzt geöffneten dateien als letzter abschnitt im start. ausgeschaltet liest die shell nicht, was du geöffnet hast."
            problem: view.problem
            presetWord: view.settings.differs("showRecent") ? (view.settings.preset("showRecent") ? "an" : "aus") : ""

            Toggle {
                objectName: "showRecent"
                width: parent.width
                disabledReason: view.disabledReason
                label: "zuletzt zeigen"
                onWord: "an"
                offWord: "aus"
                checked: view.settings.value("showRecent")
                onToggled: {
                    view.settings.set("showRecent", checked);
                    checked = Qt.binding(() => view.settings.value("showRecent"));
                }
            }
        }
    }

    Component {
        id: pinnedField

        PinnedApps {
            file: view.startFile
            apps: view.apps
            toaster: view.toaster
        }
    }

    Component {
        id: comingSoon

        Hint {
            text: "kommt"
        }
    }

    // The step stands until Plasma has switched, or for as long as a switch may take.
    Connections {
        target: Prefs

        function onResolvedThemeChanged() {
            view.chosenStep = -1;
        }
    }

    Timer {
        // Plasma applies a global theme in about a second; a refused switch leaves the shown step as the system has it.
        interval: 3000
        running: view.chosenStep >= 0
        onTriggered: view.chosenStep = -1
    }

    PlaceTurn {
        id: turner

        objectName: "turn"
    }

    Pivot {
        id: pivot

        objectName: "pivot"
        focus: true
        x: view.inset
        width: view.width - 2 * view.inset
        level: "nav"
        titles: view.places.map(place => place.title)
        placeWidth: view.width
        viewportHeight: view.height
        onSelected: index => view.showPlace(index)
    }

    // Compact, the strip has a hairline below it across the whole place; sideways it has none (rekta.css:1169–1172, :1533).
    Hairline {
        objectName: "underPivot"
        visible: view.columns === 1
        y: pivot.height
        width: view.width
    }

    Repeater {
        id: pages

        model: view.places

        delegate: Flickable {
            id: page

            required property var modelData
            required property int index
            readonly property real columnWidth: (width - (view.columns - 1) * Tokens.spaceXl) / view.columns

            objectName: `page-${index}`
            x: view.inset
            y: pivot.height + (view.columns === 1 ? Geometry.hairline : 0)
            width: view.width - 2 * view.inset
            height: view.height - y
            visible: index === 0
            clip: true
            contentHeight: grid.height
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Grid {
                id: grid

                columns: view.columns
                // Each group carries its own space-xl above and below (rekta.css:1157); sideways they stand space-xl apart (layout.md:92).
                columnSpacing: Tokens.spaceXl
                rowSpacing: 0

                Repeater {
                    model: page.modelData.groups

                    delegate: Column {
                        id: group

                        required property string modelData
                        required property int index

                        objectName: `group-${modelData}`
                        width: page.columnWidth
                        // A section: space-xl above and below, its title space-l above what follows (layout.md:76–96; rekta.css:1157, :1160).
                        topPadding: Tokens.spaceXl
                        bottomPadding: Tokens.spaceXl
                        spacing: Tokens.spaceL

                        GroupHeading {
                            width: group.width
                            placeWidth: view.width
                            text: group.modelData
                        }
                        Loader {
                            width: group.width
                            sourceComponent: view.contents[group.modelData] ?? comingSoon
                        }

                        // Compact, a hairline parts a stacked section from the one above (layout.md:92; rekta.css:1158, :1527); it stands outside the column's flow.
                        Hairline {
                            objectName: `hairline-${group.modelData}`
                            parent: grid.parent
                            visible: view.columns === 1 && group.index > 0
                            x: grid.x + group.x
                            y: grid.y + group.y
                            width: group.width
                        }
                    }
                }
            }
        }
    }

    // The app has no app bar: its toasts hang from the top centre, as Rekta's do sideways (rekta.css:1189–1203, :1451).
    Toaster {
        id: toaster

        objectName: "toaster"
        width: view.width
        hangsFromTop: true
        undoWord: "rückgängig"
    }

    // The lists of its selects and comboboxes, over everything but the tip.
    Item {
        id: floats

        objectName: "floats"
        anchors.fill: parent
        z: Tokens.layerFloat
    }

    // The tip of any control in the window, over everything.
    Tooltip {
        readonly property var place: target ? Placement.tip(parent.mapFromItem(target, 0, 0, target.width, target.height), Qt.size(width, height), area) : null

        objectName: "tip"
        area: Qt.size(view.width, view.height)
        x: place?.x ?? 0
        y: place?.y ?? 0
        side: place?.side ?? "above"
    }
}
