{
  config,
  lib,
  pkgs,
  ...
}:

# The session itself is system-wide and comes from the NixOS module; this is the place for per-user settings.
let
  cfg = config.programs.rekta-shell;
  shared = import ./shell-options.nix { inherit lib; };
in
{
  options.programs.rekta-shell = {
    enable = lib.mkEnableOption "rekta-shell in the user's profile";

    package = lib.mkOption {
      type = lib.types.package;
      # Built with this configuration's nixpkgs, so Quickshell shares Qt with Plasma. The same options and defaults as the
      # NixOS module's, so the profile's rekta-settings, which comes first in PATH, sees the same defaults.json.
      default = pkgs.callPackage ./package.nix { defaults = shared.defaultsOf cfg; };
      defaultText = lib.literalExpression "rekta-shell built with this configuration's pkgs";
      description = "The rekta-shell package.";
    };
  }
  // shared.options;

  config = lib.mkIf cfg.enable { home.packages = [ cfg.package ]; };
}
