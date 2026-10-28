{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.rekta-shell;
in
{
  options.programs.rekta-shell = {
    enable = lib.mkEnableOption "the rekta session: Plasma's services with rekta-shell in place of plasmashell";

    package = lib.mkOption {
      type = lib.types.package;
      # Built with this system's nixpkgs, so Quickshell shares Qt with its Plasma.
      default = pkgs.callPackage ./package.nix {
        defaults = {
          inherit (cfg) background;
        }
        // lib.optionalAttrs (cfg.density != null) { inherit (cfg) density; };
      };
      defaultText = lib.literalExpression "rekta-shell built with this system's pkgs";
      description = "The rekta-shell package; it carries the session, its user units and the plasmashell drop-in.";
    };

    background = lib.mkOption {
      type = lib.types.enum [
        "rekta"
        "solid"
      ];
      default = "rekta";
      description = "What each monitor shows behind the windows: \"rekta\" is the colour bg with a faint print of tiles in the bottom right corner, \"solid\" the colour bg alone. It takes effect with the default package once the module is enabled, as the default that a \"background\" in the user's ~/.config/rekta-shell/settings.json overrides.";
    };

    density = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "comfortable"
          "compact"
        ]
      );
      default = null;
      description = "How much room the shell's controls take: \"comfortable\" (larger targets) or \"compact\". Null leaves it automatic: compact for a fine pointer. It takes effect with the default package once the module is enabled, as the default that a \"density\" in the user's ~/.config/rekta-shell/settings.json overrides.";
    };
  };

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
