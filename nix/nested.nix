{
  lib,
  writeShellApplication,
  writeTextDir,
  symlinkJoin,
  coreutils,
  gnugrep,
  kdePackages,
  dbus,
  pipewire,
  wireplumber,
  rekta-shell,
}:

let
  # PipeWire and WirePlumber read only these directories, never the host's /etc or the user's config: no D-Bus, no
  # realtime scheduling, no devices. WirePlumber only links streams, such as KWin's screencasts to the shell.
  pipewireConfig = symlinkJoin {
    name = "rekta-nested-pipewire";
    paths = [
      "${pipewire}/share/pipewire"
      (writeTextDir "pipewire.conf.d/nested.conf" ''
        context.properties = {
          support.dbus = false
          module.rt = false
          module.portal = false
          module.x11.bell = false
          module.jackdbus-detect = false
        }
      '')
    ];
  };
  wireplumberConfig = writeTextDir "wireplumber.conf.d/nested.conf" ''
    wireplumber.profiles = {
      nested = {
        inherits = [ policy ]
        support.dbus = disabled
        support.system-dbus = disabled
        support.logind = disabled
        support.reserve-device = disabled
        support.portal-permissionstore = disabled
        support.modem-manager = disabled
        support.mpris = disabled
        hardware.audio = disabled
        hardware.bluetooth = disabled
        hardware.video-capture = disabled
      }
    }
  '';
