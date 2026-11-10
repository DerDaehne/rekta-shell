{
  runCommand,
  callPackage,
  kdePackages,
  dbus,
  makeFontsConf,
  atkinson-hyperlegible-next,
  tzdata,
  rekta-shell,
  # The shell's and the tests' QML, side by side.
  qml,
  # Also render the contact sheets, pictures for people, and keep them as the result.
  contactSheets ? false,
}:

let
  counterpart = callPackage ./dbus-counterpart.nix { };
in
runCommand (if contactSheets then "rekta-shell-contact-sheets" else "rekta-shell-qml-tests")
  {
    nativeBuildInputs = [
      kdePackages.qtdeclarative
      dbus
    ];
    QT_QUICK_BACKEND = "software";
    FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ atkinson-hyperlegible-next ]; };
    QT_PLUGIN_PATH = "${kdePackages.qtbase}/lib/qt-6/plugins";
    QML_IMPORT_PATH = "${kdePackages.qtdeclarative}/lib/qt-6/qml:${rekta-shell}/lib/qt-6/qml:${counterpart}/lib/qt-6/qml";
    DBUS_SESSION_CONFIG = "${dbus}/share/dbus-1/session.conf";
    TZDIR = "${tzdata}/share/zoneinfo";
    LANG = "C.UTF-8";
    CONTACT_SHEETS = if contactSheets then "1" else "";
  }
  (
    ''
      export HOME="$TMPDIR"
      ${qml}/tests/run-qml-tests.sh ${qml}
    ''
    + (
      if contactSheets then
        ''
          mkdir $out
          cp *.png $out/
        ''
      else
        ''
          touch $out
        ''
    )
  )
