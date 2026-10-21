{
  writeShellApplication,
  kdePackages,
}:

# Saves the whole nested desktop as a PNG, through KWin's own screenshot interface (KWin offers clients no screencopy).
writeShellApplication {
  name = "rekta-nested-shot";
  runtimeInputs = [ kdePackages.spectacle ];
  text = ''
    file="$(realpath -m "''${1:?usage: rekta-nested-shot <file.png>}")"
    shopt -s nullglob
    sessions=("''${TMPDIR:-/tmp}"/rekta-nested.*/session.env)
    if [ "''${#sessions[@]}" -ne 1 ]; then
      echo "rekta-nested-shot: expected one running nested session (nix run .#nested), found ''${#sessions[@]}" >&2
      exit 1
    fi
    # shellcheck disable=SC1090
    source "''${sessions[0]}"
    export QT_QPA_PLATFORM=wayland
    unset DISPLAY
    spectacle --background --nonotify --fullscreen --output "$file"
    echo "$file"
  '';
}
