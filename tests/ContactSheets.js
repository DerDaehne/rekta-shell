.pragma library

// Contact sheets are pictures for people, built on demand by `nix build .#contact-sheets`, whose runner passes
// `-file-selector contact-sheets`. qmltestrunner hands no flag of its own to QML; the application's arguments show it.
const wanted = Qt.application.arguments.includes("contact-sheets");

// The colour sets the sheets of the bar, the Start, the panel and the settings app are drawn in: the two themes, the
// black ground and the black ground with more contrast.
const colourSets = ["light", "dark", "black", "black-contrast"];
