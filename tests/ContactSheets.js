.pragma library

// Contact sheets are pictures for people, built on demand by `nix build .#contact-sheets`, whose runner passes
// `-file-selector contact-sheets`. qmltestrunner hands no flag of its own to QML; the application's arguments show it.
const wanted = Qt.application.arguments.includes("contact-sheets");
