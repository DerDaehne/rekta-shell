{
  config,
  lib,
  pkgs,
  ...
}:

# The session itself is system-wide and comes from the NixOS module; this is the place for per-user settings.
let
  cfg = config.programs.rekta-shell;
in
{
  options.programs.rekta-shell = {
    enable = lib.mkEnableOption "rekta-shell in the user's profile";

    package = lib.mkOption {
      type = lib.types.package;
      # Built with this configuration's nixpkgs, so Quickshell shares Qt with Plasma.
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "rekta-shell built with this configuration's pkgs";
      description = "The rekta-shell package.";
    };
  };

  config = lib.mkIf cfg.enable { home.packages = [ cfg.package ]; };
}
