{
  lib,
  writeShellApplication,
  runCommand,
  fetchurl,
  coreutils,
  qemu_kvm,
  cloud-utils,
  sourceIso,
}:

let
  # The Fedora 45 Beta image: a pre-release that stays on the mirror until Fedora 45 is released
  # (then it moves to releases/45/ under another name and hash). Plasma 6.8 is in no stable release yet.
  image = fetchurl {
    url = "https://dl.fedoraproject.org/pub/fedora/linux/releases/test/45_Beta/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-45_Beta-1.3.x86_64.qcow2";
    sha256 = "06bd4382a3bc5e5f94cd520f9ee15bdfb38d7bb72552b27fe06d581ba9a84292";
  };

  userData = builtins.toFile "user-data" ''
    #cloud-config
    users:
      - name: rekta
        plain_text_passwd: rekta
        lock_passwd: false
        shell: /bin/bash
        sudo: ALL=(ALL) NOPASSWD:ALL
    chpasswd:
      expire: false
    mounts:
      - [/dev/disk/by-label/REKTA_SRC, /mnt/rekta, iso9660, "ro,nofail"]
  '';

  metaData = builtins.toFile "meta-data" ''
    instance-id: rekta-fedora
    local-hostname: rekta-fedora
  '';

  seed = runCommand "rekta-fedora-seed.iso" { nativeBuildInputs = [ cloud-utils ]; } ''
    cloud-localds $out ${userData} ${metaData}
  '';
in
# Headless by default; --window opens QEMU's GTK window in the desktop.
writeShellApplication {
  name = "rekta-shell-fedora-vm";
  runtimeInputs = [
    coreutils
    qemu_kvm
  ];
  text = ''
    if [[ ! -f shell/shell.qml || ! -f flake.nix ]]; then
      echo "rekta-shell-fedora-vm: start it from the root of a rekta-shell checkout" >&2
      exit 1
    fi

    disk=""
    rpms=""
    display=(-display none)
    while [ $# -gt 0 ]; do
      case "$1" in
        --disk) disk=$(realpath -m "''${2:?--disk needs a file}"); shift 2 ;;
        --rpms) rpms=$(realpath "''${2:?--rpms needs a directory}"); shift 2 ;;
        --window) display=(-display gtk); shift ;;
        *) break ;;
      esac
    done

    # The overlay, the source ISO and whatever QEMU writes to HOME live only as long as the VM.
    state=$(mktemp -d)
    trap 'rm -rf "$state"' EXIT
    trap 'kill "''${qemu:-}" 2>/dev/null || true; wait "''${qemu:-}" 2>/dev/null || true; exit 130' INT TERM

    disk=''${disk:-$state/disk.qcow2}
    [ -e "$disk" ] || qemu-img create -q -f qcow2 -b ${image} -F qcow2 "$disk" 30G
    ${lib.getExe sourceIso} "$state/source.iso" ''${rpms:+"$rpms"}

    # An allow-list, so the host's QEMU_OPTS and friends never reach QEMU.
    vm_env=(HOME="$state" TMPDIR="$state" LANG="''${LANG:-C.UTF-8}")
    if [ "''${display[1]}" = gtk ]; then
      host_display="''${WAYLAND_DISPLAY:-wayland-0}"
      [[ "$host_display" == /* ]] || host_display="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is unset}/$host_display"
      vm_env+=(WAYLAND_DISPLAY="$host_display")
    fi

    serial=(-serial mon:stdio)
    for arg in "$@"; do [ "$arg" = -serial ] && serial=(); done

    # In the background so the traps can stop QEMU; stdin is handed on explicitly for -serial stdio.
    env -i "''${vm_env[@]}" qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 6G \
      -drive file="$disk",if=virtio \
      -drive file=${seed},media=cdrom,readonly=on \
      -drive file="$state/source.iso",media=cdrom,readonly=on \
      -nic user,model=virtio-net-pci \
      -device virtio-vga "''${display[@]}" "''${serial[@]}" "$@" <&0 &
    qemu=$!
    wait "$qemu"
  '';
}
