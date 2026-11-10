pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// One of many from a list you know (forms.md, "Inputs"; rekta.css:388–403, :435–440): a field's box with the chosen
// option, cut where it is too long, and a caret pointing down at its end. ↓, Alt+↓, Enter, Space or a press expand it in
// place, like Metro's list picker: the box grows to hold every option as a row and pushes what stands below it down;
// nothing floats. Expanded, the box is a list as `select.rk-input[multiple]` is (rekta.css:439): no caret, space-xs
// above and below the rows. The chosen option takes the accent like any Metro selection (rekta.css:949–951); the row
// the keys are on looks focused while the focus stays on the select, as a combobox's active option does (rekta.css:463,
// :967). ↑ ↓ Home End move, Enter or Space chooses and Escape collapses without a change; a press on an option chooses
// it. It unfolds and folds as a tree branch does (motion.md, "Tree branch"; rekta.js:3336, :3339) and keeps itself in
// view in the scroller it stands in. Disabled, the box greys, stays focusable and says why below it.
Item {
    id: select

    // Each with its text and value.
    property var options: []
    property int currentIndex: -1
    readonly property var currentValue: options[currentIndex]?.value
    readonly property string currentText: options[currentIndex]?.text ?? ""
    // What it chooses, for the screen reader.
    property string label
    property string disabledReason
    readonly property bool disabled: disabledReason !== ""
    property bool expanded: false
    // The option the keys are on while it is expanded.
    property int highlighted: -1
    // Runs from 0 to 1 as it unfolds, and back as it folds.
    property real unfolded: 0
    readonly property real expandedHeight: 2 * Geometry.inputBorder + 2 * Tokens.spaceXs + options.length * Tokens.rowHeight
    property var removeEscapeLayer: () => {}

    // A choice made here.
    signal activated(int index)

    // The keys start on the chosen option.
    function expand(): bool {
        if (disabled || options.length === 0)
            return false;
        highlighted = Math.max(0, currentIndex);
        expanded = true;
        folding.stop();
        unfolding.start();
        return true;
    }

    function collapse() {
        if (!expanded)
            return;
        expanded = false;
        unfolding.stop();
        folding.start();
    }

    function choose(index: int) {
        if (index < 0 || index >= options.length || index === currentIndex)
            return;
        currentIndex = index;
        activated(index);
    }

    // Choosing collapses it, choosing the chosen option too.
    function pick(index: int) {
        collapse();
        choose(index);
    }

    // Untyped, so a test can hand it a held key; a held key opens or chooses only once.
    function handleKey(event: var): bool {
        const choosing = [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key);
        if (!expanded)
            return !event.isAutoRepeat && (choosing || event.key === Qt.Key_Down) && expand();
        if (choosing) {
            if (!event.isAutoRepeat)
                pick(highlighted);
            return true;
        }
        const last = options.length - 1;
        const moves = new Map([[Qt.Key_Down, Math.min(last, highlighted + 1)], [Qt.Key_Up, Math.max(0, highlighted - 1)], [Qt.Key_Home, 0], [Qt.Key_End, last]]);
        if (moves.has(event.key))
            highlighted = moves.get(event.key);
        else if (event.key === Qt.Key_Escape)
            collapse();
        else
            return false;
        return true;
    }

    // Expanded by a pointer it holds no focus, yet Escape folds it before anything behind it sees the key, as a
    // combobox's list is closed first; a sheet or menu over it is nearer (navigation.md, "Who gets a key"). Untyped,
    // so a test can hand it a key.
    function foldOnEscape(event: var, focusItem: Item): bool {
        if (!expanded || event.key !== Qt.Key_Escape || KeyLayers.surfaces.length > 0 || focusItem?.Window.window !== Window.window)
            return false;
        collapse();
        return true;
    }

    implicitHeight: disabled ? why.y + why.height : box.height
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: `${label} ${currentText}`.trim()
    Accessible.description: disabledReason

    ExpandedState {
        target: select
        expanded: select.expanded
    }

    // Out of sight it folds at once, so it comes back collapsed.
    onVisibleChanged: {
        if (visible)
            return;
        collapse();
        folding.complete();
    }
    // Focus the keyboard gives shows the whole of a cut choice at once; focus a pointer gave does not (`:focus-visible`,
    // rekta.js:3081). Expanded, the focus stays here and the keys only move the highlight.
    onActiveFocusChanged: {
        if (activeFocus && !ring.hiddenByHost)
            choiceTip.show();
        else
            Tips.leave(choice);
        if (!activeFocus)
            collapse();
    }
    Keys.onPressed: event => event.accepted = handleKey(event)
    Component.onCompleted: removeEscapeLayer = KeyLayers.on(40, (event, focusItem) => foldOnEscape(event, focusItem))
    Component.onDestruction: removeEscapeLayer()

    NumberAnimation {
        id: unfolding

        objectName: "unfolding"
        target: select
        property: "unfolded"
        to: 1
        duration: Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
    }

    NumberAnimation {
        id: folding

        objectName: "folding"
        target: select
        property: "unfolded"
        to: 0
        duration: Geometry.branchCloseShare * Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeOut
    }

    Rectangle {
        id: box

        objectName: "box"
        width: select.width
        height: Tokens.controlHeight + select.unfolded * (select.expandedHeight - Tokens.controlHeight)
        radius: Tokens.radiusS
        color: Tokens.color.bg
        border.width: Geometry.inputBorder
        // Hover only with a pointer that hovers (rekta.css:1335).
        border.color: {
            if (select.disabled)
                return Tokens.color.disabled;
            return select.activeFocus || pointer.hovered ? Tokens.color.textPrimary : Tokens.color.textContrastMedium;
        }

        onHeightChanged: {
            if (select.expanded)
                Reveal.intoView(select, box.height);
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Tokens.durationShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeBase
            }
        }

        Item {
            objectName: "folded"
            width: box.width
            height: Tokens.controlHeight
            opacity: 1 - select.unfolded

            Text {
                id: choice

                objectName: "chosen"
                x: Geometry.inputPadding
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, box.width - Geometry.inputPadding - Geometry.selectPaddingEnd)
                text: select.currentText
                elide: Text.ElideRight
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.fontSizeS
                color: select.disabled ? Tokens.color.disabled : Tokens.color.textPrimary

                // Expanded, the options stand over it.
                OverflowTip {
                    id: choiceTip

                    enabled: !select.expanded
                }
            }

            // Drawn in the padding box, as a background is.
            Shape {
                objectName: "caret"
                x: box.width - box.border.width - Geometry.selectCaretEnd - width
                y: Math.round(box.border.width + Geometry.selectCaretDown * (parent.height - 2 * box.border.width - height))
                width: 2 * Geometry.selectCaretHalf
                height: Geometry.selectCaretHalf
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "transparent"
                    fillColor: select.disabled ? Tokens.color.disabled : Tokens.color.textPrimary
                    startX: 0
                    startY: 0

                    PathLine {
                        x: 2 * Geometry.selectCaretHalf
                        y: 0
                    }

                    PathLine {
                        x: Geometry.selectCaretHalf
                        y: Geometry.selectCaretHalf
                    }
                }
            }
        }

        // Inside the border, cut to the box as it grows.
        Item {
            anchors.fill: parent
            anchors.margins: box.border.width
            clip: true
            opacity: select.unfolded
            visible: select.unfolded > 0

            Item {
                id: rows

                objectName: "options"
                y: Tokens.spaceXs
                width: parent.width
                height: select.options.length * Tokens.rowHeight

                Repeater {
                    model: select.options

                    Item {
                        id: option

                        required property var modelData
                        required property int index
                        readonly property bool chosen: index === select.currentIndex
                        readonly property bool keyed: index === select.highlighted && select.activeFocus

                        objectName: "option"
                        // Placed by hand: a Column lays out only once its rows are in sight, a frame late.
                        y: index * Tokens.rowHeight
                        width: rows.width
                        height: Tokens.rowHeight
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData.text
                        Accessible.selected: chosen

                        Rectangle {
                            objectName: "fill"
                            anchors.fill: parent
                            visible: option.chosen
                            color: Tokens.color.accent
                        }

                        // Over the fill (rekta.css:1339), and on the row the keys are on (rekta.css:463).
                        Rectangle {
                            objectName: "tint"
                            anchors.fill: parent
                            visible: option.keyed || rowPointer.hovered
                            color: Tokens.color.hover
                        }

                        Text {
                            objectName: "label"
                            // Where the collapsed box has its text.
                            x: Geometry.inputPadding - Geometry.inputBorder
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, option.width - 2 * x)
                            text: option.modelData.text
                            elide: Text.ElideRight
                            font.family: Tokens.fontSans
                            font.pixelSize: Tokens.fontSizeS
                            color: option.chosen ? Tokens.color.textOnAccent : Tokens.color.textPrimary

                            OverflowTip {}
                        }

                        FocusRing {
                            objectName: "ring"
                            onFill: option.chosen
                            ink: Tokens.color.textOnAccent
                            offset: option.chosen ? -Geometry.focusRingInsetOnChosenRow : -Geometry.focusRingInsetInRow
                            shown: option.keyed
                        }

                        HoverHandler {
                            id: rowPointer

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            longPressThreshold: 0

                            onTapped: select.pick(option.index)
                        }
                    }
                }
            }
        }

        FocusRing {
            id: ring

            objectName: "ring"
            shown: select.activeFocus
        }

        // A press gives no focus, so the ring shows only for the keyboard, like :focus-visible.
        TapHandler {
            enabled: !select.expanded
            // A slow click is still a click.
            longPressThreshold: 0

            onTapped: select.expand()
        }

        HoverHandler {
            id: pointer

            cursorShape: select.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
        }
    }

    Hint {
        id: why

        objectName: "why"
        y: box.height + Tokens.spaceXs
        width: select.width
        visible: select.disabled
        text: select.disabledReason
    }
}
