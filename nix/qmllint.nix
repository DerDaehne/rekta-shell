{
  writeShellApplication,
  coreutils,
  kdePackages,
  quickshell,
}:

# One lint command for the dev shell and the flake check, with Qt's and Quickshell's modules on the import path.
writeShellApplication {
  name = "rekta-qmllint";
  runtimeInputs = [
    coreutils
    kdePackages.qtdeclarative
  ];
  text = ''
    # qmllint misreads a module's own qmldir (its singletons) when given relative paths, so every path goes absolute.
    args=()
    for arg in "$@"; do
      if [ -e "$arg" ]; then args+=("$(realpath "$arg")"); else args+=("$arg"); fi
    done
    # Quickshell's type descriptions mark its windows (PanelWindow and friends) as uncreatable, although QML creates them.
    exec qmllint --max-warnings 0 --uncreatable-type disable \
      -I ${kdePackages.qtdeclarative}/lib/qt-6/qml \
      -I ${quickshell}/lib/qt-6/qml \
      "''${args[@]}"
  '';
}
