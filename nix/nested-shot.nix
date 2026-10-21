{
  writeShellApplication,
  coreutils,
  kdePackages,
}:

# Saves the whole nested desktop as a PNG, through KWin's own screenshot interface (KWin offers clients no screencopy).
writeShellApplication {
  name = "rekta-nested-shot";
  runtimeInputs = [ coreutils ];
  text = ''
    file="$(realpath -m "''${1:?usage: rekta-nested-shot <file.png>}")"
    shopt -s nullglob
    sessions=("''${TMPDIR:-/tmp}"/rekta-nested.*/session.env)
    if [ "''${#sessions[@]}" -ne 1 ]; then
      echo "rekta-nested-shot: expected one running nested session (nix run .#nested), found ''${#sessions[@]}" >&2
      exit 1
    fi
    # The session's own environment only, so spectacle neither loads the desktop's plugins nor talks to its bus.
    mapfile -t session <"''${sessions[0]}"
    env -i "''${session[@]}" QT_QPA_PLATFORM=wayland \
      ${kdePackages.spectacle}/bin/spectacle --background --nonotify --fullscreen --output "$file"
    echo "$file"
  '';
}
