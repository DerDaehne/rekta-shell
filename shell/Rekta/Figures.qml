import QtQuick

// Figures outside a tile, as a status region shows them (rekta.css:96–97): stat pairs side by side, wrapping, space-m
// between rows and space-xl between figures. It takes the width it is given, like a block.
Flow {
    // A Flow has one spacing. Each Stat in it pads its end by space-xl − space-m and the flow gives that much back at
    // its edge, so a figure wraps exactly where `gap: space-m space-xl` would wrap it.
    spacing: Tokens.spaceM
    rightPadding: Tokens.spaceM - Tokens.spaceXl
}
