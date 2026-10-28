pragma ComponentBehavior: Bound

import QtQuick

// A pivot (navigation.md, "Pivot"; rekta.css:148–190): titles in a fixed order, exactly one active. Along the top, a
// strip that does not fit glides by the active title's place in the order, and only the old and the new active title
// change size, scaled from one fixed line box, so the strip's height never changes. Down the side, the title in sight
// steps in by space-m. Compact, a side pivot is the strip along the top again, and a nav strip takes the facet sizes.
Item {
    id: pivot

    property list<string> titles
    property int currentIndex: 0
    // "nav" picks the place, "facet" a facet of it.
    property string level: "facet"
    property bool side: false
    property real placeWidth: Window.width
    property real viewportHeight: Window.height
    readonly property bool compact: Prefs.sizeClass(placeWidth, viewportHeight) === "compact"
    readonly property bool down: side && !compact
    readonly property bool navSizes: level === "nav" && !compact
    // The fluid size tokens of the active and the inactive title; a place may set larger ones.
    property var activeToken: navSizes ? Tokens.fontSizeNavActive : Tokens.fontSizePivotActive
    property var inactiveToken: navSizes ? Tokens.fontSizeNavInactive : Tokens.fontSizePivotInactive
    readonly property real activeSize: Tokens.fluid(activeToken, placeWidth)
    readonly property real inactiveSize: Tokens.fluid(inactiveToken, placeWidth)

    signal selected(int index)

    function select(index: int) {
        if (index < 0 || index >= titles.length || index === currentIndex)
            return;
        currentIndex = index;
        selected(index);
    }

    // Where the strip rests for the active title, after rekta.js pivotGlide(): its place in the order sets how far
    // along the strip is, and it is always whole in sight.
    function glideTarget(): real {
        const count = repeater.count;
        let x = 0, left = 0, span = 0, previous = 0;
        for (let k = 0; k < count; k++) {
            const title = repeater.itemAt(k) as PivotTitleBox;
            // While the repeater is still creating its titles, the strip waits at its start.
            if (!title)
                return 0;
            const w = k === currentIndex ? title.restingWidth : title.restingWidth * title.ratio;
            if (k === currentIndex - 1)
                previous = x;
            if (k === currentIndex) {
                left = x;
                span = w;
            }
            x += w + Tokens.spaceL;
        }
        // The strip fills the pivot; its own width may not have followed yet when the pivot resizes.
        const room = pivot.width;
        const most = Math.max(0, x - Tokens.spaceL - room);
        const along = most * (count > 1 ? currentIndex / (count - 1) : 0);
        return Math.min(most, Math.max(0, left + span - room, Math.min(along, currentIndex > 0 ? previous : left)));
    }

    // Puts the strip where it rests at once: on the first layout, a new width or new sizes.
    function rest() {
        glideAnimation.stop();
        strip.contentX = down ? 0 : glideTarget();
    }

    function glide() {
        if (down) {
            strip.contentX = 0;
            return;
        }
        glideAnimation.to = glideTarget();
        glideAnimation.restart();
    }

    implicitWidth: titlesGrid.implicitWidth
    implicitHeight: Math.max(Tokens.touchTarget, titlesGrid.implicitHeight)
    activeFocusOnTab: true
    Accessible.role: Accessible.PageTabList

    onCurrentIndexChanged: glide()
    onWidthChanged: rest()
    onDownChanged: rest()
    onActiveSizeChanged: rest()
    onInactiveSizeChanged: rest()

    Keys.onPressed: event => {
        const count = titles.length;
        const moves = {
            [down ? Qt.Key_Down : Qt.Key_Right]: currentIndex + 1,
            [down ? Qt.Key_Up : Qt.Key_Left]: currentIndex - 1,
            [Qt.Key_Home]: 0,
            [Qt.Key_End]: count - 1
        };
        if (count === 0 || !(event.key in moves))
            return;
        select((moves[event.key] + count) % count);
        event.accepted = true;
    }

    Flickable {
        id: strip

        objectName: "strip"
        anchors.fill: parent
        clip: !pivot.down
        interactive: !pivot.down && contentWidth > width
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: titlesGrid.width
        contentHeight: titlesGrid.height

        NumberAnimation {
            id: glideAnimation

            objectName: "glide"
            target: strip
            property: "contentX"
            duration: Tokens.durationPivotGlide
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easePivotGlide
        }

        Grid {
            id: titlesGrid

            anchors.bottom: parent.bottom
            columns: pivot.down ? 1 : Math.max(1, repeater.count)
            columnSpacing: Tokens.spaceL
            rowSpacing: Tokens.spaceXs
            verticalItemAlignment: Grid.AlignBottom

            Repeater {
                id: repeater

                model: pivot.titles

                delegate: PivotTitleBox {}

                onItemAdded: pivot.rest()
                onItemRemoved: pivot.rest()
            }
        }
    }

    component PivotTitleBox: Item {
        id: title

        required property string modelData
        required property int index
        readonly property bool active: index === pivot.currentIndex
        // The width the title takes at the active size; an inactive one takes this times the ratio.
        readonly property real restingWidth: word.implicitWidth
        readonly property real ratio: pivot.down ? 1 : pivot.inactiveSize / pivot.activeSize
        // A title under the pointer darkens like the active one (rekta.css:1020).
        readonly property bool lit: active || hover.hovered

        objectName: `title-${index}`
        width: pivot.down ? word.implicitWidth + Tokens.spaceM : word.implicitWidth * word.shrink
        height: word.height
        Accessible.role: Accessible.PageTab
        Accessible.name: modelData
        Accessible.selected: active

        TextRole {
            id: word

            objectName: "word"
            anchors.bottom: parent.bottom
            x: pivot.down && title.active ? Tokens.spaceM : 0
            // How far the title is scaled down from the active size, around its own baseline (navigation.md, "Pivot").
            property real shrink: title.active ? 1 : title.ratio

            transform: Scale {
                origin.y: word.baselineOffset
                xScale: word.shrink
                yScale: word.shrink
            }
            text: title.modelData
            font.pixelSize: pivot.down ? Tokens.fluid(Tokens.fontSizePivotActive, pivot.placeWidth) : pivot.activeSize
            font.weight: Tokens.fontWeightLight
            lineHeightFactor: Tokens.lineHeightNav
            color: title.lit ? Tokens.color.textPrimary : Tokens.color.textContrastMedium

            Behavior on x {
                NumberAnimation {
                    duration: Tokens.durationPivotSize
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Geometry.easeInOut
                }
            }
            Behavior on shrink {
                NumberAnimation {
                    duration: Tokens.durationPivotSize
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Geometry.easeInOut
                }
            }
            // Along the top the colour eases like any state change; down the side it moves with the step.
            Behavior on color {
                ColorAnimation {
                    duration: pivot.down ? Tokens.durationPivotSize : Tokens.durationShort
                    easing.type: Easing.Bezier
                    easing.bezierCurve: pivot.down ? Geometry.easeInOut : Tokens.easeBase
                }
            }
        }

        HoverHandler {
            id: hover

            cursorShape: Qt.PointingHandCursor
        }

        // Each title's hit area is at least touch-target tall (rekta.css:167–169).
        TapHandler {
            margin: Math.max(0, (Tokens.touchTarget - title.height) / 2)
            onTapped: pivot.select(title.index)
        }

        FocusRing {
            shown: pivot.activeFocus && title.active
        }
    }
}
