{
  writeShellApplication,
  kdePackages,
  quickshell,
}:

# One lint command for the dev shell and the flake check, with Qt's and Quickshell's modules on the import path.
writeShellApplication {
  name = "rekta-qmllint";
  runtimeInputs = [ kdePackages.qtdeclarative ];
  # Quickshell's type descriptions mark its windows (PanelWindow and friends) as uncreatable, although QML creates them.
  text = ''
    exec qmllint --max-warnings 0 --uncreatable-type disable \
      -I ${kdePackages.qtdeclarative}/lib/qt-6/qml \
      -I ${quickshell}/lib/qt-6/qml \
      "$@"
  '';
}
