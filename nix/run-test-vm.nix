{
  lib,
  writeShellApplication,
  vm,
}:

writeShellApplication {
  name = "rekta-shell-test-vm";
  text = ''
    if [[ ! -f shell/shell.qml || ! -f flake.nix ]]; then
      echo "rekta-shell-test-vm: start it from the root of a rekta-shell checkout" >&2
      exit 1
    fi

    # The disk image and QEMU's runtime files live only as long as the VM.
    state=$(mktemp -d)
    trap 'rm -rf "$state"' EXIT

    REKTA_SHELL_DIR=$PWD/shell NIX_DISK_IMAGE=$state/test-vm.qcow2 TMPDIR=$state USE_TMPDIR=1 \
      ${lib.getExe vm} "$@"
  '';
}
