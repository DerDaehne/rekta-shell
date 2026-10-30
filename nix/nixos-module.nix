{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.rekta-shell;
  shared = import ./shell-options.nix { inherit lib; };
in
{
  options.programs.rekta-shell = {
    enable = lib.mkEnableOption "the rekta session: Plasma's services with rekta-shell in place of plasmashell";

    package = lib.mkOption {
      type = lib.types.package;
      # Built with this system's nixpkgs, so Quickshell shares Qt with its Plasma.
      default = pkgs.callPackage ./package.nix { defaults = shared.defaultsOf cfg; };
      defaultText = lib.literalExpression "rekta-shell built with this system's pkgs";
      description = "The rekta-shell package; it carries the session, its user units and the plasmashell drop-in.";
    };
  }
  // shared.options;

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.desktopManager.plasma6.enable;
        message = "programs.rekta-shell runs on Plasma's services; enable services.desktopManager.plasma6 too.";
      }
    ];

    services.displayManager.sessionPackages = [ cfg.package ];
    systemd.packages = [ cfg.package ];
    # On the system's XDG data path, so the desktop entries the package brings are found.
    environment.systemPackages = [ cfg.package ];
  };
}
