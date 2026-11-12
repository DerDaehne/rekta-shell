pragma ComponentBehavior: Bound

import QtQuick
import Rekta

// One pinned app in "angeheftet", a row on a hairline at the density's row height (rekta.css:73–75, :625–635): the
// grip, the app's 20px icon, its name, cut with its whole as a tip, its size as a select, and a quiet "lösen" at the
// end (collections.md:164–166). An app that is not installed shows its id, and "nicht installiert" beside it. Delete
// anywhere in the row, or pulling the row towards the trailing edge, unpin it too; a pull starts never on a control,
// and with a finger never within space-l of the window's edge (rekta.js:3487ff.). Let go past half its width the row
// leaves, else it glides back. A row leaves drifting 12px and fading over 0.6 × duration-short, and arrives 6px from
// above, fading in over duration-short (motion.md:24–25).
SortableRow {
    id: row

    required property PinnedApps group
    required property string key
    required property string appId
    required property string title
    required property string icon
    required property bool missing
    // "‹columns›×‹rows›".
    required property string size
    // The four sizes, and a size written by hand as one more, only in its own row.
    readonly property var sizeOptions: group.sizes.some(option => option.value === size) ? group.sizes : [...group.sizes, {
            value: size,
            text: size
        }]
    // How far a pointer has pulled it towards the trailing edge.
    property real pulled: 0
    // From 0 to 1 as it leaves, and from 1 to 0 as it arrives.
    property real leaving: 0
    property real arriving: 0
    readonly property bool going: leaving > 0 || goingOut.running
    // A hairline row holds its controls space-s from its hairlines (rekta.css:74), at least the density's row height.
    readonly property real lineHeight: Math.max(Tokens.rowHeight, Tokens.controlHeight + 2 * Tokens.spaceS)

    function arrive() {
        arriving = 1;
        comingIn.restart();
    }

    function leave() {
        if (going)
            return;
        glidingBack.stop();
        goingOut.start();
    }

    function letGo() {
        if (pulled > Geometry.rowPullAway * width)
            row.group.remove(row);
        else
            glidingBack.start();
    }

    // "grip", "size" or "remove": the part that holds the focus, "" for none.
    function partWithFocus(): string {
        const focused = Window.activeFocusItem;
        if (sizeSelect.activeFocus)
            return "size";
        if (remove.activeFocus)
            return "remove";
        return holds(focused) ? "grip" : "";
    }

    function focusPart(part: string) {
        ({
                size: sizeSelect,
                remove: remove
            }[part] ?? grip).forceActiveFocus(Qt.TabFocusReason);
    }

    name: title
    disabledReason: group.disabledReason
    opacity: (1 - leaving) * (1 - arriving)
    transform: Translate {
        x: row.pulled + row.leaving * Geometry.rowLeaveDrift
        y: -row.arriving * Geometry.rowEnterShift
    }

    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Delete)
            return;
        event.accepted = true;
        row.group.remove(row);
    }

    NumberAnimation {
        id: comingIn

        target: row
        property: "arriving"
        to: 0
        duration: Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeIn
    }

    NumberAnimation {
        id: goingOut

        objectName: "goingOut"
        target: row
        property: "leaving"
        to: 1
        duration: Geometry.rowLeaveShare * Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeOut
        // Refused (the file not read yet), the row comes back.
        onFinished: {
            if (row.group.unpin(row.key, row.title))
                return;
            row.leaving = 0;
            row.pulled = 0;
        }
    }

    // Let go short of half, it settles back as a state change does (motion.md, "State changes").
    NumberAnimation {
        id: glidingBack

        target: row
        property: "pulled"
        to: 0
        duration: Tokens.durationShort
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.easeBase
    }

    Hairline {
        objectName: "hairline"
        x: -row.grip.width
        width: row.width
    }

    // The name and what stands beside it: where a pull starts.
    Item {
        objectName: "pullArea"
        width: sizeSelect.x
        height: row.lineHeight

        DragHandler {
            id: pull

            objectName: "pull"
            property bool refused: false

            target: null
            yAxis.enabled: false
            enabled: !row.going && row.group.disabledReason === ""

            onActiveTranslationChanged: {
                if (active && !refused)
                    row.pulled = Math.max(0, activeTranslation.x);
            }
            onActiveChanged: {
                if (active) {
                    const x = centroid.scenePressPosition.x;
                    const nearEdge = x < Tokens.spaceL || x > row.Window.width - Tokens.spaceL;
                    refused = centroid.device.type !== PointerDevice.Mouse && nearEdge;
                    glidingBack.stop();
                } else if (!refused) {
                    row.letGo();
                }
            }
        }

        PictureIcon {
            objectName: "icon"
            x: Tokens.spaceS
            anchors.verticalCenter: parent.verticalCenter
            source: row.icon
        }

        Body {
            id: words

            objectName: "name"
            x: Tokens.spaceS + Geometry.iconSize + Tokens.spaceS
            width: Math.min(implicitWidth, parent.width - x - (row.missing ? absent.width + Tokens.spaceS : 0) - Tokens.spaceS)
            anchors.verticalCenter: parent.verticalCenter
            text: row.title
            textFormat: Text.PlainText
            wrapMode: Text.NoWrap
            elide: Text.ElideRight

            OverflowTip {}
        }

        Meta {
            id: absent

            objectName: "missing"
            x: words.x + words.width + Tokens.spaceS
            anchors.baseline: words.baseline
            visible: row.missing
            text: "nicht installiert"
            wrapMode: Text.NoWrap
        }
    }

    Select {
        id: sizeSelect

        objectName: "size"
        x: remove.x - Tokens.spaceS - width
        y: (row.lineHeight - Tokens.controlHeight) / 2
        width: Geometry.inputPadding + widest.width + Geometry.selectPaddingEnd
        label: `größe von ${row.title}`
        disabledReason: row.group.disabledReason
        options: row.sizeOptions
        currentIndex: row.sizeOptions.findIndex(option => option.value === row.size)
        onActivated: index => {
            const option = row.sizeOptions[index];
            if (option.value !== row.size)
                row.group.resize(row.appId, row.title, option.value, option.text);
            currentIndex = Qt.binding(() => row.sizeOptions.findIndex(option => option.value === row.size));
        }

        TextMetrics {
            id: widest

            font.family: Tokens.fontSans
            font.pixelSize: Tokens.fontSizeS
            text: row.sizeOptions.reduce((longest, option) => option.text.length > longest.length ? option.text : longest, "")
        }
    }

    IconButton {
        id: remove

        objectName: "remove"
        x: row.width - row.grip.width - width
        y: (row.lineHeight - height) / 2
        inRow: true
        variant: "quiet"
        icon: "close"
        label: "lösen"
        Accessible.name: `${row.title} lösen`
        disabledReason: row.group.disabledReason
        onClicked: row.group.remove(row)
    }
}
