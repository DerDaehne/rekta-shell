{
  writeShellApplication,
  callPackage,
  coreutils,
  kdePackages,
  rekta-shell,
}:

let
  counterpart = callPackage ./dbus-counterpart.nix { };
in
# One lint command for the dev shell and the flake check, with the modules the shell and its tests import on the import
# path.
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
      -I ${rekta-shell.quickshell}/lib/qt-6/qml \
      -I ${rekta-shell}/lib/qt-6/qml \
      -I ${counterpart}/lib/qt-6/qml \
      -I ${kdePackages.plasma-workspace}/lib/qt-6/qml \
      -I ${kdePackages.kpipewire}/lib/qt-6/qml \
      "''${args[@]}"
  '';
}
