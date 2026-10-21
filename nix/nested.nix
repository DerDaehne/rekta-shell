{
  lib,
  writeShellApplication,
  coreutils,
  kdePackages,
  dbus,
  rekta-shell,
}:

# A KWin nested in the running desktop. It starts from an empty environment with its own HOME, runtime directory,
# config directories and a session bus without service activation, so neither the desktop's plugins, config and
# services reach it nor does anything it starts (portals, wallets, FUSE mounts) reach the desktop.
writeShellApplication {
  name = "rekta-nested";
  runtimeInputs = [ coreutils ];
  text = ''
    usage() {
      echo "usage: rekta-nested [--outputs N] [--size WIDTHxHEIGHT]" >&2
      exit 2
    }

    outputs=1
    size=1600x900
    while [ $# -gt 0 ]; do
      case "$1" in
        --outputs) outputs="''${2:?}"; shift 2 ;;
        --size) size="''${2:?}"; shift 2 ;;
        *) usage ;;
      esac
    done
    [[ "$outputs" =~ ^[1-9]$ ]] || usage
    [[ "$size" =~ ^[0-9]+x[0-9]+$ ]] || usage

    # The working tree's shell when run from the repository (Quickshell reloads it on every change), else the package's.
    shell_dir=${rekta-shell}/share/rekta-shell
    if [ -f shell/shell.qml ] && [ -f flake.nix ]; then
      shell_dir="$PWD/shell"
    fi

    # The host display by absolute path: the only thing the session takes from the desktop.
    host_display="''${WAYLAND_DISPLAY:-wayland-0}"
    [[ "$host_display" == /* ]] || host_display="$XDG_RUNTIME_DIR/$host_display"

    home="$(mktemp -d -t rekta-nested.XXXXXX)"
    cleanup() {
      [ -n "''${kwin:-}" ] && kill "$kwin" 2>/dev/null && wait "$kwin" 2>/dev/null
      [ -n "''${bus_pid:-}" ] && kill "$bus_pid" 2>/dev/null
      rm -rf "$home"
    }
    trap cleanup EXIT
    trap 'exit 130' INT TERM

    mkdir -p "$home/.config" "$home/.local/share/applications" "$home/.local/state" "$home/.cache" "$home/xdg"
    mkdir -m 700 "$home/runtime"
    session=(
      PATH="${
        lib.makeBinPath [
          kdePackages.kwin
          dbus
          coreutils
        ]
      }"
      HOME="$home"
      XDG_CONFIG_HOME="$home/.config"
      XDG_DATA_HOME="$home/.local/share"
      XDG_STATE_HOME="$home/.local/state"
      XDG_CACHE_HOME="$home/.cache"
      XDG_RUNTIME_DIR="$home/runtime"
      XDG_CONFIG_DIRS="$home/xdg"
      XDG_DATA_DIRS="${kdePackages.kwin}/share"
      LANG="''${LANG:-C.UTF-8}"
    )
    [ -n "''${LOCALE_ARCHIVE:-}" ] && session+=(LOCALE_ARCHIVE="$LOCALE_ARCHIVE")

    mapfile -t bus < <(env -i "''${session[@]}" dbus-daemon --config-file=${./nested-bus.xml} --fork --print-address=1 --print-pid=1)
    bus_pid="''${bus[1]}"
    session+=(DBUS_SESSION_BUS_ADDRESS="''${bus[0]}")

    # KWin hands its screenshot interface only to programs whose desktop file asks for it; nested-shot uses spectacle.
    cp ${kdePackages.spectacle}/share/applications/org.kde.spectacle.desktop "$home/.local/share/applications/"

    # kwin_wayland starts its program without passing on any arguments, so the shell path goes into a launcher.
    launcher="$home/rekta-shell"
    printf '#!/bin/sh\nexport QML_IMPORT_PATH=%q\nexec %q --path %q\n' "$shell_dir" "${rekta-shell.quickshell}/bin/quickshell" "$shell_dir" >"$launcher"
    chmod +x "$launcher"

    socket="rekta-nested"
    printf '%s\n' "''${session[@]}" "WAYLAND_DISPLAY=$socket" >"$home/session.env"

    echo "rekta-nested: shell from $shell_dir, HOME $home"
    env -i "''${session[@]}" WAYLAND_DISPLAY="$host_display" kwin_wayland --socket "$socket" \
      --width "''${size%x*}" --height "''${size#*x}" --output-count "$outputs" \
      --no-lockscreen --no-global-shortcuts --no-kactivities \
      -- "$launcher" &
    kwin=$!
    wait "$kwin"
  '';
}
