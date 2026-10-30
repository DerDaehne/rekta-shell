import QtQuick

// A panorama section (rekta.css `.rk-sec`, :853–857, :1173): a heading and what belongs to it, space-m apart, space-l
// above and below. Sideways it scrolls vertically within itself when its content is taller than the panorama's box;
// stacked (compact) it takes its content's height and a hairline separates it from the section above (:855).
Flickable {
    id: section

    property string title
    // 0: the panorama's section width.
    property real sectionWidth: 0
    // Rekta's values are the defaults; a place may set larger ones (the Start does: ADR-034, point 3).
    property real verticalInset: Tokens.spaceL
    property real headingSpacing: Tokens.spaceM
    property var headingToken: Tokens.fontSizeGroup
    property real placeWidth: Window.width
    // Set by the panorama: stacked top to bottom (compact), and not the first one.
    property bool stacked: false
    property bool separated: false
    readonly property bool headingFocused: headline.activeFocus
    default property alias content: column.data

    // The section's heading takes the focus when a jump asks for it (rekta.js focusHeading(), :192–198).
    function focusHeading() {
        headline.forceActiveFocus(Qt.TabFocusReason);
    }

    implicitHeight: column.height + 2 * section.verticalInset
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

        y: section.verticalInset
        // Sideways a section keeps space-s clear on the right for its scrollbar (rekta.css:1173).
        width: section.width - (section.stacked ? 0 : Tokens.spaceS)
        spacing: section.headingSpacing

        GroupHeading {
            id: headline

            objectName: "heading"
            width: parent.width
            sizeToken: section.headingToken
            placeWidth: section.placeWidth
            text: section.title
            visible: text !== ""
            // No tab stop of its own (rekta.js:192–198 gives it tabindex -1); once a jump has put the focus on it, Tab goes
            // on into the section.
            activeFocusOnTab: activeFocus
            Accessible.role: Accessible.Heading
            Accessible.name: text

            FocusRing {
                shown: headline.activeFocus
            }
        }
    }
}
