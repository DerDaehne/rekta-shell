{ pkgs, modulesPath, ... }:

{
  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "26.11";

  virtualisation = {
    cores = 4;
    memorySize = 4096;
    qemu.forceAccel = true;
    # Without GL: with virtio-vga-gl and gtk,gl=on the VM often hung in the BIOS, and screendump cannot read GL scanouts.
    qemu.options = [
      "-device virtio-vga"
      "-display gtk"
    ];
    sharedDirectories.rekta-shell = {
      source = ''"$REKTA_SHELL_DIR"'';
      target = "/mnt/rekta-shell/shell";
    };
  };

  services.desktopManager.plasma6.enable = true;
  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
    autoLogin = {
      enable = true;
      user = "rekta";
    };
  };

  # Public test credentials: the VM has no forwarded ports, so nothing outside can log in.
  users.users.rekta = {
    isNormalUser = true;
    password = "rekta";
  };

  environment.systemPackages = [
    pkgs.kdePackages.konsole
    pkgs.kdePackages.dolphin
    pkgs.kdePackages.kate
    pkgs.quickshell
  ];
}
