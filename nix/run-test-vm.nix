{
  lib,
  writeShellApplication,
  coreutils,
  vm,
}:

# Headless by default; --window (before any QEMU arguments) opens QEMU's GTK window in the desktop.
writeShellApplication {
  name = "rekta-shell-test-vm";
  runtimeInputs = [ coreutils ];
  text = ''
    if [[ ! -f shell/shell.qml || ! -f flake.nix ]]; then
      echo "rekta-shell-test-vm: start it from the root of a rekta-shell checkout" >&2
      exit 1
    fi

    # The disk image, QEMU's runtime files and whatever QEMU writes to HOME live only as long as the VM.
    state=$(mktemp -d)
    trap 'rm -rf "$state"' EXIT
    trap 'kill "''${qemu:-}" 2>/dev/null || true; wait "''${qemu:-}" 2>/dev/null || true; exit 130' INT TERM

    # An allow-list, so the host's run-vm variables (SHARED_DIR, QEMU_OPTS, ...) never reach the VM.
    vm_env=(
      HOME="$state"
      TMPDIR="$state"
      USE_TMPDIR=1
      NIX_DISK_IMAGE="$state/test-vm.qcow2"
      REKTA_SHELL_DIR="$PWD/shell"
      LANG="''${LANG:-C.UTF-8}"
    )
    [ -n "''${LOCALE_ARCHIVE:-}" ] && vm_env+=(LOCALE_ARCHIVE="$LOCALE_ARCHIVE")

    display=()
    if [ "''${1:-}" = --window ]; then
      shift
      host_display="''${WAYLAND_DISPLAY:-wayland-0}"
      if [[ "$host_display" != /* && -z "''${XDG_RUNTIME_DIR:-}" ]]; then
        echo "rekta-shell-test-vm: WAYLAND_DISPLAY '$host_display' is relative and XDG_RUNTIME_DIR is unset, so the desktop's display cannot be found" >&2
        exit 1
      fi
      [[ "$host_display" == /* ]] || host_display="$XDG_RUNTIME_DIR/$host_display"
      vm_env+=(WAYLAND_DISPLAY="$host_display")
      display=(-display gtk)
    fi

    # In the background so the traps can stop QEMU; stdin is handed on explicitly for -serial stdio.
    env -i "''${vm_env[@]}" ${lib.getExe vm} "''${display[@]}" "$@" <&0 &
    qemu=$!
    wait "$qemu"
  '';
}
