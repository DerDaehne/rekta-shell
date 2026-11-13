import QtQuick

// The chevron of a select and a combobox (forms.md:76–78; rekta.css:425–437): 8 × 4px, a 1.6px stroke in the text
// colour, pointing down, and up while its list is open (rekta-core controls.c:650–652). The host places it.
Chevron {
    id: chevron

    property bool open: false
    property bool disabled: false

    // A turned box whose diagonal spans the chevron's width.
    width: Geometry.comboChevronWidth / Math.SQRT2
    height: width
    rotation: open ? Geometry.chevronOnTurn - 90 : Geometry.chevronOnTurn + 90
    color: disabled ? Tokens.color.disabled : Tokens.color.textPrimary
    // Turned about its centre, the arms lie on the side the point is on; half the chevron's height back centres it, as
    // Rekta draws it.
    transform: Translate {
        y: (chevron.open ? 1 : -1) * Geometry.comboChevronWidth / 4
    }
}
