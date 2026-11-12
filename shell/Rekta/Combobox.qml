pragma ComponentBehavior: Bound

import QtQuick

// One of many from a long list, or one to search (forms.md:28; rekta.js combobox(), :4258–4263): a field with the
// combobox's chevron at its end, and a list that floats below it like a menu (states.md, "Floating surfaces"). Typing
// filters the list as the Start's search does, the focus staying in the field. ↓ or Alt+↓ opens, ↑ ↓ move around the
// list, Enter chooses, Escape closes and then clears, and never goes further while there is something to close or
// clear (forms.md:71–75). A press on the field opens, on an option chooses, outside closes. It keeps only a choice from
// its list: leaving it with other text puts the last choice back, leaving it empty takes the choice away. The chosen
// option carries a tick without a box; the chevron points up while the list is open (forms.md:76–84). Disabled, it
// greys, stays focusable and says why below it.
Item {
    id: combo

    // Each { label, value }, with a key hint (`hint`), more words the filter matches (`keywords`) and why it cannot be
    // chosen now (`disabledReason`) where it has them.
    property var options: []
    // What it chooses, for the screen reader.
    property string label
    property string placeholder
    property string disabledReason
    readonly property bool disabled: disabledReason !== ""
    // The option chosen, or null; take() sets it with its words.
    property var chosen: null
    readonly property var value: chosen ? chosen.value : undefined
    readonly property bool expanded: list.open
    // The option of `shown` the keys are on, -1 for none.
    property int active: -1
    readonly property string query: input.text.trim()
    // The chosen option's own words filter nothing.
    readonly property bool filtering: query !== "" && query !== (chosen?.label ?? "")
    readonly property var shown: Match.ranked(options, option => Match.score(option.label, option.keywords ?? "", filtering ? query : ""))
    // The list's sentence when nothing matches what was typed, and when there is nothing to choose; the host sets their
    // language (states.md:12).
    property var noMatch: typed => `Nothing matches “${typed}”.`
    property string nothingYet: "Nothing to choose yet."
    // The option last said to the screen reader while the list is open; as with aria-activedescendant (rekta.js:4320),
    // the same option set again is not said again.
    property var said: null

    // A choice made here: the chosen option's value, or null once its words are cleared.
    signal activated(var value)
    // The words just said to the screen reader.
    signal announced(string words)

    function open() {
        if (disabled || list.open)
            return;
        list.open = true;
        markStart();
        place();
    }

    function close() {
        list.open = false;
        said = null;
    }

    // Empties the field and the choice, such as after the choice has been acted on.
    function clear() {
        close();
        take(null);
    }

    function take(option: var) {
        chosen = option;
        input.text = option?.label ?? "";
    }

    function choose(index: int) {
        const option = shown[index];
        if (!option || option.disabledReason)
            return;
        take(option);
        close();
        activated(option.value);
    }

    // The keys start on the best match while filtering, else on the chosen option.
    function markStart() {
        mark(filtering ? 0 : shown.findIndex(option => option.value === combo.value));
    }

    function mark(index: int) {
        active = shown.length > 0 ? Math.max(-1, Math.min(index, shown.length - 1)) : -1;
        Qt.callLater(revealActive);
    }

    function revealActive() {
        const row = optionRows()[active];
        if (!row)
            return;
        list.reveal(row);
        if (shown[active] !== said)
            announce(row.spoken);
        said = shown[active];
    }

    // Qt has no active descendant and the focus stays in the field, so the active option is said instead.
    function announce(words: string) {
        Accessible.announce(words, Accessible.Polite);
        announced(words);
    }

    function optionRows(): var {
        return Array.from(list.rows).filter(row => row instanceof MenuItem);
    }

    function rowIndexAt(position: point): int {
        return optionRows().indexOf(listColumn().childAt(position.x, position.y));
    }

    function listColumn(): Item {
        return list.rows[0]?.parent ?? null;
    }

    // Without a choice of its own in the field, leaving it keeps only a choice from the list (rekta.js:4342–4348).
    function settle() {
        if (query === "") {
            if (chosen)
                activated(null);
            take(null);
            return;
        }
        if (query === chosen?.label)
            return;
        const exact = options.find(option => !option.disabledReason && option.label.toLowerCase() === query.toLowerCase());
        if (exact) {
            take(exact);
            activated(exact.value);
        } else {
            take(chosen);
        }
    }

    // The list is open only while the focus is in the field, so its keys come here before any key layer. Untyped, so a
    // test can hand it a key.
    function handleKey(event: var): bool {
        const wrap = shown.length;
        switch (event.key) {
        case Qt.Key_Down:
            if (list.open)
                mark(active + 1 >= wrap ? 0 : active + 1);
            else
                open();
            return true;
        case Qt.Key_Up:
            if (list.open)
                mark(active <= 0 ? wrap - 1 : active - 1);
            return list.open;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (list.open)
                choose(active);
            return list.open;
        case Qt.Key_Escape:
            return closeOrClear();
        }
        return false;
    }

    // Disabled, it changes nothing and lets the key go on.
    function closeOrClear(): bool {
        if (disabled)
            return false;
        if (list.open) {
            close();
            return true;
        }
        if (input.text === "")
            return false;
        input.text = "";
        settle();
        return true;
    }

    // In the window's coordinates, as a floating surface is placed.
    function place() {
        if (!list.open || list.parent === combo)
            return;
        const at = box.mapToItem(list.parent, 0, 0);
        const spot = Placement.float(Qt.rect(at.x, at.y, box.width, box.height), Qt.size(list.width, list.height), list.area);
        list.x = spot.x;
        list.y = spot.y;
        list.side = spot.side;
    }

    function holds(scenePosition: point): bool {
        return box.contains(box.mapFromItem(null, scenePosition)) || list.contains(list.mapFromItem(null, scenePosition));
    }

    implicitHeight: disabled ? why.y + why.height : box.height
    onVisibleChanged: {
        if (!visible)
            close();
    }
    onShownChanged: {
        if (list.open)
            markStart();
    }

    Rectangle {
        id: box

        objectName: "box"
        width: combo.width
        height: Tokens.controlHeight
        radius: Tokens.radiusS
        color: Tokens.color.bg
        border.width: Geometry.inputBorder
        // Hover only with a pointer that hovers (rekta.css:1335).
        border.color: {
            if (combo.disabled)
                return Tokens.color.disabled;
            return input.activeFocus || pointer.hovered ? Tokens.color.textPrimary : Tokens.color.textContrastMedium;
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Tokens.durationShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeBase
            }
        }

        HoverHandler {
            id: pointer
        }

        TextInput {
            id: input

            objectName: "input"
            anchors.fill: parent
            leftPadding: Geometry.inputPadding
            rightPadding: Geometry.comboPaddingEnd
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            readOnly: combo.disabled
            activeFocusOnTab: true
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.fontSizeS
            color: combo.disabled ? Tokens.color.disabled : Tokens.color.textPrimary
            selectionColor: Tokens.color.accent
            selectedTextColor: Tokens.color.textOnAccent
            Accessible.role: Accessible.ComboBox
            Accessible.name: combo.label
            Accessible.description: combo.disabledReason
            Accessible.editable: true

            Keys.onPressed: event => event.accepted = combo.handleKey(event)
            onTextEdited: combo.open()
            onActiveFocusChanged: {
                if (activeFocus)
                    return;
                combo.close();
                combo.settle();
            }

            ExpandedState {
                target: input
                expanded: list.open
            }

            // Before the input takes the press, so a press that places the caret opens the list too.
            TapHandler {
                longPressThreshold: 0

                onTapped: combo.open()
            }

            Text {
                objectName: "placeholder"
                anchors.fill: parent
                leftPadding: input.leftPadding
                verticalAlignment: Text.AlignVCenter
                visible: input.text === ""
                text: combo.placeholder
                font: input.font
                color: Tokens.color.textContrastMedium
            }
        }

        // `.rk-combo-btn`: out of the focus order and unheard, a press on it opens or closes the list and puts the focus
        // in the field (rekta.js:4274, :4360, :4367).
        Rectangle {
            objectName: "button"
            x: box.width - Geometry.inputBorder - width
            y: Geometry.inputBorder
            width: Geometry.comboButton
            height: box.height - 2 * Geometry.inputBorder
            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: Tokens.radiusS
            bottomRightRadius: Tokens.radiusS
            color: buttonPointer.hovered && !combo.disabled ? Tokens.color.hover : "transparent"

            Chevron {
                objectName: "chevron"
                // A turned box whose diagonal spans the chevron's width.
                width: Geometry.comboChevronWidth / Math.SQRT2
                height: width
                x: Geometry.comboChevronStart + (Geometry.comboChevronWidth - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                rotation: list.open ? Geometry.chevronOnTurn - 90 : Geometry.chevronOnTurn + 90
                color: combo.disabled ? Tokens.color.disabled : Tokens.color.textPrimary
                // Turned about its centre, the arms lie on the side the point is on; half the chevron's height back
                // centres it, as Rekta draws it.
                transform: Translate {
                    y: (list.open ? 1 : -1) * Geometry.comboChevronWidth / 4
                }
            }

            HoverHandler {
                id: buttonPointer

                cursorShape: combo.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
            }

            // Holds the press, so the field under it does not open the list again.
            TapHandler {
                gesturePolicy: TapHandler.WithinBounds
                longPressThreshold: 0

                onTapped: {
                    input.forceActiveFocus();
                    if (list.open)
                        combo.close();
                    else
                        combo.open();
                }
            }
        }

        FocusRing {
            shown: input.activeFocus
        }
    }

    Hint {
        id: why

        objectName: "why"
        y: box.height + Tokens.spaceXs
        width: combo.width
        visible: combo.disabled
        text: combo.disabledReason
    }

    // Just under the list, over everything else: sees a press anywhere without taking it.
    Item {
        parent: list.parent
        anchors.fill: parent
        z: list.z - 1
        visible: list.open

        PointHandler {
            onActiveChanged: {
                if (active && !combo.holds(point.scenePosition))
                    combo.close();
            }
        }
    }

    // A scroller moving the field moves the list with it.
    Connections {
        target: list.open ? Reveal.scrollerOf(combo) : null
        ignoreUnknownSignals: true

        function onContentYChanged() {
            combo.place();
        }
    }

    // Above everything in its window, as wide as the field at least (rekta.js:4324).
    FloatSurface {
        id: list

        objectName: "list"
        parent: combo.Window.window?.contentItem ?? combo
        width: Math.max(implicitWidth, combo.width)
        height: implicitHeight
        Accessible.role: Accessible.List
        Accessible.name: combo.label

        onWidthChanged: combo.place()
        onHeightChanged: combo.place()
        onAreaChanged: combo.place()

        Empty {
            objectName: "empty"
            x: Tokens.spaceM
            width: parent.width - 2 * Tokens.spaceM
            visible: combo.shown.length === 0
            // `.rk-float` sets the compact line height (rekta.css:1007).
            lineHeightFactor: Tokens.lineHeightCompact
            text: combo.filtering ? combo.noMatch(combo.query) : combo.nothingYet
        }

        Repeater {
            model: combo.shown

            MenuItem {
                required property var modelData
                required property int index

                objectName: "option"
                kind: "option"
                text: modelData.label
                keyHint: modelData.hint ?? ""
                disabledReason: modelData.disabledReason ?? ""
                checked: combo.chosen !== null && modelData.value === combo.value
                active: index === combo.active
            }
        }

        // Declared here they land in the rows' column, so they find their row; neither takes the focus from the field.
        TapHandler {
            longPressThreshold: 0

            onTapped: eventPoint => combo.choose(combo.rowIndexAt(eventPoint.position))
        }

        HoverHandler {
            onPointChanged: {
                const index = combo.rowIndexAt(point.position);
                if (index >= 0)
                    combo.mark(index);
            }
        }
    }
}
