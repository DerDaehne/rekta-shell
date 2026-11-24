{
  lib,
  writeShellApplication,
  writeTextDir,
  symlinkJoin,
  coreutils,
  gnugrep,
  jq,
  util-linux,
  systemd,
  at-spi2-core,
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
  # WirePlumber's own PipeWire context loads the realtime module, which falls back to RTKit on the system bus unless
  # the context has no D-Bus.
  wireplumberConfig = writeTextDir "wireplumber.conf.d/nested.conf" ''
    context.properties = {
      support.dbus = false
    }
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
# from an empty environment with its own HOME, runtime directory, config directories, a session and a system bus without
# service activation and a PipeWire without devices, so neither the desktop's plugins, config and services reach it nor
# does anything it starts (portals, wallets, FUSE mounts) reach the desktop.
writeShellApplication {
  name = "rekta-nested";
  runtimeInputs = [
    coreutils
    gnugrep
    jq
    util-linux
    systemd
  ];
  text = ''
    usage() {
      echo "usage: rekta-nested [--window] [--outputs N] [--size WIDTHxHEIGHT] [--background solid|rekta] [--touch-edges]" >&2
      echo "                    [--state FILE [--wait-ready] [--timeout SECONDS]] [--a11y]" >&2
      echo "  --touch-edges  let KWin take touch screen edges (it then also runs global shortcuts, on the session's own bus)" >&2
      echo "  --state FILE   keep the session's state as JSON in FILE while the session runs (not directly in /tmp or $TMPDIR)" >&2
      echo "  --wait-ready   run the session detached and return once its shell and effects stand (needs --state)" >&2
      echo "  --timeout S    stop the session if it is not ready after S seconds (default 120)" >&2
      echo "  --a11y         add an accessibility bus of the session's own, for AT-SPI probes" >&2
      exit 2
    }

    window=false
    outputs=1
    size=1600x900
    background=solid
    # Without global shortcuts KWin also installs no screen edge filter, so a finger at an edge never reaches an effect.
    global_shortcuts=(--no-global-shortcuts)
    state=""
    wait_ready=false
    timeout=120
    a11y=false
    original_args=("$@")
    while [ $# -gt 0 ]; do
      case "$1" in
        --window) window=true; shift ;;
        --outputs) outputs="''${2:?}"; shift 2 ;;
        --size) size="''${2:?}"; shift 2 ;;
        --background) background="''${2:?}"; shift 2 ;;
        --touch-edges) global_shortcuts=(); shift ;;
        --state) state="$(realpath -m "''${2:?}")"; shift 2 ;;
        --wait-ready) wait_ready=true; shift ;;
        --timeout) timeout="''${2:?}"; shift 2 ;;
        --a11y) a11y=true; shift ;;
        *) usage ;;
      esac
    done
    [[ "$outputs" =~ ^[1-9]$ ]] || usage
    [[ "$size" =~ ^[0-9]+x[0-9]+$ ]] || usage
    [[ "$background" =~ ^(rekta|solid)$ ]] || usage
    [[ "$timeout" =~ ^[1-9][0-9]*$ ]] || usage
    [ "$wait_ready" = false ] || [ -n "$state" ] || usage
    # The shell's file watcher rescans every directory it sees changing under /tmp, so the state file lives in a subdirectory.
    [ -z "$state" ] || [[ "$(dirname "$state")" != "$(realpath -m "''${TMPDIR:-/tmp}")" && "$(dirname "$state")" != /tmp ]] || usage

    # The session's script runs on in the background; every PID, Quickshell's included, comes from the state file.
    detach_and_wait() {
      rm -f "$state"
      REKTA_NESTED_DETACHED=1 setsid "$0" "''${original_args[@]}" >"$state.log" 2>&1 </dev/null &
      local session_pid=$!
      trap 'kill "$session_pid" 2>/dev/null; exit 130' INT TERM HUP
      until [ "$(jq -r .ready "$state" 2>/dev/null)" = true ]; do
        kill -0 "$session_pid" 2>/dev/null || { tail -n 20 "$state.log" >&2; exit 1; }
        sleep 0.2
      done
      cat "$state"
      exit 0
    }
    [ "$wait_ready" = false ] || [ -n "''${REKTA_NESTED_DETACHED:-}" ] || detach_and_wait

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
      local status=$?
      stop "''${kwin:-}"
      for shell_pid in $(quickshell_pids || true); do stop "$shell_pid"; done
      stop "''${a11y_launcher_pid:-}"
      stop "''${a11y_registry_pid:-}"
      stop "''${wireplumber_pid:-}"
      stop "''${pipewire_pid:-}"
      stop "''${system_bus_pid:-}"
      stop "''${bus_pid:-}"
      [ -z "$state" ] || rm -f "$state" "$state.tmp"
      # The log of a detached session is kept when it failed.
      [ "$status" -ne 0 ] && [ "$status" -ne 130 ] || [ -z "$state" ] || rm -f "$state.log"
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
      # Its programs log to its own stderr; only the AT-SPI bus's dbus-broker (--a11y) writes two lines to the desktop's journal.
      QT_FORCE_STDERR_LOGGING=1
    )
    [ -n "''${LOCALE_ARCHIVE:-}" ] && session+=(LOCALE_ARCHIVE="$LOCALE_ARCHIVE")

    start_bus() {
      env -i "''${session[@]}" dbus-daemon --config-file=${./nested-bus.xml} --address="unix:dir=$home/runtime" \
        --fork --print-address=1 --print-pid=1
    }
    mapfile -t bus < <(start_bus)
    bus_pid="''${bus[1]}"
    # A system bus of its own without services: a call to logind, UPower, NetworkManager or RTKit fails there at once
    # instead of reaching the host's, where it could change the host or have its bus start a service.
    mapfile -t system_bus < <(start_bus)
    system_bus_pid="''${system_bus[1]}"
    session+=(DBUS_SESSION_BUS_ADDRESS="''${bus[0]}" DBUS_SYSTEM_BUS_ADDRESS="''${system_bus[0]}")

    # What the state file reports; the shell and the effects are ready once all of these stand.
    rekta_effects='["rekta-fadeback","rekta-metahold","rekta-turnstile"]'
    session_bus() { busctl --address="''${bus[0]}" --json=short "$@" 2>/dev/null; }

    # Quickshell leaves KWin's process tree, but registers by PID in the session's own runtime directory.
    quickshell_pids() {
      local entry pid
      for entry in "$home"/runtime/quickshell/by-pid/*; do
        pid="$(basename "$entry")"
        grep -qzxF "XDG_RUNTIME_DIR=$home/runtime" "/proc/$pid/environ" 2>/dev/null && echo "$pid"
      done
      return 0
    }

    ipc_functions() {
      env -i "''${session[@]}" ${rekta-shell.quickshell}/bin/quickshell ipc --pid "$1" show 2>/dev/null |
        jq -Rnc 'reduce inputs as $line ({target: null, ipc: {}};
          if ($line | startswith("target ")) then .target = ($line | ltrimstr("target ")) | .ipc[.target] = []
          elif ($line | test("^\\s+function ")) then .ipc[.target] += [$line | sub("^\\s+function "; "")]
          else . end) | .ipc'
    }

    probe_session() {
      shell_pid=""
      effects='[]'
      ipc='{}'
      actions='[]'
      shell_pid="$(quickshell_pids | head -n 1)"
      [ -n "$shell_pid" ] || return 0
      effects="$(session_bus get-property org.kde.KWin /Effects org.kde.kwin.Effects loadedEffects |
        jq -c '[.data[] | select(startswith("rekta-"))]')" || effects='[]'
      ipc="$(ipc_functions "$shell_pid")" || ipc='{}'
      actions="$(session_bus call rekta.Actions /rekta/Actions rekta.Actions1 ListActions |
        jq -c '[.data[0][] | .[0]]')" || actions='[]'
      ready="$(jq -n --argjson want "$rekta_effects" --argjson e "$effects" --argjson i "$ipc" --argjson a "$actions" \
        '($want - $e | length == 0) and ($i | length > 0) and ($a | length > 0)')"
    }

    write_state() {
      jq -n --argjson ready "$ready" --arg home "$home" --arg socket "$socket" --arg a11y "$a11y_address" \
        --argjson nested "$$" --argjson kwin "''${kwin:-null}" --argjson quickshell "''${shell_pid:-null}" \
        --argjson pipewire "''${pipewire_pid:-null}" --argjson wireplumber "''${wireplumber_pid:-null}" \
        --argjson session_bus "$bus_pid" --argjson system_bus "$system_bus_pid" \
        --argjson a11y_launcher "''${a11y_launcher_pid:-null}" --argjson a11y_registry "''${a11y_registry_pid:-null}" \
        --arg session_address "''${bus[0]}" --arg system_address "''${system_bus[0]}" \
        --argjson effects "$effects" --argjson ipc "$ipc" --argjson actions "$actions" '{
          ready: $ready,
          home: $home,
          session_env: "\($home)/session.env",
          sockets: {wayland: "\($home)/runtime/\($socket)", pipewire: "\($home)/runtime/pipewire-0"},
          pids: {nested: $nested, kwin: $kwin, quickshell: $quickshell, pipewire: $pipewire, wireplumber: $wireplumber,
                 session_bus: $session_bus, system_bus: $system_bus, a11y_launcher: $a11y_launcher, a11y_registry: $a11y_registry},
          buses: {session: $session_address, system: $system_address, a11y: (if $a11y == "" then null else $a11y end)},
          effects: $effects, ipc: $ipc, actions: $actions}' >"$state.tmp"
      mv "$state.tmp" "$state"
    }

    # Writes the state until the shell and the effects stand; fails when KWin dies or the time is up.
    publish_state() {
      local deadline=$((SECONDS + timeout))
      while :; do
        ready=false
        probe_session
        write_state
        [ "$ready" = false ] || return 0
        kill -0 "$kwin" 2>/dev/null || return 1
        [ "$SECONDS" -lt "$deadline" ] || { echo "rekta-nested: not ready after ''${timeout}s" >&2; return 1; }
        sleep 0.5
      done
    }

    # The shell connects to PipeWire once, as it starts, so the socket has to be there before KWin starts the shell.
    env -i "''${session[@]}" pipewire &
    pipewire_pid=$!
    for _ in {1..50}; do
      [ -S "$home/runtime/pipewire-0" ] && break
      sleep 0.1
    done
    # WirePlumber quits if PipeWire's socket is not there yet.
    env -i "''${session[@]}" wireplumber --profile nested &
    wireplumber_pid=$!

    # A bus for AT-SPI of the session's own, in its runtime directory; the launcher tells clients its address on the
    # session bus.
    start_a11y() {
      env -i "''${session[@]}" ${at-spi2-core}/libexec/at-spi-bus-launcher --launch-immediately &
      a11y_launcher_pid=$!
      for _ in {1..50}; do
        a11y_address="$(session_bus call org.a11y.Bus /org/a11y/bus org.a11y.Bus GetAddress | jq -r '.data[0] // empty')"
        [ -z "$a11y_address" ] || break
        sleep 0.1
      done
      [ -n "$a11y_address" ] || return 1
      env -i "''${session[@]}" ${at-spi2-core}/libexec/at-spi2-registryd &
      a11y_registry_pid=$!
    }
    a11y_address=""
    if [ "$a11y" = true ]; then
      start_a11y || { echo "rekta-nested: no accessibility bus" >&2; exit 1; }
      session+=(QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1)
    fi

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
      --no-lockscreen "''${global_shortcuts[@]}" --no-kactivities \
      -- "$launcher" &
    kwin=$!
    [ -z "$state" ] || publish_state || exit 1
    wait "$kwin"
  '';
}
