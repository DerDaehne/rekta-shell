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
        // lib.filterAttrs (_: value: value != null) { inherit (cfg) density startTempo searchEscape; };
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

    startTempo = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "fast"
          "rekta"
        ]
      );
      default = null;
      description = "How fast the Start opens, closes and turns: \"fast\" at twice Rekta's pace, \"rekta\" at Rekta's own. Null leaves it at \"fast\". It takes effect with the default package once the module is enabled, as the default that a \"startTempo\" in the user's ~/.config/rekta-shell/settings.json overrides.";
    };

    searchEscape = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "close"
          "back"
        ]
      );
      default = null;
      description = "What Escape does in the Start's search: \"close\" clears the search and closes the Start, \"back\" clears the search and goes back to the place before. Null leaves it at \"close\". It takes effect with the default package once the module is enabled, as the default that a \"searchEscape\" in the user's ~/.config/rekta-shell/settings.json overrides.";
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
