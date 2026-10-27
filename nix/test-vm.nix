{ modulesPath, pkgs, ... }:

{
  imports = [
    "${modulesPath}/virtualisation/qemu-vm.nix"
    ./nixos-module.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "26.11";

  virtualisation = {
    cores = 4;
    memorySize = 4096;
    qemu.forceAccel = true;
    # Without GL: with virtio-vga-gl and gtk,gl=on the VM often hung in the BIOS, and screendump cannot read GL scanouts.
    # Headless; the runner's --window adds a GTK window, and QEMU takes the last -display.
    qemu.options = [
      "-device virtio-vga"
      "-display none"
    ];
    sharedDirectories.rekta-shell = {
      source = ''"$REKTA_SHELL_DIR"'';
      target = "/mnt/rekta-shell/shell";
    };
  };

  services.desktopManager.plasma6.enable = true;
  programs.rekta-shell.enable = true;
  # BlueZ and System Settings' Bluetooth page, but no adapter: QEMU has none, and bluetoothd starts only once the
  # bluetooth module is loaded (`modprobe bluetooth`).
  hardware.bluetooth.enable = true;
  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
    autoLogin = {
      enable = true;
      user = "rekta";
    };
  };

  # Public test credentials: the VM has no forwarded ports, so nothing outside can log in. sudo asks for the same
  # password; spikes need root to read what session processes see.
  users.users.rekta = {
    isNormalUser = true;
    password = "rekta";
    extraGroups = [ "wheel" ];
  };

  environment.systemPackages = [
    pkgs.kdePackages.konsole
    pkgs.kdePackages.dolphin
    pkgs.kdePackages.kate
    pkgs.keepassxc
    pkgs.kdePackages.kdeconnect-kde
    (pkgs.python3.withPackages (python: [ python.dbus-next ]))
    pkgs.quickshell
  ];
}
