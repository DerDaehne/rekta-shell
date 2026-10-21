{
  writeShellApplication,
  kdePackages,
  dbus,
  rekta-shell,
}:

# A KWin nested in the running desktop. It gets its own HOME, its own runtime directory and its own session bus without
# service activation, so nothing it starts (portals, wallets, FUSE mounts) can reach the real session.
writeShellApplication {
  name = "rekta-nested";
  runtimeInputs = [
    kdePackages.kwin
    dbus
  ];
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

    # The host display by absolute path, so it stays reachable once the runtime directory is our own.
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

    export HOME="$home"
    export XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share"
    export XDG_STATE_HOME="$home/.local/state" XDG_CACHE_HOME="$home/.cache"
    export XDG_RUNTIME_DIR="$home/runtime"
    mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME/applications" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"
    mkdir -m 700 "$XDG_RUNTIME_DIR"
    export WAYLAND_DISPLAY="$host_display"
    unset DISPLAY

    mapfile -t bus < <(dbus-daemon --config-file=${./nested-bus.xml} --fork --print-address=1 --print-pid=1)
    export DBUS_SESSION_BUS_ADDRESS="''${bus[0]}"
    bus_pid="''${bus[1]}"

    # KWin hands its screenshot interface only to programs whose desktop file asks for it; nested-shot uses spectacle.
    cp ${kdePackages.spectacle}/share/applications/org.kde.spectacle.desktop "$XDG_DATA_HOME/applications/"

    # kwin_wayland starts its program without passing on any arguments, so the shell path goes into a launcher.
    launcher="$home/rekta-shell"
    printf '#!/bin/sh\nexec %q --path %q\n' "${rekta-shell.quickshell}/bin/quickshell" "$shell_dir" >"$launcher"
    chmod +x "$launcher"

    socket="rekta-nested"
    printf 'export %s=%q\n' HOME "$HOME" XDG_CONFIG_HOME "$XDG_CONFIG_HOME" XDG_DATA_HOME "$XDG_DATA_HOME" \
      XDG_STATE_HOME "$XDG_STATE_HOME" XDG_CACHE_HOME "$XDG_CACHE_HOME" XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR" \
      DBUS_SESSION_BUS_ADDRESS "$DBUS_SESSION_BUS_ADDRESS" WAYLAND_DISPLAY "$socket" >"$home/session.env"

    echo "rekta-nested: shell from $shell_dir, HOME $home"
    kwin_wayland --socket "$socket" \
      --width "''${size%x*}" --height "''${size#*x}" --output-count "$outputs" \
      --no-lockscreen --no-global-shortcuts --no-kactivities \
      -- "$launcher" &
    kwin=$!
    wait "$kwin"
  '';
}
