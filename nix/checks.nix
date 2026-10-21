{ pkgs, self }:

let
  rekta-shell = self.packages.${pkgs.stdenv.hostPlatform.system}.rekta-shell;
  qmlImportPath = "${rekta-shell.quickshell}/lib/qt-6/qml";
in
{
  package = rekta-shell;

  qmllint =
    pkgs.runCommand "rekta-shell-qmllint"
      {
        nativeBuildInputs = [ pkgs.kdePackages.qtdeclarative ];
        LANG = "C.UTF-8";
      }
      ''
        find ${../shell} -name '*.qml' -print0 | xargs -0 qmllint --max-warnings 0 -I ${qmlImportPath}
        touch $out
      '';

  formatting = pkgs.runCommand "rekta-shell-nixfmt" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
    find ${self} -name '*.nix' -print0 | xargs -0 nixfmt --check
    touch $out
  '';
}