in
# A KWin of its own, headless in a virtual framebuffer or, with --window, as a window in the running desktop. It starts
# from an empty environment with its own HOME, runtime directory, config directories, a session bus without service
# activation and a PipeWire without devices, so neither the desktop's plugins, config and services reach it nor does
# anything it starts (portals, wallets, FUSE mounts) reach the desktop.
writeShellApplication {
  name = "rekta-nested";
  runtimeInputs = [ coreutils ];
  text = ''
    usage() {
      echo "usage: rekta-nested [--window] [--outputs N] [--size WIDTHxHEIGHT] [--background rekta|solid]" >&2
      exit 2
    }

    window=false
    outputs=1
    size=1600x900
    background=rekta
    while [ $# -gt 0 ]; do
      case "$1" in
        --window) window=true; shift ;;
        --outputs) outputs="''${2:?}"; shift 2 ;;
        --size) size="''${2:?}"; shift 2 ;;
        --background) background="''${2:?}"; shift 2 ;;
        *) usage ;;
      esac
    done
    [[ "$outputs" =~ ^[1-9]$ ]] || usage
    [[ "$size" =~ ^[0-9]+x[0-9]+$ ]] || usage
    [[ "$background" =~ ^(rekta|solid)$ ]] || usage

    # The working tree's shell and KWin effects when run from the repository (Quickshell reloads the shell on every
    # change), else the packages'. The compiled effects always come from the package.
    shell_dir=${rekta-shell}/share/rekta-shell
    kwin_dir=${rekta-shell}/share/rekta-kwin/kwin
    if [ -f shell/shell.qml ] && [ -f flake.nix ]; then
      shell_dir="$PWD/shell"
      kwin_dir="$PWD/kwin"
    fi

    # Headless by default: KWin renders into a virtual framebuffer and never learns the desktop's display.
    backend=(--virtual)
    host_display=()
    if [ "$window" = true ]; then
      # The host display by absolute path: the only thing a windowed session takes from the desktop.
      display="''${WAYLAND_DISPLAY:-wayland-0}"
      [[ "$display" == /* ]] || display="$XDG_RUNTIME_DIR/$display"
      backend=()
      host_display=(WAYLAND_DISPLAY="$display")
    fi

    home="$(mktemp -d -t rekta-nested.XXXXXX)"
    # Each step may find its process gone already; none of them may keep the next from running.
    stop() {
      [ -n "$1" ] || return 0
      kill "$1" 2>/dev/null || true
      wait "$1" 2>/dev/null || true
    }
    cleanup() {
      stop "''${kwin:-}"
      stop "''${wireplumber_pid:-}"
      stop "''${pipewire_pid:-}"
      stop "''${bus_pid:-}"
      rm -rf "$home"
    }
    trap cleanup EXIT
    trap 'exit 130' INT TERM

    mkdir -p "$home/.config" "$home/.local/share/applications" "$home/.local/state" "$home/.cache" "$home/rekta-kwin"
    mkdir -m 700 "$home/runtime"
    # The rekta session's KWin parts, laid out as in the package and added as their own XDG dirs: effects under
    # rekta-kwin/kwin/effects, the kwinrc defaults (beneath the user's own) in rekta-kwin/kwin.
    ln -s "$kwin_dir" "$home/rekta-kwin/kwin"
    session=(
      PATH="${
        lib.makeBinPath [
          kdePackages.kwin
          kdePackages.libkscreen
          dbus
          pipewire
          wireplumber
          coreutils
          gnugrep
        ]
      }"
      HOME="$home"
      XDG_CONFIG_HOME="$home/.config"
      XDG_DATA_HOME="$home/.local/share"
      XDG_STATE_HOME="$home/.local/state"
      XDG_CACHE_HOME="$home/.cache"
      XDG_RUNTIME_DIR="$home/runtime"
      XDG_CONFIG_DIRS="$home/rekta-kwin/kwin"
      XDG_DATA_DIRS="$home/rekta-kwin:${kdePackages.kwin}/share:${rekta-shell}/share"
      LANG="''${LANG:-C.UTF-8}"
      # The rekta session's name, which the shell checks before it takes over names of Plasma's.
      XDG_SESSION_DESKTOP=rekta
      PIPEWIRE_CONFIG_DIR=${pipewireConfig}
      WIREPLUMBER_CONFIG_DIR=${wireplumberConfig}:${wireplumber}/share/wireplumber
      # Its programs log to its own stderr, not to the desktop's journal.
      QT_FORCE_STDERR_LOGGING=1
    )
    [ -n "''${LOCALE_ARCHIVE:-}" ] && session+=(LOCALE_ARCHIVE="$LOCALE_ARCHIVE")

    mapfile -t bus < <(env -i "''${session[@]}" dbus-daemon --config-file=${./nested-bus.xml} --fork --print-address=1 --print-pid=1)
    bus_pid="''${bus[1]}"
    session+=(DBUS_SESSION_BUS_ADDRESS="''${bus[0]}")

    # The shell connects to PipeWire once, as it starts, so the socket has to be there before KWin starts the shell.
    env -i "''${session[@]}" pipewire &
    pipewire_pid=$!
    env -i "''${session[@]}" wireplumber --profile nested &
    wireplumber_pid=$!
    for _ in {1..50}; do
      [ -S "$home/runtime/pipewire-0" ] && break
      sleep 0.1
    done

    # KWin hands its screenshot interface only to programs whose desktop file asks for it; nested-shot uses spectacle.
    cp ${kdePackages.spectacle}/share/applications/org.kde.spectacle.desktop "$home/.local/share/applications/"

    # The Nix defaults, as the module's package carries them; the user's own settings live in the session's HOME.
    printf '{"background":"%s"}\n' "$background" >"$home/defaults.json"

    # kwin_wayland starts its program without passing on any arguments, so the shell path goes into a launcher.
    launcher="$home/rekta-shell"
    printf '#!/bin/sh\nexport QML_IMPORT_PATH=%q REKTA_DEFAULTS=%q\nexec %q --path %q\n' "$shell_dir:${rekta-shell}/lib/qt-6/qml:${kdePackages.plasma-workspace}/lib/qt-6/qml:${kdePackages.kpipewire}/lib/qt-6/qml" "$home/defaults.json" "${rekta-shell.quickshell}/bin/quickshell" "$shell_dir" >"$launcher"
    chmod +x "$launcher"

    socket="rekta-nested"
    printf '%s\n' "''${session[@]}" "WAYLAND_DISPLAY=$socket" >"$home/session.env"

    echo "rekta-nested: shell from $shell_dir, HOME $home"
    # The effects take their values from the shell's Rekta module, and KWin's animation speed through KDE's Kirigami units.
    env -i "''${session[@]}" "''${host_display[@]}" QML_IMPORT_PATH="$shell_dir" QT_QUICK_CONTROLS_STYLE=org.kde.desktop \
      QT_PLUGIN_PATH=${rekta-shell}/lib/rekta-kwin/plugins kwin_wayland "''${backend[@]}" --socket "$socket" \
      --width "''${size%x*}" --height "''${size#*x}" --output-count "$outputs" \
      --no-lockscreen --no-global-shortcuts --no-kactivities \
      -- "$launcher" &
    kwin=$!
    wait "$kwin"
  '';
}
