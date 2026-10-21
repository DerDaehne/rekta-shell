{ pkgs, self }:

let
  rekta-shell = self.packages.${pkgs.stdenv.hostPlatform.system}.rekta-shell;
  rekta-qmllint = pkgs.callPackage ./qmllint.nix { inherit (rekta-shell) quickshell; };
in
{
  package = rekta-shell;

  qmllint = pkgs.runCommand "rekta-shell-qmllint" { LANG = "C.UTF-8"; } ''
    find ${../shell} -name '*.qml' -print0 | xargs -0 ${pkgs.lib.getExe rekta-qmllint}
    touch $out
  '';

  formatting = pkgs.runCommand "rekta-shell-nixfmt" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
    find ${self} -name '*.nix' -print0 | xargs -0 nixfmt --check
    touch $out
  '';
}
