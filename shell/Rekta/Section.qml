import QtQuick

// A panorama section (layout.md:76–96; rekta.css `.rk-sec`, :1167–1174, :1547): a heading and what belongs to it,
// space-xl above and below, the heading space-l above what follows it and the blocks after it space-m apart. Sideways
// it scrolls vertically within itself when its content is taller than the panorama's box; stacked (compact) it takes
// its content's height and a hairline separates it from the section above (rekta.css:1171).
Flickable {
    id: section

    property string title
    // 0: the panorama's section width.
    property real sectionWidth: 0
    // Rekta's is the default; a place may set a larger one.
    property var headingToken: Tokens.fontSizeGroup
    property real placeWidth: Window.width
    // Set by the panorama: stacked top to bottom (compact), and not the first one.
    property bool stacked: false
    property bool separated: false
    readonly property bool headingFocused: headline.activeFocus
    default property alias content: blocks.data

    // The section's heading takes the focus when a jump asks for it (rekta.js focusHeading(), :222–228).
    function focusHeading() {
        headline.forceActiveFocus(Qt.TabFocusReason);
    }

    implicitHeight: column.height + 2 * Tokens.spaceXl
    contentWidth: width
    contentHeight: implicitHeight
    interactive: !stacked
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    Hairline {
        visible: section.stacked && section.separated
        width: section.width
    }

    Column {
        id: column

        y: Tokens.spaceXl
        // Sideways a section keeps space-s clear on the right for its scrollbar (rekta.css:1547).
        width: section.width - (section.stacked ? 0 : Tokens.spaceS)
        spacing: Tokens.spaceL

        GroupHeading {
            id: headline

            objectName: "heading"
            width: parent.width
            sizeToken: section.headingToken
            placeWidth: section.placeWidth
            text: section.title
            visible: text !== ""
            // No tab stop of its own (rekta.js:222–228 gives it tabindex -1); once a jump has put the focus on it, Tab goes
            // on into the section.
            activeFocusOnTab: activeFocus
            Accessible.role: Accessible.Heading
            Accessible.name: text

            FocusRing {
                shown: headline.activeFocus
            }
        }

        Column {
            id: blocks

            objectName: "blocks"
            width: parent.width
            spacing: Tokens.spaceM
        }
    }
}
