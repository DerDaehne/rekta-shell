{
  writeShellApplication,
  callPackage,
  coreutils,
  jq,
  kdePackages,
  rekta-shell,
}:

let
  counterpart = callPackage ./dbus-counterpart.nix { };
in
# One lint command for the dev shell and the flake check, with the modules the shell, the lock screen and the tests
# import on the import path.
writeShellApplication {
  name = "rekta-qmllint";
  runtimeInputs = [
    coreutils
    jq
    kdePackages.qtdeclarative
  ];
  text = ''
    for arg in "$@"; do
      case "$arg" in -h | --help | --help-all | -v | --version) exec qmllint "$arg" ;; esac
    done
    # qmllint misreads a module's own qmldir (its singletons) when given relative paths, so every path goes absolute.
    args=()
    for arg in "$@"; do
      if [ -e "$arg" ]; then args+=("$(realpath "$arg")"); else args+=("$arg"); fi
    done
    # Quickshell's type descriptions mark its windows (PanelWindow and friends) as uncreatable, although QML creates them.
    # qmllint's text mode drops some warnings and still exits 255; its JSON report has them all.
    report=$(mktemp)
    trap 'rm -f "$report"' EXIT
    status=0
    qmllint --json "$report" --max-warnings 0 --uncreatable-type disable \
      -I ${kdePackages.qtdeclarative}/lib/qt-6/qml \
      -I ${rekta-shell.quickshell}/lib/qt-6/qml \
      -I ${rekta-shell}/lib/qt-6/qml \
      -I ${counterpart}/lib/qt-6/qml \
      -I ${kdePackages.plasma-workspace}/lib/qt-6/qml \
      -I ${kdePackages.kpipewire}/lib/qt-6/qml \
      -I ${kdePackages.kscreenlocker}/lib/qt-6/qml \
      -I ${kdePackages.kirigami.unwrapped}/lib/qt-6/qml \
      "''${args[@]}" >/dev/null || status=$?
    jq -r '.files[] | (.filename // .module) as $file | .warnings[]? |
      "\($file)\(if .line then ":\(.line):\(.column):" else ":" end) \(.type): \(.message) [\(.id)]",
      (.suggestions[]? | "    \(.message)")' "$report" >&2
    exit "$status"
  '';
}
