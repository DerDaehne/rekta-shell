{ pkgs, self }:

let
  rekta-shell = self.packages.${pkgs.stdenv.hostPlatform.system}.rekta-shell;
  rekta-qmllint = pkgs.callPackage ./qmllint.nix { inherit (rekta-shell) quickshell; };
  dist = self.packages.${pkgs.stdenv.hostPlatform.system}.rekta-design-dist;
  qt = pkgs.kdePackages;
in
{
  package = rekta-shell;

  qmllint = pkgs.runCommand "rekta-shell-qmllint" { LANG = "C.UTF-8"; } ''
    find ${../shell} ${../tests} -name '*.qml' -print0 | xargs -0 ${pkgs.lib.getExe rekta-qmllint} -I ${../shell}
    touch $out
  '';

  tokens-drift =
    pkgs.runCommand "rekta-shell-tokens-drift" { nativeBuildInputs = [ pkgs.nodejs ]; }
      ''
        node ${../scripts/generate-tokens.mjs} ${dist} ${../shell} --check
        touch $out
      '';

  qml-tests =
    pkgs.runCommand "rekta-shell-qml-tests"
      {
        nativeBuildInputs = [ qt.qtdeclarative ];
        QT_QPA_PLATFORM = "offscreen";
        QT_PLUGIN_PATH = "${qt.qtbase}/lib/qt-6/plugins";
        QML_IMPORT_PATH = "${qt.qtdeclarative}/lib/qt-6/qml";
        LANG = "C.UTF-8";
      }
      ''
        export HOME="$TMPDIR"
        qmltestrunner -import ${../shell} -input ${../tests}
        touch $out
      '';

  formatting = pkgs.runCommand "rekta-shell-nixfmt" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
    find ${self} -name '*.nix' -print0 | xargs -0 nixfmt --check
    touch $out
  '';
}
