import QtQuick

// A panorama section (rekta.css `.rk-sec`, :853–857, :1173): a heading and what belongs to it, space-m apart, space-l
// above and below. Sideways it scrolls vertically within itself when its content is taller than the panorama's box;
// stacked (compact) it takes its content's height and a hairline separates it from the section above (:855).
Flickable {
    id: section

    property string title
    // 0: the panorama's section width.
    property real sectionWidth: 0
    // Set by the panorama: stacked top to bottom (compact), and not the first one.
    property bool stacked: false
    property bool separated: false
    readonly property bool headingFocused: headline.activeFocus
    default property alias content: column.data

    // The section's heading takes the focus when a jump asks for it (rekta.js focusHeading(), :192–198).
    function focusHeading() {
        headline.forceActiveFocus(Qt.TabFocusReason);
    }

    implicitHeight: column.height + 2 * Tokens.spaceL
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

        y: Tokens.spaceL
        // Sideways a section keeps space-s clear on the right for its scrollbar (rekta.css:1173).
        width: section.width - (section.stacked ? 0 : Tokens.spaceS)
        spacing: Tokens.spaceM

        GroupHeading {
            id: headline

            objectName: "heading"
            width: parent.width
            text: section.title
            visible: text !== ""
            Accessible.role: Accessible.Heading
            Accessible.name: text

            FocusRing {
                shown: headline.activeFocus
            }
        }
    }
}
