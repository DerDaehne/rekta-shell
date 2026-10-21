{
  lib,
  writeShellApplication,
  coreutils,
  vm,
}:

writeShellApplication {
  name = "rekta-shell-test-vm";
  runtimeInputs = [ coreutils ];
  text = ''
    if [[ ! -f shell/shell.qml || ! -f flake.nix ]]; then
      echo "rekta-shell-test-vm: start it from the root of a rekta-shell checkout" >&2
      exit 1
    fi

    host_display="''${WAYLAND_DISPLAY:-wayland-0}"
    [[ "$host_display" == /* ]] || host_display="$XDG_RUNTIME_DIR/$host_display"

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
      WAYLAND_DISPLAY="$host_display"
      LANG="''${LANG:-C.UTF-8}"
    )
    [ -n "''${LOCALE_ARCHIVE:-}" ] && vm_env+=(LOCALE_ARCHIVE="$LOCALE_ARCHIVE")

    # In the background so the traps can stop QEMU; stdin is handed on explicitly for -serial stdio.
    env -i "''${vm_env[@]}" ${lib.getExe vm} "$@" <&0 &
    qemu=$!
    wait "$qemu"
  '';
}
